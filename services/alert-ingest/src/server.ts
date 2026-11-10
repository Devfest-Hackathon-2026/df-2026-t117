// HTTP の受け口。認証はアプリでは行わず、Cloud Run の IAM（--no-allow-unauthenticated）で守る。
import { createServer, type IncomingMessage, type Server, type ServerResponse } from 'node:http';
import { ingest, type IngestDeps, type IngestResult } from './ingest.js';
import { log } from './log.js';

class BodyTooLargeError extends Error {}

function readBody(req: IncomingMessage, maxBytes: number): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    let size = 0;
    req.on('data', (chunk: Buffer) => {
      size += chunk.length;
      if (size > maxBytes) {
        req.removeAllListeners('data');
        req.resume();
        reject(new BodyTooLargeError());
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

function send(res: ServerResponse, status: number, body: unknown): void {
  const json = JSON.stringify(body);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  });
  res.end(json);
}

const STATUS: Record<IngestResult['result'], number> = {
  sent: 200,
  'sent-unrecorded': 200,
  duplicate: 200,
  superseded: 200,
  ignored: 200,
  // 別の処理が送っている途中。その処理が落ちていることもあるので、送信元には再送させる。
  'in-progress': 503,
  // FCM には送ったが記録を書けなかった。記録と基準をそろえるため、送信元に再送させる。
  'sent-unconfirmed': 503,
  invalid: 400,
  failed: 502,
};

/** レスポンスには状態の要約だけを返す。 */
function summarize(r: IngestResult): Record<string, unknown> {
  if (r.result === 'sent' || r.result === 'sent-unrecorded') {
    const s = r.state;
    return {
      result: r.result,
      key: r.key,
      messageId: r.messageId,
      kind: s.kind,
      level: s.level,
      change: s.change,
      maxHeight: s.maxHeight,
      arrivalTime: s.arrivalTime,
      webPush: r.webPush,
    };
  }
  return { ...r };
}

export function createApp(deps: IngestDeps): Server {
  return createServer(async (req, res) => {
    const path = (req.url ?? '/').split('?')[0];
    try {
      if (req.method === 'GET' && path === '/healthz') {
        send(res, 200, { ok: true });
        return;
      }
      if (path !== '/ingest') {
        send(res, 404, { error: 'not found' });
        return;
      }
      if (req.method !== 'POST') {
        res.setHeader('allow', 'POST');
        send(res, 405, { error: 'method not allowed' });
        return;
      }
      let body: string;
      try {
        body = await readBody(req, deps.config.maxBodyBytes);
      } catch (e) {
        if (e instanceof BodyTooLargeError) {
          res.setHeader('connection', 'close');
          send(res, 413, { error: 'payload too large' });
          return;
        }
        throw e;
      }
      const result = await ingest(body, deps);
      if (result.result === 'in-progress' || result.result === 'sent-unconfirmed') {
        res.setHeader('retry-after', String(Math.max(1, Math.ceil(deps.config.staleSendingMs / 1000))));
      }
      if (result.result === 'invalid' || result.result === 'ignored') {
        log('WARNING', `電文を配信しませんでした: ${result.reason}`, { result: result.result });
      }
      send(res, STATUS[result.result], summarize(result));
    } catch (e) {
      log('ERROR', '電文の処理中にエラーが発生しました', {
        error: e instanceof Error ? (e.stack ?? e.message) : String(e),
      });
      if (!res.headersSent) send(res, 500, { error: 'internal error' });
    }
  });
}
