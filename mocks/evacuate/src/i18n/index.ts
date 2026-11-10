// i18n foundation (implementation-plan.md 3.3).
// Screen-specific strings live in each screen file:
//   const t = useT({ en: {...}, ja: {...}, 'zh-Hans': {...}, ko: {...}, ar: {...} });
// Translations for zh-Hans / ko / ar are mock drafts, not native-checked (requirements 6.6).
import { useCallback } from 'react';
import type { Alert, EqSituation, L10n, Lang } from '../state/types';
import { actions, useAppState, useDispatch } from '../state/store';

export { LANGS, detectLang, loadLang, saveLang, isRtl, applyDocumentLang, isLang, matchLang } from './detect';
export type { Lang, L10n };

/** Native names for the language picker. */
export const LANG_NATIVE_NAMES: Record<Lang, string> = {
  en: 'English',
  ja: '日本語',
  'zh-Hans': '简体中文',
  ko: '한국어',
  ar: 'العربية',
};

/** BCP-47 tags for speechSynthesis etc. */
export const LANG_SPEECH_TAGS: Record<Lang, string> = {
  en: 'en-US',
  ja: 'ja-JP',
  'zh-Hans': 'zh-CN',
  ko: 'ko-KR',
  ar: 'ar-SA',
};

/** Current language (from the store). */
export function useLang(): Lang {
  return useAppState().lang;
}

/** Returns a setter that changes the language (App updates <html lang/dir>). Not persisted: S09 calls saveLang. */
export function useSetLang(): (lang: Lang) => void {
  const dispatch = useDispatch();
  return useCallback((lang: Lang) => dispatch(actions.patch({ lang })), [dispatch]);
}

export type Dict<K extends string> = Record<Lang, Record<K, string>>;

/** Pick the current language's strings from a 5-language dictionary (falls back to en). */
export function useT<K extends string>(dict: Dict<K>): Record<K, string> {
  const lang = useLang();
  return dict[lang] ?? dict.en;
}

/** Replace {name} placeholders: fmt('{n} m', { n: 40 }) -> '40 m' */
export function fmt(template: string, vars: Record<string, string | number>): string {
  return template.replace(/\{(\w+)\}/g, (m, k: string) => (k in vars ? String(vars[k]) : m));
}

/**
 * Place names: current language + Japanese (requirements 1, F25).
 * `ja` is null when the current language is Japanese (avoid duplication).
 */
export function bilingual(l10n: L10n, lang: Lang): { primary: string; ja: string | null } {
  if (lang === 'ja') return { primary: l10n.ja, ja: null };
  return { primary: l10n[lang] ?? l10n.en, ja: l10n.ja };
}

/** One-line form: "Hill Park / 高台公園" (or just "高台公園" in Japanese). */
export function bilingualText(l10n: L10n, lang: Lang, sep = ' / '): string {
  const b = bilingual(l10n, lang);
  return b.ja ? `${b.primary}${sep}${b.ja}` : b.primary;
}

// ---------------------------------------------------------------------------
// Common strings (buttons, headers, badges, meta lines)

