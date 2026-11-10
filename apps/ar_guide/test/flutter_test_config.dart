// Runs before every test file under test/. The S04 AR button's pictogram loops forever, which would keep
// pumpAndSettle from returning; the suite settles with it still. raise_pictogram_test.dart turns it back on.
import 'dart:async';

import 'package:ar_guide/app/raise_pictogram.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  RaisePhonePictogram.debugDisableMotion = true;
  await testMain();
}
