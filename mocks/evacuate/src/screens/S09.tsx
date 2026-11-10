// S09 Language picker (light). Apply sets + persists (localStorage) the language and goes back; App flips dir.
import { useState } from 'react';
import { SubLayout } from '../components/SubLayout';
import { BigButton } from '../components/BigButton';
import { Icon } from '../components/Icon';
import { FooterMeta } from '../components/FooterMeta';
import { actions, useDispatch } from '../state/store';
import { LANGS, LANG_NATIVE_NAMES, saveLang, useCommon, useLang, useSetLang, useT, type Lang } from '../i18n';
import './t3.css';

const dict = {
  en: { apply: 'Apply', note: 'Demo translations (not native-checked)' },
  ja: { apply: '適用', note: 'デモ用の翻訳です（ネイティブ確認なし）' },
  'zh-Hans': { apply: '应用', note: '演示用翻译（未经母语审校）' },
  ko: { apply: '적용', note: '데모용 번역(원어민 검수 없음)' },
  ar: { apply: 'تطبيق', note: 'ترجمة تجريبية (لم يراجعها متحدث أصلي)' },
};

export default function S09() {
  const t = useT(dict);
  const c = useCommon();
  const lang = useLang();
  const setLang = useSetLang();
  const dispatch = useDispatch();
  const [sel, setSel] = useState<Lang>(lang);

  const apply = () => {
    setLang(sel);
    saveLang(sel); // only an explicit user choice is remembered (not ?lang= or the demo panel)
    dispatch(actions.back());
  };

  return (
    <SubLayout
      theme="light"
      headerTitle={c.titleLanguage}
      title={c.titleLanguage}
      actions={
        <BigButton variant="black" icon="check" onClick={apply}>
          {t.apply}
        </BigButton>
      }
      footer={<FooterMeta theme="light" items={[t.note]} />}
    >
      <div className="t3-list" role="radiogroup" aria-label={c.titleLanguage}>
        {LANGS.map((l) => (
          <button
            key={l}
            type="button"
            role="radio"
            aria-checked={sel === l}
            lang={l}
            dir={l === 'ar' ? 'rtl' : 'ltr'}
            className={`t3-row ${sel === l ? 't3-row--sel' : ''}`}
            onClick={() => setSel(l)}
            style={l === 'ar' ? { textAlign: 'right' } : undefined}
          >
            <span className="t3-row__label">{LANG_NATIVE_NAMES[l]}</span>
            {sel === l && <Icon name="check" size={30} />}
          </button>
        ))}
      </div>
    </SubLayout>
  );
}
