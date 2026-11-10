// AR camera view for S11 (T5). The "camera" is a still image of a fictional Japanese residential street:
//  - public/ar/street.jpg when it exists (optional; loaded from the same origin only), otherwise
//  - an original SVG illustration (road going forward, a right-hand uphill branch, block walls, houses,
//    utility poles + wires, greenery, hills, sky).
// The turn arrow, the registered landmark sign and the detection box are drawn on top in the same
// 390 x 500 coordinate space, so they line up with either background.
// A left turn mirrors the whole street (the branch is then on the left); straight keeps the street.
// On real devices S11 passes the rear camera stream (H5): the video then covers the still street, and
// the arrow can be rotated by the compass (difference between the way to walk and the device heading).
import { useEffect, useRef, useState } from 'react';
import type { TurnDirection } from '../logic/nav';

export const AR_VIEW_W = 390;
export const AR_VIEW_H = 500;

/** Sign rectangle (right-turn geometry); mirrored horizontally for a left turn. */
const SIGN = { x: 222, y: 154, w: 22, h: 22 };

const PHOTO_URL = `${import.meta.env.BASE_URL}ar/street.jpg`;
/** Remember a missing photo for the session so re-entering S11 does not request it again. */
let photoState: 'unknown' | 'ok' | 'missing' = 'unknown';

const YELLOW = 'var(--tk-yellow, #ffd54f)';
const INK = '#16141a';

function mirrorX(x: number, w = 0): number {
  return AR_VIEW_W - x - w;
}

export function signRect(direction: TurnDirection) {
  return direction === 'left' ? { ...SIGN, x: mirrorX(SIGN.x, SIGN.w) } : SIGN;
}

// ---------------------------------------------------------------------------
// Background illustration (right-branch geometry)

