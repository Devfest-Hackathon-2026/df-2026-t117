// 音声ファイルにする固定の指示文の一覧（H6）。
// 文そのものはここに書かず、モックのソース（画面ごとの辞書）から取り出す。辞書の文を直したら
// `node tools/voice/generate.mjs` を流せば、ハッシュが変わった文だけ作り直される。
//
// - file: mocks/evacuate からの相対パス
// - dict: 'useT' ならそのファイルで最初の useT({...}) の引数。それ以外は、その名前の const の初期値
// - prop: 辞書のキー
// - key:  音声ファイルの名前（public/voice/<lang>/<key>.mp3）
//
// 載せるのは、読み上げ（useAnnounceOnEnter / ListenButton）で実際に読む文のうち、数値を含まないものだけ。
// 「Turn right in 40 meters.」や標高・余裕の文は数値が入るので載せない（Web Speech API で読む）。

export const PHRASES = [
  // S01 ロック画面の通知: 「<災害名>. <指示>」
  { key: 's01.protect', file: 'src/screens/S01.tsx', dict: 'useT', prop: 'protect' },
  { key: 's01.car', file: 'src/screens/S01.tsx', dict: 'useT', prop: 'car' },
  { key: 's01.goNow', file: 'src/screens/S01.tsx', dict: 'useT', prop: 'goNow' },
  { key: 's01.go', file: 'src/screens/S01.tsx', dict: 'useT', prop: 'go' },
  { key: 's01.stay', file: 'src/screens/S01.tsx', dict: 'useT', prop: 'stay' },
  { key: 's01.check', file: 'src/screens/S01.tsx', dict: 'useT', prop: 'check' },
  { key: 'common.earthquake', file: 'src/i18n/index.ts', dict: 'common', prop: 'badgeEarthquake' },
  { key: 'common.tsunami', file: 'src/i18n/index.ts', dict: 'common', prop: 'badgeTsunami' },
  { key: 'common.simulatedAlert', file: 'src/i18n/index.ts', dict: 'common', prop: 'simulatedAlert' },
  // S02 地震（屋内 / 屋外 / 車内待機）
  { key: 's02.protect', file: 'src/screens/S02.tsx', dict: 'useT', prop: 'indoors' },
  { key: 's02.outdoorsSub', file: 'src/screens/S02.tsx', dict: 'useT', prop: 'outdoorsSub' },
  { key: 's02.car', file: 'src/screens/S02.tsx', dict: 'useT', prop: 'car' },
  { key: 's02.carSub', file: 'src/screens/S02.tsx', dict: 'useT', prop: 'carSub' },
  // S03 / S05 津波（車を降りる）
  { key: 's03.goUphill', file: 'src/screens/S03.tsx', dict: 'useT', prop: 'headline' },
  { key: 's03.now', file: 'src/screens/S03.tsx', dict: 'useT', prop: 'now' },
  { key: 's03.leaveCar', file: 'src/screens/S03.tsx', dict: 'useT', prop: 'leaveCar' },
  { key: 's05.goUphill', file: 'src/screens/S05.tsx', dict: 'useT', prop: 'headline' },
  { key: 's05.leaveCar', file: 'src/screens/S05.tsx', dict: 'useT', prop: 'leaveCar' },
  // FB2 / FB4: もっと高い所へ、青い標識に従う
  { key: 'guide.goHigher', file: 'src/screens/_alertShared.tsx', dict: 'guideDict', prop: 'goHigher' },
  { key: 'guide.followSigns', file: 'src/screens/_alertShared.tsx', dict: 'guideDict', prop: 'followSigns' },
  // S06 高台（FB2: 指定避難所では係員の指示に従う）
  { key: 's06.stayHere', file: 'src/screens/S06.tsx', dict: 'useT', prop: 'headline' },
  { key: 'common.highGround', file: 'src/i18n/index.ts', dict: 'common', prop: 'highGround' },
  { key: 'margin.staff', file: 'src/screens/_alertShared.tsx', dict: 'cardDict', prop: 'staff' },
  // S11 後ろを向く（H5）
  { key: 's11.turnAround', file: 'src/screens/S11.tsx', dict: 'useT', prop: 'turnAround' },
];

/** モックの言語 → Text-to-Speech の言語コード。 */
export const LANGS = {
  en: 'en-US',
  ja: 'ja-JP',
  'zh-Hans': 'cmn-CN',
  ko: 'ko-KR',
  ar: 'ar-XA',
};

/** 使いたい声（Chirp 3 HD）。その言語にない場合は、その言語の Chirp 3 HD の声の先頭を使う。 */
export const PREFERRED_VOICE = 'Kore';

/** 出力の形式。文のハッシュに含めるので、変えると全部作り直しになる。 */
export const AUDIO_CONFIG = { audioEncoding: 'MP3', sampleRateHertz: 24000 };
