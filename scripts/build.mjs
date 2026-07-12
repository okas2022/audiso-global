import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  SITE,
  LOCALES,
  NAV,
  PAGE_META,
  CONTACT,
} from '../site.config.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const DIST = path.join(ROOT, 'dist');
const PUBLIC = path.join(ROOT, 'public');
const SOURCE = path.join(ROOT, 'source');
const TEMPLATES = path.join(ROOT, 'templates');

function copyDir(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const from = path.join(src, entry.name);
    const to = path.join(dest, entry.name);
    if (entry.isDirectory()) copyDir(from, to);
    else fs.copyFileSync(from, to);
  }
}

function pageHref(locale, slug) {
  const base = `/${locale}`;
  return slug ? `${base}/${slug}/` : `${base}/`;
}

function uiLabels(locale) {
  const L = {
    en: { menu: 'Menu', solutions: 'Solutions', links: 'Links', nav: 'Main' },
    zh: { menu: '菜单', solutions: '解决方案', links: '链接', nav: '主导航' },
    ja: { menu: 'メニュー', solutions: 'ソリューション', links: 'リンク', nav: 'メインナビ' },
  };
  return L[locale] || L.en;
}

function fontLinkFor(locale) {
  if (locale === 'zh') {
    return `<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.min.css">
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400;600;700;800&display=swap">
  <style>body.ag-body{font-family:'Noto Sans SC','Pretendard',sans-serif}</style>`;
  }
  if (locale === 'ja') {
    return `<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.min.css">
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@400;600;700;800&display=swap">
  <style>body.ag-body{font-family:'Noto Sans JP','Pretendard',sans-serif}</style>`;
  }
  return `<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.min.css">`;
}

function renderHeader(locale, activeSlug) {
  const ui = uiLabels(locale);
  const links = NAV.map((item) => {
    const href = pageHref(locale, item.href);
    const active = item.href === activeSlug ? ' is-active' : '';
    const label = item.label[locale] || item.label.en;
    return `<a class="ag-nav__link${active}" href="${href}">${label}</a>`;
  }).join('\n        ');

  const langLinks = Object.entries(LOCALES)
    .map(([code, meta]) => {
      if (meta.live) {
        return `<a class="ag-lang__item${code === locale ? ' is-active' : ''}" href="${pageHref(code, activeSlug === 'index' ? '' : activeSlug)}" hreflang="${code}">${meta.label}</a>`;
      }
      return `<span class="ag-lang__item ag-lang__item--soon" title="Coming soon">${meta.label}</span>`;
    })
    .join('\n          ');

  return `<header class="ag-header">
  <div class="ag-header__inner">
    <a class="ag-logo" href="${pageHref(locale, '')}">
      <span class="ag-logo__text">Audiso</span>
      <span class="ag-logo__sub">AudiMall</span>
    </a>
    <button class="ag-nav-toggle" type="button" aria-expanded="false" aria-controls="ag-nav" data-nav-toggle>
      <span class="ag-nav-toggle__bar"></span>
      <span class="ag-nav-toggle__bar"></span>
      <span class="ag-nav-toggle__bar"></span>
      <span class="sr-only">{{menuLabel}}</span>
    </button>
    <nav class="ag-nav" id="ag-nav" aria-label="${ui.nav}">
      <div class="ag-nav__links">
        ${links}
      </div>
      <div class="ag-lang" aria-label="Language">
        ${langLinks}
        <a class="ag-lang__item ag-lang__item--ko" href="${SITE.koStore}" hreflang="ko">KO</a>
      </div>
    </nav>
  </div>
</header>`;
}

