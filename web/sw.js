// MedSentry Offline-First Service Worker
// Version: 1.0.2
const CACHE_NAME = 'medsentry-cache-v1.0.2';

// Essential assets to cache immediately upon installation
const PRECACHE_ASSETS = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'main.dart.js',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
  'assets/AssetManifest.bin',
  'assets/AssetManifest.bin.json',
  'assets/FontManifest.json',
  'assets/assets/images/rhu_doctors.jpg',
  'assets/assets/images/rhu_background.jpg',
];

// Install Event: Pre-cache static assets
self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      // Attempt to cache essential assets; ignore individual failures so installation completes
      return Promise.allSettled(
        PRECACHE_ASSETS.map((url) =>
          cache.add(url).catch((err) => {
            console.warn(`[MedSentry SW] Could not precache: ${url}`, err);
          })
        )
      );
    })
  );
});

// Activate Event: Remove old caches and claim clients immediately
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => name !== CACHE_NAME)
          .map((name) => {
            console.log(`[MedSentry SW] Deleting outdated cache: ${name}`);
            return caches.delete(name);
          })
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch Event: Intelligent routing for offline-first PWA
self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);

  // 1. Bypass non-GET requests (mutations handled by local SQLite/IndexedDB)
  if (request.method !== 'GET') {
    return;
  }

  // 2. Bypass Supabase and external API calls (always handled by client sync layer)
  if (
    url.hostname.includes('supabase.co') ||
    url.pathname.startsWith('/rest/v1/') ||
    url.pathname.startsWith('/auth/v1/') ||
    url.pathname.startsWith('/storage/v1/')
  ) {
    return;
  }

  // 3. Bypass DWDS & Dev Server modules during debug runs
  if (
    url.pathname.includes('$dwds') ||
    url.pathname.includes('$hotReload') ||
    url.pathname.includes('main_module.bootstrap.js') ||
    url.pathname.includes('dart_sdk') ||
    url.pathname.includes('.lib.js') ||
    url.pathname.includes('__latency__') ||
    url.search.includes('flutter-web')
  ) {
    return;
  }

  // 4. Navigation requests: Return index.html from cache if offline
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request).catch(() => {
        return caches.match('./').then((res) => res || caches.match('index.html'));
      })
    );
    return;
  }

  // 5. App entrypoint scripts: Network-First with Cache Fallback
  if (url.pathname.endsWith('flutter_bootstrap.js') || url.pathname.endsWith('main.dart.js')) {
    event.respondWith(
      fetch(request)
        .then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            const responseToCache = networkResponse.clone();
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(request, responseToCache);
            });
          }
          return networkResponse;
        })
        .catch(() => caches.match(request))
    );
    return;
  }

  // 6. Static assets (WASM, canvaskit, CSS, Fonts, Images): Cache-First with Stale-While-Revalidate
  event.respondWith(
    caches.match(request).then((cachedResponse) => {
      if (cachedResponse) {
        // Fetch update in background to refresh cache
        fetch(request)
          .then((networkResponse) => {
            if (networkResponse && networkResponse.status === 200) {
              caches.open(CACHE_NAME).then((cache) => {
                cache.put(request, networkResponse.clone());
              });
            }
          })
          .catch(() => {
            // Offline - no-op, cachedResponse is already served
          });
        return cachedResponse;
      }

      // Not in cache: fetch from network and store in cache
      return fetch(request).then((networkResponse) => {
        if (!networkResponse || networkResponse.status !== 200 || networkResponse.type === 'opaque') {
          return networkResponse;
        }

        const responseToCache = networkResponse.clone();
        caches.open(CACHE_NAME).then((cache) => {
          cache.put(request, responseToCache);
        });

        return networkResponse;
      }).catch((err) => {
        console.warn(`[MedSentry SW] Offline and asset not in cache: ${url.pathname}`, err);
        return new Response('Offline', { status: 503, statusText: 'Offline' });
      });
    })
  );
});