function StreetIllustration({ uid }: { uid: string }) {
  const sky = `${uid}-sky`;
  const road = `${uid}-road`;
  const hill = `${uid}-hill`;
  const vig = `${uid}-vig`;
  const wire = { fill: 'none', stroke: '#2b2a2c', strokeWidth: 0.9, strokeLinecap: 'round' as const };
  return (
    <g>
      <defs>
        <linearGradient id={sky} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#a9bfd2" />
          <stop offset="0.6" stopColor="#dbe4ea" />
          <stop offset="1" stopColor="#eef1f2" />
        </linearGradient>
        <linearGradient id={road} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" stopColor="#4f4f52" />
          <stop offset="0.55" stopColor="#68686b" />
          <stop offset="1" stopColor="#7d7c7d" />
        </linearGradient>
        <linearGradient id={hill} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#5f8650" />
          <stop offset="1" stopColor="#3f6337" />
        </linearGradient>
        <radialGradient id={vig} cx="0.5" cy="0.55" r="0.75">
          <stop offset="0.65" stopColor="#000" stopOpacity="0" />
          <stop offset="1" stopColor="#000" stopOpacity="0.28" />
        </radialGradient>
      </defs>

      {/* sky + clouds */}
      <rect x="0" y="0" width={AR_VIEW_W} height="270" fill={`url(#${sky})`} />
      <g fill="#fff" opacity="0.55">
        <ellipse cx="120" cy="58" rx="46" ry="12" />
        <ellipse cx="150" cy="50" rx="30" ry="10" />
        <ellipse cx="300" cy="84" rx="40" ry="9" />
      </g>

      {/* hills */}
      <path d="M0 168 C40 132 92 116 140 126 C182 104 232 100 272 122 C312 110 352 120 390 136 L390 270 L0 270 Z" fill={`url(#${hill})`} />
      <g fill="#6d9658" opacity="0.7">
        <circle cx="70" cy="150" r="14" />
        <circle cx="110" cy="134" r="12" />
        <circle cx="168" cy="122" r="13" />
        <circle cx="205" cy="116" r="11" />
        <circle cx="330" cy="128" r="12" />
      </g>
      <path d="M0 200 C60 172 120 168 170 180 C220 164 292 168 390 180 L390 270 L0 270 Z" fill="#3c5f35" />

      {/* far houses */}
      <g>
        <rect x="86" y="176" width="66" height="40" fill="#dcd4c4" />
        <path d="M80 178 L119 160 L158 178 Z" fill="#62666b" />
        <rect x="98" y="188" width="14" height="10" fill="#4b4a48" />
        <rect x="126" y="188" width="14" height="10" fill="#4b4a48" />
      </g>
      <g>
        <rect x="180" y="148" width="122" height="78" fill="#e6dfcf" />
        <path d="M170 152 L241 122 L312 152 Z" fill="#6a6e73" />
        <path d="M170 152 L312 152 L312 156 L170 156 Z" fill="#4f5256" />
        <rect x="196" y="166" width="26" height="20" fill="#56524c" />
        <rect x="236" y="166" width="20" height="20" fill="#7a6e5e" />
        <rect x="268" y="166" width="24" height="20" fill="#56524c" />
        <rect x="196" y="166" width="26" height="3" fill="#8b8274" />
        <rect x="268" y="166" width="24" height="3" fill="#8b8274" />
      </g>
      <g>
        <rect x="300" y="136" width="78" height="70" fill="#d8d0bf" />
        <path d="M293 140 L339 116 L386 140 Z" fill="#5c6065" />
        <rect x="314" y="152" width="18" height="16" fill="#4e4a45" />
        <rect x="346" y="152" width="18" height="16" fill="#4e4a45" />
        <path d="M354 152 v16 M322 152 v16" stroke="#8b8274" strokeWidth="1" />
      </g>

      {/* big tree behind the branch wall */}
      <rect x="246" y="150" width="6" height="64" fill="#5b4a3a" />
      <g fill="#5b8a3c">
        <circle cx="236" cy="134" r="26" />
        <circle cx="266" cy="124" r="28" />
        <circle cx="292" cy="142" r="20" />
        <circle cx="214" cy="152" r="16" />
      </g>
      <g fill="#78a552" opacity="0.85">
        <circle cx="258" cy="112" r="12" />
        <circle cx="230" cy="126" r="10" />
        <circle cx="284" cy="132" r="9" />
      </g>

      {/* far wall straight ahead (end of the road) */}
      <path d="M70 190 L178 186 L178 244 L70 246 Z" fill="#a8a59d" />
      <path d="M70 190 L178 186 L178 190 L70 194 Z" fill="#8f8c84" />
      <g stroke="#94918a" strokeWidth="0.8">
        <path d="M96 190 v55 M124 189 v55 M152 188 v56" />
        <path d="M70 218 L178 215" />
      </g>

      {/* block wall along the uphill branch (right) */}
      <path d="M178 206 L390 140 L390 192 L178 244 Z" fill="#b6b1a5" />
      <path d="M178 206 L390 140 L390 146 L178 211 Z" fill="#8e8a80" />
      <g stroke="#9d998e" strokeWidth="0.8" fill="none">
        <path d="M178 219 L390 159" />
        <path d="M178 232 L390 176" />
        <path d="M214 197 v38 M252 186 v40 M292 173 v43 M334 160 v46" />
      </g>
      {/* hedge on top of the branch wall */}
      <g fill="#4f7d33">
        <circle cx="190" cy="203" r="9" />
        <circle cx="204" cy="198" r="10" />
        <circle cx="300" cy="170" r="9" />
        <circle cx="318" cy="164" r="10" />
        <circle cx="352" cy="152" r="9" />
      </g>

      {/* near house on the left */}
      <path d="M0 0 L64 36 L64 304 L0 350 Z" fill="#e9e2d5" />
      <path d="M0 56 L46 82 L46 200 L0 220 Z" fill="#3a3531" />
      <path d="M0 56 L46 82 L46 88 L0 64 Z" fill="#6b625a" />
      <g stroke="#5a524b" strokeWidth="1.2">
        <path d="M8 66 V214 M20 72 V209 M32 77 V204" />
      </g>
      <path d="M0 236 L46 214 L46 262 L0 288 Z" fill="#cfc7b8" />
      <path d="M0 330 L64 296 L64 318 L0 358 Z" fill="#9f9b92" />
      {/* air conditioner unit */}
      <path d="M6 268 L30 256 L30 280 L6 294 Z" fill="#e4e4e0" stroke="#b8b6ae" strokeWidth="0.8" />
      {/* shrubs + potted plants */}
      <g fill="#4f7d33">
        <circle cx="52" cy="290" r="12" />
        <circle cx="64" cy="276" r="9" />
        <circle cx="40" cy="300" r="8" />
      </g>

      {/* road */}
      <path
        d="M-40 500 L70 244 L178 244 L390 190 L390 214 L338 330 L334 360 L390 420 L390 500 Z"
        fill={`url(#${road})`}
      />
      {/* left sidewalk */}
      <path d="M0 350 L64 304 L70 244 L0 408 Z" fill="#97948d" />
      <path d="M70 244 L-40 500" stroke="#b9b5ad" strokeWidth="2" />
      {/* right sidewalk + curb along the branch */}
      <path d="M390 214 L338 330 L334 360 L390 420 Z" fill="#aca89f" />
      <path d="M390 214 L338 330 L334 360 L390 420" fill="none" stroke="#c9c5bc" strokeWidth="2" />
      {/* curb at the foot of the far / branch walls */}
      <path d="M70 246 L178 244 L390 192" fill="none" stroke="#c2beb5" strokeWidth="2" />
      {/* road details: drain grate + cracks */}
      <path d="M344 372 L362 366 L366 374 L348 380 Z" fill="#2f2f30" />
      <g stroke="#3d3d3f" strokeWidth="0.8" fill="none" opacity="0.7">
        <path d="M262 330 C268 352 280 362 276 392" />
        <path d="M90 420 C110 410 118 430 140 424" />
      </g>

      {/* traffic mirror (left corner) */}
      <rect x="58.5" y="150" width="3" height="140" fill="#d27a2f" />
      <circle cx="60" cy="140" r="14" fill="#c7d1d6" stroke="#d27a2f" strokeWidth="3" />
      <path d="M52 134 Q60 128 68 136" stroke="#fff" strokeWidth="1.5" fill="none" opacity="0.7" />

      {/* utility poles + wires */}
      <rect x="154" y="0" width="8" height="240" fill="#b9b4a9" />
      <rect x="159" y="0" width="3" height="240" fill="#9e998f" />
      <rect x="140" y="38" width="36" height="3" fill="#8f8a80" />
      <rect x="371" y="38" width="5" height="150" fill="#c2bdb2" />
      <rect x="360" y="60" width="26" height="2.5" fill="#8f8a80" />
      <g {...wire}>
        <path d="M140 40 C200 52 300 50 362 62" />
        <path d="M176 40 C240 54 320 56 386 62" />
        <path d="M158 20 C230 38 320 34 374 40" />
        <path d="M140 40 C100 30 60 18 0 4" />
        <path d="M176 40 C150 20 130 8 112 0" />
        <path d="M158 20 C200 10 240 4 270 0" />
        <path d="M374 40 C380 30 386 16 390 8" />
      </g>

      <rect x="0" y="0" width={AR_VIEW_W} height={AR_VIEW_H} fill={`url(#${vig})`} />
    </g>
  );
}

