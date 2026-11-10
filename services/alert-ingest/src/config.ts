// 環境変数からの設定。秘密情報は扱わない（認証は Cloud Run の IAM と実行時 SA の ADC）。

export interface Config {
  port: number;
  /** 配信先の FCM トピック。 */
  fcmTopic: string;
  /** モックが使う地域 ID と表示名（架空の町）。 */
  areaId: string;
  areaName: string;
  /**
   * true のとき、どの津波予報区の電文でも「みなと湾」の警報として扱う（デモ用）。
   * false のときは targetAreaCodes に含まれる予報区だけを見る。
   */
  demoAreaOverride: boolean;
  /** 対象にする津波予報区コード（demoAreaOverride が false のとき）。 */
  targetAreaCodes: string[];
  /** 受け付ける運用種別（Control/Status）。それ以外は配信しない。 */
  allowedStatuses: string[];
  /** sending のままこの時間がたった記録は、送り直してよい（D6）。 */
  staleSendingMs: number;
  /** sentAlerts の TTL（expireAt に入れる日数）。 */
  sentTtlDays: number;
  /** 受け付ける電文の最大バイト数。 */
  maxBodyBytes: number;
  /** Web のクライアントのトークン（fcmTokens、有効期限内）を読む最大数。0 なら Web へは送らない。 */
  maxWebTokens: number;
}

function list(v: string | undefined, fallback: string[]): string[] {
  if (v === undefined || v.trim() === '') return fallback;
  return v
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s !== '');
}

function int(v: string | undefined, fallback: number): number {
  if (v === undefined || v.trim() === '') return fallback;
  const n = Number(v);
  if (!Number.isInteger(n) || n < 0) throw new Error(`整数ではない設定値です: ${v}`);
  return n;
}

function bool(v: string | undefined, fallback: boolean): boolean {
  if (v === undefined || v.trim() === '') return fallback;
  return ['1', 'true', 'yes', 'on'].includes(v.trim().toLowerCase());
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  return {
    port: int(env.PORT, 8080),
    fcmTopic: env.FCM_TOPIC?.trim() || 'demo-minato-bay',
    areaId: env.AREA_ID?.trim() || 'minato-bay',
    areaName: env.AREA_NAME?.trim() || 'みなと湾（架空）',
    demoAreaOverride: bool(env.DEMO_AREA_OVERRIDE, false),
    targetAreaCodes: list(env.TARGET_AREA_CODES, []),
    allowedStatuses: list(env.ALLOWED_STATUSES, ['通常', '訓練']),
    staleSendingMs: int(env.STALE_SENDING_MS, 60_000),
    sentTtlDays: int(env.SENT_TTL_DAYS, 7),
    maxBodyBytes: int(env.MAX_BODY_BYTES, 1_000_000),
    maxWebTokens: int(env.MAX_WEB_TOKENS, 200),
  };
}
