// MedSentry Offline-First Service Worker
const CACHE_PREFIX = 'medsentry-cache-';
const CACHE_NAME = `${CACHE_PREFIX}v1.0.6`;
const APP_SHELL_ASSETS = [
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
  'assets/AssetManifest.bin.json',
  'assets/assets/images/rhu_doctors.png',
];

async function cachedAppShell(cache) {
  const shellUrl = new URL('index.html', self.registration.scope);
  return (await cache.match(shellUrl)) ||
    new Response('MedSentry is not available offline yet. Reconnect and reload.', {
      status: 503,
      statusText: 'Offline',
      headers: { 'Content-Type': 'text/plain; charset=utf-8' },
    });
}

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await Promise.allSettled(APP_SHELL_ASSETS.map(async (asset) => {
      const url = new URL(asset, self.registration.scope);
      try {
        const response = await fetch(url);
        if (response.ok && response.type !== 'opaque') {
          await cache.put(url, response);
        } else {
          console.warn(`[MedSentry SW] Could not precache ${url.pathname}: HTTP ${response.status}`);
        }
      } catch (error) {
        console.warn(`[MedSentry SW] Could not precache ${url.pathname}`, error);
      }
    }));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const cacheNames = await caches.keys();
    await Promise.all(cacheNames
      .filter((name) => name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME)
      .map((name) => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      const cache = await caches.open(CACHE_NAME);
      try {
        const response = await fetch(request);
        if (response.ok) {
          event.waitUntil(cache.put(new URL('index.html', self.registration.scope), response.clone()));
        }
        return response;
      } catch (_) {
        return cachedAppShell(cache);
      }
    })());
    return;
  }

  const isEntrypoint =
    url.pathname.endsWith('/flutter_bootstrap.js') ||
    url.pathname.endsWith('/main.dart.js');

  if (isEntrypoint) {
    event.respondWith((async () => {
      const cache = await caches.open(CACHE_NAME);
      try {
        const response = await fetch(request);
        if (response.ok) {
          event.waitUntil(cache.put(request, response.clone()));
        }
        return response;
      } catch (_) {
        return (await cache.match(request, { ignoreSearch: true })) ||
          new Response('MedSentry startup files are unavailable offline.', {
            status: 503,
            statusText: 'Offline',
            headers: { 'Content-Type': 'text/plain; charset=utf-8' },
          });
      }
    })());
    return;
  }

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cachedResponse = await cache.match(request, { ignoreSearch: true });
    if (cachedResponse) {
      event.waitUntil(fetch(request).then((response) => {
        if (response.ok && response.type !== 'opaque') {
          return cache.put(request, response);
        }
      }).catch(() => {}));
      return cachedResponse;
    }

    try {
      const response = await fetch(request);
      if (response.ok && response.type !== 'opaque') {
        event.waitUntil(cache.put(request, response.clone()));
      }
      return response;
    } catch (_) {
      return new Response('This resource is not available offline.', {
        status: 503,
        statusText: 'Offline',
        headers: { 'Content-Type': 'text/plain; charset=utf-8' },
      });
    }
  })());
});
