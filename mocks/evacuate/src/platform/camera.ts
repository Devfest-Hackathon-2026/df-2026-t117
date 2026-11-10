// Rear camera stream for the Web AR view (S11, architecture.md 10.1 H5 / requirements F3C).
// Real devices only (touch primary pointer, secure context): PCs keep the still image / SVG street.
// The stream is stopped (track.stop()) whenever S11 unmounts or the page is hidden, and restarted
// when the page becomes visible again. A denial is remembered for the session, so the still image is
// used from then on without asking again.
import { useEffect, useState } from 'react';
import { tiltSupported } from './orientation';

export type CameraStatus = 'off' | 'starting' | 'on' | 'denied' | 'unavailable';

let deniedThisSession = false;

export function cameraSupported(): boolean {
  if (typeof window === 'undefined' || !window.isSecureContext) return false;
  return tiltSupported() && typeof navigator.mediaDevices?.getUserMedia === 'function';
}

function stopStream(stream: MediaStream | null) {
  stream?.getTracks().forEach((t) => t.stop());
}

function usePageVisible(): boolean {
  const [visible, setVisible] = useState(() => typeof document === 'undefined' || document.visibilityState !== 'hidden');
  useEffect(() => {
    const onChange = () => setVisible(document.visibilityState !== 'hidden');
    const onHide = () => setVisible(false);
    const onShow = () => setVisible(document.visibilityState !== 'hidden');
    document.addEventListener('visibilitychange', onChange);
    window.addEventListener('pagehide', onHide);
    window.addEventListener('pageshow', onShow);
    return () => {
      document.removeEventListener('visibilitychange', onChange);
      window.removeEventListener('pagehide', onHide);
      window.removeEventListener('pageshow', onShow);
    };
  }, []);
  return visible;
}

/** Back camera while `enabled` and the page is visible. `stream` is null whenever the still image should show. */
export function useBackCamera(enabled: boolean): { stream: MediaStream | null; status: CameraStatus } {
  const visible = usePageVisible();
  const [stream, setStream] = useState<MediaStream | null>(null);
  const [status, setStatus] = useState<CameraStatus>('off');

  useEffect(() => {
    if (!enabled || !visible || !cameraSupported()) {
      setStatus('off');
      return;
    }
    if (deniedThisSession) {
      setStatus('denied');
      return;
    }
    let cancelled = false;
    let current: MediaStream | null = null;
    setStatus('starting');
    navigator.mediaDevices
      .getUserMedia({ video: { facingMode: 'environment' }, audio: false })
      .then((s) => {
        if (cancelled) {
          stopStream(s);
          return;
        }
        current = s;
        // The camera can be taken away (another app, OS): fall back to the still image.
        s.getVideoTracks().forEach((t) =>
          t.addEventListener('ended', () => {
            if (cancelled) return;
            setStream(null);
            setStatus('unavailable');
          }),
        );
        setStream(s);
        setStatus('on');
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        const name = err instanceof DOMException ? err.name : '';
        if (name === 'NotAllowedError' || name === 'SecurityError') {
          deniedThisSession = true;
          setStatus('denied');
        } else {
          setStatus('unavailable');
        }
      });
    return () => {
      cancelled = true;
      stopStream(current);
      current = null;
      setStream(null);
    };
  }, [enabled, visible]);

  return { stream, status };
}
