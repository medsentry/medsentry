// MedSentry Offline-First Service Worker
const CACHE_PREFIX = 'medsentry-cache-';
const CACHE_NAME = `${CACHE_PREFIX}v1.0.17`;
const APP_SHELL_ASSETS = [
  './',
  'index.html',
  'app_startup.js',
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
  'assets/fonts/MaterialIcons-Regular.otf',
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
];

// Weak rural links often connect and then stall. Without a deadline the
// installed app waited on the network indefinitely instead of opening from
// its cache. The deadline covers the wait for the response to start; a slow
// download that has started still completes from the network.
const NETWORK_DEADLINE_MS = 4000;
// Once a request misses the deadline, the requests right behind it would
// each wait out their own, so the cache answers at once for a while.
const SLOW_NETWORK_HOLD_MS = 30000;
let networkSlowUntil = 0;

/**
 * Network-first with a deadline: answers from the network when it responds
 * in time, otherwise from the cache. The network copy still refreshes the
 * cache afterwards. Rejects only if the network fails and nothing is cached.
 */
async function networkFirst(event, request, cacheKey, fetchOptions) {
  const cache = await caches.open(CACHE_NAME);
  const network = fetch(request, fetchOptions);
  event.waitUntil(network.then(async (response) => {
    if (response.ok && response.type !== 'opaque') {
      await cache.put(cacheKey, response.clone());
    }
  }).catch(() => {}));

  if (Date.now() < networkSlowUntil) {
    const cached = await cache.match(cacheKey, { ignoreSearch: true });
    if (cached) return cached;
  }

  let timer;
  const deadline = new Promise((resolve) => {
    timer = setTimeout(resolve, NETWORK_DEADLINE_MS, null);
  });
  try {
    const response = await Promise.race([network, deadline]);
    if (response) {
      networkSlowUntil = 0;
      return response;
    }
    networkSlowUntil = Date.now() + SLOW_NETWORK_HOLD_MS;
  } catch (_) {
    // Offline: fall through to the cached copy.
  } finally {
    clearTimeout(timer);
  }
  const cached = await cache.match(cacheKey, { ignoreSearch: true });
  // Nothing cached yet: keep waiting for the network after all.
  return cached || network;
}

function isFontAsset(pathname) {
  return /\.(woff2?|ttf|otf)$/i.test(pathname);
}

function isRefreshableAsset(pathname) {
  return isFontAsset(pathname) ||
    /\/(?:FontManifest\.json|AssetManifest\.bin(?:\.json)?)$/i.test(pathname);
}

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
        // Revalidate so a stale HTTP-cached file never seeds a new cache.
        const response = await fetch(url, { cache: 'no-cache' });
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

  if (isRefreshableAsset(url.pathname)) {
    event.respondWith((async () => {
      try {
        return await networkFirst(event, request, request, { cache: 'no-cache' });
      } catch (error) {
        console.warn(`[MedSentry SW] Could not refresh asset ${url.pathname}`, error);
        return new Response('This asset is unavailable offline.', {
          status: 503,
          statusText: 'Offline',
          headers: { 'Content-Type': 'text/plain; charset=utf-8' },
        });
      }
    })());
    return;
  }

  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      const shellUrl = new URL('index.html', self.registration.scope);
      try {
        return await networkFirst(event, request, shellUrl);
      } catch (_) {
        return cachedAppShell(await caches.open(CACHE_NAME));
      }
    })());
    return;
  }

  const isEntrypoint =
    url.pathname.endsWith('/app_startup.js') ||
    url.pathname.endsWith('/flutter_bootstrap.js') ||
    url.pathname.endsWith('/main.dart.js');

  if (isEntrypoint) {
    event.respondWith((async () => {
      try {
        // Bypass the HTTP cache: older deploys marked these files immutable,
        // and browsers would otherwise keep running that build.
        return await networkFirst(event, request, request, { cache: 'no-cache' });
      } catch (_) {
        return new Response('MedSentry startup files are unavailable offline.', {
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
