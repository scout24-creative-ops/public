/*
 * Isolated Legacy Counter runtime proof.
 * Source behaviour: LP/LP Builder/runtime/core/core-interactions.js
 * Scope: Counter only. No external dependencies or global API.
 */
(function () {
  var observed = new WeakSet();
  var started = new WeakSet();

  function startCount(el) {
    if (started.has(el)) return;
    started.add(el);

    var originalText = el.textContent.trim();
    var match = originalText.match(/(\d+[.,]?\d*)/);
    if (!match) return;

    var numberPart = match[1];
    var prefix = originalText.slice(0, match.index);
    var suffix = originalText.slice(match.index + numberPart.length);
    var hasComma = numberPart.indexOf(',') !== -1;
    var cleaned = numberPart.replace(/\./g, '').replace(',', '.');
    var decimals = cleaned.indexOf('.') !== -1 ? cleaned.split('.')[1].length : 0;
    var target = parseFloat(cleaned);
    if (isNaN(target)) return;

    var duration = 1200;
    var start = null;

    function step(timestamp) {
      if (!start) start = timestamp;
      var progress = Math.min((timestamp - start) / duration, 1);
      var value = target * progress * (2 - progress);
      var display = decimals > 0 ? value.toFixed(decimals) : Math.round(value).toString();

      if (hasComma) display = display.replace('.', ',');
      el.textContent = prefix + display + suffix;

      if (progress < 1) requestAnimationFrame(step);
      else el.textContent = originalText;
    }

    requestAnimationFrame(step);
  }

  function initCounterAnimated(root) {
    var scope = root || document;
    var items = scope.querySelectorAll(
      '.counter-animated__item > [class^="font-heading-"], .counter-animated__item > [class*=" font-heading-"]'
    );

    if (!items.length) return;

    if (!('IntersectionObserver' in window)) {
      items.forEach(startCount);
      return;
    }

    var observer = new IntersectionObserver(function (entries, activeObserver) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          startCount(entry.target);
          activeObserver.unobserve(entry.target);
        }
      });
    }, { threshold: 0.4 });

    items.forEach(function (item) {
      if (observed.has(item) || started.has(item)) return;
      observed.add(item);
      observer.observe(item);
    });
  }

  function boot() {
    initCounterAnimated(document);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot, { once: true });
  } else {
    boot();
  }
}());
