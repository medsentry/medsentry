import 'package:supabase_flutter/supabase_flutter.dart' hide User;

/// Thin wrapper over Supabase Auth used by the email-OTP login flow, so the
/// flow can be unit-tested without a network connection.
abstract class OtpGateway {
  /// Verifies email + password against the server. Returns the auth user id.
  /// Throws [AuthException] for invalid credentials.
  Future<String> verifyPassword(String email, String password);

  /// Requests a one-time code be emailed. Never creates new users.
  Future<void> sendOtp(String email);

  /// Verifies the emailed code and establishes a session.
  /// Returns the auth user id. Throws [AuthException] for a bad/expired code.
  Future<String> verifyOtp(String email, String code);

  /// Discards the local session without revoking other devices.
  Future<void> signOutLocal();

  /// Loads the `users` row for the given auth user, or null if none exists.
  Future<Map<String, dynamic>?> fetchProfile(String authUserId);

  /// Records a successful login on the server audit trail (best effort).
  Future<void> logLoginEvent();

  /// Whether a Supabase session currently exists.
  bool get hasSession;
}

class SupabaseOtpGateway implements OtpGateway {
  static const Duration _timeout = Duration(seconds: 10);
  static const String _profileColumns =
      'id,clinic_id,email,first_name,last_name,role,license_number,specialization,'
      'contact_number,profile_image_url,is_active,pin_enabled,'
      'last_login_at,created_at,updated_at';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  bool get hasSession => _client.auth.currentSession != null;

  @override
  Future<String> verifyPassword(String email, String password) async {
    final response = await _client.auth
        .signInWithPassword(email: email, password: password)
        .timeout(_timeout);
    final user = response.user;
    if (user == null) {
      throw const AuthException('Invalid login credentials');
    }
    return user.id;
  }

  @override
  Future<void> sendOtp(String email) {
    return _client.auth
        .signInWithOtp(email: email, shouldCreateUser: false)
        .timeout(_timeout);
  }

  @override
  Future<String> verifyOtp(String email, String code) async {
    final response = await _client.auth
        .verifyOTP(email: email, token: code, type: OtpType.email)
        .timeout(_timeout);
    final user = response.user;
    if (user == null) {
      throw const AuthException('Invalid or expired code');
    }
    return user.id;
  }

  @override
  Future<void> signOutLocal() =>
      _client.auth.signOut(scope: SignOutScope.local);

  @override
  Future<Map<String, dynamic>?> fetchProfile(String authUserId) async {
    final profile = await _client
        .from('users')
        .select(_profileColumns)
        .eq('auth_user_id', authUserId)
        .maybeSingle()
        .timeout(_timeout);
    return profile == null ? null : Map<String, dynamic>.from(profile);
  }

  @override
  Future<void> logLoginEvent() async {
    try {
      await _client.rpc(
        'medsentry_log_auth_event',
        params: {'event_action': 'LOGIN'},
      );
    } catch (_) {
      // Non-fatal: the local audit log already records the login.
    }
  }
}

