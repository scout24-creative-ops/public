/* LP Builder Accordion — scoped legacy-compatible disclosure behaviour. */
(function () {
  function initialise(accordion) {
    accordion.querySelectorAll('.accordion__trigger').forEach(function (trigger) {
      var item = trigger.closest('.accordion__item');
      var panelId = trigger.getAttribute('aria-controls');
      var panel = panelId && document.getElementById(panelId);
      if (!item || !panel) return;

      function setOpen(open) {
        item.classList.toggle('is-open', open);
        trigger.setAttribute('aria-expanded', String(open));
        panel.hidden = !open;
      }

      setOpen(item.classList.contains('is-open'));
      trigger.addEventListener('click', function () {
        setOpen(!item.classList.contains('is-open'));
      });
    });
  }

  function boot() {
    document.querySelectorAll('[data-lpb-accordion]').forEach(initialise);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
}());