/** Blue tsunami evacuation sign (wave icon) on a pole. Not mirrored, so the icon stays readable. */
function EvacuationSign({ x, y, w, h }: { x: number; y: number; w: number; h: number }) {
  const cx = x + w / 2;
  return (
    <g>
      <rect x={cx - 1.5} y={y + h - 2} width="3" height={98 - h} fill="#d6d6d6" />
      <rect x={cx - 1.5} y={y + h - 2} width="1" height={98 - h} fill="#f3f3f3" />
      <rect x={x} y={y} width={w} height={h} rx="2" fill="#1f5fae" stroke="#fff" strokeWidth="1.4" />
      <path
        d={`M${x + 4} ${y + h - 6} c3 -9 9 -12 14 -8 c-4 -1 -7 2 -6 5 c1 2 4 2 6 1 v2 Z`}
        fill="#fff"
      />
      <path d={`M${x + 3} ${y + h - 4} h${w - 6}`} stroke="#fff" strokeWidth="1.6" />
    </g>
  );
}

// ---------------------------------------------------------------------------
// Turn arrow (big yellow perspective arrow with a dark outline, drawn on the road)

type Pt = readonly [number, number];
type Cubic = readonly [Pt, Pt, Pt, Pt];

/** Centre lines (cubic curves) of the guide band on the road: from the lower centre, away from the user. */
const BAND_RIGHT: Cubic[] = [
  [[195, 500], [196, 420], [200, 350], [226, 306]],
  [[226, 306], [250, 272], [290, 256], [334, 241]],
];
const BAND_STRAIGHT: Cubic[] = [[[195, 500], [195, 430], [195, 360], [195, 296]]];

const BAND_ROOT = { x: 195, y: 500 };
const BAND_HALF_NEAR = 34;
const BAND_HALF_FAR = 9;
const BAND_HEAD_HALF = 24;
const BAND_HEAD_LEN = 42;

