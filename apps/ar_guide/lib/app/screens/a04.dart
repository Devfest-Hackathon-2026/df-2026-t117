// A04 disaster preparedness column (light): list -> detail inside the screen.
// New safety tips come first with a "new" tag and their pictogram; H00 can open one directly.
import 'package:flutter/material.dart';

import '../data/articles.dart';
import '../i18n/i18n.dart';
import '../state/store.dart';
import '../state/types.dart';
import '../theme.dart';
import '_shared.dart';

const Dict _dict = {
  Lang.en: {'list': 'All articles', 'note': 'General guidance, demo content', 'new': 'NEW'},
  Lang.ja: {'list': '記事一覧', 'note': '一般的な案内（デモ用）', 'new': '新着'},
  Lang.zhHans: {'list': '全部文章', 'note': '通用指引（演示内容）', 'new': '新'},
  Lang.ko: {'list': '전체 글', 'note': '일반 안내(데모용)', 'new': '새 글'},
  Lang.ar: {'list': 'كل المقالات', 'note': 'إرشادات عامة (محتوى تجريبي)', 'new': 'جديد'},
};

/// Exposed for the key-parity test.
const Dict a04Dict = _dict;

/// Pictogram shown with an article (list row and detail), reusing the guidance artwork.
const Map<String, PictogramKind> articlePicto = {
  'advisory-30cm': PictogramKind.goUphill,
  'leave-car': PictogramKind.getOutOfCar,
};

/// New articles first, then the rest in their original order.
List<Article> get orderedArticles => [...articles.where((a) => a.isNew), ...articles.where((a) => !a.isNew)];

String? _initialArticleId;

/// Open A04 on this article next time (consumed once; no store change), like [setA03InitialTab].
void setA04InitialArticle(String id) => _initialArticleId = id;

class A04Screen extends StatefulWidget {
  const A04Screen({super.key});

  @override
  State<A04Screen> createState() => _A04ScreenState();
}

class _A04ScreenState extends State<A04Screen> {
  Article? _article;

  @override
  void initState() {
    super.initState();
    final id = _initialArticleId;
    _initialArticleId = null;
    if (id != null) _article = articles.where((a) => a.id == id).firstOrNull;
  }

  void _close() => setState(() => _article = null);

  @override
  Widget build(BuildContext context) {
    final c = context.common;
    final lang = context.lang;
    final t = context.t(_dict);
    final article = _article;
    final radius = BorderRadius.circular(TkSizes.radiusCard);
    return SubLayout(
      theme: TkTheme.light,
      headerTitle: c.titleArticles,
      onBack: article != null ? _close : null,
      title: article != null ? article.title[lang] : c.titleArticles,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: article != null
            ? [
                if (articlePicto[article.id] case final picto?) _PictoBox(picto: picto, height: 140),
                for (final p in article.body) Text(p[lang], style: t3Body),
              ]
            : [
                for (final a in orderedArticles)
                  Material(
                    color: TkColors.lightCard,
                    borderRadius: radius,
                    child: InkWell(
                      borderRadius: radius,
                      onTap: () => setState(() => _article = a),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 14,
                          children: [
                            if (articlePicto[a.id] case final picto?)
                              SizedBox(width: 64, child: _PictoBox(picto: picto, height: 64)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 4,
                                children: [
                                  if (a.isNew)
                                    TkBadge(label: t['new'], icon: Icons.fiber_new_outlined, small: true),
                                  Text(a.title[lang], style: t3Heading),
                                  Text(a.summary[lang], style: const TextStyle(fontSize: 16, color: TkColors.textMutedOnLight)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
      ),
      actions: article != null
          ? BigButton(label: t['list'], variant: BigButtonVariant.black, icon: Icons.arrow_back, onTap: _close)
          : null,
      footer: FooterMeta(theme: TkTheme.light, items: [t['note'], c.translationNote]),
    );
  }
}

class _PictoBox extends StatelessWidget {
  const _PictoBox({required this.picto, required this.height});

  final PictogramKind picto;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: TkColors.pictoBg, borderRadius: BorderRadius.circular(14)),
        child: ExcludeSemantics(child: Pictogram(picto)),
      );
}
