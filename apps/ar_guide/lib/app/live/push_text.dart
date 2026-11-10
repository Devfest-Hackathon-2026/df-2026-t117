// Text of the alert notification, in 5 languages. Copied from mocks/evacuate/public/firebase-messaging-sw.js.
import '../i18n/i18n.dart';
import '../state/types.dart';

const Dict _pushText = {
  Lang.en: {
    'demo': '[DEMO]',
    'major-tsunami-warning': 'Major Tsunami Warning',
    'tsunami-warning': 'Tsunami Warning',
    'tsunami-advisory': 'Tsunami Advisory',
    'cleared': 'Tsunami alert lifted',
    'cancelled': 'Tsunami alert cancelled',
    'goNow': 'Go uphill NOW',
    'advisory': 'Get out of the water and away from the coast',
    'clearedBody': 'Stay alert. Check official updates.',
    'upgrade': 'Upgraded',
    'raise': 'Height raised',
    'height': 'Expected height',
    'huge': 'Huge',
    'high': 'High',
    'area': 'Minato Bay (fictional)',
  },
  Lang.ja: {
    'demo': '【デモ】',
    'major-tsunami-warning': '大津波警報',
    'tsunami-warning': '津波警報',
    'tsunami-advisory': '津波注意報',
    'cleared': '津波の警報・注意報は解除されました',
    'cancelled': '津波の情報は取り消されました',
    'goNow': '今すぐ高台へ',
    'advisory': '海から上がって、海岸から離れて',
    'clearedBody': '引き続き注意してください。公式の情報を確認してください。',
    'upgrade': '格上げ',
    'raise': '高さの引き上げ',
    'height': '予想される高さ',
    'huge': '巨大',
    'high': '高い',
    'area': 'みなと湾（架空）',
  },
  Lang.zhHans: {
    'demo': '【演示】',
    'major-tsunami-warning': '大海啸警报',
    'tsunami-warning': '海啸警报',
    'tsunami-advisory': '海啸注意报',
    'cleared': '海啸警报已解除',
    'cancelled': '海啸信息已取消',
    'goNow': '立即去高处',
    'advisory': '离开水中，远离海岸',
    'clearedBody': '请继续保持警惕，查看官方信息。',
    'upgrade': '已升级',
    'raise': '高度已上调',
    'height': '预计高度',
    'huge': '巨大',
    'high': '高',
    'area': '港湾（虚构）',
  },
  Lang.ko: {
    'demo': '[데모]',
    'major-tsunami-warning': '대쓰나미 경보',
    'tsunami-warning': '쓰나미 경보',
    'tsunami-advisory': '쓰나미 주의보',
    'cleared': '쓰나미 경보가 해제되었습니다',
    'cancelled': '쓰나미 정보가 취소되었습니다',
    'goNow': '지금 바로 높은 곳으로',
    'advisory': '물에서 나와 해안에서 떨어지세요',
    'clearedBody': '계속 주의하고 공식 정보를 확인하세요.',
    'upgrade': '격상',
    'raise': '높이 상향',
    'height': '예상 높이',
    'huge': '거대',
    'high': '높음',
    'area': '미나토만(가상)',
  },
  Lang.ar: {
    'demo': '[عرض تجريبي]',
    'major-tsunami-warning': 'تحذير من تسونامي كبير',
    'tsunami-warning': 'تحذير من تسونامي',
    'tsunami-advisory': 'إشعار تسونامي',
    'cleared': 'تم رفع تنبيه التسونامي',
    'cancelled': 'تم إلغاء تنبيه التسونامي',
    'goNow': 'اصعد إلى مكان مرتفع الآن',
    'advisory': 'اخرج من الماء وابتعد عن الساحل',
    'clearedBody': 'ابقَ متيقظًا وتحقق من التحديثات الرسمية.',
    'upgrade': 'تم الرفع',
    'raise': 'تم رفع الارتفاع',
    'height': 'الارتفاع المتوقع',
    'huge': 'هائل',
    'high': 'مرتفع',
    'area': 'خليج ميناتو (خيالي)',
  },
};

/// What to show for one FCM data message.
class PushContent {
  const PushContent({required this.title, required this.body, required this.tag, required this.lifted, required this.urgent});

  final String title;
  final String body;

  /// One notification per alert (EventID): a follow-up replaces it and alerts again.
  final String tag;

  /// Cleared or cancelled: shown without vibration.
  final bool lifted;

  /// A warning or major warning (not an advisory, not lifted).
  final bool urgent;
}

const _kinds = {'major-tsunami-warning', 'tsunami-warning', 'tsunami-advisory', 'cleared', 'cancelled'};

String? _height(Map<String, String> t, String? h) {
  if (h == null || h.isEmpty) return null;
  if (h == 'over10') return '> 10 m';
  if (h == 'huge') return t['huge'];
  if (h == 'high') return t['high'];
  return '$h m';
}

/// The notification for a data message (services/alert-ingest/README.md, "FCM の data"), or null when it is
/// not a tsunami message this app knows. Same rules as the service worker's onBackgroundMessage.
PushContent? pushContent(Map<String, dynamic> data, Lang lang) {
  String? s(String key) => data[key]?.toString();
  final kind = s('kind');
  if (s('type') != 'tsunami' || !_kinds.contains(kind)) return null;
  final t = _pushText[lang]!;
  final lifted = kind == 'cleared' || kind == 'cancelled';
  final lines = <String>[
    if (s('change') == 'upgrade') t['upgrade']!,
    if (s('change') == 'height-up') t['raise']!,
    if (lifted) t['clearedBody']! else if (s('level') == 'advisory') t['advisory']! else t['goNow']!,
  ];
  final h = _height(t, s('expectedHeight'));
  if (h != null && !lifted) lines.add('${t['height']}: $h');
  lines.add(t['area']!);
  final id = [s('alertId'), s('eventId')].firstWhere((v) => v != null && v.isNotEmpty, orElse: () => 'alert');
  return PushContent(
    title: '${t['demo']} ${t[kind]}',
    body: lines.join('\n'),
    tag: 'tasuku-$id',
    lifted: lifted,
    urgent: !lifted && s('level') != 'advisory',
  );
}
