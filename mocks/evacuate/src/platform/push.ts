// Web Push support check and opt-in (H2, S01). No static Firebase import: the SDK is loaded on demand.
// iPhone / iPad: Web Push only works in a PWA added to the home screen, which this mock is not set up as.
// There the Firestore subscription alone keeps the app up to date and the button shows "not supported".

export type PushSupport = 'checking' | 'supported' | 'ios' | 'unsupported';
export type PushState = 'idle' | 'working' | 'enabled' | 'denied' | 'error';

export function isIos(): boolean {
  if (typeof navigator === 'undefined') return false;
  const ua = navigator.userAgent;
  // iPadOS reports itself as a Mac; touch support tells them apart.
  return /iPad|iPhone|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
}

export async function detectPushSupport(): Promise<PushSupport> {
  if (isIos()) return 'ios';
  if (typeof window === 'undefined' || !('Notification' in window) || !('serviceWorker' in navigator) || !('PushManager' in window)) {
    return 'unsupported';
  }
  try {
    const { isSupported } = await import('firebase/messaging');
    return (await isSupported()) ? 'supported' : 'unsupported';
  } catch {
    return 'unsupported';
  }
}

export function notificationPermission(): NotificationPermission | 'unsupported' {
  return typeof Notification === 'undefined' ? 'unsupported' : Notification.permission;
}

/**
 * Ask for notification permission (call from a user action: H00 or the demo panel button), then register.
 * The permission request comes first, before any await, so it runs inside the user gesture.
 */
export async function enablePush(onForeground: () => void): Promise<'enabled' | 'denied'> {
  const permission = Notification.permission === 'granted' ? 'granted' : await Notification.requestPermission();
  if (permission !== 'granted') return 'denied';
  // One registration at a time (a double click, or React StrictMode running the startup effect twice).
  inflight ??= import('./pushFirebase')
    .then(({ registerPush }) => registerPush(onForeground))
    .finally(() => {
      inflight = null;
    });
  await inflight;
  return 'enabled';
}

let inflight: Promise<string> | null = null;
