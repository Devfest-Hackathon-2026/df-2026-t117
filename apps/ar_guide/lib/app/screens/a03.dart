// A03 disaster-type guide (light): Earthquake (3 situations) / Tsunami.
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../state/store.dart';
import '../state/types.dart';
import '../theme.dart';
import '_shared.dart';

const Dict _dict = {
  Lang.en: {'quake': 'Earthquake', 'tsunami': 'Tsunami', 'in': 'Indoors', 'inD': 'Drop, cover and hold on under a sturdy table. Stay away from windows.', 'out': 'Outdoors', 'outD': 'Move away from buildings, walls and glass. Protect your head.', 'car': 'In car', 'carD': 'Slow down and pull over to the left. Turn off the engine and stay inside until the shaking stops.', 'carAfter': 'After the shaking', 'carAfterD': 'Leave the key in the car, take your valuables and go on foot. Do not drive.', 't1': 'Go uphill now', 't1d': 'Move to high ground or a tall building right away.', 't2': 'Do not wait to see the wave', 't2d': 'Do not go to look at the sea. Waves can arrive within minutes.', 't3': 'Stay until the official all-clear', 't3d': 'Tsunami can come many times. Wait for the official announcement.', 'note': 'Short guide for the demo'},
  Lang.ja: {'quake': '地震', 'tsunami': '津波', 'in': '屋内', 'inD': '丈夫な机の下で頭を守り、揺れがおさまるまで動かない。窓から離れる。', 'out': '屋外', 'outD': '建物・塀・ガラスから離れ、頭を守る。', 'car': '車内', 'carD': 'ゆっくり減速して道路の左側に止め、エンジンを切る。揺れがおさまるまで車の中で待つ。', 'carAfter': '揺れがおさまったら', 'carAfterD': 'キーは付けたまま、貴重品を持って歩いて避難する。車では逃げない。', 't1': 'すぐ高台へ', 't1d': '高い場所や高い建物にすぐ移動する。', 't2': '波を見に行かない', 't2d': '海を見に行かない。数分で到達することがあります。', 't3': '解除まで戻らない', 't3d': '津波は何度も来ます。公式の解除発表を待つ。', 'note': 'デモ用の短い案内'},
  Lang.zhHans: {'quake': '地震', 'tsunami': '海啸', 'in': '室内', 'inD': '躲在坚固的桌下，保护头部，远离窗户。', 'out': '室外', 'outD': '远离建筑物、围墙和玻璃，保护头部。', 'car': '车内', 'carD': '慢慢减速，靠道路左侧停车并熄火。在车内等到摇晃停止。', 'carAfter': '摇晃停止后', 'carAfterD': '把钥匙留在车上，带上贵重物品步行避难。不要开车逃离。', 't1': '立即前往高处', 't1d': '马上前往高地或高楼。', 't2': '不要等着看海浪', 't2d': '不要去看海，海浪几分钟内就可能到达。', 't3': '等到官方解除', 't3d': '海啸可能多次袭来，请等待官方通知。', 'note': '演示用简要指南'},
  Lang.ko: {'quake': '지진', 'tsunami': '쓰나미', 'in': '실내', 'inD': '튼튼한 탁자 아래에서 머리를 보호하고 창문에서 떨어지세요.', 'out': '실외', 'outD': '건물, 담, 유리에서 떨어지고 머리를 보호하세요.', 'car': '차 안', 'carD': '천천히 속도를 줄여 도로 왼쪽에 세우고 시동을 끄세요. 흔들림이 멈출 때까지 차 안에서 기다리세요.', 'carAfter': '흔들림이 멈추면', 'carAfterD': '열쇠는 꽂아 둔 채 귀중품을 챙겨 걸어서 대피하세요. 차로 대피하지 마세요.', 't1': '바로 고지대로', 't1d': '높은 곳이나 높은 건물로 즉시 이동하세요.', 't2': '파도를 보러 가지 마세요', 't2d': '바다를 보러 가지 마세요. 몇 분 안에 도달할 수 있습니다.', 't3': '해제될 때까지 머무르기', 't3d': '쓰나미는 여러 번 올 수 있습니다. 공식 발표를 기다리세요.', 'note': '데모용 짧은 안내'},
  Lang.ar: {'quake': 'زلزال', 'tsunami': 'تسونامي', 'in': 'في الداخل', 'inD': 'احتمِ تحت طاولة متينة واحمِ رأسك وابتعد عن النوافذ.', 'out': 'في الخارج', 'outD': 'ابتعد عن المباني والجدران والزجاج واحمِ رأسك.', 'car': 'في السيارة', 'carD': 'خفف السرعة وتوقف على يسار الطريق وأطفئ المحرك. ابقَ داخل السيارة حتى يتوقف الاهتزاز.', 'carAfter': 'بعد توقف الاهتزاز', 'carAfterD': 'اترك المفتاح في السيارة وخذ أغراضك الثمينة وتوجه سيرًا على الأقدام. لا تقد السيارة.', 't1': 'اصعد إلى مكان مرتفع الآن', 't1d': 'توجه فورًا إلى مكان مرتفع أو مبنى عالٍ.', 't2': 'لا تنتظر رؤية الموجة', 't2d': 'لا تذهب لمشاهدة البحر؛ قد تصل الموجات خلال دقائق.', 't3': 'ابقَ حتى الإعلان الرسمي', 't3d': 'قد تأتي موجات متعددة. انتظر الإعلان الرسمي.', 'note': 'دليل مختصر للعرض'},
};

