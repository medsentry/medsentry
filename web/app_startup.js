// Startup shell for MedSentry web: loader, error recovery, PWA install and
// offline service worker. Kept in a file (not inline) so the site can send a
// Content-Security-Policy that forbids inline scripts.

async function clearCacheAndReload() {
  try {
    if ('serviceWorker' in navigator) {
      var registration = await navigator.serviceWorker.getRegistration(
        new URL('./', document.baseURI).href
      );
      var workers = registration
        ? [registration.active, registration.waiting, registration.installing]
        : [];
      if (workers.some(function(worker) {
        return worker && new URL(worker.scriptURL).pathname.endsWith('/sw.js');
      })) {
        await registration.unregister();
      }
    }
    if ('caches' in window) {
      var keys = await caches.keys();
      for (var j = 0; j < keys.length; j++) {
        if (keys[j].startsWith('medsentry-cache-')) {
          await caches.delete(keys[j]);
        }
      }
    }
  } catch (e) {
    console.warn('Cache clearing error:', e);
  }
  window.location.reload();
}
window.clearCacheAndReload = clearCacheAndReload;

// Show the admin's logo (cached by the app in localStorage) on the loader and
// browser tab before Flutter starts.
(function showCachedBrandLogo() {
  var logo;
  try {
    logo = window.localStorage.getItem('medsentry_brand_logo');
  } catch (e) {
    return;
  }
  if (!logo || logo.indexOf('data:image/') !== 0) return;

  var box = document.getElementById('ms-loading-logo');
  if (box) {
    var img = document.createElement('img');
    img.src = logo;
    img.alt = '';
    box.replaceChildren(img);
  }
  var icon = document.querySelector('link[rel="icon"]');
  if (icon) icon.setAttribute('href', logo);
})();

// Keep the shell visible until Flutter confirms that its first frame rendered.
var loaderHidden = false;
var bootTimeout;
function showLoaderError(message) {
  if (loaderHidden) return;
  window.clearTimeout(bootTimeout);
  var loader = document.getElementById('loading-container');
  var errBox = document.getElementById('ms-error-display');
  var errText = document.getElementById('ms-error-text');
  var spinner = loader && loader.querySelector('.loading-spinner');
  if (spinner) spinner.style.display = 'none';
  if (errText) errText.textContent = message;
  if (errBox) errBox.style.display = 'block';
}
window.showMedSentryBootstrapError = function() {
  showLoaderError('MedSentry could not download its startup files. Check your connection and reload.');
};

function hideMedSentryLoader() {
  if (loaderHidden) return;
  var loader = document.getElementById('loading-container');
  if (loader) {
    loaderHidden = true;
    window.clearTimeout(bootTimeout);
    loader.style.opacity = '0';
    loader.style.pointerEvents = 'none';
    setTimeout(function() {
      if (loader && loader.parentNode) {
        loader.parentNode.removeChild(loader);
      }
    }, 350);
  }
}

window.hideMedSentryLoader = hideMedSentryLoader;
window.addEventListener('flutter-first-frame', hideMedSentryLoader);
bootTimeout = window.setTimeout(function() {
  showLoaderError('MedSentry is taking longer than expected to start. Check your connection and reload.');
}, 45000);

// Report startup failures without deleting unrelated origin caches or workers.
window.addEventListener('error', function(e) {
  if (loaderHidden) return;
  console.error('[MedSentry] Startup error:', e.error || e.message);
  showLoaderError('MedSentry could not start. Reload the app; if the problem continues, clear its cached app files.');
});

window.addEventListener('unhandledrejection', function(e) {
  if (loaderHidden) return;
  console.error('[MedSentry] Startup promise rejected:', e.reason);
  showLoaderError('MedSentry could not finish starting. Check your connection and reload.');
});

// 2. PWA Install Prompt Bridge
let deferredInstallPrompt = null;
window.pwaCanInstall = false;

