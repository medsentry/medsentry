import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/login_challenge.dart';
import '../models/models.dart';
import '../services/app_notification.dart';
import '../providers/providers.dart';
import '../utils/biometric_auth/biometric_auth.dart';
import '../utils/rate_limiter.dart';
import '../widgets/app_form_dialog.dart';
import '../widgets/otp_verification_panel.dart';
import '../widgets/system_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final bool locked;

  const LoginScreen({super.key, this.locked = false});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _pinFocusNode = FocusNode();
  bool _isPinLogin = false;
  bool _isLoading = false;
  OtpChallenge? _otpChallenge;
  String? _error;
  String? _lastUserEmail;
  bool _pinLoginAvailable = false;
  bool _sessionLocked = false;
  bool _obscurePassword = true;
  bool _obscurePin = true;
  bool _canCheckBiometrics = false;
  bool _rememberMe = true;
  bool _isCapsLockOn = false;
  String? _emailError;
  String? _passwordFieldError;
  String? _pinFieldError;
  final BiometricAuthService _biometricAuth = createBiometricAuthService();

  @override
  void initState() {
    super.initState();
    ServicesBinding.instance.keyboard.addHandler(_handleKeyEvent);
    _ensureDefaultAccounts();
    _checkPinLoginAvailability();
    _checkBiometrics();
  }

  bool _handleKeyEvent(KeyEvent event) {
    final capsLockActive = HardwareKeyboard.instance.lockModesEnabled.contains(
      KeyboardLockMode.capsLock,
    );
    if (capsLockActive != _isCapsLockOn && mounted) {
      setState(() => _isCapsLockOn = capsLockActive);
    }
    return false;
  }

  Future<void> _ensureDefaultAccounts() async {
    await ref.read(authRepositoryProvider).ensureDefaultAccounts();
    await ref.read(databaseSeedServiceProvider).seedIfEmpty();
    if (mounted) {
      await _checkPinLoginAvailability();
    }
  }

  Future<void> _checkBiometrics() async {
    try {
      final canAuthenticate = await _biometricAuth.canCheckBiometrics();
      if (mounted) {
        setState(() {
          _canCheckBiometrics = canAuthenticate;
        });
      }
    } catch (e) {
      debugPrint('Error checking biometrics: $e');
    }
  }

  Future<void> _checkPinLoginAvailability() async {
    final authRepo = ref.read(authRepositoryProvider);
    final db = ref.read(databaseProvider);
    final locked = widget.locked || await authRepo.isSessionLocked();
    final rememberMe = await db.getRememberMe();
    final rememberedEmail = rememberMe ? await db.getRememberedEmail() : null;

    if (!mounted) return;

    if (locked) {
      final available = await authRepo.isPinLoginAvailable();
      final email = await authRepo.getLastLoggedInUserEmail();
      setState(() {
        _pinLoginAvailable = available;
        _lastUserEmail = email;
        _sessionLocked = true;
        _isPinLogin = available;
        _rememberMe = rememberMe;
        if (email != null) {
          _emailController.text = email;
        }
      });
      return;
    }

    setState(() {
      _pinLoginAvailable = false;
      _lastUserEmail = null;
      _sessionLocked = false;
      _isPinLogin = false;
      _rememberMe = rememberMe;
      _emailController.text = rememberedEmail ?? '';
      _passwordController.clear();
      _pinController.clear();
    });
  }

  @override
  void dispose() {
    ServicesBinding.instance.keyboard.removeHandler(_handleKeyEvent);
    _emailController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _submitFromEmailField() {
    if (_isPinLogin) return;
    if (!_sessionLocked) {
      _passwordFocusNode.requestFocus();
      return;
    }
    _login();
  }

  void _submitLogin() {
    if (_isLoading) return;
    _login();
  }

  /// Finishes a successful password or OTP login: remembers the email choice,
  /// publishes the user and navigates to their home.
  Future<void> _completeLogin(User user) async {
    final db = ref.read(databaseProvider);
    await db.setRememberMe(_rememberMe);
    await db.setRememberedEmail(_rememberMe ? user.email : null);
    AppNotification.success(
      title: 'Welcome Back!',
      message: 'Login successful.',
    );
    if (mounted) {
      ref.read(currentUserProvider.notifier).state = user;
      context.go(user.homePath);
    }
  }

  void _cancelOtp({String? message}) {
    if (!mounted) return;
    setState(() {
      _otpChallenge = null;
      _isLoading = false;
      _passwordController.clear();
      _error = message;
    });
  }

  Future<void> _login() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final pin = _pinController.text.trim();
    final emailError =
        !_isPinLogin &&
            !_sessionLocked &&
            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
        ? (email.isEmpty
              ? 'Enter your email address.'
              : 'Enter a valid email address.')
        : null;
    final passwordError = !_isPinLogin && password.isEmpty
        ? 'Enter your password.'
        : null;
    final pinError = _isPinLogin && !RegExp(r'^\d{4}$').hasMatch(pin)
        ? 'Enter your 4-digit PIN.'
        : null;

    if (emailError != null || passwordError != null || pinError != null) {
      setState(() {
        _emailError = emailError;
        _passwordFieldError = passwordError;
        _pinFieldError = pinError;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _emailError = null;
      _passwordFieldError = null;
      _pinFieldError = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);

      if (_isPinLogin) {
        if (!pinRateLimiter.canAttempt('pin_login')) {
          final wait = pinRateLimiter.remainingCooldown('pin_login');
          final message =
              'Too many PIN attempts. Please wait ${wait.inSeconds} seconds.';
          AppNotification.warning(title: 'Rate Limit', message: message);
          setState(() {
            _error = message;
            _isLoading = false;
          });
          return;
        }
        pinRateLimiter.recordAttempt('pin_login');

        final user = await authRepo.loginWithPin(pin);
        if (user != null) {
          pinRateLimiter.reset('pin_login');
          AppNotification.success(
            title: 'Welcome Back!',
            message: 'Login successful.',
          );
          if (mounted) {
            ref.read(currentUserProvider.notifier).state = user;
            context.go(user.homePath);
          }
        } else {
          AppNotification.error(
            title: 'Authentication Failed',
            message: 'Invalid PIN. Please try again.',
          );
          if (mounted) {
            setState(() {
              _error = 'Invalid PIN. Please try again.';
              _isLoading = false;
            });
          }
        }
      } else {
        if (!loginRateLimiter.canAttempt(email)) {
          final wait = loginRateLimiter.remainingCooldown(email);
          final message =
              'Too many login attempts. Please wait ${wait.inSeconds} seconds.';
          AppNotification.warning(title: 'Rate Limit', message: message);
          setState(() {
            _error = message;
            _isLoading = false;
          });
          return;
        }
        loginRateLimiter.recordAttempt(email);

        final result = await authRepo.beginLogin(email, password);
        switch (result) {
          case LoginSuccess(:final user):
            loginRateLimiter.reset(email);
            await _completeLogin(user);
          case LoginOtpRequired(:final challenge):
            if (mounted) {
              setState(() {
                _otpChallenge = challenge;
                _passwordController.clear();
                _isLoading = false;
              });
            }
          case LoginFailure(:final message, :final isNetworkError):
            AppNotification.error(
              title: isNetworkError ? 'No Connection' : 'Authentication Failed',
              message: message,
            );
            if (mounted) {
              setState(() {
                _error = message;
                _isLoading = false;
              });
            }
        }
      }
    } catch (e) {
      AppNotification.error(title: 'Login Error', message: 'Login failed: $e');
      if (mounted) {
        setState(() {
          _error = 'Login failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _switchUser() async {
    await ref.read(authRepositoryProvider).logout();
    if (!mounted) return;
    context.go('/login');
    await _checkPinLoginAvailability();
    if (!mounted) return;
    setState(() {
      _error = null;
    });
  }

  Future<void> _loginWithBiometrics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authenticated = await _biometricAuth.authenticate(
        reason: 'Authenticate to access MedSentry',
      );

      if (authenticated) {
        final authRepo = ref.read(authRepositoryProvider);
        final user = await authRepo.loginWithBiometrics();
        if (user != null && mounted) {
          AppNotification.success(
            title: 'Welcome Back!',
            message: 'Biometric authentication successful.',
          );
          ref.read(currentUserProvider.notifier).state = user;
          context.go(user.homePath);
        } else if (mounted) {
          AppNotification.error(
            title: 'Biometric Login Failed',
            message: 'User not found or inactive.',
          );
          setState(() {
            _error = 'Biometric login failed. User not found or inactive.';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      AppNotification.error(
        title: 'Authentication Error',
        message: 'Biometric authentication error: $e',
      );
      if (mounted) {
        setState(() {
          _error = 'Biometric authentication error: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _LoginPalette.of(context);

    return Scaffold(
      backgroundColor: palette.surface,
      body: LayoutBuilder(
        builder: (context, constraints) =>
            _buildCenteredLayout(context, constraints, palette),
      ),
    );
  }

  Widget _buildCenteredLayout(
    BuildContext context,
    BoxConstraints constraints,
    _LoginPalette palette,
  ) {
    final isCompact = constraints.maxWidth < 900;
    final gutter = constraints.maxWidth < 360 ? 16.0 : 24.0;
    const topClearance = 64.0;
    const bottomClearance = 64.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Clinic Environmental Background Photo
        Positioned.fill(
          child: ExcludeSemantics(
            child: Image.asset(
              'assets/images/rhu_background.jpg',
              key: const ValueKey('login-background-image'),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  ColoredBox(color: palette.surface),
            ),
          ),
        ),

        // Contrast-Enhancing Vignette & Gradient Overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        const Color(0xCC0A0F1D),
                        const Color(0xF2040711),
                      ]
                    : [
                        const Color(0x730F172A),
                        const Color(0xB30F172A),
                      ],
              ),
            ),
          ),
        ),

        SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                gutter,
                topClearance,
                gutter,
                bottomClearance,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      (viewport.maxHeight - topClearance - bottomClearance)
                          .clamp(0.0, double.infinity),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Container(
                      key: const ValueKey('login-form-card'),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B).withValues(alpha: 0.75)
                            : Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.16)
                              : Colors.white.withValues(alpha: 0.90),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.45 : 0.22,
                            ),
                            blurRadius: 36,
                            spreadRadius: -4,
                            offset: const Offset(0, 16),
                          ),
                          BoxShadow(
                            color: (isDark
                                    ? AppColors.primaryEmerald
                                    : const Color(0xFF047857))
                                .withValues(alpha: 0.08),
                            blurRadius: 40,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Padding(
                            padding: EdgeInsets.all(isCompact ? 20 : 32),
                            child: _entrance(
                              context,
                              _buildAuthForm(
                                context,
                                palette,
                                isTall: !isCompact && viewport.maxHeight >= 760,
                                isMobile: isCompact,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // PWA Install Button (Frosted Glass Pill)
        Align(
          alignment: Alignment.topRight,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1,
                      ),
                    ),
                    child: _buildPwaInstallButton(context, isMobile: isCompact),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Footer Banner (Frosted Glass Pill)
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A).withValues(alpha: 0.70)
                            : Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1,
                        ),
                      ),
                      child: _buildFooter(context, palette),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// A single short fade-and-rise when the form first appears, so the eye
  /// lands on it. Skipped when the platform asks for reduced motion.
  Widget _entrance(BuildContext context, Widget child) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: child,
        ),
      ),
      child: child,
    );
  }

  Widget _buildPwaInstallButton(BuildContext context, {bool isMobile = false}) {
    final installer = ref.watch(pwaInstallerProvider);
    if (!installer.isSupported || installer.isInstalled) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<bool>(
      stream: installer.onInstallableChanged,
      initialData: installer.canInstall,
      builder: (context, snapshot) {
        final canInstall = snapshot.data ?? installer.canInstall;
        if (!canInstall) return const SizedBox.shrink();

        return FilledButton.tonalIcon(
          onPressed: () async {
            final installed = await installer.promptInstall();
            if (installed) {
              AppNotification.success(
                title: 'Installation Started',
                message: 'MedSentry is being installed to your device.',
              );
            }
          },
          style: FilledButton.styleFrom(
            visualDensity: isMobile ? VisualDensity.compact : null,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 14,
              vertical: isMobile ? 6 : 10,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.roundedMd,
            ),
            textStyle: TextStyle(
              fontSize: isMobile ? 12 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: Icon(Icons.install_desktop_outlined, size: isMobile ? 16 : 18),
          label: Text(isMobile ? 'Install' : 'Install App'),
        );
      },
    );
  }

  InputDecoration _fieldDecoration(
    _LoginPalette palette, {
    required IconData icon,
    String? hint,
    String? error,
    Widget? suffix,
  }) {
    OutlineInputBorder outline(Color color, double width) => OutlineInputBorder(
      borderRadius: AppRadius.roundedMd,
      borderSide: BorderSide(color: color, width: width),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: palette.hint),
      errorText: error,
      errorStyle: TextStyle(color: palette.error, fontSize: 12.5),
      prefixIcon: Icon(icon, size: 20, color: palette.muted),
      suffixIcon: suffix,
      filled: true,
      fillColor: palette.field,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: outline(palette.border, 1),
      enabledBorder: outline(palette.border, 1),
      focusedBorder: outline(palette.accent, 1.6),
      errorBorder: outline(palette.error, 1),
      focusedErrorBorder: outline(palette.error, 1.6),
    );
  }

  /// Label sits above its input so it stays readable while typing.
  Widget _labeledField(_LoginPalette palette, String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.text,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }

  Widget _buildAuthForm(
    BuildContext context,
    _LoginPalette palette, {
    bool isTall = false,
    bool isMobile = false,
  }) {
    final pendingChallenge = _otpChallenge;
    if (pendingChallenge != null) {
      final authRepo = ref.read(authRepositoryProvider);
      return OtpVerificationPanel(
        key: ValueKey(pendingChallenge.email),
        challenge: pendingChallenge,
        onVerify: authRepo.verifyLoginOtp,
        onResend: authRepo.resendLoginOtp,
        onVerified: _completeLogin,
        onCancel: _cancelOtp,
      );
    }

    final settings =
        ref.watch(systemSettingsProvider).valueOrNull ?? const SystemSettings();
    final inputStyle = TextStyle(
      color: palette.text,
      fontSize: 14.5,
      fontWeight: FontWeight.w500,
    );
    final linkStyle = TextButton.styleFrom(
      foregroundColor: palette.accent,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );

    Future<void> toggleRememberMe([bool? val]) async {
      final next = val ?? !_rememberMe;
      setState(() {
        _rememberMe = next;
      });
      final db = ref.read(databaseProvider);
      await db.setRememberMe(next);
      if (!next) {
        await db.setRememberedEmail(null);
      }
    }

    final showAlternatives =
        _sessionLocked || ((_isPinLogin) && _canCheckBiometrics);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SystemLogo(
              dataUri: settings.logoDataUri,
              size: 32,
              backgroundColor: palette.accent,
              iconColor: palette.onAccent,
              iconSize: 20,
              borderRadius: AppRadius.md,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                settings.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isTall ? 40 : (isMobile ? 24 : 32)),

        Text(
          _sessionLocked ? 'Screen Locked' : 'Welcome back',
          style: TextStyle(
            fontSize: isMobile ? 26 : 30,
            fontWeight: FontWeight.w700,
            color: palette.text,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _sessionLocked
              ? (_isPinLogin
                    ? 'Enter your 4-digit PIN to unlock your session.'
                    : 'Sign in again to unlock your session.')
              : 'Sign in to securely access your clinic workspace.',
          style: TextStyle(color: palette.muted, fontSize: 14.5, height: 1.45),
        ),
        SizedBox(height: isMobile ? 24 : 28),

        // Session locked banner if returning user
        if ((_isPinLogin || _sessionLocked) && _lastUserEmail != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: palette.accentSubtle,
              borderRadius: AppRadius.roundedMd,
            ),
            child: Row(
              children: [
                Icon(
                  _sessionLocked ? Icons.lock_outline : Icons.person_outline,
                  color: palette.accent,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _sessionLocked ? 'Locked session' : 'Current account',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: palette.accent,
                        ),
                      ),
                      Text(
                        _lastUserEmail!,
                        style: TextStyle(
                          color: palette.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        if (!_isPinLogin) ...[
          if (!_sessionLocked) ...[
            _labeledField(
              palette,
              'Email Address',
              TextField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                scrollPadding: const EdgeInsets.only(bottom: 120),
                style: inputStyle,
                cursorColor: palette.accent,
                decoration: _fieldDecoration(
                  palette,
                  icon: Icons.mail_outline_rounded,
                  hint: 'Enter your email',
                  error: _emailError,
                ),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_emailError != null || _error != null) {
                    setState(() {
                      _emailError = null;
                      _error = null;
                    });
                  }
                },
                onSubmitted: (_) => _submitFromEmailField(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _labeledField(
            palette,
            'Password',
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              scrollPadding: const EdgeInsets.only(bottom: 120),
              style: inputStyle,
              cursorColor: palette.accent,
              decoration: _fieldDecoration(
                palette,
                icon: Icons.lock_outline_rounded,
                error: _passwordFieldError,
                suffix: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: palette.muted,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              autofillHints: const [AutofillHints.password],
              autocorrect: false,
              enableSuggestions: false,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_passwordFieldError != null || _error != null) {
                  setState(() {
                    _passwordFieldError = null;
                    _error = null;
                  });
                }
              },
              onSubmitted: (_) => _submitLogin(),
            ),
          ),
          if (_isCapsLockOn) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.keyboard_capslock, size: 16, color: palette.warning),
                const SizedBox(width: 6),
                Text(
                  'Caps Lock is on',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: palette.warning,
                  ),
                ),
              ],
            ),
          ],
          if (_sessionLocked && !_pinLoginAvailable) ...[
            const SizedBox(height: 8),
            Text(
              'Tip: Enable a PIN in Settings for faster unlock next time.',
              style: TextStyle(color: palette.muted, fontSize: 12.5),
            ),
          ],
        ] else ...[
          _labeledField(
            palette,
            '4-digit PIN',
            TextField(
              controller: _pinController,
              focusNode: _pinFocusNode,
              scrollPadding: const EdgeInsets.only(bottom: 120),
              style: inputStyle.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 8,
              ),
              cursorColor: palette.accent,
              decoration: _fieldDecoration(
                palette,
                icon: Icons.pin_outlined,
                hint: 'Enter your password',
                error: _pinFieldError,
                suffix: IconButton(
                  tooltip: _obscurePin ? 'Show PIN' : 'Hide PIN',
                  icon: Icon(
                    _obscurePin
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: palette.muted,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePin = !_obscurePin;
                    });
                  },
                ),
              ).copyWith(counterText: ''),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: _obscurePin,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_pinFieldError != null || _error != null) {
                  setState(() {
                    _pinFieldError = null;
                    _error = null;
                  });
                }
              },
              onSubmitted: (_) => _submitLogin(),
            ),
          ),
        ],

        const SizedBox(height: 14),

        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            InkWell(
              borderRadius: AppRadius.roundedSm,
              onTap: () => toggleRememberMe(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: palette.accent,
                        checkColor: palette.onAccent,
                        side: BorderSide(color: palette.hint, width: 1.3),
                        onChanged: toggleRememberMe,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.roundedXs,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Remember Me',
                      style: TextStyle(
                        color: palette.text,
                        fontWeight: FontWeight.w500,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: () => _showForgotPasswordDialog(context),
              style: linkStyle,
              child: const Text('Forgot Password?'),
            ),
          ],
        ),

        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.errorBg,
              borderRadius: AppRadius.roundedMd,
              border: Border.all(color: palette.errorBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: palette.error,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: palette.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _isLoading ? null : _login,
            style: FilledButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: palette.onAccent,
              disabledBackgroundColor: palette.accent.withValues(alpha: 0.55),
              disabledForegroundColor: palette.onAccent,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.roundedMd,
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoading) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.onAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    _isLoading
                        ? 'Signing in...'
                        : _sessionLocked
                        ? (_isPinLogin ? 'Unlock with PIN' : 'Unlock session')
                        : (_isPinLogin
                              ? 'Continue with PIN'
                              : 'Sign in securely'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (showAlternatives) ...[
          SizedBox(height: isTall ? 24 : 18),
          Row(
            children: [
              Expanded(child: Divider(color: palette.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Other ways to sign in',
                  style: TextStyle(color: palette.muted, fontSize: 12.5),
                ),
              ),
              Expanded(child: Divider(color: palette.border)),
            ],
          ),
          const SizedBox(height: 14),
          if (_pinLoginAvailable) ...[
            _buildAlternativeButton(
              palette,
              icon: _isPinLogin ? Icons.password_rounded : Icons.pin_outlined,
              label: _isPinLogin ? 'Use Password' : 'Use PIN',
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _isPinLogin = !_isPinLogin;
                        _error = null;
                        _emailError = null;
                        _passwordFieldError = null;
                        _pinFieldError = null;
                      });
                    },
            ),
            const SizedBox(height: 8),
          ],
          if (_canCheckBiometrics) ...[
            _buildAlternativeButton(
              palette,
              icon: Icons.fingerprint_rounded,
              label: 'Use Biometrics / Windows Hello',
              onPressed: _isLoading ? null : _loginWithBiometrics,
            ),
            const SizedBox(height: 8),
          ],
          if (_sessionLocked)
            TextButton.icon(
              onPressed: _isLoading ? null : _switchUser,
              style: linkStyle.copyWith(
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              icon: const Icon(Icons.switch_account_outlined, size: 18),
              label: const Text('Sign in as a different user'),
            ),
        ],

        SizedBox(height: isTall ? 28 : 20),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Trouble signing in?',
              style: TextStyle(color: palette.muted, fontSize: 13),
            ),
            TextButton(
              onPressed: () => _showNeedHelpDialog(context),
              style: linkStyle,
              child: const Text('Need Help?'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlternativeButton(
    _LoginPalette palette, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.text,
        minimumSize: const Size.fromHeight(46),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
        side: BorderSide(color: palette.border),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, _LoginPalette palette) {
    final settings =
        ref.watch(systemSettingsProvider).valueOrNull ?? const SystemSettings();
    final orgName = settings.organizationName.isNotEmpty
        ? settings.organizationName
        : 'Madrid Rural Health Unit';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.textSecondary
        : Colors.white.withValues(alpha: 0.92);
    final iconColor = isDark
        ? AppColors.textSecondary
        : Colors.white.withValues(alpha: 0.85);
    final style = TextStyle(color: textColor, fontSize: 12, height: 1.4);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_outlined, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'RA 10173 compliant. Records are encrypted and access is audited.',
                textAlign: TextAlign.center,
                style: style,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '© 2026 $orgName. All Rights Reserved.',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ],
    );
  }

  void _showNeedHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AppFormDialog(
        title: 'Login Assistance',
        subtitle: 'Healthcare Provider Security',
        icon: Icons.help_outline,
        maxWidth: 460,
        content: const Text(
          'Contact your Rural Health Unit administrator to create, unlock, or reset an account. '
          'For security, MedSentry does not display account credentials in the application.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AppFormDialog(
        title: 'Password Assistance',
        subtitle: 'Account Recovery',
        icon: Icons.lock_reset_rounded,
        maxWidth: 460,
        content: const Text(
          'To ensure patient data privacy under RA 10173 and DOH guidelines, '
          'password resets must be processed through your clinic administrator. '
          'Please contact your Rural Health Unit administrator to reset your credentials.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }
}

/// Light and dark colors for the sign-in screen, built on the app's design
/// tokens. Every text/background pair meets WCAG AA.
class _LoginPalette {
  const _LoginPalette({
    required this.surface,
    required this.card,
    required this.field,
    required this.border,
    required this.text,
    required this.muted,
    required this.hint,
    required this.accent,
    required this.onAccent,
    required this.accentSubtle,
    required this.error,
    required this.errorBg,
    required this.errorBorder,
    required this.warning,
  });

  final Color surface;
  final Color card;
  final Color field;
  final Color border;
  final Color text;
  final Color muted;
  final Color hint;
  final Color accent;
  final Color onAccent;
  final Color accentSubtle;
  final Color error;
  final Color errorBg;
  final Color errorBorder;
  final Color warning;

  static const light = _LoginPalette(
    surface: AppColors.lightAppBackground,
    card: AppColors.lightCardSurface,
    field: AppColors.lightCardSurface,
    border: Color(0xFFCBD5E1),
    text: AppColors.lightTextPrimary,
    muted: Color(0xFF334155),
    hint: Color(0xFF475569),
    accent: AppColors.primaryEmeraldDeep,
    onAccent: AppColors.lightAppBackground,
    accentSubtle: Color(0x14047857),
    error: Color(0xFFB91C1C),
    errorBg: Color(0xFFFEF2F2),
    errorBorder: Color(0xFFFCA5A5),
    warning: Color(0xFFB45309),
  );

  static const dark = _LoginPalette(
    surface: AppColors.appBackground,
    card: AppColors.cardSurface,
    field: AppColors.inputSurface,
    border: AppColors.borderActive,
    text: AppColors.textPrimary,
    muted: Color(0xFFB4B8C0),
    hint: AppColors.textSecondary,
    accent: AppColors.primaryEmerald,
    onAccent: AppColors.textOnEmerald,
    accentSubtle: AppColors.primaryEmeraldSubtle,
    error: AppColors.critical,
    errorBg: AppColors.criticalBg,
    errorBorder: AppColors.criticalBorder,
    warning: Color(0xFFFBBF24),
  );

  static _LoginPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