function renderFooter(locale) {
  const year = new Date().getFullYear();
  const ui = uiLabels(locale);
  const t = {
    en: {
      tagline: 'Smart ear care from screening to wellness.',
      koShop: 'Korean store',
      company: 'Company site',
      rights: 'All rights reserved.',
      disclaimer: 'Information only — not medical advice. Consult a specialist for diagnosis or treatment.',
    },
    zh: { tagline: '从筛查到日常护理的智能耳部健康。', koShop: '韩国商城', company: '公司网站', rights: '版权所有。', disclaimer: '仅供参考，非医疗建议。' },
    ja: { tagline: '検査からウェルネスまで、スマートな耳ケア。', koShop: '韓国ストア', company: '会社サイト', rights: 'All rights reserved.', disclaimer: '情報提供のみ。診断・治療は専門医にご相談ください。' },
  }[locale] || {
    tagline: 'Smart ear care from screening to wellness.',
    koShop: 'Korean store',
    company: 'Company site',
    rights: 'All rights reserved.',
    disclaimer: 'Information only — not medical advice.',
  };

  const cols = NAV.filter((n) => n.id !== 'home')
    .map((item) => `<a href="${pageHref(locale, item.href)}">${item.label[locale] || item.label.en}</a>`)
    .join('\n          ');

  return `<footer class="ag-footer">
  <div class="ag-footer__inner">
    <div class="ag-footer__brand">
      <strong>Audiso · AudiMall</strong>
      <p>${t.tagline}</p>
    </div>
    <div class="ag-footer__links">
      <div class="ag-footer__col">
        <span class="ag-footer__label">${ui.solutions}</span>
        ${cols}
      </div>
      <div class="ag-footer__col">
        <span class="ag-footer__label">${ui.links}</span>
        <a href="${SITE.koStore}" rel="noopener">${t.koShop}</a>
        <a href="${SITE.companyUrl}" rel="noopener">${t.company}</a>
        <a href="mailto:${CONTACT.email}">${CONTACT.email}</a>
      </div>
    </div>
  </div>
  <div class="ag-footer__bottom">
    <p>© ${year} Audiso Co., Ltd. ${t.rights}</p>
    <p class="ag-footer__note">${t.disclaimer}</p>
  </div>
</footer>`;
}

function renderPage(locale, slug, body) {
  const layout = fs.readFileSync(path.join(TEMPLATES, 'layout.html'), 'utf8');
  const meta = PAGE_META[locale]?.[slug] || PAGE_META.en[slug] || PAGE_META.en.index;
  const ui = uiLabels(locale);
  const canonical = slug === 'index'
    ? `https://${SITE.domain}/${locale}/`
    : `https://${SITE.domain}/${locale}/${slug}/`;

  return layout
    .replaceAll('{{lang}}', locale)
    .replaceAll('{{dir}}', LOCALES[locale]?.dir || 'ltr')
    .replaceAll('{{title}}', meta.title)
    .replaceAll('{{description}}', meta.description)
    .replaceAll('{{canonical}}', canonical)
    .replaceAll('{{baseUrl}}', SITE.baseUrl)
    .replaceAll('{{fontLink}}', fontLinkFor(locale))
    .replaceAll('{{menuLabel}}', ui.menu)
    .replaceAll('{{header}}', renderHeader(locale, slug === 'index' ? '' : slug))
    .replaceAll('{{content}}', body)
    .replaceAll('{{footer}}', renderFooter(locale));
}

function buildLocale(locale) {
  const dir = path.join(SOURCE, locale);
  if (!fs.existsSync(dir)) return;
  const outDir = path.join(DIST, locale);
  fs.mkdirSync(outDir, { recursive: true });

  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.html'))) {
    const slug = file.replace(/\.html$/, '');
    const body = fs.readFileSync(path.join(dir, file), 'utf8');
    const html = renderPage(locale, slug, body);
    const outName = slug === 'index' ? 'index.html' : `${slug}/index.html`;
    const outPath = path.join(DIST, locale, outName);
    fs.mkdirSync(path.dirname(outPath), { recursive: true });
    fs.writeFileSync(outPath, html);
    console.log(`  ✓ /${locale}/${slug === 'index' ? '' : slug + '/'}`);
  }
}

function buildComingSoon(locale) {
  const stub = fs.readFileSync(path.join(SOURCE, 'stubs', 'coming-soon.html'), 'utf8');
  const labels = { zh: '中文', ja: '日本語' };
  const html = renderPage(locale, 'index', stub
    .replace('{{localeLabel}}', labels[locale] || locale)
    .replace('{{enLink}}', pageHref('en', '')));
  const outPath = path.join(DIST, locale, 'index.html');
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, html);
  console.log(`  ✓ /${locale}/ (coming soon)`);
}

function buildRootRedirect() {
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="0;url=/en/">
  <link rel="canonical" href="https://${SITE.domain}/en/">
  <title>Redirecting…</title>
  <script>location.replace('/en/');</script>
</head>
<body><p><a href="/en/">Audiso Global — English</a></p></body>
</html>`;
  fs.writeFileSync(path.join(DIST, 'index.html'), html);
  console.log('  ✓ / → /en/');
}

// ── main ──
fs.rmSync(DIST, { recursive: true, force: true });
fs.mkdirSync(DIST, { recursive: true });
copyDir(PUBLIC, DIST);

console.log('Building audiso-global…');
for (const [code, meta] of Object.entries(LOCALES)) {
  if (meta.live) buildLocale(code);
}
buildRootRedirect();
console.log('Done → dist/');