window.addEventListener('beforeinstallprompt', function(e) {
  e.preventDefault();
  deferredInstallPrompt = e;
  window.pwaCanInstall = true;
  window.dispatchEvent(new CustomEvent('pwa-installable'));
  console.log('[MedSentry PWA] App is installable! Event captured.');
});

window.installMedSentryPwa = async function() {
  if (!deferredInstallPrompt) {
    console.warn('[MedSentry PWA] No installation prompt available.');
    return false;
  }
  deferredInstallPrompt.prompt();
  const choice = await deferredInstallPrompt.userChoice;
  deferredInstallPrompt = null;
  window.pwaCanInstall = false;
  return choice && choice.outcome === 'accepted';
};

window.isPwaInstalled = function() {
  return window.matchMedia('(display-mode: standalone)').matches ||
         window.navigator.standalone === true;
};

window.addEventListener('appinstalled', function() {
  window.pwaCanInstall = false;
  deferredInstallPrompt = null;
  console.log('[MedSentry PWA] App was successfully installed to device!');
});

// 3. Register Offline Service Worker (Skip during local DWDS debug development)
if ('serviceWorker' in navigator) {
  window.addEventListener('load', function() {
    var isDebugMode = window.location.port === '52137' ||
                      window.location.search.includes('flutter-web') ||
                      window.location.search.includes('dwds');

    if (isDebugMode) {
      console.log('[MedSentry] DWDS debug mode detected - clearing service worker to avoid cache conflicts.');
      navigator.serviceWorker.getRegistrations().then(function(regs) {
        for (var r of regs) r.unregister();
      });
      return;
    }

    var controller = navigator.serviceWorker.controller;
    var hasMedSentryController = controller &&
      new URL(controller.scriptURL).pathname.endsWith('/sw.js');
    var initialControlReloadKey = 'medsentry-initial-service-worker-control';
    if (hasMedSentryController) {
      try {
        sessionStorage.removeItem(initialControlReloadKey);
      } catch (e) {
        console.warn('[MedSentry PWA] Could not read session storage:', e);
      }
    }
    navigator.serviceWorker.addEventListener('controllerchange', function() {
      if (hasMedSentryController) {
        window.location.reload();
        return;
      }
      try {
        if (sessionStorage.getItem(initialControlReloadKey)) return;
        sessionStorage.setItem(initialControlReloadKey, '1');
        window.location.reload();
      } catch (e) {
        console.warn('[MedSentry PWA] Could not reload after first service worker control:', e);
      }
    });

    navigator.serviceWorker.register(new URL('sw.js', document.baseURI), {
      scope: './',
      updateViaCache: 'none'
    })
      .then(function(registration) {
        console.log('[MedSentry PWA] Offline Service Worker registered:', registration.scope);

        registration.onupdatefound = function() {
          var newWorker = registration.installing;
          if (newWorker) {
            newWorker.onstatechange = function() {
              if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
                console.log('[MedSentry PWA] New application version detected.');
                window.dispatchEvent(new CustomEvent('pwa-update-available'));
              }
            };
          }
        };
      })
      .catch(function(err) {
        console.warn('[MedSentry PWA] Service Worker registration skipped/failed:', err);
      });
  });
}

// Wired here instead of inline onclick/onerror attributes, which CSP blocks.
var reloadButton = document.getElementById('ms-reload-button');
if (reloadButton) reloadButton.addEventListener('click', clearCacheAndReload);

// A failed script download does not bubble, so listen in the capture phase.
window.addEventListener('error', function(e) {
  var target = e.target;
  if (target && target.tagName === 'SCRIPT' &&
      String(target.src).indexOf('flutter_bootstrap.js') !== -1) {
    window.showMedSentryBootstrapError();
  }
}, true);

// package:printing loads pdf.js for PDF previews. Serve the pinned copy in
// web/pdfjs/ instead of unpkg.com so previews work under the site's CSP.
window.dartPdfJsBaseUrl = new URL('pdfjs/', document.baseURI).href;
