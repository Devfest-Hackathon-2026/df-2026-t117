// TownMap (T1): SVG map of the fictional town "Minato Bay" (requirements 6.3 / 6.4, implementation-plan 3.4).
// Route / position / heading come from useNavigation(), so S04 / S07 / S08 / S11 / S12 all show the same values.
import {
  useId,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
  type KeyboardEvent,
  type PointerEvent,
  type RefObject,
} from 'react';
import type { Point } from '../state/types';
import { useAppState } from '../state/store';
import {
  COASTLINE,
  EDGES,
  HAZARD_ZONE,
  HIGH_GROUND_MIN_X,
  MAP_LABELS,
  NODES,
  REFUGES,
  SEA_POLYGON,
  STREETS,
  TOWN_BOUNDS,
  TOWN_NAME,
} from '../data/town';
import { useNavigation } from '../logic/nav';
import './TownMap.css';

export interface ViewBox {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface TownMapProps {
  /** mini = card in S04/S11 (wide, 810:435), full = S07/S08/S12 (810:780). Override the size with style. */
  variant?: 'mini' | 'full';
  /** blue (S04), yellow with dark outline (S11), none (S07/S08/S12). Draws the remaining route. */
  routeColor?: 'blue' | 'yellow' | 'none';
  /** GPS accuracy circle (S07). The blue dot is then drawn at gps.position instead of the walk position. */
  showAccuracy?: boolean;
  /** Pin can be tapped / dragged (S07). Uncontrolled unless `pin` is given. */
  pinEditable?: boolean;
  /** Controlled pin position. Undefined = uncontrolled (starts at manualPin ?? gps.position when editable). */
  pin?: Point | null;
  /** Called on tap and while dragging (town meters, clamped to the visible map). */
  onPinChange?: (p: Point) => void;
  /** Current position as a blue circle with a white navigation arrow (S11). Otherwise a blue dot. */
  showHeading?: boolean;
  /** Live compass heading for that marker (deg). null / omitted = the walking direction along the route. */
  headingDeg?: number | null;
  /** Show the current-position marker at all (default true). */
  showPosition?: boolean;
  /** Show closed-road markers (default: only while online — offline the live status is unknown). */
  showClosures?: boolean;
  /** Show every refuge flag. Default: full = all refuges, mini = only the route's refuge. */
  showAllRefuges?: boolean;
  /** Explicit view box in town meters (cropped with "slice" to fill the card). */
  viewBox?: ViewBox;
  /** Center the default view on this point. */
  focus?: Point;
  /** Accessible label. Defaults to the town name. */
  ariaLabel?: string;
  className?: string;
  style?: CSSProperties;
}

/**
 * The accuracy circle is proportional to gps.accuracyM (F21) but drawn at half scale so that ±180 m
 * still leaves the map readable (matches screen-07).
 */
export const ACCURACY_DRAW_SCALE = 1;

const DEFAULT_ASPECT = { mini: 810 / 435, full: 810 / 780 } as const;
const ASSUMED_WIDTH_PX = 340;

const COLORS = {
  sea: 'var(--tk-map-sea, #bad3e6)',
  land: 'var(--tk-map-land, #e8e8e0)',
  road: 'var(--tk-map-road, #ffffff)',
  hazard: 'var(--tk-map-hazard, #f0c4bc)',
  stripe: 'var(--tk-map-hazard-stripe, #a8323a)',
  route: 'var(--tk-map-route, #1a4f9c)',
  routeAr: 'var(--tk-map-route-ar, #ffd54f)',
  accuracy: 'var(--tk-map-accuracy-fill, #cfe0f0)',
  seaLabel: 'var(--tk-map-label-sea, #1a4f9c)',
  ink: '#17151a',
  steps: '#a8a095',
  closed: '#ae1428',
};

// ---------------------------------------------------------------------------
// Static geometry (computed once)

function pathD(points: Point[], close = false): string {
  return points.map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(' ') + (close ? ' Z' : '');
}

function extend(from: Point, toward: Point, len: number): Point {
  const dx = from.x - toward.x;
  const dy = from.y - toward.y;
  const l = Math.hypot(dx, dy) || 1;
  return { x: from.x + (dx / l) * len, y: from.y + (dy / l) * len };
}

const EXTENSION_M = 400;

const STREET_PATHS = STREETS.map((s) => {
  const pts: Point[] = s.nodes.map((id) => ({ x: NODES[id].x, y: NODES[id].y }));
  if (s.extendStart && pts.length > 1) pts.unshift(extend(pts[0], pts[1], EXTENSION_M));
  if (s.extendEnd && pts.length > 1) pts.push(extend(pts[pts.length - 1], pts[pts.length - 2], EXTENSION_M));
  return { id: s.id, stairs: !!s.stairs, d: pathD(pts) };
});

const SEA_D = pathD(SEA_POLYGON, true);
const HAZARD_D = pathD(HAZARD_ZONE, true);

const CLOSED_EDGES = EDGES.filter((e) => e.closure).map((e) => {
  const a = NODES[e.a];
  const b = NODES[e.b];
  return { id: e.id, mid: { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }, angle: (Math.atan2(b.y - a.y, b.x - a.x) * 180) / Math.PI };
});

/** x of the coastline at a given y (linear interpolation). */
function coastXAt(y: number): number {
  for (let i = 0; i < COASTLINE.length - 1; i++) {
    const a = COASTLINE[i];
    const b = COASTLINE[i + 1];
    if (y >= a.y && y <= b.y) return a.x + ((b.x - a.x) * (y - a.y)) / (b.y - a.y || 1);
  }
  return COASTLINE[COASTLINE.length - 1].x;
}

// ---------------------------------------------------------------------------
// View box helpers

function fitBox(points: Point[], aspect: number, minW: number, pad: number): ViewBox {
  let x0 = Infinity;
  let y0 = Infinity;
  let x1 = -Infinity;
  let y1 = -Infinity;
  for (const p of points) {
    x0 = Math.min(x0, p.x);
    y0 = Math.min(y0, p.y);
    x1 = Math.max(x1, p.x);
    y1 = Math.max(y1, p.y);
  }
  x0 -= pad;
  y0 -= pad;
  x1 += pad;
  y1 += pad;
  let w = Math.max(minW, x1 - x0);
  let h = y1 - y0;
  if (w / h < aspect) w = h * aspect;
  else h = w / aspect;
  const cx = (x0 + x1) / 2;
  const cy = (y0 + y1) / 2;
  return { x: cx - w / 2, y: cy - h / 2, w, h };
}

/** Area actually visible inside a cw x ch box with preserveAspectRatio="xMidYMid slice". */
function visibleRect(vb: ViewBox, cw: number, ch: number): { rect: ViewBox; mPerPx: number } {
  const scale = Math.max(cw / vb.w, ch / vb.h);
  const w = cw / scale;
  const h = ch / scale;
  return { rect: { x: vb.x + (vb.w - w) / 2, y: vb.y + (vb.h - h) / 2, w, h }, mPerPx: 1 / scale };
}

function useElementSize(ref: RefObject<HTMLElement | null>, fallback: { w: number; h: number }) {
  const [size, setSize] = useState(fallback);
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const update = () => {
      const r = el.getBoundingClientRect();
      if (r.width > 0 && r.height > 0) {
        setSize((s) => (Math.abs(s.w - r.width) < 0.5 && Math.abs(s.h - r.height) < 0.5 ? s : { w: r.width, h: r.height }));
      }
    };
    update();
    if (typeof ResizeObserver === 'undefined') return;
    const ro = new ResizeObserver(update);
    ro.observe(el);
    return () => ro.disconnect();
  }, [ref]);
  return size;
}

