// Demo control panel (requirements 9). Presenter-facing, Japanese labels.
import type { ReactNode } from 'react';
import { actions, useAppState, useDispatch } from '../state/store';
import { SCENARIOS } from '../state/scenarios';
import { deriveMode, freshness, resolveScreen, topPriorityAction } from '../state/derive';
import { formatJst, MINUTE_MS } from '../state/time';
import { useNavigation } from '../logic/nav';
import { SCREEN_META } from '../screens/meta';
import { ALERT_EARTHQUAKE, ALERT_TSUNAMI, DEFAULT_HEIGHT, withLevel } from '../data/alerts';
import { maxHeight, raisedHeight, useMargin } from '../logic/margin';
import type { AlertLevel, EqSituation, ExpectedHeight, Lang, StatePatch } from '../state/types';
import { useLiveAlerts, type LiveStatus } from '../live/LiveAlerts';
import { hhmm } from '../live/liveDoc';
import type { PushState, PushSupport } from '../platform/push';
import './DemoPanel.css';

type TsunamiSel = 'none' | AlertLevel;

const LEVEL_ORDER: AlertLevel[] = ['advisory', 'warning', 'emergency'];
const HEIGHT_OPTIONS: { id: string; value: ExpectedHeight; label: string }[] = [
  { id: '1', value: 1, label: '1 m' },
  { id: '3', value: 3, label: '3 m' },
  { id: '5', value: 5, label: '5 m' },
  { id: '10', value: 10, label: '10 m' },
  { id: 'over10', value: 'over10', label: '10 m 超' },
  { id: 'huge', value: 'huge', label: '巨大（10 m 超として判定）' },
  { id: 'high', value: 'high', label: '高い（3 m として判定）' },
];
const MARGIN_LABEL = { ample: '余裕あり', low: '余裕が少ない（Go higher.）', short: '足りない（Go higher. NOW）' } as const;

const LIVE_STATUS_LABEL: Record<LiveStatus, string> = {
  off: 'OFF（デモパネルで操作）',
  connecting: '接続中…',
  live: '接続中（受信待ち）',
  cache: '未接続（オフライン・キャッシュ）',
  error: 'エラー（デモパネルで操作）',
};
const LIVE_KIND_LABEL: Record<string, string> = {
  'major-tsunami-warning': '大津波警報',
  'tsunami-warning': '津波警報',
  'tsunami-advisory': '津波注意報',
  cleared: '解除',
  cancelled: '取消',
};
function pushLabel(support: PushSupport, state: PushState): string {
  if (support === 'checking') return '確認中…';
  if (support === 'ios') return '非対応（iPhone はホーム画面の PWA のみ。Firestore の購読で動きます）';
  if (support === 'unsupported') return '非対応（このブラウザ）';
  return { idle: '未設定', working: '設定中…', enabled: '受け取る（トークン登録済み）', denied: '拒否されています', error: 'エラー' }[state];
}
function clock(ms: number): string {
  return new Date(ms).toLocaleTimeString('ja-JP', { hour12: false });
}

const LANGS: { id: Lang; label: string }[] = [
  { id: 'en', label: 'English' },
  { id: 'ja', label: '日本語' },
  { id: 'zh-Hans', label: '简体中文' },
  { id: 'ko', label: '한국어' },
  { id: 'ar', label: 'العربية' },
];

function Section({ title, open, children }: { title: string; open?: boolean; children: ReactNode }) {
  return (
    <details className="tk-demo__sec" open={open}>
      <summary>{title}</summary>
      <div className="tk-demo__body">{children}</div>
    </details>
  );
}

function Check({ label, checked, onChange }: { label: string; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <label className="tk-demo__row">
      <span>{label}</span>
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} />
    </label>
  );
}

function Slider(props: { label: string; value: number; min: number; max: number; step?: number; unit: string; onChange: (v: number) => void }) {
  return (
    <label className="tk-demo__row">
      <span>
        {props.label}: {props.value}
        {props.unit}
      </span>
      <input
        type="range"
        min={props.min}
        max={props.max}
        step={props.step ?? 1}
        value={props.value}
        onChange={(e) => props.onChange(Number(e.target.value))}
      />
    </label>
  );
}

