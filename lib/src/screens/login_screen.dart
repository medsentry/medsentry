import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../services/app_notification.dart';
import '../providers/providers.dart';
import '../utils/biometric_auth/biometric_auth.dart';

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
  String? _error;
  String? _lastUserEmail;
  bool _pinLoginAvailable = false;
  bool _sessionLocked = false;
  bool _obscurePassword = true;
  bool _obscurePin = true;
  bool _canCheckBiometrics = false;
  bool _rememberMe = true;
  final BiometricAuthService _biometricAuth = createBiometricAuthService();

  @override
  void initState() {
    super.initState();
    _ensureDefaultAccounts();
    _checkPinLoginAvailability();
    _checkBiometrics();
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
    final locked = widget.locked || await authRepo.isSessionLocked();

    if (!mounted) return;

    if (locked) {
      final available = await authRepo.isPinLoginAvailable();
      final email = await authRepo.getLastLoggedInUserEmail();
      setState(() {
        _pinLoginAvailable = available;
        _lastUserEmail = email;
        _sessionLocked = true;
        _isPinLogin = available;
        if (email != null) {
          _emailController.text = email;
        }
      });
      return;
    }

    // Fresh login (logout or first launch) — no saved account shortcuts.
    setState(() {
      _pinLoginAvailable = false;
      _lastUserEmail = null;
      _sessionLocked = false;
      _isPinLogin = false;
      _emailController.clear();
      _passwordController.clear();
      _pinController.clear();
    });
  }

  @override
  void dispose() {
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

  Future<void> _login() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);

      if (_isPinLogin) {
        final user = await authRepo.loginWithPin(_pinController.text);
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
          setState(() {
            _error = 'Invalid PIN. Please try again.';
            _isLoading = false;
          });
        }
      } else {
        final user = await authRepo.login(
          _emailController.text,
          _passwordController.text,
        );
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
            message: 'Invalid email or password.',
          );
          setState(() {
            _error = 'Invalid email or password.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      AppNotification.error(title: 'Login Error', message: 'Login failed: $e');
      setState(() {
        _error = 'Login failed: $e';
        _isLoading = false;
      });
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
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      AppNotification.error(
        title: 'Authentication Error',
        message: 'Biometric authentication error: $e',
      );
      setState(() {
        _error = 'Biometric authentication error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final isWide = width >= 900;
            final isTall = height >= 820;

            if (!isWide) {
              final showIllustration = height >= 580;
              final compactIllustrationHeight = (height * 0.28).clamp(
                120.0,
                240.0,
              );
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTopBar(context, compact: true),
                        if (showIllustration) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: compactIllustrationHeight,
                            child: Image.asset(
                              'assets/images/rhu_doctors.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildAuthForm(context, isTall: false),
                        const SizedBox(height: 20),
                        _buildBottomBar(context, compact: true),
                      ],
                    ),
                  ),
                ),
              );
            }

            final horizontalPadding = (width * 0.045).clamp(32.0, 88.0);
            final formMaxWidth = (width * 0.28).clamp(380.0, 480.0);
            final columnGap = (width * 0.035).clamp(28.0, 64.0);

            final wideContent = Column(
              children: [
                _buildTopBar(
                  context,
                  horizontalPadding: horizontalPadding,
                  isTall: isTall,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: isTall ? 12 : 4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: Doctor & Clinician Illustration (Auto-resizes to fill available space)
                        Expanded(
                          flex: 6,
                          child: _buildIllustrationPanel(context),
                        ),
                        SizedBox(width: columnGap),
                        // Right: Clean Auth Form (Proportionally scales maxWidth & vertical spacing)
                        Expanded(
                          flex: 5,
                          child: Center(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.symmetric(
                                vertical: isTall ? 16 : 8,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: formMaxWidth,
                                ),
                                child: _buildAuthForm(context, isTall: isTall),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(
                  context,
                  horizontalPadding: horizontalPadding,
                  isTall: isTall,
                ),
              ],
            );

            if (height < 560) {
              return SingleChildScrollView(
                child: SizedBox(
                  height: 560,
                  child: wideContent,
                ),
              );
            }

            return wideContent;
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context, {
    bool compact = false,
    double horizontalPadding = 48,
    bool isTall = false,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final settings = ref.watch(systemSettingsProvider).valueOrNull ??
        const SystemSettings();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : horizontalPadding,
        vertical: compact ? 10 : (isTall ? 20 : 12),
      ),
      child: Row(
        children: [
          Container(
            width: isTall ? 36 : 30,
            height: isTall ? 36 : 30,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.local_hospital,
              color: Colors.white,
              size: isTall ? 22 : 18,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            settings.appName,
            style: TextStyle(
              fontSize: isTall ? 20 : 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: primary,
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

  Widget _buildIllustrationPanel(BuildContext context) {
    final settings = ref.watch(systemSettingsProvider).valueOrNull ??
        const SystemSettings();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Image.asset(
              settings.logoAssetPath,
              fit: BoxFit.contain,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.transparent,
                child: const Center(
                  child: Icon(Icons.medical_services_outlined, size: 80),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuthForm(BuildContext context, {bool isTall = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final fieldBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final settings = ref.watch(systemSettingsProvider).valueOrNull ??
        const SystemSettings();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Brand logo and title matching the reference
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isTall ? 40 : 34,
              height: isTall ? 40 : 34,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.local_hospital,
                color: Colors.white,
                size: isTall ? 24 : 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.appName,
                  style:
                      (isTall
                              ? theme.textTheme.headlineSmall
                              : theme.textTheme.titleLarge)
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: primary,
                          ),
                ),
                Text(
                  settings.organizationName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: isTall ? 24 : 16),

        // Welcome Back
        Text(
          _sessionLocked ? 'Screen Locked' : 'Welcome Back',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: isTall ? 28 : 23,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _sessionLocked
              ? (_isPinLogin
                    ? 'Enter your 4-digit PIN to unlock.'
                    : 'Enter your password to unlock this session.')
              : 'Sign in to continue',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: isTall ? 22 : 16),

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

        // Input fields with soft filled styling matching the reference image
        if (!_isPinLogin) ...[
          if (!_sessionLocked) ...[
            TextField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'name@rhu.gov.ph',
                prefixIcon: const Icon(
                  Icons.medical_services_outlined,
                  size: 20,
                ),
                filled: true,
                fillColor: fieldBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: primary, width: 1.6),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _submitFromEmailField(),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
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
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: primary, width: 1.6),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitLogin(),
          ),
          if (_sessionLocked && !_pinLoginAvailable) ...[
            const SizedBox(height: 8),
            Text(
              'Tip: Enable a PIN in Settings for faster unlock next time.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ] else ...[
          TextField(
            controller: _pinController,
            focusNode: _pinFocusNode,
            decoration: InputDecoration(
              labelText: '4-digit PIN',
              hintText: 'Enter your PIN',
              prefixIcon: const Icon(Icons.pin_outlined, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePin
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
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
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: primary, width: 1.6),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: _obscurePin,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitLogin(),
          ),
        ],

        const SizedBox(height: 8),

        // Remember Me ! & Need Help? row (matching reference)
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
                    onChanged: (val) {
                      setState(() {
                        _rememberMe = val ?? false;
                      });
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Remember Me !',
                  style: theme.textTheme.bodyMedium?.copyWith(
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
              color: theme.colorScheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: theme.colorScheme.error,
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
        ElevatedButton(
          onPressed: _isLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            minimumSize: Size.fromHeight(isTall ? 50 : 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  _sessionLocked
                      ? (_isPinLogin ? 'Unlock with PIN' : 'Unlock')
                      : (_isPinLogin ? 'Continue with PIN' : 'Sign In'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
        ),

        // Alternative Login Options
        if ((_isPinLogin || _sessionLocked) && _canCheckBiometrics ||
            _sessionLocked) ...[
          SizedBox(height: isTall ? 18 : 12),
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Alternative Login Options',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
          SizedBox(height: isTall ? 14 : 10),
          if (_canCheckBiometrics) ...[
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _loginWithBiometrics,
              icon: const Icon(Icons.fingerprint_rounded, size: 20),
              label: const Text('Use Biometrics / Windows Hello'),
              style: OutlinedButton.styleFrom(
                minimumSize: Size.fromHeight(isTall ? 46 : 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_sessionLocked)
            TextButton.icon(
              onPressed: _isLoading ? null : _switchUser,
              icon: const Icon(Icons.switch_account_outlined, size: 18),
              label: const Text('Sign in as a different user'),
            ),
        ],
      ],
    );
  }

  Widget _buildBottomBar(
    BuildContext context, {
    bool compact = false,
    double horizontalPadding = 48,
    bool isTall = false,
  }) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final settings = ref.watch(systemSettingsProvider).valueOrNull ??
        const SystemSettings();

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
