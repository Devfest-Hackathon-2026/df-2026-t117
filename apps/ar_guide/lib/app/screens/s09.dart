// S09 language picker (light). Apply sets + saves the language and goes back.
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../state/store.dart';
import '../state/types.dart';
import '../theme.dart';
import '_shared.dart';

const Dict _dict = {
  Lang.en: {'apply': 'Apply', 'note': 'Demo translations (not native-checked)'},
  Lang.ja: {'apply': '適用', 'note': 'デモ用の翻訳です（ネイティブ確認なし）'},
  Lang.zhHans: {'apply': '应用', 'note': '演示用翻译（未经母语审校）'},
  Lang.ko: {'apply': '적용', 'note': '데모용 번역(원어민 검수 없음)'},
  Lang.ar: {'apply': 'تطبيق', 'note': 'ترجمة تجريبية (لم يراجعها متحدث أصلي)'},
};

class S09Screen extends StatefulWidget {
  const S09Screen({super.key});

  @override
  State<S09Screen> createState() => _S09ScreenState();
}

class _S09ScreenState extends State<S09Screen> {
  Lang? _sel;

  void _apply(Lang lang) {
    final store = context.store;
    store.patch(StatePatch(lang: lang));
    saveLang(lang); // only an explicit user choice is remembered
    store.back();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.common;
    final t = context.t(_dict);
    final sel = _sel ?? context.lang;
    return SubLayout(
      theme: TkTheme.light,
      headerTitle: c.titleLanguage,
      title: c.titleLanguage,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          for (final l in langs)
            Directionality(
              textDirection: textDirectionOf(l),
              child: LightRow(
                selected: sel == l,
                onTap: () => setState(() => _sel = l),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        langNativeNames[l]!,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: sel == l ? FontWeight.w800 : FontWeight.w400,
                          color: TkColors.textOnLight,
                          locale: localeOf(l),
                        ),
                      ),
                    ),
                    if (sel == l) const Icon(Icons.check, size: 30, color: TkColors.textOnLight),
                  ],
                ),
              ),
            ),
        ],
      ),
      actions: BigButton(
        label: t['apply'],
        variant: BigButtonVariant.black,
        icon: Icons.check,
        onTap: () => _apply(sel),
      ),
      footer: FooterMeta(theme: TkTheme.light, items: [t['note']]),
    );
  }
}
