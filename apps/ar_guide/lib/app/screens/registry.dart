// Screen registry: ScreenId -> widget. Every screen already has its own file, so porting a screen
// means replacing the body of that file; this list does not need to change.
import 'package:flutter/widgets.dart';

import '../state/types.dart';
import 'a01.dart';
import 'a02.dart';
import 'a03.dart';
import 'a04.dart';
import 'h00.dart';
import 's01.dart';
import 's02.dart';
import 's03.dart';
import 's04.dart';
import 's05.dart';
import 's06.dart';
import 's07.dart';
import 's08.dart';
import 's09.dart';
import 's10.dart';
import 's11.dart';
import 's12.dart';

final Map<ScreenId, WidgetBuilder> screenBuilders = {
  ScreenId.s01: (_) => const S01Screen(),
  ScreenId.s02: (_) => const S02Screen(),
  ScreenId.s03: (_) => const S03Screen(),
  ScreenId.s04: (_) => const S04Screen(),
  ScreenId.s05: (_) => const S05Screen(),
  ScreenId.s06: (_) => const S06Screen(),
  ScreenId.s07: (_) => const S07Screen(),
  ScreenId.s08: (_) => const S08Screen(),
  ScreenId.s09: (_) => const S09Screen(),
  ScreenId.s10: (_) => const S10Screen(),
  ScreenId.s11: (_) => const S11Screen(),
  ScreenId.s12: (_) => const S12Screen(),
  ScreenId.h00: (_) => const H00Screen(),
  ScreenId.a01: (_) => const A01Screen(),
  ScreenId.a02: (_) => const A02Screen(),
  ScreenId.a03: (_) => const A03Screen(),
  ScreenId.a04: (_) => const A04Screen(),
};
