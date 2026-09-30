abstract class PwaInstaller {
  /// Whether PWA features are supported on this platform.
  bool get isSupported;

  /// Whether the app is already running as an installed standalone PWA.
  bool get isInstalled;

  /// Whether an installation prompt is available right now.
  bool get canInstall;

  /// Triggers the browser's native install prompt.
  Future<bool> promptInstall();

  /// Stream of changes to installability (e.g. when beforeinstallprompt fires).
  Stream<bool> get onInstallableChanged;
}