export type CommonKey =
  | 'appName'
  | 'demo'
  | 'simulatedAlert'
  | 'listen'
  | 'onHighGround'
  | 'backToGuidance'
  | 'back'
  | 'close'
  | 'details'
  | 'officialUpdates'
  | 'evacuationMap'
  | 'savedMap'
  | 'openGuide'
  | 'shakingStopped'
  | 'changeLanguage'
  | 'emergencyCall'
  // header titles
  | 'titleHome'
  | 'titleLanguage'
  | 'titleEmergency'
  | 'titleLocation'
  | 'titleSavedMap'
  | 'titleArGuidance'
  | 'titleMapGuidance'
  | 'titlePermission'
  | 'titleAlertDetails'
  | 'titleGuides'
  | 'titleArticles'
  // badges / hazard names
  | 'badgeEarthquake'
  | 'badgeTsunami'
  | 'badgeTsunamiAdvisory'
  | 'badgeTsunamiWarning'
  | 'badgeMajorTsunamiWarning'
  | 'badgeTsunamiWarningActive'
  | 'badgeIndoors'
  | 'badgeOutdoors'
  | 'badgeInCar'
  | 'badgeOffline'
  | 'badgeSavedGuide'
  | 'badgeLocationUncertain'
  | 'badgeArPaused'
  // levels
  | 'levelAdvisory'
  | 'levelWarning'
  | 'levelEmergency'
  // meta / freshness
  | 'jma'
  | 'jst'
  | 'lastAlert'
  | 'stale'
  | 'routeUnverified'
  | 'liveRoadUnavailable'
  | 'passabilityChecked'
  | 'warningActive'
  | 'routeGuidancePaused'
  // map legend / labels
  | 'stripedHazard'
  | 'flagRefuge'
  | 'stepsOnRoute'
  | 'highGround'
  | 'sea'
  | 'map'
  // directions
  | 'left'
  | 'right'
  | 'straight'
  | 'meters'
  | 'translationNote';

