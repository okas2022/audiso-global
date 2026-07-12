/**
 * VDR beacon — forwards to Mac mini pipeline webhook when configured.
 * Env: PIPELINE_VDR_WEBHOOK_URL (e.g. https://<tunnel>/webhooks/vdr-beacon)
 *      PIPELINE_WEBHOOK_SECRET
 */
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ ok: false });

  let body = req.body;
  if (typeof body === 'string') {
    try {
      body = JSON.parse(body);
    } catch {
      return res.status(400).json({ ok: false });
    }
  }
  if (!body || typeof body !== 'object') return res.status(400).json({ ok: false });

  const webhookUrl = process.env.PIPELINE_VDR_WEBHOOK_URL || '';
  const secret = process.env.PIPELINE_WEBHOOK_SECRET || '';

  if (webhookUrl) {
    try {
      const headers = { 'Content-Type': 'application/json' };
      if (secret) headers['X-Webhook-Secret'] = secret;
      const url = webhookUrl.includes('vdr-beacon')
        ? webhookUrl
        : webhookUrl.replace('whitepaper-lead', 'vdr-beacon');
      const fwd = await fetch(url, { method: 'POST', headers, body: JSON.stringify(body) });
      const data = await fwd.json().catch(() => ({}));
      return res.status(200).json({ ok: true, forwarded: fwd.ok, ...data });
    } catch (err) {
      console.warn('vdr beacon forward failed', err?.message);
    }
  }

  return res.status(200).json({ ok: true, forwarded: false, session_id: body.session_id });
}
