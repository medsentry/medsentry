abstract class BiometricAuthService {
  Future<bool> canCheckBiometrics();
  Future<bool> authenticate({required String reason});
}