// ---------------------------------------------------------------------------
// Markers

function RefugeFlag({ at, u, r }: { at: Point; u: number; r: number }) {
  const s = r * u;
  return (
    <g transform={`translate(${at.x} ${at.y})`}>
      <circle r={s + 2.5 * u} fill={COLORS.road} />
      <circle r={s} fill={COLORS.ink} />
      <g
        fill="none"
        stroke="#fff"
        strokeWidth={1.6 * u}
        strokeLinecap="round"
        strokeLinejoin="round"
        transform={`scale(${s / 14})`}
      >
        {/* pole + two-part flag (outline), like the refuge flag in the designs */}
        <path d="M-5.5 8 V-8" />
        <path d="M-5.5 -8 H1 V-5.5 H6.5 V2.5 H0.5 V0 H-5.5" />
      </g>
    </g>
  );
}

function PositionDot({ at, u }: { at: Point; u: number }) {
  return (
    <g transform={`translate(${at.x} ${at.y})`}>
      <circle r={9.5 * u} fill="#fff" />
      <circle r={6.5 * u} fill={COLORS.route} />
    </g>
  );
}

function HeadingMarker({ at, u, headingDeg }: { at: Point; u: number; headingDeg: number }) {
  return (
    <g transform={`translate(${at.x} ${at.y})`}>
      <circle r={13 * u} fill="#fff" />
      <circle r={10.5 * u} fill={COLORS.route} />
      <path
        transform={`rotate(${headingDeg}) scale(${u})`}
        d="M0 -6.8 L5.4 5.6 L0 3 L-5.4 5.6 Z"
        fill="#fff"
        stroke="#fff"
        strokeWidth={1}
        strokeLinejoin="round"
      />
    </g>
  );
}

