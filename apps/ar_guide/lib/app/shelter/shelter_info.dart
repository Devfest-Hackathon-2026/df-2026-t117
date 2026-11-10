// Feature G: shelter reassurance for visitors from abroad, shown on S06 under the Listen button.
// Many visitors do not know they may enter a Japanese evacuation shelter. Three short facts, shown only
// (not read aloud: the S06 announcement stays the instruction itself). Strings: shelter_strings.dart.
// Self-contained so it can be removed with one line in s06.dart.
import 'package:flutter/material.dart';

import '../state/store.dart';
import '../state/types.dart';
import '../theme.dart';
import 'shelter_strings.dart';

class ShelterInfo extends StatelessWidget {
  const ShelterInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t(shelterDict);
    final lang = context.lang;
    const line = TextStyle(color: TkColors.textOnDark, fontSize: 16, fontWeight: FontWeight.w600, height: 1.35);
    return Padding(
      padding: const EdgeInsets.fromLTRB(TkSizes.gutter, 22, TkSizes.gutter, 0),
      child: Semantics(
        container: true, // one group for TalkBack; the visible heading names it
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: TkColors.btnDark,
            borderRadius: BorderRadius.circular(TkSizes.radiusCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Row(
                spacing: 10,
                children: [
                  const Icon(Icons.night_shelter_outlined, size: 26, color: TkColors.yellow),
                  Flexible(
                    child: Text(
                      t['title'],
                      style: const TextStyle(color: TkColors.textOnDark, fontSize: 19, fontWeight: FontWeight.w800, height: 1.25),
                    ),
                  ),
                  if (lang != Lang.ja)
                    Text(
                      shelterJapanese,
                      style: TkFonts.japaneseName.copyWith(
                        color: TkColors.textMutedOnDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              _Fact(icon: Icons.groups_outlined, text: t['free'], style: line),
              _Fact(icon: Icons.badge_outlined, text: t['passport'], style: line),
              _Fact(icon: Icons.translate, text: t['tellStaff'], style: line),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text, required this.style});

  final IconData icon;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 22, color: TkColors.textMutedOnDark),
          ),
          Expanded(child: Text(text, style: style)),
        ],
      );
}
