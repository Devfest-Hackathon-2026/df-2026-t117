// Firebase Web app config (H2). These values are meant to be embedded in a web app (not secrets),
// see architecture.md 10.3. Access is controlled by services/alert-ingest/firestore.rules.
// Analytics (measurementId) is intentionally not used.
// public/firebase-messaging-sw.js has its own copy (a static file outside the build): keep them in sync.

export const firebaseConfig = {
  apiKey: 'AIzaSyBp-2qW5UrPZNAsPkUr8p_5YDi7tlMWLYo',
  authDomain: 'devfest2026-oauthmountains.firebaseapp.com',
  projectId: 'devfest2026-oauthmountains',
  storageBucket: 'devfest2026-oauthmountains.firebasestorage.app',
  messagingSenderId: '190933809967',
  appId: '1:190933809967:web:cf79a5ecbca079e4c4bfda',
} as const;

/** Web Push certificate (VAPID) public key, for getToken. */
export const VAPID_KEY = 'BNGddgMcNncF-wDoMRrE44S2--LNuk31OZlga3XNjEHTki-SkkaJe4XVohrnWsRx8NdRsRm--8mwI9oerZJMcw8';

/** The demo town's area id in `alerts/{EventID}.areaId` (services/alert-ingest AREA_ID). */
export const DEMO_AREA_ID = 'minato-bay';
