// Cloud Logging が読める 1 行 JSON のログ。
export type Severity = 'DEBUG' | 'INFO' | 'WARNING' | 'ERROR';

let silent = false;

/** テスト中にログを止める。 */
export function setLogSilent(value: boolean): void {
  silent = value;
}

export function log(severity: Severity, message: string, fields: Record<string, unknown> = {}): void {
  if (silent) return;
  const line = JSON.stringify({ severity, message, ...fields });
  if (severity === 'ERROR' || severity === 'WARNING') console.error(line);
  else console.log(line);
}
