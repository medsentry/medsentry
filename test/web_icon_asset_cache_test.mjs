import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const iconFontUrl =
  'https://medsentry.test/assets/fonts/MaterialIcons-Regular.otf';
const packageIconFontUrl =
  'https://medsentry.test/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf';
const fontManifestUrl = 'https://medsentry.test/assets/FontManifest.json';
const assetManifestUrl = 'https://medsentry.test/assets/AssetManifest.bin';
const workerSource = readFileSync(new URL('../web/sw.js', import.meta.url), 'utf8');

// expireDeadlines: the network deadline passes at once, as on a stalled link.
// A custom setTimeout replaces the worker's timer outright.
function createWorker({
  cache,
  fetch,
  expireDeadlines = false,
  setTimeout: workerSetTimeout,
}) {
  const listeners = new Map();
  const self = {
    addEventListener: (type, listener) => listeners.set(type, listener),
    location: { origin: 'https://medsentry.test' },
    registration: { scope: 'https://medsentry.test/' },
  };

  vm.runInNewContext(workerSource, {
    self,
    caches: { open: async () => cache },
    fetch,
    Request,
    Response,
    URL,
    console,
    setTimeout: workerSetTimeout ?? (expireDeadlines
      ? (callback, _ms, ...args) => setTimeout(callback, 0, ...args)
      : setTimeout),
    clearTimeout,
  });

  return listeners.get('fetch');
}

function createCache(initialEntries = []) {
  const entries = new Map(initialEntries);
  return {
    entries,
    // The Cache API accepts a Request, a string, or a URL object.
    async match(request) {
      return entries.get(request instanceof Request ? request.url : String(request));
    },
    async put(request, response) {
      entries.set(request instanceof Request ? request.url : String(request), response.clone());
    },
  };
}

test('revalidates fonts and Flutter asset manifests before serving stale cache', async () => {
  for (const assetUrl of [
    iconFontUrl,
    packageIconFontUrl,
    fontManifestUrl,
    assetManifestUrl,
  ]) {
    const cache = createCache([[assetUrl, new Response('old asset')]]);
    const fetchCalls = [];
    const handleFetch = createWorker({
      cache,
      fetch: async (request, options) => {
        fetchCalls.push({ request, options });
        return new Response('current asset');
      },
    });
    const pendingWork = [];
    let responsePromise;

    handleFetch({
      request: new Request(assetUrl),
      respondWith: (promise) => {
        responsePromise = promise;
      },
      waitUntil: (promise) => pendingWork.push(promise),
    });

    const response = await responsePromise;
    await Promise.all(pendingWork);

    assert.equal(await response.text(), 'current asset');
    assert.equal(fetchCalls[0].options.cache, 'no-cache');
    assert.equal(await (await cache.entries.get(assetUrl).clone()).text(), 'current asset');
  }
});

test('uses the cached font when the network is unavailable', async () => {
  const cache = createCache([
    [iconFontUrl, new Response('cached subset')],
  ]);
  const handleFetch = createWorker({
    cache,
    fetch: async () => {
      throw new TypeError('Network unavailable');
    },
  });
  let responsePromise;

  handleFetch({
    request: new Request(iconFontUrl),
    respondWith: (promise) => {
      responsePromise = promise;
    },
    waitUntil: () => {},
  });

  const response = await responsePromise;
  assert.equal(response.status, 200);
  assert.equal(await response.text(), 'cached subset');
});

/** Dispatches a fetch event; resolves to the response and pending work. */
async function dispatch(handleFetch, request) {
  const pendingWork = [];
  let responsePromise;
  handleFetch({
    request,
    respondWith: (promise) => {
      responsePromise = promise;
    },
    waitUntil: (promise) => pendingWork.push(promise),
  });
  return { response: await responsePromise, pendingWork };
}

function navigation(url) {
  const request = new Request(url);
  Object.defineProperty(request, 'mode', { value: 'navigate' });
  return request;
}

test('opens from the cache when the network stalls', async () => {
  const shellUrl = 'https://medsentry.test/index.html';
  const mainUrl = 'https://medsentry.test/main.dart.js';
  const cache = createCache([
    [shellUrl, new Response('cached shell')],
    [mainUrl, new Response('cached app')],
    [fontManifestUrl, new Response('cached manifest')],
  ]);
  const handleFetch = createWorker({
    cache,
    fetch: () => new Promise(() => {}),
    expireDeadlines: true,
  });

  for (const [request, expected] of [
    [navigation('https://medsentry.test/patients'), 'cached shell'],
    [new Request(mainUrl), 'cached app'],
    [new Request(fontManifestUrl), 'cached manifest'],
  ]) {
    const { response } = await dispatch(handleFetch, request);
    assert.equal(await response.text(), expected);
  }
});

