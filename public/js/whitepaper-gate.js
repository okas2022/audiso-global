(function () {
  var form = document.getElementById('whitepaper-form');
  var gate = document.getElementById('whitepaper-gate');
  var success = document.getElementById('whitepaper-success');
  var statusEl = document.getElementById('whitepaper-status');
  var downloadLink = document.getElementById('whitepaper-download');
  var submitBtn = document.getElementById('whitepaper-submit');
  if (!form || !gate || !success) return;

  var PDF_BASE = '/downloads/Audiso_Whitepaper_ISO7029.pdf';

  function setStatus(msg, isError) {
    if (!statusEl) return;
    statusEl.textContent = msg || '';
    statusEl.className = 'ag-form__status' + (isError ? ' ag-form__status--error' : '');
  }

  function applyPdfUrl(manifest) {
    var url = PDF_BASE;
    if (manifest && manifest.version) {
      url += '?v=' + encodeURIComponent(manifest.version);
    }
    if (downloadLink) {
      downloadLink.href = url;
    }
    return url;
  }

  fetch('/downloads/whitepaper_manifest.json', { cache: 'no-store' })
    .then(function (r) { return r.ok ? r.json() : null; })
    .then(applyPdfUrl)
    .catch(function () { applyPdfUrl(null); });

  form.addEventListener('submit', function (e) {
    e.preventDefault();
    var fd = new FormData(form);
    var payload = {
      email: String(fd.get('email') || '').trim().toLowerCase(),
      first_name: String(fd.get('first_name') || '').trim(),
      company_name: String(fd.get('company_name') || '').trim(),
      source: 'audimall_whitepaper_gate',
    };

    if (!payload.first_name || !payload.company_name || !payload.email) {
      setStatus('Please fill in all fields.', true);
      return;
    }
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(payload.email)) {
      setStatus('Please enter a valid work email.', true);
      return;
    }

    submitBtn.disabled = true;
    setStatus('Preparing your download…');

    fetch('/api/whitepaper-lead', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    })
      .then(function (r) { return r.json().then(function (j) { return { ok: r.ok, body: j }; }); })
      .then(function (res) {
        var pdfUrl = (res.body && res.body.pdf_url) || applyPdfUrl(null);
        gate.hidden = true;
        success.hidden = false;
        setStatus('');
        if (downloadLink) downloadLink.href = pdfUrl;
        window.location.href = pdfUrl;
      })
      .catch(function () {
        var pdfUrl = applyPdfUrl(null);
        gate.hidden = true;
        success.hidden = false;
        setStatus('');
        if (downloadLink) downloadLink.href = pdfUrl;
        window.location.href = pdfUrl;
      })
      .finally(function () {
        submitBtn.disabled = false;
      });
  });
})();
