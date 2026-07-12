(function () {
  var host = document.getElementById('vdr-deck-host');
  if (!host) return;

  var params = new URLSearchParams(window.location.search);
  var token = params.get('t') || '';
  var sessionId = (typeof crypto !== 'undefined' && crypto.randomUUID)
    ? crypto.randomUUID()
    : ('vdr-' + Date.now() + '-' + Math.random().toString(16).slice(2));

  var BEACON_URL = '/api/vdr-beacon';
  var HEARTBEAT_MS = 5000;
  var currentSlide = '';
  var slideEnteredAt = Date.now();
  var dwellMap = {};

  function utm(key) {
    return params.get(key) || '';
  }

  function postBeacon(payload) {
    var body = Object.assign({
      token: token,
      session_id: sessionId,
      utm_source: utm('utm_source'),
      utm_medium: utm('utm_medium'),
      utm_campaign: utm('utm_campaign'),
      asset: 'ir_deck',
    }, payload);
    return fetch(BEACON_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    }).catch(function () { return null; });
  }

  function flushSlide() {
    if (!currentSlide) return;
    var secs = Math.round((Date.now() - slideEnteredAt) / 1000);
    if (secs < 1) return;
    dwellMap[currentSlide] = Math.max(dwellMap[currentSlide] || 0, secs);
    postBeacon({ event: 'heartbeat', slide_id: currentSlide, dwell_seconds: dwellMap[currentSlide] });
  }

  function setSlide(slideId) {
    if (slideId === currentSlide) return;
    flushSlide();
    currentSlide = slideId;
    slideEnteredAt = Date.now();
    postBeacon({ event: 'slide_enter', slide_id: slideId, dwell_seconds: 0 });
  }

  function observeSlides(root) {
    var slides = root.querySelectorAll('[data-vdr-slide]');
    if (!slides.length) return;
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting && entry.intersectionRatio >= 0.45) {
          setSlide(entry.target.getAttribute('data-vdr-slide'));
        }
      });
    }, { threshold: [0.45, 0.6] });
    slides.forEach(function (el) { observer.observe(el); });
  }

  function finalize() {
    flushSlide();
    var total = Object.values(dwellMap).reduce(function (a, b) { return a + b; }, 0);
    postBeacon({ event: 'session_end', slide_id: currentSlide, dwell_seconds: dwellMap[currentSlide] || 0, total_seconds: total, finalize: true });
  }

  window.addEventListener('pagehide', finalize);
  window.addEventListener('beforeunload', finalize);
  setInterval(flushSlide, HEARTBEAT_MS);

  fetch('/vdr/ir-deck-content.html', { cache: 'no-store' })
    .then(function (r) { return r.text(); })
    .then(function (html) {
      host.innerHTML = html;
      observeSlides(host);
      postBeacon({ event: 'session_start', slide_id: 'cover', dwell_seconds: 0 });
    })
    .catch(function () {
      host.innerHTML = '<p class="ag-muted">Unable to load deck. <a href="/downloads/Audiso_Global_IR_Deck.pdf">Download PDF</a> instead.</p>';
    });
})();