enum A03Tab { earthquake, tsunami }

A03Tab _initialTab = A03Tab.earthquake;

/// Set the tab A03 opens on next time (consumed once; no store change).
void setA03InitialTab(A03Tab tab) => _initialTab = tab;

class A03Screen extends StatefulWidget {
  const A03Screen({super.key});

  @override
  State<A03Screen> createState() => _A03ScreenState();
}

class _A03ScreenState extends State<A03Screen> {
  late A03Tab _tab;

  @override
  void initState() {
    super.initState();
    _tab = _initialTab;
    _initialTab = A03Tab.earthquake;
  }

  Widget _segment(A03Tab tab, String label) {
    final on = _tab == tab;
    return Expanded(
      child: Semantics(
        selected: on,
        child: Material(
          color: on ? TkColors.black : TkColors.lightCard,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => setState(() => _tab = tab),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: on ? TkColors.white : TkColors.textOnLight,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.common;
    final t = context.t(_dict);
    final items = _tab == A03Tab.earthquake
        ? [
            (PictogramKind.protectHead, t['in'], t['inD']),
            (PictogramKind.outdoorsProtect, t['out'], t['outD']),
            (PictogramKind.stayInCar, t['car'], t['carD']),
            (PictogramKind.getOutOfCar, t['carAfter'], t['carAfterD']),
          ]
        : [
            (PictogramKind.goUphill, t['t1'], t['t1d']),
            (PictogramKind.goUphill, t['t2'], t['t2d']),
            (PictogramKind.stayHere, t['t3'], t['t3d']),
          ];
    return SubLayout(
      theme: TkTheme.light,
      headerTitle: c.titleGuides,
      title: c.titleGuides,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Row(
            spacing: 10,
            children: [_segment(A03Tab.earthquake, t['quake']), _segment(A03Tab.tsunami, t['tsunami'])],
          ),
          for (final (picto, title, body) in items)
            LightCard(
              plain: true,
              children: [
                Row(
                  spacing: 14,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(color: TkColors.pictoBg, borderRadius: BorderRadius.circular(16)),
                      child: ExcludeSemantics(child: Pictogram(picto)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [Text(title, style: t3Heading), Text(body, style: t3Body)],
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
      footer: FooterMeta(theme: TkTheme.light, items: [t['note']]),
    );
  }
}
