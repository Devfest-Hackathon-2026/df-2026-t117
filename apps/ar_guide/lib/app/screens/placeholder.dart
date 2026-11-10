// Shared placeholder used by not-yet-ported screens. Safe to delete once all screens are real.
import 'package:flutter/material.dart';

import '../state/types.dart';
import '../theme.dart';
import 'meta.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.id});

  final ScreenId id;

  @override
  Widget build(BuildContext context) {
    final meta = screenMeta[id]!;
    if (meta.kind == ScreenKind.sub) {
      return SubLayout(
        headerTitle: meta.name,
        theme: meta.theme,
        badge: const TkBadge(label: 'PLACEHOLDER', icon: Icons.schedule),
        title: id.label,
        subtitle: meta.name,
        footer: FooterMeta(theme: meta.theme, items: ['Placeholder', id.label]),
      );
    }
    final tone = switch (id) {
      ScreenId.s06 => GuidanceTone.maroon,
      ScreenId.s05 || ScreenId.h00 || ScreenId.s01 => GuidanceTone.grey,
      _ => GuidanceTone.red,
    };
    return GuidanceLayout(
      tone: tone,
      badge: TkBadge(label: ['PLACEHOLDER', id.label]),
      headline: id.label,
      subline: meta.name,
      footer: FooterMeta(items: ['Placeholder', id.label]),
    );
  }
}
