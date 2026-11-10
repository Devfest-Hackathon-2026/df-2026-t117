// One Firebase.initializeApp for Live alerts and Remote Config (they start at the same time).
import 'package:firebase_core/firebase_core.dart';

Future<FirebaseApp>? _app;

/// Initializes the default Firebase app once. Throws when Firebase cannot be used (no google-services.json);
/// the next call tries again.
Future<FirebaseApp> ensureFirebase() {
  return _app ??= Firebase.initializeApp().catchError((Object e) {
    _app = null;
    throw e;
  });
}
