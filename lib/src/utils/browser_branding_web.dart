import 'package:web/web.dart' as web;

/// Read by web/app_startup.js to show the logo before Flutter starts.
const _startupLogoKey = 'medsentry_brand_logo';

void updateBrowserBrand({
  required String appName,
  required String logoDataUri,
}) {
  web.document.title = '$appName - Healthcare Management System';

  web.document
      .querySelector('link[rel="icon"]')
      ?.setAttribute('href', logoDataUri.isEmpty ? 'favicon.png' : logoDataUri);

  web.document
      .querySelector('link[rel="apple-touch-icon"]')
      ?.setAttribute(
        'href',
        logoDataUri.isEmpty ? 'icons/Icon-192.png' : logoDataUri,
      );

  try {
    if (logoDataUri.isEmpty) {
      web.window.localStorage.removeItem(_startupLogoKey);
    } else {
      web.window.localStorage.setItem(_startupLogoKey, logoDataUri);
    }
  } catch (_) {
    // Storage can be full or blocked; the loader then shows its default mark.
  }
}
