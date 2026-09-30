import 'biometric_auth_interface.dart';

class WebBiometricAuthService implements BiometricAuthService {
  @override
  Future<bool> canCheckBiometrics() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}

BiometricAuthService createBiometricAuthService() => WebBiometricAuthService();
