// Firebase app + Firestore (H2). Import this module only dynamically (import('...')) so the Firebase SDK
// stays out of the main bundle and a load failure never stops the rest of the mock.
import { getApp, getApps, initializeApp, type FirebaseApp } from 'firebase/app';
import { getFirestore, type Firestore } from 'firebase/firestore';
import { firebaseConfig } from './firebaseConfig';

export function firebaseApp(): FirebaseApp {
  return getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);
}

export function firestore(): Firestore {
  return getFirestore(firebaseApp());
}
