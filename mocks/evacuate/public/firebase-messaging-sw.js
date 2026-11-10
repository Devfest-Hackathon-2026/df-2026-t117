/* FCM service worker (H2): shows the lock-screen notification (S01) for a tsunami alert while the mock is
 * not in the foreground, and opens the mock when it is clicked.
 * A static file outside the Vite build, so it loads the Firebase SDK from the CDN with importScripts.
 * Keep the SDK version equal to "firebase" in package.json, and the config equal to src/platform/firebaseConfig.ts.
 * The server sends data-only messages (services/alert-ingest/README.md, "FCM の data"); the text is chosen here
 * in the browser's language. Messages received while the page is in the foreground are not shown (the app
 * state is updated from Firestore). */

// Before importScripts, so this handler sees the clicks of the notifications shown below.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = new URL('./', self.location.href).href;
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const client of list) {
        if (client.url.startsWith(url) && 'focus' in client) return client.focus();
      }
      return self.clients.openWindow(url);
    }),
  );
});

importScripts('https://www.gstatic.com/firebasejs/13.2.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/13.2.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBp-2qW5UrPZNAsPkUr8p_5YDi7tlMWLYo',
  authDomain: 'devfest2026-oauthmountains.firebaseapp.com',
  projectId: 'devfest2026-oauthmountains',
  storageBucket: 'devfest2026-oauthmountains.firebasestorage.app',
  messagingSenderId: '190933809967',
  appId: '1:190933809967:web:cf79a5ecbca079e4c4bfda',
});

const TEXT = {
  en: {
    demo: '[DEMO]',
    'major-tsunami-warning': 'Major Tsunami Warning',
    'tsunami-warning': 'Tsunami Warning',
    'tsunami-advisory': 'Tsunami Advisory',
    cleared: 'Tsunami alert lifted',
    cancelled: 'Tsunami alert cancelled',
    goNow: 'Go uphill NOW',
    advisory: 'Get out of the water and away from the coast',
    clearedBody: 'Stay alert. Check official updates.',
    upgrade: 'Upgraded',
    raise: 'Height raised',
    height: 'Expected height',
    huge: 'Huge',
    high: 'High',
    area: 'Minato Bay (fictional)',
  },
  ja: {
    demo: '【デモ】',
    'major-tsunami-warning': '大津波警報',
    'tsunami-warning': '津波警報',
    'tsunami-advisory': '津波注意報',
    cleared: '津波の警報・注意報は解除されました',
    cancelled: '津波の情報は取り消されました',
    goNow: '今すぐ高台へ',
    advisory: '海から上がって、海岸から離れて',
    clearedBody: '引き続き注意してください。公式の情報を確認してください。',
    upgrade: '格上げ',
    raise: '高さの引き上げ',
    height: '予想される高さ',
    huge: '巨大',
    high: '高い',
    area: 'みなと湾（架空）',
  },
  'zh-Hans': {
    demo: '【演示】',
    'major-tsunami-warning': '大海啸警报',
    'tsunami-warning': '海啸警报',
    'tsunami-advisory': '海啸注意报',
    cleared: '海啸警报已解除',
    cancelled: '海啸信息已取消',
    goNow: '立即去高处',
    advisory: '离开水中，远离海岸',
    clearedBody: '请继续保持警惕，查看官方信息。',
    upgrade: '已升级',
    raise: '高度已上调',
    height: '预计高度',
    huge: '巨大',
    high: '高',
    area: '港湾（虚构）',
  },
  ko: {
    demo: '[데모]',
    'major-tsunami-warning': '대쓰나미 경보',
    'tsunami-warning': '쓰나미 경보',
    'tsunami-advisory': '쓰나미 주의보',
    cleared: '쓰나미 경보가 해제되었습니다',
    cancelled: '쓰나미 정보가 취소되었습니다',
    goNow: '지금 바로 높은 곳으로',
    advisory: '물에서 나와 해안에서 떨어지세요',
    clearedBody: '계속 주의하고 공식 정보를 확인하세요.',
    upgrade: '격상',
    raise: '높이 상향',
    height: '예상 높이',
    huge: '거대',
    high: '높음',
    area: '미나토만(가상)',
  },
  ar: {
    demo: '[عرض تجريبي]',
    'major-tsunami-warning': 'تحذير من تسونامي كبير',
    'tsunami-warning': 'تحذير من تسونامي',
    'tsunami-advisory': 'إشعار تسونامي',
    cleared: 'تم رفع تنبيه التسونامي',
    cancelled: 'تم إلغاء تنبيه التسونامي',
    goNow: 'اصعد إلى مكان مرتفع الآن',
    advisory: 'اخرج من الماء وابتعد عن الساحل',
    clearedBody: 'ابقَ متيقظًا وتحقق من التحديثات الرسمية.',
    upgrade: 'تم الرفع',
    raise: 'تم رفع الارتفاع',
    height: 'الارتفاع المتوقع',
    huge: 'هائل',
    high: 'مرتفع',
    area: 'خليج ميناتو (خيالي)',
  },
};

function pickLang() {
  const l = String(self.navigator.language || 'en').toLowerCase();
  if (l.startsWith('ja')) return 'ja';
  if (l.startsWith('zh')) return 'zh-Hans';
  if (l.startsWith('ko')) return 'ko';
  if (l.startsWith('ar')) return 'ar';
  return 'en';
}

function heightText(t, h) {
  if (!h) return null;
  if (h === 'over10') return '> 10 m';
  if (h === 'huge') return t.huge;
  if (h === 'high') return t.high;
  return `${h} m`;
}

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const d = (payload && payload.data) || {};
  if (d.type !== 'tsunami' || !TEXT.en[d.kind]) return undefined;
  const lang = pickLang();
  const t = TEXT[lang];
  const lifted = d.kind === 'cleared' || d.kind === 'cancelled';
  const title = `${t.demo} ${t[d.kind]}`;
  const lines = [];
  if (d.change === 'upgrade') lines.push(t.upgrade);
  if (d.change === 'height-up') lines.push(t.raise);
  if (lifted) lines.push(t.clearedBody);
  else lines.push(d.level === 'advisory' ? t.advisory : t.goNow);
  const h = heightText(t, d.expectedHeight);
  if (h && !lifted) lines.push(`${t.height}: ${h}`);
  lines.push(t.area);
  return self.registration.showNotification(title, {
    body: lines.join('\n'),
    lang,
    dir: lang === 'ar' ? 'rtl' : 'auto',
    // One notification per alert (EventID): a follow-up replaces it and alerts again.
    tag: `tasuku-${d.alertId || d.eventId || 'alert'}`,
    renotify: true,
    requireInteraction: !lifted && d.level !== 'advisory',
    vibrate: lifted ? undefined : [400, 120, 400, 120, 400],
    data: { alertId: d.alertId || null },
  });
});
