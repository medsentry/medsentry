import 'dart:async';
import 'dart:js_interop';

import 'pwa_installer_interface.dart';

@JS('installMedSentryPwa')
external JSPromise<JSBoolean>? _jsInstallMedSentryPwa();

@JS('pwaCanInstall')
external JSBoolean? get _jsPwaCanInstall;

@JS('isPwaInstalled')
external JSBoolean? _jsIsPwaInstalled();

@JS('hideMedSentryLoader')
external void _jsHideMedSentryLoader();

class WebPwaInstaller implements PwaInstaller {
  final _controller = StreamController<bool>.broadcast();
  bool _lastCanInstall = false;

  WebPwaInstaller() {
    try {
      _jsHideMedSentryLoader();
    } catch (_) {}

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_controller.isClosed) {
        timer.cancel();
        return;
      }
      final current = canInstall;
      if (current != _lastCanInstall) {
        _lastCanInstall = current;
        _controller.add(current);
      }
    });
  }

  @override
  bool get isSupported => true;

  @override
  bool get isInstalled {
    try {
      return _jsIsPwaInstalled()?.toDart == true;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get canInstall {
    try {
      return _jsPwaCanInstall?.toDart == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> promptInstall() async {
    try {
      final promise = _jsInstallMedSentryPwa();
      if (promise == null) return false;
      final jsBool = await promise.toDart;
      final outcome = jsBool.toDart;
      _controller.add(false);
      return outcome;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<bool> get onInstallableChanged => _controller.stream;
}

PwaInstaller createPwaInstaller() => WebPwaInstaller();
