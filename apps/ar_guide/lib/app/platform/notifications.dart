// Local notifications: the alert notification for FCM data messages (also from the background isolate) and
// the re-notification of the app. No Firebase here, so they work without google-services.json.
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../live/push_text.dart';

const _icon = '@mipmap/ic_launcher';

/// Long-short-long, as the service worker: Android takes [wait, on, off, on, ...].
final Int64List _alertVibration = Int64List.fromList([0, 400, 120, 400, 120, 400]);

/// Stable across isolates and runs (FNV-1a, 31 bits), so a follow-up replaces the notification of its alert.
int notificationId(String tag) {
  var h = 0x811c9dc5;
  for (final c in tag.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

class LocalNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings(_icon)));
    _ready = true;
  }

  /// POST_NOTIFICATIONS (Android 13+). Android shows no dialog when the user has refused for good.
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  AndroidNotificationDetails _alertChannel({StyleInformation? style, bool autoCancel = true}) => AndroidNotificationDetails(
        'tasuku_alerts',
        'TASUKU alerts',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        vibrationPattern: _alertVibration,
        icon: _icon,
        styleInformation: style,
        autoCancel: autoCancel,
      );

  /// Tapping any notification opens the app (the plugin's default content intent).
  Future<void> showAlert(PushContent c) async {
    await _init();
    final style = BigTextStyleInformation(c.body);
    // Vibration belongs to the channel on Android 8+, so an alert and a lift use different channels.
    final details = c.lifted
        ? AndroidNotificationDetails(
            'tasuku_updates',
            'TASUKU updates',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            enableVibration: false,
            icon: _icon,
            styleInformation: style,
          )
        : _alertChannel(style: style, autoCancel: !c.urgent);
    await _plugin.show(
      id: notificationId(c.tag),
      title: c.title,
      body: c.body,
      notificationDetails: NotificationDetails(android: details),
    );
  }

  /// The in-app re-notification (F88 / F89) and the demo panel's button.
  Future<void> showSimple(String title, String body) async {
    await _init();
    await _plugin.show(
      id: notificationId('tasuku-app'),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: _alertChannel()),
    );
  }
}
