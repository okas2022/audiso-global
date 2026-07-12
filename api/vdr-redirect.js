/** Tracked PDF/asset redirect — logs via pipeline webhook when token present. */
export default async function handler(req, res) {
  const token = req.query.t || '';
  const asset = req.query.a || 'ma_onepager';
  const base = 'https://audimall.vercel.app';
  const targets = {
    ma_onepager: '/downloads/Audiso_MA_OnePager.pdf',
    ir_deck_pdf: '/downloads/Audiso_Global_IR_Deck.pdf',
    whitepaper: '/downloads/Audiso_Whitepaper_ISO7029.pdf',
  };
  const dest = targets[asset] || targets.ma_onepager;

  const webhookUrl = process.env.PIPELINE_VDR_WEBHOOK_URL;
  if (token && webhookUrl) {
    try {
      const clickUrl = webhookUrl.replace('/webhooks/vdr-beacon', `/webhooks/vdr-click/${encodeURIComponent(token)}`);
      return res.redirect(302, clickUrl);
    } catch {
      /* fall through */
    }
  }

  return res.redirect(302, `${base}${dest}`);
}
