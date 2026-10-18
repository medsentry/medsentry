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
        final user = await authRepo.loginWithPin(pin);
        if (user != null) {
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
        final result = await authRepo.beginLogin(email, password);
        switch (result) {
          case LoginSuccess(:final user):
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
          const ColoredBox(color: Color(0x66001410)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth >= 900
                    ? (constraints.maxWidth * 0.045).clamp(32.0, 88.0)
                    : 24.0;
                final isTall = constraints.maxHeight >= 820;
                final card = Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: ClipRRect(
                        borderRadius: AppRadius.roundedLg,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isTall ? 32 : 24),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.98),
                              borderRadius: AppRadius.roundedLg,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.24),
                                  blurRadius: 36,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                brightness: Brightness.light,
                                colorScheme:
                                    Theme.of(context).colorScheme.copyWith(
                                  brightness: Brightness.light,
                                  surface: Colors.white,
                                  onSurface: const Color(0xFF0F172A),
                                  outline: const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: _buildAuthForm(context, isTall: isTall),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );

                if (constraints.maxHeight < 680) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTopBar(
                          context,
                          compact: true,
                          onBackground: true,
                        ),
                        const SizedBox(height: 16),
                        card,
                        const SizedBox(height: 16),
                        _buildBottomBar(
                          context,
                          compact: true,
                          onBackground: true,
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    _buildTopBar(
                      context,
                      horizontalPadding: horizontalPadding,
                      isTall: isTall,
                      onBackground: true,
                    ),
                    Expanded(child: card),
                    _buildBottomBar(
                      context,
                      horizontalPadding: horizontalPadding,
                      isTall: isTall,
                      onBackground: true,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context, {
    bool compact = false,
    double horizontalPadding = 48,
    bool isTall = false,
    bool onBackground = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = onBackground
        ? Colors.white
        : isDark
        ? AppColors.primaryEmerald
        : theme.colorScheme.primary;
    final settings =
        ref.watch(systemSettingsProvider).valueOrNull ?? const SystemSettings();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : horizontalPadding,
        vertical: compact ? 10 : (isTall ? 20 : 12),
      ),
      child: Row(
        children: [
          SystemLogo(
            dataUri: settings.logoDataUri,
            size: isTall ? 36 : 30,
            backgroundColor: onBackground
                ? AppColors.primaryEmerald
                : isDark
                ? AppColors.primaryEmeraldSubtle
                : primary,
            iconColor: isDark && !onBackground
                ? AppColors.primaryEmerald
                : Colors.white,
            iconSize: isTall ? 22 : 18,
          ),
          const SizedBox(width: 10),
          Text(
            settings.appName,
            style: TextStyle(
              fontSize: isTall ? 20 : 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: onBackground
                  ? Colors.white
                  : isDark
                  ? AppColors.textPrimary
                  : primary,
            ),
          ),
          const Spacer(),
          _buildPwaInstallButton(context),
        ],
      ),
    );
  }

  Widget _buildPwaInstallButton(BuildContext context) {
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
          icon: const Icon(Icons.install_desktop_outlined, size: 18),
          label: const Text('Install App'),
        );
      },
    );
  }

  Widget _buildAuthForm(BuildContext context, {bool isTall = false}) {
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
    final primary = AppColors.primaryEmeraldDark;
    const fieldBg = Color(0xFFF8FAFC);
    const borderColor = Color(0xFFCBD5E1);
    const cardTextColor = Color(0xFF0F172A);
    const cardSecondaryTextColor = Color(0xFF475569);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primary.withValues(alpha: 0.16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_outlined, size: 15, color: primary),
                const SizedBox(width: 7),
                Text(
                  'SECURE CLINIC ACCESS',
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: isTall ? 22 : 16),

        Text(
          _sessionLocked ? 'Screen Locked' : 'Welcome back',
          textAlign: TextAlign.left,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: isTall ? 30 : 26,
            fontWeight: FontWeight.w800,
            color: cardTextColor,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _sessionLocked
              ? (_isPinLogin
                    ? 'Enter your 4-digit PIN to unlock your session.'
                    : 'Sign in again to unlock your session.')
              : 'Sign in to securely access your clinic workspace.',
          textAlign: TextAlign.left,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cardSecondaryTextColor,
            height: 1.45,
          ),
        ),
        SizedBox(height: isTall ? 24 : 20),

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
              style: const TextStyle(
                color: cardTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: primary,
              decoration: InputDecoration(
                labelText: 'Email Address',
                labelStyle: const TextStyle(color: cardSecondaryTextColor),
                floatingLabelStyle:
                    TextStyle(color: primary, fontWeight: FontWeight.w600),
                hintText: 'name@rhu.gov.ph',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                errorText: _emailError,
                prefixIcon: const Icon(
                  Icons.medical_services_outlined,
                  size: 20,
                  color: cardSecondaryTextColor,
                ),
                filled: true,
                fillColor: fieldBg,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.roundedSm,
                  borderSide: const BorderSide(
                    color: borderColor,
                    width: AppColors.borderWidth,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.roundedSm,
                  borderSide: const BorderSide(
                    color: borderColor,
                    width: AppColors.borderWidth,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.roundedSm,
                  borderSide: BorderSide(
                    color: primary,
                    width: AppColors.borderWidthActive,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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
            style: const TextStyle(
              color: cardTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            cursorColor: primary,
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(color: cardSecondaryTextColor),
              floatingLabelStyle:
                  TextStyle(color: primary, fontWeight: FontWeight.w600),
              errorText: _passwordFieldError,
              prefixIcon: const Icon(
                Icons.vpn_key_outlined,
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
                borderRadius: AppRadius.roundedSm,
                borderSide: const BorderSide(
                  color: borderColor,
                  width: AppColors.borderWidth,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.roundedSm,
                borderSide: const BorderSide(
                  color: borderColor,
                  width: AppColors.borderWidth,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.roundedSm,
                borderSide: BorderSide(
                  color: primary,
                  width: AppColors.borderWidthActive,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
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
            style: const TextStyle(
              color: cardTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 8,
            ),
            cursorColor: primary,
            decoration: InputDecoration(
              labelText: '4-digit PIN',
              labelStyle: const TextStyle(color: cardSecondaryTextColor),
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
                borderRadius: AppRadius.roundedSm,
                borderSide: const BorderSide(
                  color: borderColor,
                  width: AppColors.borderWidth,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.roundedSm,
                borderSide: const BorderSide(
                  color: borderColor,
                  width: AppColors.borderWidth,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.roundedSm,
                borderSide: BorderSide(
                  color: primary,
                  width: AppColors.borderWidthActive,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _rememberMe,
                    activeColor: primary,
                    checkColor: Colors.white,
                    side: const BorderSide(color: borderColor, width: 1.5),
                    onChanged: (val) async {
                      final next = val ?? false;
                      setState(() {
                        _rememberMe = next;
                      });
                      final db = ref.read(databaseProvider);
                      await db.setRememberMe(next);
                      if (!next) {
                        await db.setRememberedEmail(null);
                      }
                    },
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
            if (_pinLoginAvailable)
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
                child: Text(
                  _isPinLogin ? 'Use Password' : 'Use PIN',
                  style: TextStyle(
                    fontSize: 13,
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              TextButton(
                onPressed: () => _showNeedHelpDialog(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Need Help?',
                  style: TextStyle(
                    fontSize: 13,
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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

        const SizedBox(height: 16),

        // Primary Login / Sign In Button
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: primary.withValues(alpha: 0.6),
            disabledForegroundColor: Colors.white70,
            minimumSize: Size.fromHeight(isTall ? 54 : 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            shadowColor: primary.withValues(alpha: 0.25),
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(
                  _sessionLocked
                      ? Icons.lock_open_rounded
                      : Icons.arrow_forward,
                  size: 18,
                ),
          label: Text(
            _isLoading
                ? 'Signing in...'
                : _sessionLocked
                ? (_isPinLogin ? 'Unlock with PIN' : 'Unlock session')
                : (_isPinLogin ? 'Continue with PIN' : 'Sign in securely'),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Colors.white,
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
              icon: const Icon(Icons.fingerprint_rounded, size: 20, color: cardTextColor),
              label: const Text(
                'Use Biometrics / Windows Hello',
                style: TextStyle(color: cardTextColor, fontWeight: FontWeight.w600),
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
              icon: Icon(Icons.switch_account_outlined, size: 18, color: primary),
              label: Text(
                'Sign in as a different user',
                style: TextStyle(color: primary, fontWeight: FontWeight.w600),
              ),
            ),
        ],

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 13,
                color: Color(0xFF64748B),
              ),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'DOH Healthcare Standards • RA 10173 • AES-256 Offline',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                  overflow: TextOverflow.ellipsis,
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
    bool compact = false,
    double horizontalPadding = 48,
    bool isTall = false,
    bool onBackground = false,
  }) {
    final theme = Theme.of(context);
    final mutedColor = onBackground
        ? Colors.white.withValues(alpha: 0.85)
        : theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final settings =
        ref.watch(systemSettingsProvider).valueOrNull ?? const SystemSettings();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : horizontalPadding,
        vertical: compact ? 10 : (isTall ? 18 : 10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              '(C) 2026 ${settings.organizationName}. All Rights are Reserved',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: mutedColor,
                fontSize: isTall ? 12 : 11,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: isTall ? 14 : 13,
                  color: mutedColor,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Protected access • Activity is audited • ${settings.appName} v1.0.0',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: mutedColor,
                      fontSize: isTall ? 12 : 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNeedHelpDialog(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: primary),
            const SizedBox(width: 10),
            const Text('Login assistance'),
          ],
        ),
        content: const Text(
          'Contact your Rural Health Unit administrator to create, unlock, or reset an account. '
          'For security, MedSentry does not display account credentials in the application.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
