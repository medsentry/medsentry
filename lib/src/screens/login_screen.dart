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
    final capsLockActive = HardwareKeyboard.instance.lockModesEnabled
        .contains(KeyboardLockMode.capsLock);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/rhu_madrid_background.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: isDark
                  ? AppColors.appBackground
                  : AppColors.lightBackground,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x8A00120E),
                  Color(0x6E000000),
                  Color(0x9E000F0B),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                final isVeryNarrow = constraints.maxWidth < 360;
                final horizontalPadding = constraints.maxWidth >= 900
                    ? (constraints.maxWidth * 0.045).clamp(32.0, 88.0)
                    : (isVeryNarrow ? 12.0 : (isMobile ? 16.0 : 24.0));
                final verticalPadding = isMobile ? 8.0 : 12.0;
                final isTall = !isMobile && constraints.maxHeight >= 820;
                final cardPadding = isVeryNarrow
                    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 18)
                    : isMobile
                    ? const EdgeInsets.symmetric(horizontal: 20, vertical: 22)
                    : EdgeInsets.all(isTall ? 32 : 28);
                final minContentHeight =
                    (constraints.maxHeight - (verticalPadding * 2)).clamp(
                      0.0,
                      double.infinity,
                    );

                final card = Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? double.infinity : 440,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                        child: Container(
                          width: double.infinity,
                          padding: cardPadding,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.92),
                                Colors.white.withValues(alpha: 0.82),
                                Colors.white.withValues(alpha: 0.88),
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.85),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 40,
                                offset: const Offset(0, 18),
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: const Color(0xFF059669).withValues(alpha: 0.08),
                                blurRadius: 32,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              brightness: Brightness.light,
                              colorScheme: Theme.of(context).colorScheme
                                  .copyWith(
                                    brightness: Brightness.light,
                                    surface: Colors.white,
                                    onSurface: const Color(0xFF0F172A),
                                    outline: const Color(0xFFCBD5E1),
                                  ),
                            ),
                            child: _buildAuthForm(
                              context,
                              isTall: isTall,
                              isMobile: isMobile,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );

                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minContentHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: verticalPadding,
                          ),
                          child: Align(
                            alignment: Alignment.topRight,
                            child: _buildPwaInstallButton(
                              context,
                              isMobile: isMobile,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: isMobile ? 10 : 20,
                          ),
                          child: card,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                left: horizontalPadding,
                                right: horizontalPadding,
                                bottom: isMobile ? 12 : 16,
                              ),
                              child: _buildRhuBrandSeal(
                                context,
                                isMobile: isMobile,
                              ),
                            ),
                            _buildBottomBar(
                              context,
                              isMobile: isMobile,
                              horizontalPadding: horizontalPadding,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRhuBrandSeal(BuildContext context, {bool isMobile = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isMobile ? 40 : 48,
          height: isMobile ? 40 : 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFF10B981),
              width: 2.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/madrid_seal.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.health_and_safety_rounded,
                color: Color(0xFF059669),
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MADRID RURAL HEALTH UNIT',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: isMobile ? 13 : 15,
                  letterSpacing: 0.6,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.85),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '& FAMILY PLANNING CENTER',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w800,
                  fontSize: isMobile ? 11.5 : 13,
                  letterSpacing: 0.6,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.85),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
          style: isMobile
              ? FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
          icon: Icon(
            Icons.install_desktop_outlined,
            size: isMobile ? 16 : 18,
          ),
          label: Text(isMobile ? 'Install' : 'Install App'),
        );
      },
    );
  }

  Widget _buildAuthForm(
    BuildContext context, {
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

    final theme = Theme.of(context);
    final settings =
        ref.watch(systemSettingsProvider).valueOrNull ?? const SystemSettings();
    final primary = AppColors.primaryEmeraldDark;
    const fieldBg = Color(0xFFF8FAFC);
    const borderColor = Color(0xFFCBD5E1);
    const cardTextColor = Color(0xFF0F172A);
    const cardSecondaryTextColor = Color(0xFF64748B);
    final fieldPadding = EdgeInsets.symmetric(
      horizontal: isMobile ? 14 : 16,
      vertical: isMobile ? 12 : 14,
    );

    final fieldBorderRadius = BorderRadius.circular(12);

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 9 : 11,
              vertical: isMobile ? 4 : 5.5,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: Color(0xFF047857),
                ),
                SizedBox(width: 5),
                Text(
                  'SECURE CLINIC ACCESS',
                  style: TextStyle(
                    color: Color(0xFF047857),
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),

        Row(
          children: [
            Container(
              width: isMobile ? 26 : 28,
              height: isMobile ? 26 : 28,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.health_and_safety_rounded,
                color: Colors.white,
                size: isMobile ? 17 : 19,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                settings.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isMobile ? 19 : 21,
                  fontWeight: FontWeight.w800,
                  color: cardTextColor,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isMobile ? 12 : 14),

        Text(
          _sessionLocked ? 'Screen Locked' : 'Welcome back',
          textAlign: TextAlign.left,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: isMobile ? 22 : 25,
            fontWeight: FontWeight.w800,
            color: cardTextColor,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _sessionLocked
              ? (_isPinLogin
                    ? 'Enter your 4-digit PIN to unlock your session.'
                    : 'Sign in again to unlock your session.')
              : 'Sign in to securely access your clinic workspace.',
          textAlign: TextAlign.left,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cardSecondaryTextColor,
            fontSize: isMobile ? 12.5 : 13.5,
            height: 1.4,
          ),
        ),
        SizedBox(height: isMobile ? 16 : 20),

        // Session locked banner if returning user
        if ((_isPinLogin || _sessionLocked) && _lastUserEmail != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: primary.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Icon(
                  _sessionLocked ? Icons.lock_outline : Icons.person_outline,
                  color: primary,
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
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
                      Text(
                        _lastUserEmail!,
                        style: const TextStyle(
                          color: cardTextColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Input fields with soft filled styling matching the design system
        if (!_isPinLogin) ...[
          if (!_sessionLocked) ...[
            TextField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              scrollPadding: const EdgeInsets.only(bottom: 120),
              style: const TextStyle(
                color: cardTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: const Color(0xFF10B981),
              decoration: InputDecoration(
                labelText: 'Email Address',
                labelStyle: const TextStyle(color: cardSecondaryTextColor),
                floatingLabelStyle: const TextStyle(
                  color: Color(0xFF059669),
                  fontWeight: FontWeight.w600,
                ),
                hintText: 'name@rhu.gov.ph',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                errorText: _emailError,
                prefixIcon: const Icon(
                  Icons.mail_outline_rounded,
                  size: 20,
                  color: cardSecondaryTextColor,
                ),
                filled: true,
                fillColor: fieldBg,
                border: OutlineInputBorder(
                  borderRadius: fieldBorderRadius,
                  borderSide: const BorderSide(
                    color: borderColor,
                    width: 1.2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: fieldBorderRadius,
                  borderSide: const BorderSide(
                    color: borderColor,
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: fieldBorderRadius,
                  borderSide: const BorderSide(
                    color: Color(0xFF10B981),
                    width: 1.6,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: fieldBorderRadius,
                  borderSide: const BorderSide(
                    color: Color(0xFFEF4444),
                    width: 1.2,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: fieldBorderRadius,
                  borderSide: const BorderSide(
                    color: Color(0xFFEF4444),
                    width: 1.6,
                  ),
                ),
                contentPadding: fieldPadding,
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
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            scrollPadding: const EdgeInsets.only(bottom: 120),
            style: const TextStyle(
              color: cardTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            cursorColor: const Color(0xFF10B981),
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(color: cardSecondaryTextColor),
              floatingLabelStyle: const TextStyle(
                color: Color(0xFF059669),
                fontWeight: FontWeight.w600,
              ),
              errorText: _passwordFieldError,
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                size: 20,
                color: cardSecondaryTextColor,
              ),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: cardSecondaryTextColor,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              filled: true,
              fillColor: fieldBg,
              border: OutlineInputBorder(
                borderRadius: fieldBorderRadius,
                borderSide: const BorderSide(
                  color: borderColor,
                  width: 1.2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: fieldBorderRadius,
                borderSide: const BorderSide(
                  color: borderColor,
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: fieldBorderRadius,
                borderSide: const BorderSide(
                  color: Color(0xFF10B981),
                  width: 1.6,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: fieldBorderRadius,
                borderSide: const BorderSide(
                  color: Color(0xFFEF4444),
                  width: 1.2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: fieldBorderRadius,
                borderSide: const BorderSide(
                  color: Color(0xFFEF4444),
                  width: 1.6,
                ),
              ),
              contentPadding: fieldPadding,
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
          if (_isCapsLockOn) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.keyboard_capslock,
                    size: 15,
                    color: Color(0xFFD97706),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Caps Lock is active',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_sessionLocked && !_pinLoginAvailable) ...[
            const SizedBox(height: 8),
            const Text(
              'Tip: Enable a PIN in Settings for faster unlock next time.',
              style: TextStyle(
                color: cardSecondaryTextColor,
                fontSize: 12,
              ),
            ),
          ],
        ] else ...[
          TextField(
            controller: _pinController,
            focusNode: _pinFocusNode,
            scrollPadding: const EdgeInsets.only(bottom: 120),
            style: const TextStyle(
              color: cardTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 8,
            ),
            cursorColor: const Color(0xFF10B981),
            decoration: InputDecoration(
              labelText: '4-digit PIN',
              labelStyle: const TextStyle(color: cardSecondaryTextColor),
              floatingLabelStyle: const TextStyle(
                color: Color(0xFF059669),
                fontWeight: FontWeight.w600,
              ),
              hintText: '••••',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              errorText: _pinFieldError,
              prefixIcon: const Icon(
                Icons.pin_outlined,
                size: 20,
                color: cardSecondaryTextColor,
              ),
              suffixIcon: IconButton(
                tooltip: _obscurePin ? 'Show PIN' : 'Hide PIN',
                icon: Icon(
                  _obscurePin
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: cardSecondaryTextColor,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePin = !_obscurePin;
                  });
                },
              ),
              filled: true,
              fillColor: fieldBg,
              border: OutlineInputBorder(
                borderRadius: fieldBorderRadius,
                borderSide: const BorderSide(
                  color: borderColor,
                  width: 1.2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: fieldBorderRadius,
                borderSide: const BorderSide(
                  color: borderColor,
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: fieldBorderRadius,
                borderSide: const BorderSide(
                  color: Color(0xFF10B981),
                  width: 1.6,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: fieldBorderRadius,
                borderSide: const BorderSide(
                  color: Color(0xFFEF4444),
                  width: 1.2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: fieldBorderRadius,
                borderSide: const BorderSide(
                  color: Color(0xFFEF4444),
                  width: 1.6,
                ),
              ),
              contentPadding: fieldPadding,
            ),
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
        ],

        const SizedBox(height: 8),

        // Remember Me & Need Help row
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => toggleRememberMe(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: const Color(0xFF059669),
                        checkColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF94A3B8), width: 1.3),
                        onChanged: toggleRememberMe,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Remember Me',
                      style: TextStyle(
                        color: cardTextColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                if (_pinLoginAvailable) ...[
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isPinLogin = !_isPinLogin;
                        _error = null;
                        _emailError = null;
                        _passwordFieldError = null;
                        _pinFieldError = null;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _isPinLogin ? 'Use Password' : 'Use PIN',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF0D9488),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                TextButton(
                  onPressed: () => _showNeedHelpDialog(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Need Help?',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF0D9488),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _showForgotPasswordDialog(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF0D9488),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        if (_error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: AppRadius.roundedSm,
              border: Border.all(
                color: const Color(0xFFFCA5A5),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        SizedBox(height: isMobile ? 14 : 16),

        // Primary Login / Sign In Button
        SizedBox(
          width: double.infinity,
          height: isMobile ? 46 : 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  const Color(0xFF059669).withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white70,
              elevation: 2,
              shadowColor: const Color(0xFF059669).withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _isLoading
                              ? 'Signing in...'
                              : _sessionLocked
                              ? (_isPinLogin
                                  ? 'Unlock with PIN'
                                  : 'Unlock session')
                              : (_isPinLogin
                                  ? 'Continue with PIN'
                                  : 'Sign in securely'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: isMobile ? 13.5 : 14.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ],
                  ),
          ),
        ),

        // Alternative Login Options
        if ((_isPinLogin || _sessionLocked) && _canCheckBiometrics ||
            _sessionLocked) ...[
          SizedBox(height: isTall ? 18 : 12),
          const Row(
            children: [
              Expanded(
                child: Divider(
                  color: borderColor,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Alternative Login Options',
                  style: TextStyle(
                    color: cardSecondaryTextColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: borderColor,
                ),
              ),
            ],
          ),
          SizedBox(height: isTall ? 14 : 10),
          if (_canCheckBiometrics) ...[
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _loginWithBiometrics,
              icon: const Icon(
                Icons.fingerprint_rounded,
                size: 20,
                color: cardTextColor,
              ),
              label: const Text(
                'Use Biometrics / Windows Hello',
                style: TextStyle(
                  color: cardTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: Size.fromHeight(isTall ? 46 : 42),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.roundedSm,
                ),
                side: const BorderSide(
                  color: borderColor,
                  width: AppColors.borderWidth,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_sessionLocked)
            TextButton.icon(
              onPressed: _isLoading ? null : _switchUser,
              icon: Icon(
                Icons.switch_account_outlined,
                size: 18,
                color: const Color(0xFF059669),
              ),
              label: const Text(
                'Sign in as a different user',
                style: TextStyle(
                  color: Color(0xFF059669),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],

        SizedBox(height: isMobile ? 12 : 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border_rounded,
                size: 12.5,
                color: Color(0xFF64748B),
              ),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'DOH Healthcare Standards • RA 10173 • AES-256 Offline',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(
    BuildContext context, {
    bool isMobile = false,
    double horizontalPadding = 48,
  }) {
    final settings =
        ref.watch(systemSettingsProvider).valueOrNull ?? const SystemSettings();
    final orgName = settings.organizationName.isNotEmpty
        ? settings.organizationName
        : 'Madrid Rural Health Unit';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.0,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : horizontalPadding,
        vertical: isMobile ? 8 : 10,
      ),
      child: isMobile
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '(C) 2026 $orgName. All Rights Reserved • ${settings.appName} v1.0.0',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 11.5,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Protected access • Activity is audited',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '(C) 2026 $orgName. All Rights Reserved • ${settings.appName} v1.0.0',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 13,
                      color: Colors.white70,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Protected access • Activity is audited',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
