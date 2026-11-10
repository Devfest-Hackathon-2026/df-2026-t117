// Firebase behind one interface, so LiveAlerts can be tested and the app runs without google-services.json.
import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../i18n/i18n.dart';
import '../platform/notifications.dart';
import 'firebase_app.dart';
import 'live_doc.dart';
import 'push_text.dart';

/// The demo town's area id in `alerts/{EventID}.areaId` (services/alert-ingest AREA_ID).
const String demoAreaId = 'minato-bay';

/// The FCM topic the server sends the demo town's alerts to.
const String demoTopic = 'demo-minato-bay';

/// How many of the most recently written alerts to read. The town's latest one is used.
const int _recent = 5;

/// The town's most recently written alert (null if none) of one snapshot.
typedef LiveSnapshot = ({LiveAlertDoc? doc, bool fromCache});

abstract class LiveBackend {
  /// Throws when Firebase cannot be used (no google-services.json, for example).
  Future<void> init();

  Stream<LiveSnapshot> alerts();

  /// Asks for the notification permission. Does not need Firebase.
  Future<bool> requestNotifications();

  /// Subscribes to the topic. [onForeground] is called for each message received while the app is open.
  Future<void> registerPush(void Function() onForeground);
}

/// For tests that use their own store: never connects.
class NoLiveBackend implements LiveBackend {
  const NoLiveBackend();

  @override
  Future<void> init() async => throw StateError('no backend');

  @override
  Stream<LiveSnapshot> alerts() => const Stream.empty();

  @override
  Future<bool> requestNotifications() async => false;

  @override
  Future<void> registerPush(void Function() onForeground) async {}
}

/// Shows the alert for a data message while the app is closed or in the background. Foreground messages are
/// not shown: the app state is updated from Firestore (same as the web).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized();
  final content = pushContent(message.data, await loadNotificationLang());
  if (content != null) await LocalNotifier().showAlert(content);
}

class FirebaseLiveBackend implements LiveBackend {
  final _notifier = LocalNotifier();
  StreamSubscription<RemoteMessage>? _foreground;

  @override
  Future<void> init() async {
    await ensureFirebase();
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  }

  /// Ordered by updatedAt (single-field index only); picks the newest document of the demo town.
  @override
  Stream<LiveSnapshot> alerts() => FirebaseFirestore.instance
      .collection('alerts')
      .orderBy('updatedAt', descending: true)
      .limit(_recent)
      .snapshots(includeMetadataChanges: true)
      .map((snap) {
        LiveAlertDoc? latest;
        for (final d in snap.docs) {
          final data = d.data();
          final updatedAt = data['updatedAt'];
          final doc = parseAlertDoc(d.id, {...data, 'updatedAt': updatedAt is Timestamp ? updatedAt.millisecondsSinceEpoch : updatedAt});
          if (doc != null && doc.areaId == demoAreaId) {
            latest = doc;
            break;
          }
        }
        return (doc: latest, fromCache: snap.metadata.isFromCache);
      });

  @override
  Future<bool> requestNotifications() => _notifier.requestPermission();

  @override
  Future<void> registerPush(void Function() onForeground) async {
    await FirebaseMessaging.instance.subscribeToTopic(demoTopic);
    _foreground ??= FirebaseMessaging.onMessage.listen((_) => onForeground());
  }
}
