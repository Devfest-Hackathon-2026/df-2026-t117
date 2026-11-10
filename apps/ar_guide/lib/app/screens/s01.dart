// S01 lock-screen notification: clock, SIMULATED ALERT, card with hazard names + rank-1 instruction.
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../state/derive.dart';
import '../state/store.dart';
import '../state/time.dart';
import '../state/types.dart';
import '../theme.dart';
import '_shared.dart';

const Dict _dict = {
  Lang.en: {'protect': 'Protect your head', 'car': 'Pull over. Stay inside.', 'outdoors': 'Protect your head', 'goNow': 'Go uphill NOW', 'go': 'Go uphill', 'stay': 'Stay here', 'check': 'Check updates'},
  Lang.ja: {'protect': '頭を守れ', 'car': '停車。車内で待つ。', 'outdoors': '頭を守れ', 'goNow': '今すぐ高台へ', 'go': '高台へ', 'stay': 'ここで待機', 'check': '情報を確認'},
  Lang.zhHans: {'protect': '保护头部', 'car': '靠边停车，留在车内', 'outdoors': '保护头部', 'goNow': '立即去高处', 'go': '去高处', 'stay': '留在这里', 'check': '查看最新信息'},
  Lang.ko: {'protect': '머리를 보호하세요', 'car': '정차하고 차 안에 머무르세요', 'outdoors': '머리를 보호하세요', 'goNow': '지금 바로 높은 곳으로', 'go': '높은 곳으로', 'stay': '여기에 머무르세요', 'check': '정보를 확인하세요'},
  Lang.ar: {'protect': 'احمِ رأسك', 'car': 'توقف وابقَ في السيارة', 'outdoors': 'احمِ رأسك', 'goNow': 'اصعد إلى مكان مرتفع الآن', 'go': 'اصعد إلى مكان مرتفع', 'stay': 'ابقَ هنا', 'check': 'تحقق من التحديثات'},
};

class S01Screen extends StatelessWidget {
  const S01Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final c = context.common;
    final t = context.t(_dict);
    final names = activeHazards(state).map((h) => h == HazardType.earthquake ? c.badgeEarthquake : c.badgeTsunami);
    final title = names.isNotEmpty ? names.join(' + ') : c.simulatedAlert;

    var picto = PictogramKind.protectHead;
    var text = t['check'];
    switch (topPriorityAction(state).kind) {
      case PriorityKind.protect:
        if (state.eqSituation == EqSituation.car) {
          picto = PictogramKind.stayInCar;
          text = t['car'];
        } else if (state.eqSituation == EqSituation.outdoors) {
          picto = PictogramKind.outdoorsProtect;
          text = t['outdoors'];
        } else {
          text = t['protect'];
        }
      case PriorityKind.goUphillNow:
        picto = PictogramKind.goUphill;
        text = t['goNow'];
      case PriorityKind.goUphill:
        picto = PictogramKind.goUphill;
        text = t['go'];
      case PriorityKind.stayHere:
        picto = PictogramKind.stayHere;
        text = t['stay'];
      default:
        break;
    }

    const simStyle = TextStyle(
      color: TkColors.textMutedOnDark,
      fontSize: 18,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
    );
    return ScrollFill(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(TkSizes.gutter, 40, TkSizes.gutter, 32),
        child: Column(
          children: [
            AnnounceOnEnter(text: '$title. $text'),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatJst(state.now),
                textDirection: TextDirection.ltr,
                style: TkText.heading.copyWith(fontSize: 104, height: 1, letterSpacing: -2),
              ),
            ),
            const SizedBox(height: 18),
            const Text('SIMULATED ALERT', style: simStyle),
            if (c.simulatedAlert != 'SIMULATED ALERT')
              Padding(padding: const EdgeInsets.only(top: 2), child: Text(c.simulatedAlert, style: simStyle)),
            const SizedBox(height: 32),
            Semantics(
              container: true,
              label: title,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: TkColors.white, borderRadius: BorderRadius.circular(28)),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: TkColors.textOnLight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(color: TkColors.red, borderRadius: BorderRadius.circular(18)),
                        child: Row(
                          spacing: 12,
                          children: [
                            const Icon(Icons.warning_rounded, size: 30, color: TkColors.white),
                            Expanded(
                              child: Text(
                                title.toUpperCase(),
                                style: const TextStyle(color: TkColors.white, fontSize: 19, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 170,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        decoration: BoxDecoration(color: TkColors.pictoBg, borderRadius: BorderRadius.circular(16)),
                        child: Pictogram(picto),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(text, textAlign: TextAlign.center, style: TkText.heading.copyWith(fontSize: 32)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: BigButton(
                          label: c.openGuide,
                          variant: BigButtonVariant.black,
                          onTap: () => context.store.patch(const StatePatch(lockScreen: false, overlay: [])),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
