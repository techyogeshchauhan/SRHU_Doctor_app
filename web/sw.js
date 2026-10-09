// ============================================================================
// STW Neo Service Worker (PWA Offline Cache)
// Ensures full offline availability of STW PDF documents, pre-built index,
// clinical synonyms, pdf.js viewer engine, and application assets.
// ============================================================================

const CACHE_NAME = 'stwneo-offline-cache-v2';

const PRECACHE_ASSETS = [
  './',
  'index.html',
  'manifest.json',
  'favicon.png',
  'styles.css',
  'flutter_bootstrap.js',
  'pdfjs/pdf.js',
  'pdfjs/pdf.worker.js',
  // STW Clinical Documents & Pre-built Extractive Index
  'assets/stw_index/stw_index.json',
  'assets/stw_index/clinical_synonyms.json',
  'assets/pdfs/respiratory_distress_neonates_stw.pdf',
  'assets/pdfs/retinopathy_of_prematurity_stw.pdf',
  // Asset manifests and core graphics
  'assets/AssetManifest.bin',
  'assets/AssetManifest.json',
  'assets/FontManifest.json',
  'assets/images/icmr_logo.png',
  'assets/images/logo212.png',
  'assets/images/hu.png',
  'assets/images/aiims-delhi.jpg',
  'assets/images/pgi-logo.jpg',
  'assets/images/GMCH%20chandigrah.png',
  'assets/images/sas_chart.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png'
];

// Install: precache critical assets
self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      // Precache known assets; tolerate individual 404s during local development
      return Promise.allSettled(
        PRECACHE_ASSETS.map((url) =>
          cache.add(url).catch((err) => {
            console.warn('[SW] Could not precache:', url, err.message);
          })
        )
      );
    })
  );
});

// Activate: clear stale caches and take control
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((name) => {
          if (name !== CACHE_NAME) {
            return caches.delete(name);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch: Cache-first for PDFs, STW index, and static assets; network-fallback for API
self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);

  // Skip caching external REST API requests (handled by local Hive queue)
  if (url.pathname.includes('/api/') || url.pathname.includes('/screenings') || url.pathname.includes('/sessions') || url.pathname.includes('/chat-logs')) {
    return;
  }

  // Cache-first strategy for PDFs, index JSON, and local assets
  const isStwAsset =
    url.pathname.includes('assets/pdfs/') ||
    url.pathname.includes('assets/stw_index/') ||
    url.pathname.includes('pdfjs/');

  if (isStwAsset) {
    event.respondWith(
      caches.match(request).then((cachedResponse) => {
        if (cachedResponse) return cachedResponse;
        return fetch(request).then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            const responseClone = networkResponse.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(request, responseClone));
          }
          return networkResponse;
        });
      })
    );
    return;
  }

  // Network-first for app code (index.html, main.dart.js, assets, ...): a new
  // deploy is picked up on the next load; the cache is only the offline
  // fallback. (Serving the cached copy first kept running the previous build.)
  event.respondWith(
    fetch(request)
      .then((networkResponse) => {
        if (networkResponse && networkResponse.status === 200) {
          const responseClone = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(request, responseClone));
        }
        return networkResponse;
      })
      .catch(() => caches.match(request))
  );
});
