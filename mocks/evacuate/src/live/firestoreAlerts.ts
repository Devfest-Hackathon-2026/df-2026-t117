// Firestore subscription to the demo town's alerts (H2). Loaded only with import(), see platform/firebase.ts.
import { collection, limit, onSnapshot, orderBy, query } from 'firebase/firestore';
import { firestore } from '../platform/firebase';
import { DEMO_AREA_ID } from '../platform/firebaseConfig';
import { parseAlertDoc, type LiveAlertDoc } from './liveDoc';

/** How many of the most recently written alerts to read. The town's latest one is used. */
const RECENT = 5;

export interface AlertSubscriber {
  /** Called with the town's most recently written alert (null if none) on every snapshot. */
  next(latest: LiveAlertDoc | null, meta: { fromCache: boolean }): void;
  error(e: Error): void;
}

/**
 * Subscribe to `alerts` ordered by updatedAt (single-field index only, no composite index needed) and pick
 * the newest document of the demo town. Returns the unsubscribe function.
 */
export function subscribeDemoAlerts(sub: AlertSubscriber): () => void {
  const q = query(collection(firestore(), 'alerts'), orderBy('updatedAt', 'desc'), limit(RECENT));
  return onSnapshot(
    q,
    { includeMetadataChanges: true },
    (snap) => {
      let latest: LiveAlertDoc | null = null;
      for (const d of snap.docs) {
        const doc = parseAlertDoc(d.id, d.data());
        if (doc && doc.areaId === DEMO_AREA_ID) {
          latest = doc;
          break;
        }
      }
      sub.next(latest, { fromCache: snap.metadata.fromCache });
    },
    (e) => sub.error(e),
  );
}
