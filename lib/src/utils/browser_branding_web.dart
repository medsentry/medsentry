import 'package:web/web.dart' as web;

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
}