function cubicAt([a, b, c, d]: Cubic, t: number): Pt {
  const u = 1 - t;
  const k = [u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t];
  return [k[0] * a[0] + k[1] * b[0] + k[2] * c[0] + k[3] * d[0], k[0] * a[1] + k[1] * b[1] + k[2] * c[1] + k[3] * d[1]];
}

/** Outline of the band: wide near the user, narrowing with distance, with the arrow head at the far end. */
function bandPath(curves: Cubic[]): string {
  const STEPS = 14;
  const line = curves.flatMap((c, n) =>
    Array.from({ length: STEPS + (n === curves.length - 1 ? 1 : 0) }, (_, i) => cubicAt(c, i / STEPS)),
  );
  const lengths = [0];
  for (let i = 1; i < line.length; i++) {
    lengths.push(lengths[i - 1] + Math.hypot(line[i][0] - line[i - 1][0], line[i][1] - line[i - 1][1]));
  }
  const total = lengths[lengths.length - 1];
  const tangent = (i: number): Pt => {
    const a = line[Math.max(i - 1, 0)];
    const b = line[Math.min(i + 1, line.length - 1)];
    const len = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1;
    return [(b[0] - a[0]) / len, (b[1] - a[1]) / len];
  };
  const sideA: Pt[] = [];
  const sideB: Pt[] = [];
  line.forEach((p, i) => {
    const [tx, ty] = tangent(i);
    const half = BAND_HALF_NEAR + (BAND_HALF_FAR - BAND_HALF_NEAR) * (lengths[i] / total);
    sideA.push([p[0] + ty * half, p[1] - tx * half]);
    sideB.push([p[0] - ty * half, p[1] + tx * half]);
  });
  const end = line[line.length - 1];
  const [tx, ty] = tangent(line.length - 1);
  const outline: Pt[] = [
    ...sideA,
    [end[0] + ty * BAND_HEAD_HALF, end[1] - tx * BAND_HEAD_HALF],
    [end[0] + tx * BAND_HEAD_LEN, end[1] + ty * BAND_HEAD_LEN],
    [end[0] - ty * BAND_HEAD_HALF, end[1] + tx * BAND_HEAD_HALF],
    ...sideB.reverse(),
  ];
  return `M${outline.map(([x, y]) => `${x.toFixed(1)} ${y.toFixed(1)}`).join(' L')} Z`;
}

const BAND_PATH_RIGHT = bandPath(BAND_RIGHT);
const BAND_PATH_STRAIGHT = bandPath(BAND_STRAIGHT);

function TurnArrowOverlay({ direction, rotateDeg }: { direction: TurnDirection; rotateDeg: number | null }) {
  const d = direction === 'straight' ? BAND_PATH_STRAIGHT : BAND_PATH_RIGHT;
  const mirror = direction === 'left' ? `translate(${AR_VIEW_W} 0) scale(-1 1)` : '';
  // The compass swings the band on the road: the root stays and the far end moves sideways (a shear, so
  // it stays on the road instead of lifting off it). Applied outside the mirror (positive = to the right).
  const k = rotateDeg === null ? 0 : Math.sin((rotateDeg * Math.PI) / 180);
  const swing = k === 0 ? '' : `matrix(1 0 ${(-k).toFixed(3)} 1 ${(k * BAND_ROOT.y).toFixed(1)} 0)`;
  const t = `${swing} ${mirror}`.trim() || undefined;
  return (
    <g transform={t} className="tk-ar__arrow">
      <path d={d} fill={YELLOW} fillOpacity="0.76" stroke={INK} strokeOpacity="0.55" strokeWidth="3" strokeLinejoin="round" />
    </g>
  );
}

/** "Turn around" U-turn arrow (the next turn is behind the user). Fixed shape, so it never swings. */
const ARROW_UTURN = {
  body: 'M240 452 C240 400 240 330 240 300 C240 230 150 230 150 300 L150 352',
  head: 'M150 392 L126 348 L174 348 Z',
};

function UTurnArrowOverlay() {
  return (
    <g className="tk-ar__arrow">
      <path d={ARROW_UTURN.body} fill="none" stroke={INK} strokeWidth="30" strokeLinecap="round" strokeLinejoin="round" />
      <path d={ARROW_UTURN.head} fill={INK} stroke={INK} strokeWidth="12" strokeLinejoin="round" />
      <path d={ARROW_UTURN.body} fill="none" stroke={YELLOW} strokeWidth="19" strokeLinecap="round" strokeLinejoin="round" />
      <path d={ARROW_UTURN.head} fill={YELLOW} stroke={YELLOW} strokeWidth="2" strokeLinejoin="round" />
    </g>
  );
}