function Seg<T extends string | number>({ value, options, onChange }: { value: T; options: { id: T; label: string }[]; onChange: (v: T) => void }) {
  return (
    <div className="tk-demo__btns">
      {options.map((o) => (
        <button
          key={String(o.id)}
          type="button"
          className={'tk-demo__btn' + (o.id === value ? ' tk-demo__btn--on' : '')}
          aria-pressed={o.id === value}
          onClick={() => onChange(o.id)}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

export function DemoPanel() {
  const s = useAppState();
  const dispatch = useDispatch();
  const patch = (p: StatePatch) => dispatch(actions.patch(p));
  const nav = useNavigation();
  const margin = useMargin();
  const live = useLiveAlerts();

  // Same nav inputs as App so the readout matches the real screen.
  const screen = resolveScreen(s, nav.nextSegmentVerified, nav.inHazardZone);
  const fresh = freshness(s);
  const prio = topPriorityAction(s, nav.inHazardZone);
  const tsunami = s.alerts.find((a) => a.type === 'tsunami');
  const tsunamiSel: TsunamiSel = tsunami ? tsunami.level : 'none';
  const hasEq = s.alerts.some((a) => a.type === 'earthquake');
  const scenario = SCENARIOS.find((x) => x.id === s.scenarioId);

  const setTsunami = (sel: TsunamiSel) => {
    const rest = s.alerts.filter((a) => a.type !== 'tsunami');
    patch({ alerts: sel === 'none' ? rest : [...rest, withLevel(tsunami ?? ALERT_TSUNAMI, sel)] });
  };
  // FB3 (F88 / F89 / F8A): a new bulletin replaces the tsunami alert. The store detects the change and shows the band.
  const replaceTsunami = (level: AlertLevel, expectedHeight: ExpectedHeight) => {
    const rest = s.alerts.filter((a) => a.type !== 'tsunami');
    patch({ alerts: [...rest, { ...(tsunami ?? ALERT_TSUNAMI), level, expectedHeight, issuedAt: s.now }] });
  };
  const levelIdx = tsunami ? LEVEL_ORDER.indexOf(tsunami.level) : -1;
  const upgrade = () => {
    const level = LEVEL_ORDER[Math.min(levelIdx + 1, LEVEL_ORDER.length - 1)];
    replaceTsunami(level, maxHeight(tsunami?.expectedHeight ?? null, DEFAULT_HEIGHT[level]) ?? DEFAULT_HEIGHT[level]);
  };
  const raise = () => {
    const h = raisedHeight(tsunami?.expectedHeight);
    if (tsunami && h !== null) replaceTsunami(tsunami.level, h);
  };
  const downgrade = () => {
    if (levelIdx <= 0) return;
    const level = LEVEL_ORDER[levelIdx - 1];
    replaceTsunami(level, DEFAULT_HEIGHT[level]);
  };
  const setHeight = (id: string) => {
    const opt = HEIGHT_OPTIONS.find((o) => o.id === id);
    if (tsunami && opt) replaceTsunami(tsunami.level, opt.value);
  };
  const liftAll = () => patch({ alerts: [] });

  const setEq = (on: boolean) => {
    const rest = s.alerts.filter((a) => a.type !== 'earthquake');
    patch({ alerts: on ? [ALERT_EARTHQUAKE, ...rest] : rest });
  };

  const fireNotification = () => {
    patch({ lockScreen: true });
    try {
      if (typeof Notification !== 'undefined' && Notification.permission === 'granted') {
        new Notification('TASUKU: EARTHQUAKE + TSUNAMI', { body: 'Go uphill NOW' });
      }
    } catch {
      /* ignore */
    }
  };

  return (
    <div className="tk-demo">
      <h2 className="tk-demo__title">デモ操作パネル</h2>

      <dl className="tk-demo__readout" aria-label="現在の状態">
        <dt>モード</dt>
        <dd>{deriveMode(s, nav.inHazardZone)}</dd>
        <dt>画面</dt>
        <dd>
          {screen} {SCREEN_META[screen].name}
        </dd>
        <dt>仮想時刻</dt>
        <dd>{formatJst(s.now)} JST</dd>
        <dt>鮮度</dt>
        <dd>
          {fresh.stale ? 'Stale' : 'Fresh'}（{fresh.ageMin.toFixed(0)} 分前{s.online ? '' : '・オフライン'}
          {s.online && s.feedPaused ? '・更新停止中' : ''}）
        </dd>
        <dt>最優先行動</dt>
        <dd>
          {prio.rank}: {prio.kind}
        </dd>
        <dt>余裕の判定</dt>
        <dd>
          {margin.level ? MARGIN_LABEL[margin.level] : '—'}
          {margin.marginM !== null ? `（差 ${margin.marginM.toFixed(1)} m）` : ''}
          {margin.designated ? '・指定避難場所' : ''}
        </dd>
      </dl>

      <Section title="シナリオ" open>
        <div className="tk-demo__btns" style={{ flexDirection: 'column' }}>
          {SCENARIOS.map((sc) => (
            <button
              key={sc.id}
              type="button"
              className={'tk-demo__btn tk-demo__scn' + (sc.id === s.scenarioId ? ' tk-demo__btn--on' : '')}
              onClick={() => dispatch(actions.loadScenario(sc.id))}
            >
              <b>{sc.id}</b>
              <span>
                {sc.label}
                <br />
                <small>{sc.description}</small>
              </span>
            </button>
          ))}
        </div>
        <div className="tk-demo__hint">選択中: {scenario?.label}</div>
        <div className="tk-demo__btns">
          <button type="button" className="tk-demo__btn tk-demo__btn--danger" onClick={() => dispatch(actions.loadScenario(s.scenarioId))}>
            リセット
          </button>
        </div>
      </Section>

      <Section title="Live alerts（Firestore）" open>
        <Check label="Firestore の警報を反映する" checked={live.enabled} onChange={live.setEnabled} />
        <dl className="tk-demo__readout" aria-label="Live alerts の状態">
          <dt>接続</dt>
          <dd>
            {LIVE_STATUS_LABEL[live.status]}
            {live.enabled && !s.online ? '・デモはオフライン（戻ると反映）' : ''}
          </dd>
          {live.error && (
            <>
              <dt>エラー</dt>
              <dd>{live.error}</dd>
            </>
          )}
          <dt>受信</dt>
          <dd>
            {live.latest && live.receivedAt !== null ? (
              <>
                {clock(live.receivedAt)} {LIVE_KIND_LABEL[live.latest.kind] ?? live.latest.kind}
                {live.latest.expectedHeight !== null ? ` ${live.latest.expectedHeight}` : ''}（Serial {live.latest.serial}・{live.latest.infoType}・
                {live.latest.change}）{live.latestApplied ? '' : '・未反映'}
              </>
            ) : (
              'なし'
            )}
          </dd>
          {live.latest && (live.latest.arrivalTime || live.latest.arrivalCondition) && (
            <>
              <dt>到達予想</dt>
              <dd>{hhmm(live.latest.arrivalTime) ?? live.latest.arrivalCondition}</dd>
            </>
          )}
        </dl>
        <div className="tk-demo__hint">
          services/alert-ingest が書いた alerts/{'{EventID}'}（みなと湾）の最新の電文を、下の「災害」の操作と同じ形で反映します（同じ EventID・Serial は 1 回だけ）。
          OFF・エラー・オフラインの間は、これまでどおりデモパネルで操作できます。リセットで受信した状態も消えます。
        </div>
      </Section>

      <Section title="通知">
        <div className="tk-demo__btns">
          <button type="button" className="tk-demo__btn" onClick={fireNotification}>
            通知を出す
          </button>
          <button
            type="button"
            className="tk-demo__btn"
            disabled={live.pushSupport !== 'supported' || live.pushState === 'working' || live.pushState === 'denied'}
            onClick={live.enablePush}
          >
            通知を受け取る
          </button>
        </div>
        <div className="tk-demo__hint">
          FCM: {pushLabel(live.pushSupport, live.pushState)}
          {live.pushError ? `（${live.pushError}）` : ''}
          {live.lastPushAt !== null ? `・前面で受信 ${clock(live.lastPushAt)}（表示はしない）` : ''}
        </div>
        <div className="tk-demo__hint">「通知を出す」は S01 を表示（ブラウザ通知は許可済みの場合のみ）。「通知を受け取る」は通知を許可して FCM に登録し、画面を閉じているときに警報をロック画面へ出します。</div>
      </Section>

      <Section title="災害">
        <Check label="揺れ" checked={s.shaking} onChange={(v) => patch({ shaking: v })} />
        <div className="tk-demo__hint">津波警報レベル</div>
        <Seg<TsunamiSel>
          value={tsunamiSel}
          onChange={setTsunami}
          options={[
            { id: 'none', label: 'なし' },
            { id: 'advisory', label: '注意報' },
            { id: 'warning', label: '警報' },
            { id: 'emergency', label: '大津波' },
          ]}
        />
        <label className="tk-demo__row">
          <span>予想される高さ</span>
          <select
            value={HEIGHT_OPTIONS.find((o) => o.value === tsunami?.expectedHeight)?.id ?? ''}
            disabled={!tsunami}
            onChange={(e) => setHeight(e.target.value)}
          >
            {!tsunami && <option value="">（津波の警報なし）</option>}
            {HEIGHT_OPTIONS.map((o) => (
              <option key={o.id} value={o.id}>
                {o.label}
              </option>
            ))}
          </select>
        </label>
        <div className="tk-demo__hint">警報の変化（帯で知らせる。格上げ・引き上げは再通知と判定のやり直し）</div>
        <div className="tk-demo__btns">
          <button type="button" className="tk-demo__btn" disabled={levelIdx >= LEVEL_ORDER.length - 1} onClick={upgrade}>
            格上げする
          </button>
          <button type="button" className="tk-demo__btn" disabled={!tsunami || raisedHeight(tsunami.expectedHeight) === null} onClick={raise}>
            高さを引き上げる
          </button>
          <button type="button" className="tk-demo__btn" disabled={levelIdx <= 0} onClick={downgrade}>
            格下げする
          </button>
          <button type="button" className="tk-demo__btn tk-demo__btn--danger" disabled={s.alerts.length === 0} onClick={liftAll}>
            解除する
          </button>
        </div>
        <Slider label="余裕ありとする差" value={s.marginAmpleM} min={0} max={30} unit=" m" onChange={(v) => patch({ marginAmpleM: v })} />
        <Slider label="10 m 超のとき必要な標高" value={s.hugeMinElevM} min={0} max={40} unit=" m" onChange={(v) => patch({ hugeMinElevM: v })} />
        <div className="tk-demo__hint">
          現在地の標高 {margin.elevMinM !== null ? `${margin.elevMinM.toFixed(1)} m` : '不明'}
          {margin.approximate && margin.elevMaxM !== null ? `〜${margin.elevMaxM.toFixed(1)} m（誤差円内）` : ''} / 判定に使う高さ{' '}
          {margin.heightInUse ?? 'なし'}（格下げしても最大値を使う）
        </div>
        <Check label="地震の警報" checked={hasEq} onChange={setEq} />
        <label className="tk-demo__row">
          <span>地震時の状況</span>
          <select value={s.eqSituation} onChange={(e) => patch({ eqSituation: e.target.value as EqSituation })}>
            <option value="indoors">INDOORS</option>
            <option value="outdoors">OUTDOORS</option>
            <option value="car">IN CAR</option>
          </select>
        </label>
      </Section>

      <Section title="通信">
        {/* Going back online resumes updates (clears feedPaused). */}
        <Check label="オンライン" checked={s.online} onChange={(v) => patch(v ? { online: true, feedPaused: false } : { online: false })} />
        <Check label="更新を止める（取得失敗）" checked={s.feedPaused} onChange={(v) => patch({ feedPaused: v })} />
        <Slider label="鮮度しきい値" value={s.staleThresholdMin} min={1} max={30} unit="分" onChange={(v) => patch({ staleThresholdMin: v })} />
        <div className="tk-demo__btns">
          <button type="button" className="tk-demo__btn" onClick={() => patch({ lastFetchAt: s.now - 15 * MINUTE_MS, feedPaused: true })}>
            最終取得を 15 分前にする
          </button>
          <button type="button" className="tk-demo__btn" onClick={() => patch({ now: s.now + 5 * MINUTE_MS })}>
            時計 +5 分
          </button>
        </div>
        <div className="tk-demo__hint">オンライン中は毎分自動で取得します。「更新を止める」かオフラインの間だけ最終取得時刻が止まり、しきい値を超えると Stale になります。</div>
      </Section>

      <Section title="位置">
        <label className="tk-demo__row">
          <span>位置情報の許可</span>
          <select value={s.gps.permission} onChange={(e) => patch({ gps: { permission: e.target.value as 'granted' | 'denied' | 'prompt' } })}>
            <option value="granted">許可</option>
            <option value="denied">拒否</option>
            <option value="prompt">未確認</option>
          </select>
        </label>
        <Slider label="GPS 精度 ±" value={s.gps.accuracyM} min={10} max={300} step={5} unit=" m" onChange={(v) => patch({ gps: { accuracyM: v } })} />
        <div className="tk-demo__btns">
          <button type="button" className="tk-demo__btn" disabled={!s.manualPin} onClick={() => patch({ manualPin: null })}>
            手動ピンを解除{s.manualPin ? '' : '（なし）'}
          </button>
        </div>
      </Section>

      <Section title="歩行">
        <div className="tk-demo__btns">
          <button type="button" className={'tk-demo__btn' + (s.walk.playing ? ' tk-demo__btn--on' : '')} onClick={() => patch({ walk: { playing: !s.walk.playing } })}>
            {s.walk.playing ? '一時停止' : '再生'}
          </button>
          <button type="button" className="tk-demo__btn" onClick={() => patch({ walk: { progressM: 0, playing: false } })}>
            進捗リセット
          </button>
          <button type="button" className="tk-demo__btn" onClick={() => patch({ onHighGround: false })}>
            高台フラグ解除
          </button>
        </div>
        <Seg<number>
          value={s.walk.speed}
          onChange={(v) => patch({ walk: { speed: v } })}
          options={[1, 2, 4].map((v) => ({ id: v, label: `×${v}` }))}
        />
        <div className="tk-demo__hint">
          進捗 {s.walk.progressM.toFixed(0)} m / 高台: {s.onHighGround ? 'はい' : 'いいえ'}
        </div>
      </Section>

      <Section title="画面">
        <Check label="画面オフ" checked={s.screenOff} onChange={(v) => patch({ screenOff: v })} />
        <Check label="端末を持ち上げる" checked={s.deviceRaised} onChange={(v) => patch({ deviceRaised: v })} />
        <Check label="画面が切り替わったら読み上げる" checked={s.autoSpeak} onChange={(v) => patch({ autoSpeak: v })} />
      </Section>

      <Section title="AR">
        <Check label="カメラ権限" checked={s.ar.cameraPermission} onChange={(v) => patch({ ar: { cameraPermission: v } })} />
        <Check label="対応端末" checked={s.ar.supported} onChange={(v) => patch({ ar: { supported: v } })} />
        <Slider label="方位精度 ±" value={s.ar.headingAccuracyDeg} min={0} max={45} unit="°" onChange={(v) => patch({ ar: { headingAccuracyDeg: v } })} />
        <Check label="追跡中" checked={s.ar.tracking} onChange={(v) => patch({ ar: { tracking: v } })} />
        <Check label="目印を認識" checked={s.ar.landmarkFound} onChange={(v) => patch({ ar: { landmarkFound: v } })} />
        <Check label="認識枠を表示" checked={s.ar.showDetection} onChange={(v) => patch({ ar: { showDetection: v } })} />
      </Section>

      <Section title="通報">
        <Check label="発信を有効にする" checked={s.dialerEnabled} onChange={(v) => patch({ dialerEnabled: v })} />
        <div className="tk-demo__warn">注意: 有効にすると 110 / 119 のボタンで実際にダイヤラーが開きます。</div>
      </Section>

      <Section title="言語">
        <label className="tk-demo__row">
          <span>表示言語</span>
          <select value={s.lang} onChange={(e) => patch({ lang: e.target.value as Lang })}>
            {LANGS.map((l) => (
              <option key={l.id} value={l.id}>
                {l.label}
              </option>
            ))}
          </select>
        </label>
      </Section>
    </div>
  );
}

export default DemoPanel;
