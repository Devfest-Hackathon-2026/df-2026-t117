// S04 route navigation: big turn arrow, "Right / 40 m", voice + vibration status, mini map, legend,
// "On high ground", passability line. All route values come from context.nav.
import 'package:flutter/material.dart';

import '../help/help_card.dart';
import '../i18n/i18n.dart';
import '../logic/nav.dart';
import '../logic/nav_effects.dart';
import '../raise_pictogram.dart';
import '../state/derive.dart';
import '../state/store.dart';
import '../state/time.dart';
import '../state/types.dart';
import '../theme.dart';
import '_shared.dart';

const Dict _dict = {
  Lang.en: {'demo': 'Demo', 'voiceOn': 'Voice guidance on', 'vibrationOn': 'Vibration on', 'vibrationVisual': 'Vibration (not supported on this device)', 'tilt': 'Raise for AR', 'tiltOn': 'Tilt on', 'mapLabel': 'Route map', 'arView': 'View in AR', 'arAria': 'View in AR (demo: simulates raising the phone)'},
  Lang.ja: {'demo': 'デモ', 'voiceOn': '音声案内オン', 'vibrationOn': '振動オン', 'vibrationVisual': '振動（この端末は非対応）', 'tilt': '持ち上げて AR', 'tiltOn': '傾き検知オン', 'mapLabel': 'ルートの地図', 'arView': 'AR で見る', 'arAria': 'AR で見る（デモ：端末を持ち上げた状態を再現）'},
  Lang.zhHans: {'demo': '演示', 'voiceOn': '语音导航已开启', 'vibrationOn': '振动已开启', 'vibrationVisual': '振动（此设备不支持）', 'tilt': '举起手机用 AR', 'tiltOn': '倾斜检测已开启', 'mapLabel': '路线地图', 'arView': '用 AR 查看', 'arAria': '用 AR 查看（演示：模拟举起手机）'},
  Lang.ko: {'demo': '데모', 'voiceOn': '음성 안내 켜짐', 'vibrationOn': '진동 켜짐', 'vibrationVisual': '진동(이 기기는 미지원)', 'tilt': '들어 올려 AR', 'tiltOn': '기울기 감지 켜짐', 'mapLabel': '경로 지도', 'arView': 'AR로 보기', 'arAria': 'AR로 보기(데모: 휴대폰을 들어 올린 상태를 재현)'},
  Lang.ar: {'demo': 'تجريبي', 'voiceOn': 'الإرشاد الصوتي مفعّل', 'vibrationOn': 'الاهتزاز مفعّل', 'vibrationVisual': 'الاهتزاز (غير مدعوم على هذا الجهاز)', 'tilt': 'ارفع الهاتف للواقع المعزز', 'tiltOn': 'كشف الإمالة مفعّل', 'mapLabel': 'خريطة المسار', 'arView': 'عرض بالواقع المعزز', 'arAria': 'عرض بالواقع المعزز (تجريبي: يحاكي رفع الهاتف)'},
};

class S04Screen extends StatelessWidget {
  const S04Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final lang = state.lang;
    final c = context.common;
    final nav = context.nav;
    final t = context.t(_dict);
    final direction = nav.nextTurn?.direction ?? TurnDirection.straight;
    final distanceM = nav.nextTurn?.distanceM ?? 0.0;
    final f = freshness(state);
    final checkedAt = f.passabilityCheckedAt;
    final footer = f.routeVerified && checkedAt != null
        ? ['${c.passabilityChecked} ${formatJstLabel(checkedAt)}', t['demo']]
        : [c.routeUnverified, t['demo']];
    // The web lets the arrow take the spare height (110-200 px); ScrollFill sizes by intrinsics, so use the screen.
    final arrowH = (MediaQuery.sizeOf(context).height - 640).clamp(110.0, 200.0);

    return ScrollFill(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TkHeader(accent: HeaderAccent.yellow),
          const AlertBand(),
          Expanded(
            child: Container(
              color: TkColors.red,
              padding: const EdgeInsets.symmetric(horizontal: TkSizes.gutter, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(alignment: AlignmentDirectional.centerStart, child: TkBadge(label: tsunamiBadge(state))),
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 4),
                    child: Center(child: TurnArrow(direction: direction, size: arrowH * 220 / 200)),
                  ),
                  Text(
                    directionLabel(direction, lang),
                    textAlign: TextAlign.center,
                    style: TkText.heading.copyWith(
                      color: TkColors.textOnDark,
                      fontSize: lang == Lang.en ? 64 : 54,
                      height: lang == Lang.en ? 1 : 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: AnnounceFlash(builder: (context, flash) => _StatusIcons(flash: flash, t: t)),
                          ),
                        ),
                      ),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          metersLabel(distanceM, lang),
                          style: TkText.heading.copyWith(color: TkColors.yellow, fontSize: 40, height: 1.1),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: canEnterAr(state) ? _ArButton(label: t['arView'], aria: t['arAria']) : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: TkSizes.gutter),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [TkColors.red, TkColors.red, TkColors.bgDark, TkColors.bgDark],
                stops: [0, 0.66, 0.66, 1],
              ),
            ),
            child: TownMap(semanticLabel: t['mapLabel']),
          ),
          ColoredBox(
            color: TkColors.bgDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(TkSizes.gutter, 8, TkSizes.gutter, 0),
                  child: MapLegend(items: [c.stripedHazard, if (nav.route.hasStairs) c.stepsOnRoute]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(TkSizes.gutter, 16, TkSizes.gutter, 0),
                  child: BigButton(
                    label: c.onHighGround,
                    variant: BigButtonVariant.white,
                    icon: Icons.flag_outlined,
                    onTap: () => context.store.patch(
                      const StatePatch(onHighGround: true, walk: WalkPatch(playing: false)),
                    ),
                  ),
                ),
                const HelpJaButton(padding: EdgeInsets.fromLTRB(TkSizes.gutter, 12, TkSizes.gutter, 0)),
                ListenButton(text: turnSpeech(lang, direction, distanceM)),
                FooterMeta(items: footer),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIcons extends StatelessWidget {
  const _StatusIcons({required this.flash, required this.t});

  final bool flash;
  final Tr t;

  @override
  Widget build(BuildContext context) {
    Widget icon(IconData data, String label) => Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: flash ? const Color(0x38FFFFFF) : Colors.transparent,
          ),
          child: Icon(data, size: 30, color: flash ? TkColors.yellow : TkColors.white, semanticLabel: label),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        icon(Icons.volume_up_rounded, t['voiceOn']),
        icon(Icons.vibration, t['vibrationOn']),
      ],
    );
  }
}

/// Demo shortcut: simulates raising the phone (deviceRaised).
class _ArButton extends StatelessWidget {
  const _ArButton({required this.label, required this.aria});

  final String label;
  final String aria;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: aria,
      excludeSemantics: true,
      child: IntrinsicMaxWidth(
        maxWidth: 104,
        child: Material(
          color: TkColors.yellow,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => context.store.patch(const StatePatch(deviceRaised: true)),
            child: Container(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44, maxWidth: 104),
              padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 10, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  if (RaisePhonePictogram.fitsBesideLabel(context)) const RaisePhonePictogram(),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: TkColors.bgDark, fontSize: 13, fontWeight: FontWeight.w800, height: 1.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
