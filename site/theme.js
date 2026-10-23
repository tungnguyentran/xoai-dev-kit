// Dark/light toggle. The saved choice lives in localStorage under the same key
// the app uses ("devkit-theme"); with nothing saved, the OS preference wins.
(function () {
  var root = document.documentElement;
  var btn = document.getElementById('theme-toggle');
  if (!btn) return;
  var dark = window.matchMedia('(prefers-color-scheme: dark)');

  function current() {
    return root.dataset.theme || (dark.matches ? 'dark' : 'light');
  }

  function render() {
    var isDark = current() === 'dark';
    btn.textContent = isDark ? '☀' : '☾';
    btn.setAttribute('aria-pressed', String(isDark));
    btn.setAttribute('aria-label', isDark ? 'Switch to light mode' : 'Switch to dark mode');
  }

  btn.addEventListener('click', function () {
    var next = current() === 'dark' ? 'light' : 'dark';
    root.dataset.theme = next;
    try { localStorage.setItem('devkit-theme', next); } catch (e) {}
    render();
  });

  if (dark.addEventListener) dark.addEventListener('change', render);
  btn.hidden = false;
  render();
})();
