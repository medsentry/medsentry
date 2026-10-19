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

function createWorker({ cache, fetch }) {
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
  });

  return listeners.get('fetch');
}

function createCache(initialEntries = []) {
  const entries = new Map(initialEntries);
  return {
    entries,
    async match(request) {
      return entries.get(typeof request === 'string' ? request : request.url);
    },
    async put(request, response) {
      entries.set(request.url, response.clone());
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

test('revalidates tree-shaken web font files at Vercel', () => {
  const config = JSON.parse(
    readFileSync(new URL('../vercel.json', import.meta.url), 'utf8'),
  );
  const headerRules = config.headers;
  const assetRuleIndex = headerRules.findIndex(
    (rule) => rule.source === '/assets/(.*)',
  );
  const fontRules = headerRules.filter((rule) =>
    [
      '/assets/fonts/(.*)',
      '/assets/packages/(.*)',
      '/assets/(FontManifest\\.json|AssetManifest\\.bin|AssetManifest\\.bin\\.json)',
    ].includes(rule.source),
  );

  assert.equal(fontRules.length, 3);
  for (const rule of fontRules) {
    assert.ok(headerRules.indexOf(rule) > assetRuleIndex);
    const cacheControl = rule.headers.find(
      (header) => header.key.toLowerCase() === 'cache-control',
    )?.value;

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