export const common: Dict<CommonKey> = {
  en: {
    appName: 'TASUKU',
    demo: 'DEMO',
    simulatedAlert: 'SIMULATED ALERT',
    listen: 'Listen',
    onHighGround: 'On high ground',
    backToGuidance: 'Back to guidance',
    back: 'Back',
    close: 'Close',
    details: 'Details',
    officialUpdates: 'Official updates',
    evacuationMap: 'Evacuation map',
    savedMap: 'Saved map',
    openGuide: 'OPEN GUIDE',
    shakingStopped: 'Shaking stopped',
    changeLanguage: 'Change language',
    emergencyCall: 'Emergency call',
    titleHome: 'Home',
    titleLanguage: 'Language',
    titleEmergency: 'Emergency',
    titleLocation: 'Location',
    titleSavedMap: 'Saved map',
    titleArGuidance: 'AR guidance',
    titleMapGuidance: 'Map guidance',
    titlePermission: 'Location access',
    titleAlertDetails: 'Alert details',
    titleGuides: 'Disaster guides',
    titleArticles: 'Safety in Japan',
    badgeEarthquake: 'EARTHQUAKE',
    badgeTsunami: 'TSUNAMI',
    badgeTsunamiAdvisory: 'TSUNAMI ADVISORY',
    badgeTsunamiWarning: 'TSUNAMI WARNING',
    badgeMajorTsunamiWarning: 'MAJOR TSUNAMI WARNING',
    badgeTsunamiWarningActive: 'TSUNAMI WARNING ACTIVE',
    badgeIndoors: 'INDOORS',
    badgeOutdoors: 'OUTDOORS',
    badgeInCar: 'IN CAR',
    badgeOffline: 'OFFLINE',
    badgeSavedGuide: 'SAVED GUIDE',
    badgeLocationUncertain: 'LOCATION UNCERTAIN',
    badgeArPaused: 'AR PAUSED',
    levelAdvisory: 'Advisory',
    levelWarning: 'Warning',
    levelEmergency: 'Emergency warning',
    jma: 'JMA',
    jst: 'JST',
    lastAlert: 'Last alert',
    stale: 'Stale',
    routeUnverified: 'Route unverified',
    liveRoadUnavailable: 'Live road status unavailable',
    passabilityChecked: 'Passability checked',
    warningActive: 'Warning active',
    routeGuidancePaused: 'Route guidance paused',
    stripedHazard: 'Striped = hazard',
    flagRefuge: 'Flag = refuge',
    stepsOnRoute: 'Steps on route',
    highGround: 'HIGH GROUND',
    sea: 'SEA',
    map: 'MAP',
    left: 'Left',
    right: 'Right',
    straight: 'Straight',
    meters: '{n} m',
    translationNote: 'Demo translations (not native-checked)',
  },
  ja: {
    appName: 'TASUKU',
    demo: 'DEMO',
    simulatedAlert: '模擬アラート',
    listen: '読み上げ',
    onHighGround: '高台に着いた',
    backToGuidance: '案内に戻る',
    back: '戻る',
    close: '閉じる',
    details: '詳細',
    officialUpdates: '公式の続報',
    evacuationMap: '避難マップ',
    savedMap: '保存済みの地図',
    openGuide: '案内を開く',
    shakingStopped: '揺れがおさまった',
    changeLanguage: '言語を変更',
    emergencyCall: '緊急通報',
    titleHome: 'ホーム',
    titleLanguage: '言語',
    titleEmergency: '緊急通報',
    titleLocation: '現在地',
    titleSavedMap: '保存済みの地図',
    titleArGuidance: 'AR 案内',
    titleMapGuidance: '地図で案内',
    titlePermission: '位置情報の利用',
    titleAlertDetails: '警報の詳細',
    titleGuides: '災害別ガイド',
    titleArticles: '日本の防災',
    badgeEarthquake: '地震',
    badgeTsunami: '津波',
    badgeTsunamiAdvisory: '津波注意報',
    badgeTsunamiWarning: '津波警報',
    badgeMajorTsunamiWarning: '大津波警報',
    badgeTsunamiWarningActive: '津波警報 発表中',
    badgeIndoors: '屋内',
    badgeOutdoors: '屋外',
    badgeInCar: '車内',
    badgeOffline: 'オフライン',
    badgeSavedGuide: '保存済みの案内',
    badgeLocationUncertain: '位置が不確か',
    badgeArPaused: 'AR 停止中',
    levelAdvisory: '注意報',
    levelWarning: '警報',
    levelEmergency: '特別警報',
    jma: '気象庁',
    jst: 'JST',
    lastAlert: '最終の警報',
    stale: '古い情報',
    routeUnverified: 'ルート未確認',
    liveRoadUnavailable: '道路の最新状況は取得できません',
    passabilityChecked: '通行確認',
    warningActive: '警報 発表中',
    routeGuidancePaused: 'ルート案内を一時停止中',
    stripedHazard: '斜線 = 危険区域',
    flagRefuge: '旗 = 避難先',
    stepsOnRoute: '経路に階段あり',
    highGround: '高台',
    sea: '海',
    map: '地図',
    left: '左',
    right: '右',
    straight: '直進',
    meters: '{n} m',
    translationNote: 'デモ用の翻訳です（ネイティブ確認なし）',
  },
  'zh-Hans': {
    appName: 'TASUKU',
    demo: 'DEMO',
    simulatedAlert: '模拟警报',
    listen: '朗读',
    onHighGround: '已到高处',
    backToGuidance: '返回指引',
    back: '返回',
    close: '关闭',
    details: '详情',
    officialUpdates: '官方更新',
    evacuationMap: '避难地图',
    savedMap: '已保存地图',
    openGuide: '打开指引',
    shakingStopped: '摇晃已停止',
    changeLanguage: '更改语言',
    emergencyCall: '紧急电话',
    titleHome: '首页',
    titleLanguage: '语言',
    titleEmergency: '紧急求助',
    titleLocation: '位置',
    titleSavedMap: '已保存地图',
    titleArGuidance: 'AR 导航',
    titleMapGuidance: '地图导航',
    titlePermission: '位置权限',
    titleAlertDetails: '警报详情',
    titleGuides: '灾害指南',
    titleArticles: '日本防灾知识',
    badgeEarthquake: '地震',
    badgeTsunami: '海啸',
    badgeTsunamiAdvisory: '海啸注意报',
    badgeTsunamiWarning: '海啸警报',
    badgeMajorTsunamiWarning: '大海啸警报',
    badgeTsunamiWarningActive: '海啸警报生效中',
    badgeIndoors: '室内',
    badgeOutdoors: '室外',
    badgeInCar: '车内',
    badgeOffline: '离线',
    badgeSavedGuide: '已保存指南',
    badgeLocationUncertain: '位置不确定',
    badgeArPaused: 'AR 已暂停',
    levelAdvisory: '注意报',
    levelWarning: '警报',
    levelEmergency: '特别警报',
    jma: '日本气象厅',
    jst: 'JST',
    lastAlert: '最近警报',
    stale: '信息可能过时',
    routeUnverified: '路线未确认',
    liveRoadUnavailable: '无法获取实时路况',
    passabilityChecked: '通行确认于',
    warningActive: '警报生效中',
    routeGuidancePaused: '路线导航已暂停',
    stripedHazard: '斜线 = 危险区域',
    flagRefuge: '旗帜 = 避难处',
    stepsOnRoute: '路线上有台阶',
    highGround: '高地',
    sea: '海',
    map: '地图',
    left: '左转',
    right: '右转',
    straight: '直行',
    meters: '{n} 米',
    translationNote: '演示用翻译（未经母语审校）',
  },
  ko: {
    appName: 'TASUKU',
    demo: 'DEMO',
    simulatedAlert: '모의 경보',
    listen: '듣기',
    onHighGround: '고지대 도착',
    backToGuidance: '안내로 돌아가기',
    back: '뒤로',
    close: '닫기',
    details: '상세',
    officialUpdates: '공식 업데이트',
    evacuationMap: '대피 지도',
    savedMap: '저장된 지도',
    openGuide: '안내 열기',
    shakingStopped: '흔들림 멈춤',
    changeLanguage: '언어 변경',
    emergencyCall: '긴급 전화',
    titleHome: '홈',
    titleLanguage: '언어',
    titleEmergency: '긴급 신고',
    titleLocation: '위치',
    titleSavedMap: '저장된 지도',
    titleArGuidance: 'AR 안내',
    titleMapGuidance: '지도 안내',
    titlePermission: '위치 권한',
    titleAlertDetails: '경보 상세',
    titleGuides: '재난별 안내',
    titleArticles: '일본의 방재',
    badgeEarthquake: '지진',
    badgeTsunami: '쓰나미',
    badgeTsunamiAdvisory: '쓰나미 주의보',
    badgeTsunamiWarning: '쓰나미 경보',
    badgeMajorTsunamiWarning: '대형 쓰나미 경보',
    badgeTsunamiWarningActive: '쓰나미 경보 발령 중',
    badgeIndoors: '실내',
    badgeOutdoors: '실외',
    badgeInCar: '차 안',
    badgeOffline: '오프라인',
    badgeSavedGuide: '저장된 안내',
    badgeLocationUncertain: '위치 불확실',
    badgeArPaused: 'AR 일시정지',
    levelAdvisory: '주의보',
    levelWarning: '경보',
    levelEmergency: '특별경보',
    jma: '일본 기상청',
    jst: 'JST',
    lastAlert: '마지막 경보',
    stale: '오래된 정보',
    routeUnverified: '경로 미확인',
    liveRoadUnavailable: '실시간 도로 정보 없음',
    passabilityChecked: '통행 확인',
    warningActive: '경보 발령 중',
    routeGuidancePaused: '경로 안내 일시정지',
    stripedHazard: '빗금 = 위험 구역',
    flagRefuge: '깃발 = 대피소',
    stepsOnRoute: '경로에 계단 있음',
    highGround: '고지대',
    sea: '바다',
    map: '지도',
    left: '왼쪽',
    right: '오른쪽',
    straight: '직진',
    meters: '{n} m',
    translationNote: '데모용 번역(원어민 검수 없음)',
  },
  ar: {
    appName: 'TASUKU',
    demo: 'DEMO',
    simulatedAlert: 'تنبيه تجريبي',
    listen: 'استمع',
    onHighGround: 'وصلت إلى مكان مرتفع',
    backToGuidance: 'العودة إلى الإرشاد',
    back: 'رجوع',
    close: 'إغلاق',
    details: 'التفاصيل',
    officialUpdates: 'التحديثات الرسمية',
    evacuationMap: 'خريطة الإخلاء',
    savedMap: 'الخريطة المحفوظة',
    openGuide: 'افتح الدليل',
    shakingStopped: 'توقف الاهتزاز',
    changeLanguage: 'تغيير اللغة',
    emergencyCall: 'اتصال طوارئ',
    titleHome: 'الرئيسية',
    titleLanguage: 'اللغة',
    titleEmergency: 'الطوارئ',
    titleLocation: 'الموقع',
    titleSavedMap: 'الخريطة المحفوظة',
    titleArGuidance: 'إرشاد الواقع المعزز',
    titleMapGuidance: 'إرشاد بالخريطة',
    titlePermission: 'إذن الموقع',
    titleAlertDetails: 'تفاصيل التنبيه',
    titleGuides: 'أدلة الكوارث',
    titleArticles: 'السلامة في اليابان',
    badgeEarthquake: 'زلزال',
    badgeTsunami: 'تسونامي',
    badgeTsunamiAdvisory: 'إشعار تسونامي',
    badgeTsunamiWarning: 'تحذير تسونامي',
    badgeMajorTsunamiWarning: 'تحذير تسونامي كبير',
    badgeTsunamiWarningActive: 'تحذير تسونامي ساري',
    badgeIndoors: 'في الداخل',
    badgeOutdoors: 'في الخارج',
    badgeInCar: 'في السيارة',
    badgeOffline: 'غير متصل',
    badgeSavedGuide: 'دليل محفوظ',
    badgeLocationUncertain: 'الموقع غير مؤكد',
    badgeArPaused: 'الواقع المعزز متوقف',
    levelAdvisory: 'إشعار',
    levelWarning: 'تحذير',
    levelEmergency: 'تحذير طارئ',
    jma: 'وكالة الأرصاد اليابانية',
    jst: 'JST',
    lastAlert: 'آخر تنبيه',
    stale: 'معلومات قديمة',
    routeUnverified: 'المسار غير مؤكد',
    liveRoadUnavailable: 'حالة الطرق المباشرة غير متاحة',
    passabilityChecked: 'تم التحقق من الطريق',
    warningActive: 'التحذير ساري',
    routeGuidancePaused: 'إرشاد المسار متوقف مؤقتًا',
    stripedHazard: 'المخطط = منطقة خطر',
    flagRefuge: 'العلم = ملجأ',
    stepsOnRoute: 'درج على المسار',
    highGround: 'مكان مرتفع',
    sea: 'البحر',
    map: 'الخريطة',
    left: 'يسار',
    right: 'يمين',
    straight: 'إلى الأمام',
    meters: '{n} م',
    translationNote: 'ترجمة تجريبية (لم يراجعها متحدث أصلي)',
  },
};

/** Common strings for the current language. */
export function useCommon(): Record<CommonKey, string> {
  return useT(common);
}

/** Badge label for an alert (F02): e.g. TSUNAMI WARNING / MAJOR TSUNAMI WARNING / TSUNAMI ADVISORY / EARTHQUAKE. */
export function alertBadgeLabel(alert: Alert, lang: Lang): string {
  const c = common[lang];
  if (alert.type === 'earthquake') return c.badgeEarthquake;
  if (alert.level === 'emergency') return c.badgeMajorTsunamiWarning;
  if (alert.level === 'advisory') return c.badgeTsunamiAdvisory;
  return c.badgeTsunamiWarning;
}

/** Badge label for the earthquake situation (INDOORS / OUTDOORS / IN CAR). */
export function eqSituationLabel(s: EqSituation, lang: Lang): string {
  const c = common[lang];
  return s === 'indoors' ? c.badgeIndoors : s === 'outdoors' ? c.badgeOutdoors : c.badgeInCar;
}
