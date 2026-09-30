import 'dart:async';
import 'pwa_installer_interface.dart';

class IoPwaInstaller implements PwaInstaller {
  @override
  bool get isSupported => false;

  @override
  bool get isInstalled => true; // Native desktop is already installed

  @override
  bool get canInstall => false;

  @override
  Future<bool> promptInstall() async => false;

  @override
  Stream<bool> get onInstallableChanged => const Stream.empty();
}

PwaInstaller createPwaInstaller() => IoPwaInstaller();
