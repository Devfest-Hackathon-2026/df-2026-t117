// Toast bound to state.toast. Auto-hides after `durationMs`. Rendered once by PhoneFrame.
// Show one with: dispatch(actions.showToast('Copied'))
import { useEffect } from 'react';
import { actions, useAppState, useDispatch } from '../state/store';
import './Toast.css';

export function Toast({ durationMs = 2500 }: { durationMs?: number }) {
  const { toast } = useAppState();
  const dispatch = useDispatch();
  useEffect(() => {
    if (!toast) return;
    const id = window.setTimeout(() => dispatch(actions.showToast(null)), durationMs);
    return () => window.clearTimeout(id);
  }, [toast, durationMs, dispatch]);
  if (!toast) return null;
  return (
    <div className="tk-toast" role="status" aria-live="polite">
      {toast}
    </div>
  );
}

export default Toast;
