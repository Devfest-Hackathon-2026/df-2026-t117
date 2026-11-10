// A04 Disaster preparedness column (light): list -> detail inside the screen.
import { useState } from 'react';
import { SubLayout } from '../components/SubLayout';
import { BigButton } from '../components/BigButton';
import { FooterMeta } from '../components/FooterMeta';
import { ARTICLES } from '../data/articles';
import { useCommon, useLang, useT } from '../i18n';
import './t3.css';

const dict = {
  en: { list: 'All articles', note: 'General guidance, demo content' },
  ja: { list: '記事一覧', note: '一般的な案内（デモ用）' },
  'zh-Hans': { list: '全部文章', note: '通用指引（演示内容）' },
  ko: { list: '전체 글', note: '일반 안내(데모용)' },
  ar: { list: 'كل المقالات', note: 'إرشادات عامة (محتوى تجريبي)' },
};

export default function A04() {
  const t = useT(dict);
  const c = useCommon();
  const lang = useLang();
  const [openId, setOpenId] = useState<string | null>(null);
  const article = ARTICLES.find((a) => a.id === openId);

  return (
    <SubLayout
      theme="light"
      headerTitle={c.titleArticles}
      onBack={article ? () => setOpenId(null) : undefined}
      title={article ? article.title[lang] : c.titleArticles}
      actions={
        article ? (
          <BigButton variant="black" icon="arrow-left" onClick={() => setOpenId(null)}>
            {t.list}
          </BigButton>
        ) : undefined
      }
      footer={<FooterMeta theme="light" items={[t.note, c.translationNote]} />}
    >
      {article ? (
        article.body.map((p, i) => (
          <p key={i} className="t3-p">
            {p[lang]}
          </p>
        ))
      ) : (
        <div className="t3-list">
          {ARTICLES.map((a) => (
            <button key={a.id} type="button" className="t3-art" onClick={() => setOpenId(a.id)}>
              <span className="t3-art__title">{a.title[lang]}</span>
              <span className="t3-art__sum">{a.summary[lang]}</span>
            </button>
          ))}
        </div>
      )}
    </SubLayout>
  );
}
