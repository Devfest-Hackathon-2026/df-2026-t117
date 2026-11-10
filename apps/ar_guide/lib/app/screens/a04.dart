// A04 disaster preparedness column (light): list -> detail inside the screen.
import 'package:flutter/material.dart';

import '../data/articles.dart';
import '../i18n/i18n.dart';
import '../state/store.dart';
import '../state/types.dart';
import '../theme.dart';
import '_shared.dart';

const Dict _dict = {
  Lang.en: {'list': 'All articles', 'note': 'General guidance, demo content'},
  Lang.ja: {'list': '記事一覧', 'note': '一般的な案内（デモ用）'},
  Lang.zhHans: {'list': '全部文章', 'note': '通用指引（演示内容）'},
  Lang.ko: {'list': '전체 글', 'note': '일반 안내(데모용)'},
  Lang.ar: {'list': 'كل المقالات', 'note': 'إرشادات عامة (محتوى تجريبي)'},
};

class A04Screen extends StatefulWidget {
  const A04Screen({super.key});

  @override
  State<A04Screen> createState() => _A04ScreenState();
}

class _A04ScreenState extends State<A04Screen> {
  Article? _article;

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
            ? [for (final p in article.body) Text(p[lang], style: t3Body)]
            : [
                for (final a in articles)
                  Material(
                    color: TkColors.lightCard,
                    borderRadius: radius,
                    child: InkWell(
                      borderRadius: radius,
                      onTap: () => setState(() => _article = a),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [
                            Text(a.title[lang], style: t3Heading),
                            Text(a.summary[lang], style: const TextStyle(fontSize: 16, color: TkColors.textMutedOnLight)),
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
