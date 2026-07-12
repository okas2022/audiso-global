/**
 * Generates source/zh and source/ja from source/en by locale prefix + string map.
 * Run: node scripts/generate-locales.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const EN_DIR = path.join(__dirname, '../source/en');
const MAP = (await import('../content/locale-strings.mjs')).LOCALE_STRINGS;

function localize(html, locale) {
  let out = html.replaceAll('/en/', `/${locale}/`);
  const pairs = [...(MAP[locale] || [])];
  pairs.sort((a, b) => b[0].length - a[0].length);
  for (const [from, to] of pairs) {
    out = out.split(from).join(to);
  }
  return out;
}

for (const locale of ['zh', 'ja']) {
  const dest = path.join(__dirname, `../source/${locale}`);
  fs.mkdirSync(dest, { recursive: true });
  for (const file of fs.readdirSync(EN_DIR).filter((f) => f.endsWith('.html'))) {
    const src = fs.readFileSync(path.join(EN_DIR, file), 'utf8');
    fs.writeFileSync(path.join(dest, file), localize(src, locale));
    console.log(`  ${locale}/${file}`);
  }
}
console.log('Done.');
