import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'scanner_service_interface.dart';

/// Windows scanner access through WIA (Windows Image Acquisition), which ships
/// with Windows and supports flatbed and sheet-fed scanners that expose a WIA
/// driver. A short PowerShell script opens the native scan dialog.
class _WiaScannerService implements ScannerService {
  static const Duration _timeout = Duration(minutes: 5);

  // WIA constants: ScannerDeviceType=1, ColorIntent=1, MaximizeQuality=131072,
  // JPEG format GUID. UseCommonUI shows the scanner's own preview dialog.
  static const String _script = r'''
$ErrorActionPreference = 'Stop'
try {
  $dialog = New-Object -ComObject WIA.CommonDialog
  $image = $dialog.ShowAcquireImage(1, 1, 131072, '{B96B3CAE-0728-11D3-9D7B-0000F81EF32E}', $false, $true, $false)
  if ($null -eq $image) { Write-Output 'CANCELLED'; exit 0 }
  $path = Join-Path $env:TEMP ('medsentry_scan_' + [guid]::NewGuid().ToString('N') + '.' + $image.FileExtension)
  $image.SaveFile($path)
  Write-Output ('OK:' + $path)
} catch {
  [Console]::Error.WriteLine($_.Exception.Message + ' [' + ('0x{0:X8}' -f $_.Exception.HResult) + ']')
  exit 1
}
''';

  @override
  bool get isSupported => Platform.isWindows;

  @override
  Future<Uint8List?> scanPage() async {
    if (!isSupported) {
      throw const ScannerException(
        'Scanner access is only available on Windows.',
      );
    }

    // -EncodedCommand avoids every quoting problem; -STA is required by WIA UI.
    final encoded = base64Encode(_utf16le(_script));
    final ProcessResult result;
    try {
      result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-STA',
        '-ExecutionPolicy',
        'Bypass',
        '-EncodedCommand',
        encoded,
      ]).timeout(_timeout);
    } on TimeoutException {
      throw const ScannerException('The scanner did not respond in time.');
    } on ProcessException {
      throw const ScannerException(
        'Windows PowerShell is required to use the scanner.',
      );
    }

    final out = '${result.stdout}'.trim();
    final err = '${result.stderr}'.trim();

    if (result.exitCode != 0) throw ScannerException(_friendly(err));
    if (out.contains('CANCELLED')) return null;

    final line = out.split(RegExp(r'[\r\n]+')).lastWhere(
      (l) => l.startsWith('OK:'),
      orElse: () => '',
    );
    if (line.isEmpty) {
      throw const ScannerException('The scanner returned no image.');
    }

    final file = File(line.substring(3).trim());
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const ScannerException('The scanned page was empty.');
      }
      return bytes;
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Temp file cleanup is best effort.
      }
    }
  }

  String _friendly(String raw) {
    final text = raw.toLowerCase();
    if (text.contains('0x80210015') ||
        text.contains('no wia device') ||
        text.contains('no scanner')) {
      return 'No scanner found. Check the USB cable, power and drivers, then try again.';
    }
    if (text.contains('0x80210006') || text.contains('busy')) {
      return 'The scanner is busy. Wait a moment and try again.';
    }
    if (text.contains('0x80210003') || text.contains('paper')) {
      return 'No paper detected. Load the document and try again.';
    }
    if (text.contains('0x80210005') || text.contains('offline')) {
      return 'The scanner is offline. Turn it on and check the connection.';
    }
    return raw.isEmpty
        ? 'Scanning failed. Please try again.'
        : 'Scanning failed: ${raw.split('\n').first}';
  }

  List<int> _utf16le(String value) {
    final bytes = <int>[];
    for (final unit in value.codeUnits) {
      bytes
        ..add(unit & 0xFF)
        ..add((unit >> 8) & 0xFF);
    }
    return bytes;
  }
}

ScannerService createScannerService() => _WiaScannerService();

