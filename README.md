# Audiso · AudiMall (Global Site)

English (and future Chinese / Japanese) marketing site for **AudiMall** — Audiso's global buyer-facing pages.  
Mirrors the Korean [peacetop.store](https://peacetop.store) visual identity — **information only, no checkout**.

**Production:** https://audimall.vercel.app/en/

## Structure

```
audiso-global/
├── source/en/          # English page bodies (edit here)
├── source/stubs/       # Coming-soon template for zh / ja
├── public/css/         # Shared styles
├── scripts/build.mjs   # Assembles layout + i18n header/footer → dist/
├── site.config.mjs     # Nav, locales, contact URLs, image CDN paths
└── vercel.json
```

| URL (after deploy) | Page |
|---|---|
| `/en/` | Home — hero, 4 solutions, brand trust |
| `/en/about/` | About Audiso |
| `/en/withhear/` | WithHear 2.0 |
| `/en/peacetop/` | Peacetop Triple Care |
| `/en/modoo/` | Modoo Hearing |
| `/en/mindtone/` | MindTone T Care |
| `/en/contact/` | Contact |
| `/zh/`, `/ja/` | Coming soon (i18n-ready) |

## Local development

```bash
cd audiso-global
npm run build      # → dist/
npm run preview    # build + serve on http://localhost:3456
```

Edit `source/en/*.html` or `public/css/theme.css`, then rebuild.

## GitHub + Vercel setup (one-time)

Same pattern as `Modu_HA` on your Desktop.

### 1. Create GitHub repository

```bash
cd audiso-global
git init
git add .
git commit -m "Initial Audiso global EN site"
# Create repo on GitHub (e.g. audimall), then:
git remote add origin git@github.com:YOUR_USER/audimall.git
git branch -M main
git push -u origin main
```

### 2. Vercel project

**Option A — Vercel Git integration (recommended)**

1. [vercel.com/new](https://vercel.com/new) → Import the GitHub repo
2. Root directory: `audiso-global` if repo is the parent folder, or `.` if repo root is `audiso-global`
3. Build command: `npm run build`
4. Output directory: `dist`
5. Deploy

**Option B — GitHub Actions (like Modu_HA)**

1. Vercel dashboard → Account Settings → Tokens → create token
2. GitHub repo → Settings → Secrets → `VERCEL_TOKEN`
3. Link project once locally:

```bash
cd audiso-global
npx vercel link
```

4. Push to `main` — `.github/workflows/deploy.yml` deploys automatically

### 3. Custom domain

Vercel project → Settings → Domains → add custom domain (e.g. `en.audimall.com`)  
DNS: CNAME → `cname.vercel-dns.com`

### 4. Link from Korean site (when ready)

Add header language link in Sixshop `widgets/11-global-layout-base.html`:

```html
<a href="https://audimall.vercel.app/en/" hreflang="en">EN</a>
```

Rebuild and redeploy Sixshop theme — **Korean store stays unchanged** until you add this.

## Adding Chinese / Japanese later

1. Set `live: true` for `zh` or `ja` in `site.config.mjs`
2. Add `source/zh/*.html` (copy from `source/en/`, translate)
3. Add `PAGE_META.zh` entries in `site.config.mjs`
4. `npm run build` — build script auto-generates `/zh/` routes

## Secrets

Do **not** commit `.vercel/` or tokens. Use GitHub `VERCEL_TOKEN` secret only.
