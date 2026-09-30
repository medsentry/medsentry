import 'package:local_auth/local_auth.dart';
import 'biometric_auth_interface.dart';

class IoBiometricAuthService implements BiometricAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<bool> canCheckBiometrics() async {
    try {
      final canAuthBiometrics = await _auth.canCheckBiometrics;
      final canAuth = canAuthBiometrics || await _auth.isDeviceSupported();
      return canAuth;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

BiometricAuthService createBiometricAuthService() => IoBiometricAuthService();
