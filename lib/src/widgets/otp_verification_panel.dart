import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_design_tokens.dart';
import '../models/login_challenge.dart';
import '../models/user.dart';

/// Inline "check your email" panel shown in place of the login form while a
/// one-time code is pending. Styled for the light login card.
class OtpVerificationPanel extends StatefulWidget {
  final OtpChallenge challenge;
  final Future<OtpVerifyResult> Function(OtpChallenge challenge, String code)
  onVerify;
  final Future<LoginResult> Function(OtpChallenge challenge) onResend;
  final ValueChanged<User> onVerified;

  /// Called when the user backs out, or when the challenge is exhausted.
  final void Function({String? message}) onCancel;

  const OtpVerificationPanel({
    super.key,
    required this.challenge,
    required this.onVerify,
    required this.onResend,
    required this.onVerified,
    required this.onCancel,
  });

  @override
  State<OtpVerificationPanel> createState() => _OtpVerificationPanelState();
}

class _OtpVerificationPanelState extends State<OtpVerificationPanel>
    with SingleTickerProviderStateMixin {
  static const Color _ink = AppColors.lightTextPrimary;
  static const Color _muted = AppColors.lightTextSecondary;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late OtpChallenge _challenge = widget.challenge;
  Timer? _ticker;
  bool _verifying = false;
  bool _resending = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _shake.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (_verifying || code.length != kOtpLength) return;
    setState(() {
      _verifying = true;
      _error = null;
      _info = null;
    });

    final result = await widget.onVerify(_challenge, code);
    if (!mounted) return;

    switch (result) {
      case OtpVerified(:final user):
        widget.onVerified(user);
      case OtpRejected(:final message, :final challenge, :final exhausted):
        if (exhausted) {
          widget.onCancel(message: message);
          return;
        }
        _controller.clear();
        setState(() {
          _verifying = false;
          _error = message;
          if (challenge != null) _challenge = challenge;
        });
        _shake.forward(from: 0);
        _focusNode.requestFocus();
    }
  }

  Future<void> _resend() async {
    if (_resending || _challenge.resendWait > Duration.zero) return;
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    final result = await widget.onResend(_challenge);
    if (!mounted) return;
    switch (result) {
      case LoginOtpRequired(:final challenge):
        _controller.clear();
        setState(() {
          _challenge = challenge;
          _info = 'A new code was sent to ${challenge.maskedEmail}.';
        });
      case LoginFailure(:final message):
        setState(() => _error = message);
      case LoginSuccess():
        break;
    }
    setState(() => _resending = false);
    _focusNode.requestFocus();
  }

  String _formatRemaining(Duration d) {
    final seconds = d.inSeconds < 0 ? 0 : d.inSeconds;
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primaryEmeraldDark;
    final remaining = _challenge.expiresAt.difference(DateTime.now());
    final expired = remaining.isNegative || remaining == Duration.zero;
    final resendWait = _challenge.resendWait;
    final code = _controller.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.mark_email_read_outlined,
              color: primary,
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Check your email',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: const TextStyle(color: _muted, height: 1.45, fontSize: 14),
            children: [
              const TextSpan(text: 'We sent a $kOtpLength-digit code to '),
              TextSpan(
                text: _challenge.maskedEmail,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(text: '. Enter it below to finish signing in.'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final dx =
                math.sin(_shake.value * math.pi * 6) * (1 - _shake.value) * 10;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: _CodeBoxes(
            controller: _controller,
            focusNode: _focusNode,
            enabled: !_verifying,
            hasError: _error != null,
            accent: primary,
            onChanged: (value) {
              setState(() => _error = null);
              if (value.length == kOtpLength) _submit();
            },
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _error != null
              ? _StatusLine(
                  key: ValueKey(_error),
                  icon: Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                  text: _error!,
                )
              : _info != null
              ? _StatusLine(
                  key: ValueKey(_info),
                  icon: Icons.check_circle_outline,
                  color: primary,
                  text: _info!,
                )
              : _StatusLine(
                  key: ValueKey(expired),
                  icon: Icons.schedule,
                  color: expired ? Theme.of(context).colorScheme.error : _muted,
                  text: expired
                      ? 'This code has expired. Request a new one.'
                      : 'Code expires in ${_formatRemaining(remaining)}',
                ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: (_verifying || code.length != kOtpLength || expired)
                ? null
                : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedSm),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            child: _verifying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text('Verify and sign in'),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final accountButton = TextButton.icon(
              onPressed: _verifying ? null : () => widget.onCancel(),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text(
                'Use a different account',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              style: TextButton.styleFrom(foregroundColor: _muted),
            );

            final resendButton = TextButton(
              onPressed:
                  (_resending || _verifying || resendWait > Duration.zero)
                  ? null
                  : _resend,
              style: TextButton.styleFrom(foregroundColor: primary),
              child: Text(
                resendWait > Duration.zero
                    ? 'Resend in ${resendWait.inSeconds}s'
                    : (_resending ? 'Sending...' : 'Resend code'),
              ),
            );

            if (constraints.maxWidth < 360) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  accountButton,
                  const SizedBox(height: 4),
                  resendButton,
                ],
              );
            }

            return Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [accountButton, resendButton],
            );
          },
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _StatusLine({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Six rounded boxes driven by a single invisible text field, so paste,
/// autofill, backspace and IME input all behave naturally.
class _CodeBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool hasError;
  final Color accent;
  final ValueChanged<String> onChanged;

  const _CodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hasError,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => focusNode.requestFocus(),
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([controller, focusNode]),
            builder: (context, _) {
              final text = controller.text;
              return Row(
                children: [
                  for (var i = 0; i < kOtpLength; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _Box(
                        char: i < text.length ? text[i] : '',
                        active:
                            focusNode.hasFocus &&
                            enabled &&
                            i == text.length.clamp(0, kOtpLength - 1),
                        hasError: hasError,
                        accent: accent,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          Positioned.fill(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: kOtpLength,
              showCursor: false,
              enableInteractiveSelection: false,
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
              cursorColor: Colors.transparent,
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  final String char;
  final bool active;
  final bool hasError;
  final Color accent;

  const _Box({
    required this.char,
    required this.active,
    required this.hasError,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? AppColors.critical
        : active
        ? accent
        : AppColors.lightBorderActive;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: char.isEmpty ? AppColors.lightAppBackground : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: active ? 2 : 1.2),
        boxShadow: active
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.14),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.lightTextPrimary,
        ),
      ),
    );
  }
}
