// FCM registration (H2, S01). Loaded only with import() from platform/push.ts.
// Web clients cannot subscribe to an FCM topic themselves, so the token is written to Firestore
// (`fcmTokens/{auto id}`, create-only by the rules) and services/alert-ingest multicasts to the valid tokens.
// Anyone can write there, so a registration expires within 2 days (`expireAt`, removed by a TTL policy) and
// the mock registers again each time it is opened (a new document: updating is not allowed).
import { getMessaging, getToken, onMessage, type Messaging } from 'firebase/messaging';
import { addDoc, collection, serverTimestamp, Timestamp } from 'firebase/firestore';
import { firebaseApp, firestore } from './firebase';
import { VAPID_KEY } from './firebaseConfig';

/** The last registration ({ token, at }), to skip re-registering on quick reloads. */
const SAVED_KEY = 'tasuku.fcmRegistration';

/**
 * Lifetime of a registration. The rules allow at most request.time + 2 days; 47 h leaves 1 h for a device
 * clock that runs fast (the client cannot write "server time + 2 days" itself).
 */
export const REGISTRATION_TTL_MS = 47 * 60 * 60 * 1000;

/** Opening the mock again within this time does not add another registration for the same token. */
const REREGISTER_AFTER_MS = 60 * 60 * 1000;

let foregroundHooked = false;

function lastRegistration(): { token: string; at: number } | null {
  try {
    const v = JSON.parse(localStorage.getItem(SAVED_KEY) ?? 'null') as { token?: unknown; at?: unknown } | null;
    return v && typeof v.token === 'string' && typeof v.at === 'number' ? { token: v.token, at: v.at } : null;
  } catch {
    return null;
  }
}

function saveRegistration(token: string, at: number): void {
  try {
    localStorage.setItem(SAVED_KEY, JSON.stringify({ token, at }));
  } catch {
    /* private mode etc.: the mock just registers again next time (each registration expires anyway) */
  }
}

function platform(): string {
  const ua = navigator.userAgent;
  if (/Android/i.test(ua)) return 'web-android';
  if (/Mobi/i.test(ua)) return 'web-mobile';
  return 'web-desktop';
}

/**
 * Register the service worker, get the FCM token and store it in Firestore.
 * Notification permission must already be granted. `onForeground` is called for a message received while
 * the page is open: nothing is shown then (the Firestore subscription updates the app state).
 */
export async function registerPush(onForeground: () => void): Promise<string> {
  // Scope away from the app pages (as the Firebase default does): the worker only handles push.
  const registration = await navigator.serviceWorker.register('firebase-messaging-sw.js', {
    scope: 'firebase-cloud-messaging-push-scope',
  });
  const messaging: Messaging = getMessaging(firebaseApp());
  const token = await getToken(messaging, { vapidKey: VAPID_KEY, serviceWorkerRegistration: registration });
  if (!token || token.length < 20 || token.length > 1024) {
    throw new Error('FCM のトークンを取得できませんでした');
  }
  if (!foregroundHooked) {
    foregroundHooked = true;
    onMessage(messaging, () => onForeground());
  }
  const last = lastRegistration();
  const now = Date.now();
  if (!last || last.token !== token || now - last.at >= REREGISTER_AFTER_MS) {
    await addDoc(collection(firestore(), 'fcmTokens'), {
      token,
      createdAt: serverTimestamp(),
      platform: platform(),
      expireAt: Timestamp.fromMillis(now + REGISTRATION_TTL_MS),
    });
    saveRegistration(token, now);
  }
  return token;
}
