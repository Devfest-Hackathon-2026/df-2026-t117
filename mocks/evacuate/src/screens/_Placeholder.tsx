// Shared placeholder used by not-yet-implemented screens (T0). Safe to delete once all screens are real.
import type { ReactNode } from 'react';
import type { ScreenId } from '../state/types';
import { GuidanceLayout } from '../components/GuidanceLayout';
import { SubLayout } from '../components/SubLayout';
import { Badge } from '../components/Badge';
import { FooterMeta } from '../components/FooterMeta';
import { SCREEN_META } from './meta';

export function Placeholder({ id, children }: { id: ScreenId; children?: ReactNode }) {
  const meta = SCREEN_META[id];
  if (meta.kind === 'sub') {
    return (
      <SubLayout
        headerTitle={meta.name}
        theme={meta.theme}
        badge={<Badge label="PLACEHOLDER" icon="clock" />}
        title={id}
        subtitle={meta.name}
        actions={children}
        footer={<FooterMeta theme={meta.theme} items={['Placeholder', id]} />}
      />
    );
  }
  return (
    <GuidanceLayout
      tone={id === 'S06' ? 'maroon' : id === 'S05' || id === 'H00' || id === 'S01' ? 'grey' : 'red'}
      badge={<Badge label={['PLACEHOLDER', id]} />}
      headline={id}
      subline={meta.name}
      footer={<FooterMeta items={['Placeholder', id]} />}
    >
      {children}
    </GuidanceLayout>
  );
}

export default Placeholder;