function DetectionBox({ x, y, w, h }: { x: number; y: number; w: number; h: number }) {
  const p = 7;
  const X = x - p;
  const Y = y - p;
  const W = w + p * 2;
  const H = h + p * 2;
  const k = 7;
  return (
    <g className="tk-ar__detect" fill="none" strokeLinecap="round">
      <rect x={X} y={Y} width={W} height={H} rx="3" stroke="#fff" strokeWidth="1.2" strokeDasharray="3 3" opacity="0.9" />
      <path
        d={`M${X} ${Y + k} V${Y} H${X + k} M${X + W - k} ${Y} H${X + W} V${Y + k} M${X + W} ${Y + H - k} V${Y + H} H${X + W - k} M${X + k} ${Y + H} H${X} V${Y + H - k}`}
        stroke={YELLOW}
        strokeWidth="3"
      />
    </g>
  );
}

// ---------------------------------------------------------------------------

export interface ArSceneProps {
  direction: TurnDirection;
  /** Draw the turn arrow (only on passability-verified segments, F3A) */
  showArrow: boolean;
  /** Draw the detection box around the registered landmark (F39) */
  showDetection: boolean;
  ariaLabel: string;
  /** Rear camera stream (real devices, H5). null = still image / SVG street */
  cameraStream?: MediaStream | null;
  /** Compass-driven arrow rotation in degrees (positive = clockwise). null = fixed arrow */
  arrowRotateDeg?: number | null;
  /** The next turn is behind the user: draw the U-turn arrow instead of the turn arrow */
  turnAround?: boolean;
}

/** Live rear camera video (muted + playsInline so iOS Safari plays it inline without a gesture). */
function CameraVideo({ stream }: { stream: MediaStream }) {
  const ref = useRef<HTMLVideoElement>(null);
  useEffect(() => {
    const v = ref.current;
    if (!v) return;
    v.srcObject = stream;
    v.play().catch(() => {});
    return () => {
      v.srcObject = null;
    };
  }, [stream]);
  return <video ref={ref} className="tk-ar__video" autoPlay muted playsInline aria-hidden="true" />;
}

export function ArScene({
  direction,
  showArrow,
  showDetection,
  ariaLabel,
  cameraStream = null,
  arrowRotateDeg = null,
  turnAround = false,
}: ArSceneProps) {
  const [photo, setPhoto] = useState(photoState);
  const mirrored = direction === 'left';
  const sign = signRect(direction);
  const uid = 'tk-ar';
  const sceneTransform = mirrored ? `translate(${AR_VIEW_W} 0) scale(-1 1)` : undefined;

  return (
    <div className="tk-ar__scene" role="img" aria-label={ariaLabel}>
      <svg
        className="tk-ar__layer"
        viewBox={`0 0 ${AR_VIEW_W} ${AR_VIEW_H}`}
        preserveAspectRatio="xMidYMax slice"
        aria-hidden="true"
        focusable="false"
      >
        <g transform={sceneTransform}>
          <StreetIllustration uid={uid} />
        </g>
        <EvacuationSign {...sign} />
      </svg>
      {photo !== 'missing' && (
        <img
          className={`tk-ar__photo${photo === 'ok' ? ' tk-ar__photo--ok' : ''}${mirrored ? ' tk-ar__photo--mirror' : ''}`}
          src={PHOTO_URL}
          alt=""
          aria-hidden="true"
          draggable={false}
          onLoad={() => {
            photoState = 'ok';
            setPhoto('ok');
          }}
          onError={() => {
            photoState = 'missing';
            setPhoto('missing');
          }}
        />
      )}
      {cameraStream && <CameraVideo stream={cameraStream} />}
      <svg
        className="tk-ar__layer tk-ar__layer--top"
        viewBox={`0 0 ${AR_VIEW_W} ${AR_VIEW_H}`}
        preserveAspectRatio="xMidYMax slice"
        aria-hidden="true"
        focusable="false"
      >
        {/* The detection box belongs to the sign in the still street; it means nothing over live video. */}
        {showDetection && !cameraStream && <DetectionBox {...sign} />}
        {showArrow && turnAround && <UTurnArrowOverlay />}
        {showArrow && !turnAround && <TurnArrowOverlay direction={direction} rotateDeg={arrowRotateDeg} />}
      </svg>
    </div>
  );
}
