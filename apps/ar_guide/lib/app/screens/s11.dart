// S11 AR guidance: feeds the existing AR screen (lib/src/guide_screen.dart) from the app state.
// Same turn / distance / bearing as the web's S11 sends in its deep link.
import 'package:flutter/widgets.dart';

import '../../src/guide_params.dart' as ar;
import '../../src/guide_screen.dart';
import '../i18n/i18n.dart';
import '../logic/geometry.dart';
import '../logic/nav.dart';
import '../state/store.dart';

class S11Screen extends StatelessWidget {
  const S11Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.nav;
    final lang = context.lang;
    final next = nav.nextTurn;
    final dest = bilingual(nav.route.refuge.name, lang);
    // Way to walk now: towards the next turn (or the route end); along the segment when at the corner.
    final bearingDeg =
        next != null && dist(nav.position, next.point) > 1 ? bearing(nav.position, next.point) : nav.headingDeg;
    return GuideScreen(
      onBack: context.store.back,
      params: ar.GuideParams(
        turn: switch (next?.direction ?? TurnDirection.straight) {
          TurnDirection.left => ar.Turn.left,
          TurnDirection.right => ar.Turn.right,
          TurnDirection.straight => ar.Turn.straight,
        },
        distanceM: (next?.distanceM ?? 0).round(),
        dest: dest.primary,
        destJa: dest.ja,
        lang: lang,
        bearingDeg: bearingDeg,
        fromLink: true,
      ),
    );
  }
}
