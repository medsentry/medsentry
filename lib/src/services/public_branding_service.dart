import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/simple_database.dart';

/// Caches the super admin's logo so the sign-in page, startup loader and
/// browser tab show it on devices that have not signed in yet.
Future<void> refreshPublicBranding(SimpleDatabase db) async {
  try {
    final result = await Supabase.instance.client.rpc(
      'medsentry_public_branding',
    );
    if (result is! Map) return;
    final logo = result['logo_data_uri'];
    await db.setPublicLogoDataUri(logo is String ? logo : '');
  } catch (error) {
    // Offline or not yet migrated: keep the cached logo.
    debugPrint('Public branding refresh skipped: $error');
  }
}
