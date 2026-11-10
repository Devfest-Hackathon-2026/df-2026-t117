// Cloud Run の起動点。認証情報は実行時サービスアカウントの ADC を使う（鍵ファイルは使わない）。
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { loadConfig } from './config.js';
import { log } from './log.js';
import { createApp } from './server.js';
import { AlertStore, type FirestoreLike } from './store.js';
import { FirestoreTokenStore, type TokenFirestoreLike } from './tokens.js';

const config = loadConfig();
const app = initializeApp();
const db = getFirestore(app);

const server = createApp({
  config,
  store: new AlertStore(db as unknown as FirestoreLike, config),
  messaging: getMessaging(app),
  tokens: new FirestoreTokenStore(db as unknown as TokenFirestoreLike),
});

server.listen(config.port, () => {
  log('INFO', 'alert-ingest を起動しました', {
    port: config.port,
    topic: config.fcmTopic,
    demoAreaOverride: config.demoAreaOverride,
    targetAreaCodes: config.targetAreaCodes,
    allowedStatuses: config.allowedStatuses,
    maxWebTokens: config.maxWebTokens,
  });
});

function shutdown(signal: string): void {
  log('INFO', `${signal} を受けたので終了します`);
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 8_000).unref();
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
