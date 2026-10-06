{{flutter_js}}
{{flutter_build_config}}

// Deferred Service Worker registration: starts only after Flutter draws its first frame
// so background caching NEVER steals bandwidth or browser connection slots from initial app startup.
var _swRegistered = false;
function _registerServiceWorker() {
  if (_swRegistered) return;
  _swRegistered = true;
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('sw.js').then(function (reg) {
      if (reg && typeof reg.update === 'function') {
        reg.update().catch(function () {});
      }
    }).catch(function (e) {
      console.info('Offline support unavailable:', e && e.message);
    });
  }
}

// Remove the HTML loading screen once Flutter has drawn its first frame.
window.addEventListener('flutter-first-frame', function () {
  var splash = document.getElementById('splash');
  if (splash) {
    splash.style.opacity = '0';
    setTimeout(function () { splash.remove(); }, 260);
  }
  _registerServiceWorker();
});

// Fallback: register SW if first frame takes longer than 3.5s
setTimeout(_registerServiceWorker, 3500);

// Flutter's own service worker is deprecated (it only unregisters itself),
// so it is not requested here; offline support comes from sw.js above.
_flutter.loader.load();

