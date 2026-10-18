import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/models/login_challenge.dart';
import 'package:medsentry/src/models/user.dart';
import 'package:medsentry/src/providers/theme_provider.dart';
import 'package:medsentry/src/widgets/otp_verification_panel.dart';

void main() {
  Widget buildTestPanel({
    required OtpChallenge challenge,
    Future<OtpVerifyResult> Function(OtpChallenge, String)? onVerify,
    Future<LoginResult> Function(OtpChallenge)? onResend,
    ValueChanged<User>? onVerified,
    void Function({String? message})? onCancel,
  }) {
    return MaterialApp(
      theme: buildMedSentryTheme(Brightness.light),
      darkTheme: buildMedSentryTheme(Brightness.dark),
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: OtpVerificationPanel(
                challenge: challenge,
                onVerify:
                    onVerify ??
                    (_, _) async => const OtpRejected('Invalid code'),
                onResend:
                    onResend ??
                    (_) async => const LoginFailure('Not implemented'),
                onVerified: onVerified ?? (_) {},
                onCancel: onCancel ?? ({message}) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  final testUser = User(
    id: 'user-1',
    email: 'staff.nurse@rhu.gov.ph',
    firstName: 'Maria',
    lastName: 'Santos',
    role: UserRole.staff,
    isActive: true,
    pinEnabled: false,
  );

  group('OtpVerificationPanel Widget Tests', () {
    testWidgets('renders header, masked email and countdown correctly', (
      tester,
    ) async {
      final maskedEmail = OtpChallenge.maskEmail('staff.nurse@rhu.gov.ph');
      final challenge = OtpChallenge(
        email: 'staff.nurse@rhu.gov.ph',
        maskedEmail: maskedEmail,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        resendAvailableAt: DateTime.now().add(const Duration(seconds: 45)),
      );

      await tester.pumpWidget(buildTestPanel(challenge: challenge));
      await tester.pump();

      expect(find.text('Check your email'), findsOneWidget);
      final richTextContent = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((richText) => richText.text.toPlainText())
          .join('\n');
      expect(richTextContent, contains(maskedEmail));
      expect(find.textContaining('Code expires in'), findsOneWidget);
      expect(find.text('Verify and sign in'), findsOneWidget);
      expect(find.text('Use a different account'), findsOneWidget);
      expect(find.textContaining('Resend in'), findsOneWidget);
    });

    testWidgets('verify button is disabled until the OTP is submitted', (
      tester,
    ) async {
      final challenge = OtpChallenge(
        email: 'staff.nurse@rhu.gov.ph',
        maskedEmail: OtpChallenge.maskEmail('staff.nurse@rhu.gov.ph'),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        resendAvailableAt: DateTime.now().add(const Duration(seconds: 60)),
      );

      await tester.pumpWidget(
        buildTestPanel(
          challenge: challenge,
          onVerify: (_, _) async {
            await Future<void>.delayed(const Duration(milliseconds: 250));
            return OtpVerified(testUser);
          },
        ),
      );
      await tester.pump();

      final verifyButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(verifyButton.onPressed, isNull);

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      await tester.enterText(textFieldFinder, '123456');
      await tester.pump();

      final verifyingButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(verifyingButton.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('successful OTP verification fires onVerified callback', (
      tester,
    ) async {
      User? verifiedUser;

      final challenge = OtpChallenge(
        email: 'staff.nurse@rhu.gov.ph',
        maskedEmail: 's*******@rhu.gov.ph',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        resendAvailableAt: DateTime.now().add(const Duration(seconds: 60)),
      );

      await tester.pumpWidget(
        buildTestPanel(
          challenge: challenge,
          onVerify: (c, code) async {
            if (code == '123456') {
              return OtpVerified(testUser);
            }
            return const OtpRejected('Incorrect code');
          },
          onVerified: (user) {
            verifiedUser = user;
          },
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(verifiedUser, isNotNull);
      expect(verifiedUser!.email, 'staff.nurse@rhu.gov.ph');
    });

    testWidgets('rejected OTP shows error feedback', (tester) async {
      final challenge = OtpChallenge(
        email: 'staff.nurse@rhu.gov.ph',
        maskedEmail: 's*******@rhu.gov.ph',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        resendAvailableAt: DateTime.now().add(const Duration(seconds: 60)),
      );

      await tester.pumpWidget(
        buildTestPanel(
          challenge: challenge,
          onVerify: (c, code) async => const OtpRejected(
            'Invalid verification code. 4 attempts remaining.',
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), '999999');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Invalid verification code. 4 attempts remaining.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('tapping cancel triggers onCancel callback', (tester) async {
      var cancelled = false;

      final challenge = OtpChallenge(
        email: 'staff.nurse@rhu.gov.ph',
        maskedEmail: 's*******@rhu.gov.ph',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        resendAvailableAt: DateTime.now().add(const Duration(seconds: 60)),
      );

      await tester.pumpWidget(
        buildTestPanel(
          challenge: challenge,
          onCancel: ({message}) {
            cancelled = true;
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Use a different account'));
      await tester.pump();

      expect(cancelled, isTrue);
    });

    testWidgets('resend button is enabled when cooldown has passed', (
      tester,
    ) async {
      var resendCalled = false;

      final challenge = OtpChallenge(
        email: 'staff.nurse@rhu.gov.ph',
        maskedEmail: 's*******@rhu.gov.ph',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        resendAvailableAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );

      await tester.pumpWidget(
        buildTestPanel(
          challenge: challenge,
          onResend: (c) async {
            resendCalled = true;
            return LoginOtpRequired(challenge);
          },
        ),
      );
      await tester.pump();

      expect(find.text('Resend code'), findsOneWidget);
      await tester.tap(find.text('Resend code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(resendCalled, isTrue);
    });
  });
}
