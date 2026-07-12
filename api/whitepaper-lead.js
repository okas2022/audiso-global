/**
 * Vercel serverless — whitepaper gate lead capture.
 * Env (optional):
 *   PIPELINE_WHITEPAPER_WEBHOOK_URL — e.g. https://<tunnel>/webhooks/whitepaper-lead
 *   PIPELINE_WEBHOOK_SECRET — X-Webhook-Secret header
 *   RESEND_API_KEY + WHITEPAPER_NOTIFY_EMAIL — fallback alert when webhook unreachable
 */
const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const PDF_PATH = '/downloads/Audiso_Whitepaper_ISO7029.pdf';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ ok: false, error: 'method_not_allowed' });
  }

  let body = req.body;
  if (typeof body === 'string') {
    try {
      body = JSON.parse(body);
    } catch {
      return res.status(400).json({ ok: false, error: 'invalid_json' });
    }
  }
  if (!body || typeof body !== 'object') {
    return res.status(400).json({ ok: false, error: 'invalid_body' });
  }

  const email = String(body.email || '').trim().toLowerCase();
  const first_name = String(body.first_name || '').trim();
  const company_name = String(body.company_name || '').trim();
  const source = String(body.source || 'audimall_whitepaper_gate').trim();

  if (!email || !EMAIL_RE.test(email)) {
    return res.status(400).json({ ok: false, error: 'invalid_email' });
  }
  if (!first_name || !company_name) {
    return res.status(400).json({ ok: false, error: 'missing_fields' });
  }

  const lead = { email, first_name, company_name, source, captured_at: new Date().toISOString() };
  const webhookUrl = process.env.PIPELINE_WHITEPAPER_WEBHOOK_URL || '';
  const webhookSecret = process.env.PIPELINE_WEBHOOK_SECRET || '';
  let forwarded = false;

  if (webhookUrl) {
    try {
      const headers = { 'Content-Type': 'application/json' };
      if (webhookSecret) headers['X-Webhook-Secret'] = webhookSecret;
      const fwd = await fetch(webhookUrl, {
        method: 'POST',
        headers,
        body: JSON.stringify(lead),
      });
      forwarded = fwd.ok;
    } catch (err) {
      console.warn('whitepaper webhook forward failed:', err?.message || err);
    }
  }

  if (!forwarded && process.env.RESEND_API_KEY) {
    const notifyTo = process.env.WHITEPAPER_NOTIFY_EMAIL || 'okas2000@gmail.com';
    try {
      await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: process.env.WHITEPAPER_FROM_EMAIL || 'Audiso <onboarding@resend.dev>',
          to: [notifyTo],
          subject: `[Whitepaper] ${company_name} — ${email}`,
          text: JSON.stringify(lead, null, 2),
        }),
      });
    } catch (err) {
      console.warn('whitepaper resend notify failed:', err?.message || err);
    }
  }

  let pdf_url = PDF_PATH;
  try {
    const manifestHost = process.env.VERCEL_URL
      ? `https://${process.env.VERCEL_URL}`
      : 'https://audimall.vercel.app';
    const manifestRes = await fetch(`${manifestHost}/downloads/whitepaper_manifest.json`, {
      cache: 'no-store',
    });
    if (manifestRes.ok) {
      const manifest = await manifestRes.json();
      if (manifest.version) {
        pdf_url = `${PDF_PATH}?v=${encodeURIComponent(manifest.version)}`;
      }
    }
  } catch {
    /* use base path */
  }

  return res.status(200).json({ ok: true, forwarded, pdf_url });
}
