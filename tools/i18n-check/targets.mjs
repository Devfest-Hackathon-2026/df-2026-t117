// 点検する文の一覧。文そのものはここに書かず、Flutter アプリ（apps/ar_guide/lib/app）の辞書から読む。
//
// - file:   apps/ar_guide/lib/app からの相対パス
// - dict:   辞書（const）の名前（`Lang.xx: ...` を並べた 5 言語の辞書）
// - consts: 1 言語ずつ別の定数にした形（`const _en = S(...)`）のとき、言語 → 定数の名前。dict の代わり
// - label:  キーの表示名の頭（省略するとファイル名や辞書の名前）
// - keys:   点検するキー。省略するとその辞書の全キー
// - skip:   点検しないキー（ブランド名・略語など、訳さない文）
// - where:  その文が出る場所（Gemini に渡す文脈。日本語でよい）
//
// 誘導画面（S01〜S06）の文、S04 の方向ラベル、tools/voice/phrases.mjs で音声にしている文（S11 の
// turnAround を含む）、警報の用語（JMA の多言語辞書に合わせるべき語）を入れている。

export const TARGETS = [
  { file: 'screens/s01.dart', dict: '_dict', where: 'S01 ロック画面の通知（災害名のあとに出る最優先の指示）' },
  { file: 'screens/s02.dart', dict: '_dict', where: 'S02 地震の画面（屋内 / 屋外 / 車内）' },
  { file: 'screens/s03.dart', dict: '_dict', where: 'S03 津波の避難誘導（高台へ向かう）' },
  { file: 'screens/s05.dart', dict: '_dict', where: 'S05 津波の保存済みガイド（オフライン）' },
  { file: 'screens/s06.dart', dict: '_dict', where: 'S06 高台に着いた画面（ここで待機）' },
  { file: 'i18n/guide_strings.dart', dict: 'guideDict', where: '誘導画面の共通の指示' },
  { file: 'i18n/guide_strings.dart', dict: 'bandDict', where: '警報の格上げ・格下げの帯' },
  { file: 'i18n/guide_strings.dart', dict: 'cardDict', where: 'S06 の「ここで待つ理由」カード' },
  { file: 'i18n/guide_strings.dart', dict: 'heightDict', where: '予想される津波の高さ（定性的な表現。JMA の用語）' },
  { file: 'logic/effect_strings.dart', dict: 'notifyBodyDict', where: '警報が変わったときの再通知の本文' },
  { file: 'logic/effect_strings.dart', dict: 'turnSpeechDict', where: '経路案内の読み上げ（{n} は数値）' },
  { file: 'live/push_text.dart', dict: '_pushText', skip: ['demo', 'area'], where: '警報のプッシュ通知（警報名は JMA の用語）' },
  {
    file: 'i18n/common_strings.dart',
    dict: 'commonStrings',
    where: '共通の語（警報名のバッジ・警報の段階・状態表示）',
    keys: [
      'simulatedAlert',
      'onHighGround',
      'shakingStopped',
      'emergencyCall',
      'evacuationMap',
      'badgeEarthquake',
      'badgeTsunami',
      'badgeTsunamiAdvisory',
      'badgeTsunamiWarning',
      'badgeMajorTsunamiWarning',
      'badgeTsunamiWarningActive',
      'badgeIndoors',
      'badgeOutdoors',
      'badgeInCar',
      'badgeLocationUncertain',
      'levelAdvisory',
      'levelWarning',
      'levelEmergency',
      'warningActive',
      'routeGuidancePaused',
      'routeUnverified',
      'liveRoadUnavailable',
      'highGround',
    ],
  },
  {
    file: 'i18n/common_strings.dart',
    dict: 'commonStrings',
    where: 'S04 経路案内の大きな矢印の下に出る、曲がる方向のラベル（左 / 右 / 直進）',
    keys: ['left', 'right', 'straight'],
  },
  {
    file: '../src/strings.dart',
    consts: { en: '_en', ja: '_ja', 'zh-Hans': '_zh', ko: '_ko', ar: '_ar' },
    label: 's11',
    keys: ['turnAround'],
    where: 'S11 AR 案内（スマホのカメラ画面）。進む向きと逆を向いているときに出す指示',
  },
];

/** 訳の対象の言語（en が原文）。値は Cloud Translation API の言語コード。 */
export const TARGET_LANGS = { ja: 'ja', 'zh-Hans': 'zh-CN', ko: 'ko', ar: 'ar' };