test('a late network response still refreshes the cache', async () => {
  const mainUrl = 'https://medsentry.test/main.dart.js';
  const cache = createCache([[mainUrl, new Response('old build')]]);
  let answer;
  const handleFetch = createWorker({
    cache,
    fetch: () => new Promise((resolve) => {
      answer = resolve;
    }),
    expireDeadlines: true,
  });

  const { response, pendingWork } = await dispatch(
    handleFetch,
    new Request(mainUrl),
  );
  assert.equal(await response.text(), 'old build');

  answer(new Response('new build'));
  await Promise.all(pendingWork);
  assert.equal(await (await cache.entries.get(mainUrl).clone()).text(), 'new build');
});

test('after one stall, the next requests skip the wait', async () => {
  const shellUrl = 'https://medsentry.test/index.html';
  const mainUrl = 'https://medsentry.test/main.dart.js';
  const cache = createCache([
    [shellUrl, new Response('cached shell')],
    [mainUrl, new Response('cached app')],
  ]);
  let deadlines = 0;
  const handleFetch = createWorker({
    cache,
    fetch: () => new Promise(() => {}),
    setTimeout: (callback, _ms, ...args) => {
      deadlines++;
      return setTimeout(callback, 0, ...args);
    },
  });

  const first = await dispatch(handleFetch, navigation('https://medsentry.test/'));
  assert.equal(await first.response.text(), 'cached shell');
  const second = await dispatch(handleFetch, new Request(mainUrl));
  assert.equal(await second.response.text(), 'cached app');
  assert.equal(deadlines, 1);
});

test('waits for a slow network when nothing is cached yet', async () => {
  const mainUrl = 'https://medsentry.test/main.dart.js';
  const handleFetch = createWorker({
    cache: createCache(),
    fetch: () => new Promise((resolve) => {
      setTimeout(() => resolve(new Response('first download')), 20);
    }),
    expireDeadlines: true,
  });

  const { response } = await dispatch(handleFetch, new Request(mainUrl));
  assert.equal(await response.text(), 'first download');
});

test('revalidates tree-shaken web font files at Vercel', () => {
  const config = JSON.parse(
    readFileSync(new URL('../vercel.json', import.meta.url), 'utf8'),
  );
  // Checks the header each path actually receives (Vercel applies matching
  // rules in order, later ones overriding), not particular rule names, so
  // the test survives the rules being merged or reordered.
  const cacheControlFor = (path) => {
    let value;
    for (const rule of config.headers) {
      if (!new RegExp(`^${rule.source}$`).test(path)) continue;
      const header = rule.headers.find(
        (candidate) => candidate.key.toLowerCase() === 'cache-control',
      );
      if (header) value = header.value;
    }
    return value;
  };

  for (const path of [
    '/assets/fonts/MaterialIcons-Regular.otf',
    '/assets/assets/fonts/AtkinsonHyperlegibleNext-400.ttf',
    '/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
    '/assets/FontManifest.json',
    '/assets/AssetManifest.bin',
    '/assets/AssetManifest.bin.json',
  ]) {
    const cacheControl = cacheControlFor(path);
    assert.ok(cacheControl, `no Cache-Control header for ${path}`);
    assert.match(cacheControl, /max-age=0/);
    assert.match(cacheControl, /must-revalidate/);
    assert.doesNotMatch(cacheControl, /immutable/);
  }
});

test('does not mark font assets immutable on Apache deployments', () => {
  const htaccess = readFileSync(new URL('../web/.htaccess', import.meta.url), 'utf8');
  const fontRuleStart = htaccess.indexOf(
    '<FilesMatch "\\.(woff2?|ttf|otf)$">',
  );
  const fontRuleEnd = htaccess.indexOf('</FilesMatch>', fontRuleStart);

  assert.ok(fontRuleStart >= 0);
  assert.ok(fontRuleEnd > fontRuleStart);
  const fontRule = htaccess.slice(fontRuleStart, fontRuleEnd);
  assert.match(fontRule, /max-age=0/);
  assert.match(fontRule, /must-revalidate/);
});
