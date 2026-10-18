import 'user.dart';

/// Number of digits in an email one-time passcode.
const int kOtpLength = 6;

/// How long an emailed code remains valid (must match Supabase `otp_expiry`).
const Duration kOtpLifetime = Duration(minutes: 5);

/// Minimum wait before another code can be requested (matches Supabase
/// `max_frequency`).
const Duration kOtpResendCooldown = Duration(seconds: 60);

/// Wrong-code attempts allowed before the challenge is discarded.
const int kOtpMaxAttempts = 5;

/// How long a verified OTP keeps PIN / biometric unlock available for roles
/// that require email verification.
const Duration kOtpTrustWindow = Duration(hours: 12);

/// Outcome of the first phase of a login (email + password).
sealed class LoginResult {
  const LoginResult();
}

/// Credentials accepted and no further verification is required.
class LoginSuccess extends LoginResult {
  final User user;
  const LoginSuccess(this.user);
}

/// Credentials accepted; an emailed one-time code must be verified next.
class LoginOtpRequired extends LoginResult {
  final OtpChallenge challenge;
  const LoginOtpRequired(this.challenge);
}

/// Login was rejected. [message] is safe to show to the user.
class LoginFailure extends LoginResult {
  final String message;
  final bool isNetworkError;
  const LoginFailure(this.message, {this.isNetworkError = false});
}

/// Outcome of verifying an emailed code.
sealed class OtpVerifyResult {
  const OtpVerifyResult();
}

class OtpVerified extends OtpVerifyResult {
  final User user;
  const OtpVerified(this.user);
}

/// The code was wrong or expired. [challenge] carries the remaining attempts
/// unless [exhausted] is true, in which case the user must log in again.
class OtpRejected extends OtpVerifyResult {
  final String message;
  final OtpChallenge? challenge;
  final bool exhausted;
  const OtpRejected(this.message, {this.challenge, this.exhausted = false});
}

/// A pending one-time-passcode verification.
class OtpChallenge {
  final String email;
  final String maskedEmail;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;
  final int attemptsLeft;

  const OtpChallenge({
    required this.email,
    required this.maskedEmail,
    required this.expiresAt,
    required this.resendAvailableAt,
    this.attemptsLeft = kOtpMaxAttempts,
  });

  bool get isExpired => !DateTime.now().isBefore(expiresAt);

  Duration get resendWait {
    final remaining = resendAvailableAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  OtpChallenge copyWith({
    DateTime? expiresAt,
    DateTime? resendAvailableAt,
    int? attemptsLeft,
  }) {
    return OtpChallenge(
      email: email,
      maskedEmail: maskedEmail,
      expiresAt: expiresAt ?? this.expiresAt,
      resendAvailableAt: resendAvailableAt ?? this.resendAvailableAt,
      attemptsLeft: attemptsLeft ?? this.attemptsLeft,
    );
  }

  /// `jane.doe@gmail.com` -> `j*******@gmail.com`
  static String maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 1) return email;
    final local = email.substring(0, at);
    return '${local[0]}${'*' * (local.length - 1).clamp(1, 8)}${email.substring(at)}';
  }
}