function MapPin({ at, u }: { at: Point; u: number }) {
  // Tip of the pin is at `at`. Drawn in px units, then scaled.
  return (
    <g transform={`translate(${at.x} ${at.y}) scale(${u})`} pointerEvents="none">
      <ellipse cx={0} cy={0} rx={4} ry={1.6} fill="rgba(0,0,0,0.25)" />
      <path
        d="M0 0 C-2.5 -6 -11 -12.5 -11 -20.5 A11 11 0 1 1 11 -20.5 C11 -12.5 2.5 -6 0 0 Z"
        fill={COLORS.ink}
        stroke="#fff"
        strokeWidth={1.2}
      />
      <circle cx={0} cy={-20.5} r={4.2} fill="#fff" />
    </g>
  );
}

function ClosureMark({ at, angle, u }: { at: Point; angle: number; u: number }) {
  return (
    <g transform={`translate(${at.x} ${at.y}) rotate(${angle}) scale(${u})`}>
      <circle r={6.5} fill={COLORS.closed} stroke="#fff" strokeWidth={1.5} />
      <rect x={-1.2} y={-3.8} width={2.4} height={7.6} rx={1} fill="#fff" />
    </g>
  );
}

// ---------------------------------------------------------------------------
// Component

export function TownMap({
  variant = 'mini',
  routeColor = 'blue',
  showAccuracy = false,
  pinEditable = false,
  pin,
  onPinChange,
  showHeading = false,
  headingDeg,
  showPosition = true,
  showClosures,
  showAllRefuges,
  viewBox,
  focus,
  ariaLabel,
  className,
  style,
}: TownMapProps) {
  const state = useAppState();
  const nav = useNavigation();
  const lang = state.lang;
  const wrapRef = useRef<HTMLDivElement>(null);
  const svgRef = useRef<SVGSVGElement>(null);
  const rawId = useId();
  const uid = rawId.replace(/[^a-zA-Z0-9_-]/g, '');

  const defaultAspect = DEFAULT_ASPECT[variant];
  const size = useElementSize(wrapRef, { w: ASSUMED_WIDTH_PX, h: ASSUMED_WIDTH_PX / defaultAspect });
  const aspect = size.w / size.h || defaultAspect;

  // Pin (uncontrolled fallback)
  const [localPin, setLocalPin] = useState<Point>(() => state.manualPin ?? state.gps.position);
  const pinPos: Point | null = pin !== undefined ? pin : pinEditable ? localPin : null;

  const markerPos = showAccuracy ? state.gps.position : nav.position;

  // View box
  const routePts = nav.route.points;
  const { x: ox, y: oy } = nav.origin;
  const vb: ViewBox = useMemo(() => {
    if (viewBox) return viewBox;
    let box: ViewBox;
    if (variant === 'mini') {
      const pts = [...routePts, { x: ox, y: oy }, nav.route.refuge.pos];
      const cy = pts.reduce((a, p) => a + p.y, 0) / pts.length;
      pts.push({ x: coastXAt(cy) - 40, y: cy }); // keep a strip of sea on the left (+ pad)
      box = fitBox(pts, aspect, 560, 50);
    } else {
      box = fitBox(
        [
          { x: -30, y: TOWN_BOUNDS.y },
          { x: TOWN_BOUNDS.x + TOWN_BOUNDS.w + 12, y: TOWN_BOUNDS.y + TOWN_BOUNDS.h },
          // keep the whole accuracy circle in frame
          ...(showAccuracy
            ? [
                { x: state.gps.position.x - state.gps.accuracyM * ACCURACY_DRAW_SCALE - 8, y: state.gps.position.y },
                { x: state.gps.position.x, y: state.gps.position.y - state.gps.accuracyM * ACCURACY_DRAW_SCALE - 8 },
              ]
            : []),
        ],
        aspect,
        0,
        0,
      );
    }
    if (focus) box = { ...box, x: focus.x - box.w / 2, y: focus.y - box.h / 2 };
    return box;
  }, [viewBox, variant, routePts, ox, oy, nav.route.refuge.pos, aspect, focus, showAccuracy, state.gps.position.x, state.gps.position.y, state.gps.accuracyM]);

  const { rect: vis, mPerPx: u } = visibleRect(vb, size.w, size.h);
  const roadW = (variant === 'mini' ? 6 : 8.5) * u;
  const stripe = 8.5 * u;

  const closuresVisible = showClosures ?? state.online;
  const allRefuges = showAllRefuges ?? variant === 'full';
  const refuges = allRefuges ? REFUGES : [nav.route.refuge];

  // ----- pin interaction -----
  const draggingRef = useRef(false);
  const toTown = (clientX: number, clientY: number): Point | null => {
    const svg = svgRef.current;
    const m = svg?.getScreenCTM();
    if (!svg || !m) return null;
    const p = new DOMPoint(clientX, clientY).matrixTransform(m.inverse());
    const inset = 12 * u;
    return {
      x: Math.round(Math.max(vis.x + inset, Math.min(vis.x + vis.w - inset, p.x))),
      y: Math.round(Math.max(vis.y + inset * 3, Math.min(vis.y + vis.h - inset, p.y))),
    };
  };
  const setPin = (p: Point) => {
    if (pin === undefined) setLocalPin(p);
    onPinChange?.(p);
  };
  const onPointerDown = (e: PointerEvent<SVGSVGElement>) => {
    if (!pinEditable) return;
    const p = toTown(e.clientX, e.clientY);
    if (!p) return;
    draggingRef.current = true;
    e.currentTarget.setPointerCapture?.(e.pointerId);
    setPin(p);
  };
  const onPointerMove = (e: PointerEvent<SVGSVGElement>) => {
    if (!pinEditable || !draggingRef.current) return;
    const p = toTown(e.clientX, e.clientY);
    if (p) setPin(p);
  };
  const endDrag = (e: PointerEvent<SVGSVGElement>) => {
    if (!draggingRef.current) return;
    draggingRef.current = false;
    e.currentTarget.releasePointerCapture?.(e.pointerId);
  };
  const onKeyDown = (e: KeyboardEvent<SVGSVGElement>) => {
    if (!pinEditable || !pinPos) return;
    const step = e.shiftKey ? 30 : 10;
    const d: Record<string, Point> = {
      ArrowUp: { x: 0, y: -step },
      ArrowDown: { x: 0, y: step },
      ArrowLeft: { x: -step, y: 0 },
      ArrowRight: { x: step, y: 0 },
    };
    const delta = d[e.key];
    if (!delta) return;
    e.preventDefault();
    setPin({ x: pinPos.x + delta.x, y: pinPos.y + delta.y });
  };

  // ----- labels -----
  const fs = 12.5 * u;
  const seaLabelY = vis.y + vis.h - 12 * u;
  const showSeaLabel = coastXAt(seaLabelY) - vis.x > 36 * u;
  const showHighGround = vis.x + vis.w > HIGH_GROUND_MIN_X + 60;
  const seaText = MAP_LABELS.sea[lang];
  const hgText = MAP_LABELS.highGround[lang];

  const routeD = routeColor !== 'none' && nav.remainingPoints.length > 1 ? pathD(nav.remainingPoints) : null;
  const hatchId = `tk-hatch-${uid}`;

  const classes = ['tk-townmap', `tk-townmap--${variant}`, pinEditable ? 'tk-townmap--editable' : '', className ?? '']
    .filter(Boolean)
    .join(' ');

  return (
    <div ref={wrapRef} className={classes} style={style} dir="ltr">
      <svg
        ref={svgRef}
        className="tk-townmap__svg"
        viewBox={`${vb.x} ${vb.y} ${vb.w} ${vb.h}`}
        preserveAspectRatio="xMidYMid slice"
        role="img"
        aria-label={ariaLabel ?? TOWN_NAME[lang]}
        tabIndex={pinEditable ? 0 : undefined}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={endDrag}
        onPointerCancel={endDrag}
        onKeyDown={onKeyDown}
      >
        <defs>
          <pattern id={hatchId} patternUnits="userSpaceOnUse" width={stripe} height={stripe} patternTransform="rotate(45)">
            <rect width={stripe} height={stripe} fill={COLORS.hazard} />
            <line x1={0} y1={0} x2={0} y2={stripe} stroke={COLORS.stripe} strokeWidth={1.5 * u} />
          </pattern>
        </defs>

        {/* land, hazard band, sea */}
        <rect x={vb.x - vb.w} y={vb.y - vb.h} width={vb.w * 3} height={vb.h * 3} fill={COLORS.land} />
        <path d={HAZARD_D} fill={`url(#${hatchId})`} />
        <path d={SEA_D} fill={COLORS.sea} />

        {/* roads */}
        <g fill="none" stroke={COLORS.road} strokeWidth={roadW} strokeLinecap="round" strokeLinejoin="round">
          {STREET_PATHS.filter((s) => !s.stairs).map((s) => (
            <path key={s.id} d={s.d} />
          ))}
        </g>
        {/* stairs: narrower road with step ticks */}
        {STREET_PATHS.filter((s) => s.stairs).map((s) => (
          <g key={s.id} fill="none" strokeLinecap="butt">
            <path d={s.d} stroke={COLORS.road} strokeWidth={roadW * 0.85} strokeLinecap="round" />
            <path d={s.d} stroke={COLORS.steps} strokeWidth={roadW * 0.85} strokeDasharray={`${1.3 * u} ${2.6 * u}`} />
          </g>
        ))}

        {closuresVisible &&
          CLOSED_EDGES.map((c) => <ClosureMark key={c.id} at={c.mid} angle={c.angle} u={u} />)}

        {/* route */}
        {routeD && routeColor === 'yellow' && (
          <g fill="none" strokeLinecap="round" strokeLinejoin="round">
            <path d={routeD} stroke={COLORS.ink} strokeWidth={9.5 * u} />
            <path d={routeD} stroke={COLORS.routeAr} strokeWidth={5.5 * u} />
          </g>
        )}
        {routeD && routeColor === 'blue' && (
          <path d={routeD} fill="none" stroke={COLORS.route} strokeWidth={6 * u} strokeLinecap="round" strokeLinejoin="round" />
        )}

        {/* refuges */}
        {refuges.map((r) => (
          <RefugeFlag key={r.id} at={r.pos} u={u} r={variant === 'mini' ? 13.5 : 14.5} />
        ))}

        {/* labels */}
        {showSeaLabel && (
          <text
            className="tk-townmap__label"
            x={vis.x + 10 * u}
            y={seaLabelY}
            fontSize={fs}
            fill={COLORS.seaLabel}
            stroke={COLORS.sea}
            strokeWidth={3 * u}
          >
            {seaText}
          </text>
        )}
        {showHighGround && (
          <text
            className="tk-townmap__label"
            x={vis.x + vis.w - 12 * u}
            y={vis.y + 22 * u}
            fontSize={fs}
            textAnchor="end"
            fill={COLORS.ink}
            stroke={COLORS.land}
            strokeWidth={3 * u}
          >
            {hgText}
          </text>
        )}

        {/* GPS accuracy */}
        {showAccuracy && (
          <circle
            cx={state.gps.position.x}
            cy={state.gps.position.y}
            r={Math.max(4 * u, state.gps.accuracyM * ACCURACY_DRAW_SCALE)}
            fill={COLORS.accuracy}
            fillOpacity={0.9}
            stroke={COLORS.route}
            strokeWidth={2 * u}
          />
        )}

        {/* current position */}
        {showPosition &&
          (showHeading ? (
            <HeadingMarker at={markerPos} u={u} headingDeg={headingDeg ?? nav.headingDeg} />
          ) : (
            <PositionDot at={markerPos} u={u} />
          ))}

        {pinPos && <MapPin at={pinPos} u={u} />}
      </svg>
    </div>
  );
}

export default TownMap;
