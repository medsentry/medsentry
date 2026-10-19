import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const iconFontUrl =
  'https://medsentry.test/assets/fonts/MaterialIcons-Regular.otf';
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

test('requests the current icon font before serving an older cached subset', async () => {
  const cache = createCache([
    [iconFontUrl, new Response('old subset')],
  ]);
  const fetchCalls = [];
  const handleFetch = createWorker({
    cache,
    fetch: async (request, options) => {
      fetchCalls.push({ request, options });
      return new Response('current subset');
    },
  });
  const pendingWork = [];
  let responsePromise;

  handleFetch({
    request: new Request(iconFontUrl),
    respondWith: (promise) => {
      responsePromise = promise;
    },
    waitUntil: (promise) => pendingWork.push(promise),
  });

  const response = await responsePromise;
  await Promise.all(pendingWork);

  assert.equal(await response.text(), 'current subset');
  assert.equal(fetchCalls[0].options.cache, 'reload');
  assert.equal(await (await cache.entries.get(iconFontUrl).clone()).text(), 'current subset');
});

test('revalidates tree-shaken web font files at Vercel', () => {
  const config = JSON.parse(
    readFileSync(new URL('../vercel.json', import.meta.url), 'utf8'),
  );
  const headerRules = config.headers;
  const assetRuleIndex = headerRules.findIndex(
    (rule) => rule.source === '/assets/(.*)',
  );
  const fontRuleIndex = headerRules.findIndex(
    (rule) => rule.source === '/assets/fonts/(.*)',
  );

  assert.ok(fontRuleIndex > assetRuleIndex);

  const cacheControl = headerRules[fontRuleIndex].headers.find(
    (header) => header.key.toLowerCase() === 'cache-control',
  )?.value;

  assert.match(cacheControl, /max-age=0/);
  assert.match(cacheControl, /must-revalidate/);
  assert.doesNotMatch(cacheControl, /immutable/);
});
