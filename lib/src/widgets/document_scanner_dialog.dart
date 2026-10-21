import 'dart:async';
import 'package:camera/camera.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_design_tokens.dart';
import '../services/document_service.dart';
import '../services/scanner/image_processing.dart';
import '../services/scanner/scanner_service.dart';

/// Interactive modal for scanning physical documents using WIA flatbed/ADF
/// scanners or live webcam capture, with multi-page management, crop, rotation,
/// and enhancement filters.
class DocumentScannerDialog extends StatefulWidget {
  const DocumentScannerDialog({super.key});

  static Future<DocumentPickerResult?> show(BuildContext context) {
    return showDialog<DocumentPickerResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const DocumentScannerDialog(),
    );
  }

  @override
  State<DocumentScannerDialog> createState() => _DocumentScannerDialogState();
}

class _DocumentScannerDialogState extends State<DocumentScannerDialog> {
  final ScannerService _scannerService = createScannerService();
  final CropController _cropController = CropController();

  final List<Uint8List> _pages = [];
  final List<ScanFilter> _filters = [];
  int _selectedIndex = 0;

  bool _isScanning = false;
  bool _isProcessing = false;
  bool _isCropping = false;
  String? _statusMessage;
  String? _errorMessage;

  // Camera capture state
  List<CameraDescription> _availableCameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraMode = false;
  bool _isInitializingCamera = false;

  /// Phones and narrow windows: the layout stacks instead of using a sidebar.
  bool _compact = false;

  bool get _canScanHardware => _scannerService.isSupported;

  @override
  void initState() {
    super.initState();
    _initCameras();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCameras() async {
    try {
      _availableCameras = await availableCameras();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('No cameras found or camera initialization error: $e');
    }
  }

  Future<void> _startCamera() async {
    if (_availableCameras.isEmpty) {
      setState(
        () => _errorMessage = 'No camera or webcam detected on this device.',
      );
      return;
    }

    setState(() {
      _isCameraMode = true;
      _isInitializingCamera = true;
      _errorMessage = null;
    });

    try {
      await _cameraController?.dispose();
      final camera = _availableCameras[_selectedCameraIndex];
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _isInitializingCamera = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraMode = false;
          _isInitializingCamera = false;
          _errorMessage = 'Failed to open camera: $e';
        });
      }
    }
  }

  Future<void> _stopCamera() async {
    await _cameraController?.dispose();
    _cameraController = null;
    if (mounted) {
      setState(() {
        _isCameraMode = false;
        _isInitializingCamera = false;
      });
    }
  }

  Future<void> _captureFromCamera() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Capturing document photo...';
    });

    try {
      final photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      final normalized = await ImageProcessing.normalize(bytes);

      if (mounted) {
        setState(() {
          _pages.add(normalized);
          _filters.add(ScanFilter.enhanced);
          _selectedIndex = _pages.length - 1;
          _isCameraMode = false;
          _errorMessage = null;
        });
      }
      await _stopCamera();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to capture photo: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _scanFromHardware() async {
    if (_isCameraMode) {
      await _stopCamera();
    }

    setState(() {
      _isScanning = true;
      _statusMessage = 'Acquiring page from scanner...';
      _errorMessage = null;
    });

    try {
      final raw = await _scannerService.scanPage();
      if (raw == null) {
        // User cancelled in scanner UI
        return;
      }

      setState(() => _statusMessage = 'Processing scanned page...');
      final normalized = await ImageProcessing.normalize(raw);

      if (mounted) {
        setState(() {
          _pages.add(normalized);
          _filters.add(ScanFilter.enhanced);
          _selectedIndex = _pages.length - 1;
        });
      }
    } on ScannerException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Scanner error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _importImageFile() async {
    if (_isCameraMode) {
      await _stopCamera();
    }

    try {
      final picked = await DocumentService.pickImage();
      if (picked == null) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Importing image...';
      });

      final bytes = await picked.getBytes();
      final normalized = await ImageProcessing.normalize(
        Uint8List.fromList(bytes),
      );

      if (mounted) {
        setState(() {
          _pages.add(normalized);
          _filters.add(ScanFilter.original);
          _selectedIndex = _pages.length - 1;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to import image: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _rotateCurrentPage({required bool clockwise}) async {
    if (_pages.isEmpty || _isCropping || _selectedIndex >= _pages.length) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Rotating page...';
    });

    try {
      final current = _pages[_selectedIndex];
      final rotated = await ImageProcessing.rotate(
        current,
        clockwise: clockwise,
      );
      if (mounted) {
        setState(() {
          _pages[_selectedIndex] = rotated;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to rotate: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
      }
    }
  }

  void _startCrop() {
    if (_pages.isEmpty || _selectedIndex >= _pages.length) return;
    setState(() {
      _isCropping = true;
      _errorMessage = null;
    });
  }

  void _cancelCrop() {
    setState(() => _isCropping = false);
  }

  void _applyCrop() {
    if (!_isCropping) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Applying crop...';
    });
    _cropController.crop();
  }

  Future<void> _onCropped(CropResult result) async {
    try {
      switch (result) {
        case CropSuccess(:final croppedImage):
          final normalized = await ImageProcessing.normalize(croppedImage);
          if (mounted) {
            setState(() {
              _pages[_selectedIndex] = normalized;
              _isCropping = false;
            });
          }
        case CropFailure(:final cause):
          if (mounted) {
            setState(() {
              _errorMessage = 'Crop failed: $cause';
              _isCropping = false;
            });
          }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error processing cropped image: $e';
          _isCropping = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _finishAndAttach() async {
    if (_pages.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Generating scanned document...';
      _errorMessage = null;
    });

    try {
      final output = await ImageProcessing.export(_pages, _filters);
      final dateStr = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final filename = 'Scan_$dateStr.${output.extension}';

      final pickerResult = DocumentPickerResult.fromBytes(
        name: filename,
        bytes: output.bytes,
        extension: output.extension,
      );

      if (mounted) {
        Navigator.of(context).pop(pickerResult);
      }
    } on ScanTooLargeException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to export scan: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    _compact = MediaQuery.sizeOf(context).width < 720;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: _compact
          ? const EdgeInsets.all(8)
          : const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 1060,
        height: 740,
        decoration: BoxDecoration(
          color: isDark ? AppColors.modalSurface : AppColors.lightModalSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.border : AppColors.lightBorder,
            width: AppColors.borderWidth,
          ),
          boxShadow: AppShadows.overlay,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildHeader(isDark),
            if (_errorMessage != null) _buildErrorBanner(),
            if (_compact) ...[
              _buildCompactCaptureBar(isDark),
              if (_pages.isNotEmpty && !_isCameraMode) _buildPageStrip(isDark),
              Divider(
                height: 1,
                thickness: 1,
                color: isDark
                    ? AppColors.borderSubtle
                    : AppColors.lightBorderSubtle,
              ),
              Expanded(child: _buildMainArea(isDark)),
            ] else
              Expanded(
                child: Row(
                  children: [
                    _buildSidebar(isDark),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: isDark
                          ? AppColors.borderSubtle
                          : AppColors.lightBorderSubtle,
                    ),
                    Expanded(child: _buildMainArea(isDark)),
                  ],
                ),
              ),
            _buildFooter(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.sidebarBackground
            : AppColors.lightElevatedSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.borderSubtle
                : AppColors.lightBorderSubtle,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryEmeraldSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryEmerald.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(
              Icons.document_scanner_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan Document to Attach',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.lightTextPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Scan via flatbed/sheet scanner or webcam, enhance, crop, and attach as encrypted PDF',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Close scanner',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 16,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            onPressed: () => setState(() => _errorMessage = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// Scanner, camera and import buttons. The scanner button only appears where
  /// a scanner can be driven (Windows desktop); elsewhere the camera leads.
  List<Widget> _buildCaptureButtons({bool compact = false}) {
    final busy = _isScanning || _isProcessing;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    final padding = EdgeInsets.symmetric(
      vertical: compact ? 8 : 11,
      horizontal: compact ? 8 : 16,
    );
    final cameraLabel = _isCameraMode
        ? (compact ? 'Close' : 'Close Camera')
        : (compact
              ? 'Camera'
              : (_canScanHardware ? 'Use Webcam' : 'Use Camera'));
    final cameraIcon = Icon(
      _isCameraMode ? Icons.videocam_off_outlined : Icons.photo_camera_outlined,
      size: 18,
    );
    final onCamera = busy ? null : (_isCameraMode ? _stopCamera : _startCamera);

    return [
      if (_canScanHardware)
        FilledButton.icon(
          onPressed: busy ? null : _scanFromHardware,
          icon: _isScanning
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.scanner_outlined, size: 18),
          label: Text(
            _isScanning
                ? 'Scanning...'
                : (compact ? 'Scan' : 'Scan Page (WIA)'),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryEmeraldDark,
            foregroundColor: Colors.white,
            padding: padding,
            shape: shape,
          ),
        ),
      if (_canScanHardware)
        OutlinedButton.icon(
          onPressed: onCamera,
          icon: cameraIcon,
          label: Text(cameraLabel),
          style: OutlinedButton.styleFrom(padding: padding, shape: shape),
        )
      else
        FilledButton.icon(
          onPressed: onCamera,
          icon: cameraIcon,
          label: Text(cameraLabel),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryEmeraldDark,
            foregroundColor: Colors.white,
            padding: padding,
            shape: shape,
          ),
        ),
      if (compact)
        OutlinedButton.icon(
          onPressed: busy ? null : _importImageFile,
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: const Text('Import'),
          style: OutlinedButton.styleFrom(padding: padding, shape: shape),
        )
      else
        TextButton.icon(
          onPressed: busy ? null : _importImageFile,
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 17),
          label: const Text(
            'Import Image File',
            style: TextStyle(fontSize: 12.5),
          ),
        ),
    ];
  }

  /// Narrow screens: capture buttons in one row above the preview.
  Widget _buildCompactCaptureBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: isDark
          ? AppColors.cardSurface
          : AppColors.lightElevatedSurface.withValues(alpha: 0.5),
      child: Row(
        children: [
          for (final (i, button) in _buildCaptureButtons(
            compact: true,
          ).indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: button),
          ],
        ],
      ),
    );
  }

  /// Narrow screens: scanned pages as a horizontal strip of thumbnails.
  Widget _buildPageStrip(bool isDark) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        itemCount: _pages.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _selectedIndex == index && !_isCameraMode;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                onTap: () {
                  if (_isCameraMode) _stopCamera();
                  setState(() {
                    _selectedIndex = index;
                    _isCropping = false;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryEmerald
                          : (isDark ? AppColors.border : AppColors.lightBorder),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(_pages[index], fit: BoxFit.cover),
                ),
              ),
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _removePage(int index) {
    setState(() {
      _pages.removeAt(index);
      _filters.removeAt(index);
      if (_selectedIndex >= _pages.length) {
        _selectedIndex = _pages.isNotEmpty ? _pages.length - 1 : 0;
      }
      _isCropping = false;
    });
  }

  Widget _buildSidebar(bool isDark) {
    return Container(
      width: 250,
      color: isDark
          ? AppColors.cardSurface
          : AppColors.lightElevatedSurface.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, button) in _buildCaptureButtons().indexed) ...[
                  if (i > 0) const SizedBox(height: 8),
                  button,
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PAGES (${_pages.length})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark
                        ? AppColors.textMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
                if (_pages.length > 1)
                  Text(
                    'Multi-page PDF',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _pages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _canScanHardware
                            ? 'No pages scanned yet.\nClick "Scan Page" or "Use Webcam" to add.'
                            : 'No pages yet.\nUse the camera or import an image to add.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.lightTextMuted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    itemCount: _pages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final isSelected =
                          _selectedIndex == index && !_isCameraMode;
                      return InkWell(
                        onTap: () {
                          if (_isCameraMode) _stopCamera();
                          setState(() {
                            _selectedIndex = index;
                            _isCropping = false;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                      ? AppColors.primaryEmerald.withValues(
                                          alpha: 0.15,
                                        )
                                      : AppColors.primaryEmerald.withValues(
                                          alpha: 0.1,
                                        ))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryEmerald
                                  : (isDark
                                        ? AppColors.border
                                        : AppColors.lightBorder),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.memory(
                                  _pages[index],
                                  width: 44,
                                  height: 58,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Page ${index + 1}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isDark
                                            ? AppColors.textPrimary
                                            : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _filters[index].label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.textSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                                color: Theme.of(context).colorScheme.error,
                                tooltip: 'Remove page',
                                onPressed: () => _removePage(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainArea(bool isDark) {
    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryEmerald,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage ?? 'Processing...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
      );
    }

    if (_isCameraMode) {
      return _buildCameraArea(isDark);
    }

    if (_pages.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.scanner_outlined,
                size: 64,
                color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
              ),
              const SizedBox(height: 16),
              Text(
                'No Pages Captured',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _canScanHardware
                    ? 'Connect a document scanner or turn on your webcam to begin scanning.'
                    : 'Turn on your camera or import an image to begin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              // On narrow screens the capture bar above already has these.
              if (!_compact) ...[
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (_canScanHardware)
                      FilledButton.icon(
                        onPressed: _scanFromHardware,
                        icon: const Icon(Icons.scanner_outlined, size: 18),
                        label: const Text('Scan with Scanner'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryEmeraldDark,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    if (_canScanHardware)
                      OutlinedButton.icon(
                        onPressed: _startCamera,
                        icon: const Icon(Icons.videocam_outlined, size: 18),
                        label: const Text('Open Webcam'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _startCamera,
                        icon: const Icon(Icons.videocam_outlined, size: 18),
                        label: const Text('Open Camera'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryEmeraldDark,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildEditorToolbar(isDark),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _isCropping
                ? Crop(
                    image: _pages[_selectedIndex],
                    controller: _cropController,
                    onCropped: _onCropped,
                    baseColor: isDark
                        ? AppColors.modalSurface
                        : AppColors.lightModalSurface,
                    maskColor: Colors.black.withValues(alpha: 0.6),
                    radius: 8,
                    interactive: true,
                  )
                : FutureBuilder<Uint8List>(
                    future: ImageProcessing.render(
                      _pages[_selectedIndex],
                      _filters[_selectedIndex],
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      return InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 3.0,
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Image.memory(
                              snapshot.data!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraArea(bool isDark) {
    if (_isInitializingCamera) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(height: 14),
            Text('Initializing camera...'),
          ],
        ),
      );
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            const Text('Camera unavailable'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _startCamera,
              child: const Text('Retry Camera'),
            ),
          ],
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          color: Colors.black,
          width: double.infinity,
          height: double.infinity,
          child: Center(child: CameraPreview(controller)),
        ),
        // Document guide overlay box
        Positioned(
          top: 36,
          bottom: 100,
          left: 48,
          right: 48,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.primaryEmerald.withValues(alpha: 0.7),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // Bottom controls
        Positioned(
          bottom: 24,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_availableCameras.length > 1) ...[
                IconButton.filledTonal(
                  icon: const Icon(Icons.switch_camera_outlined),
                  tooltip: 'Switch camera',
                  onPressed: () {
                    _selectedCameraIndex =
                        (_selectedCameraIndex + 1) % _availableCameras.length;
                    _startCamera();
                  },
                ),
                const SizedBox(width: 20),
              ],
              FilledButton.icon(
                onPressed: _captureFromCamera,
                icon: const Icon(Icons.camera_alt, size: 20),
                label: const Text(
                  'Capture Document',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryEmeraldDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              IconButton.filledTonal(
                icon: const Icon(Icons.close),
                tooltip: 'Exit camera',
                onPressed: _stopCamera,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditorToolbar(bool isDark) {
    if (_pages.isEmpty || _selectedIndex >= _pages.length) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[
      Text(
        'Page ${_selectedIndex + 1} of ${_pages.length}',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      if (!_compact) const SizedBox(width: 16),
      if (!_isCropping) ...[
        if (_compact)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: Theme.of(context).colorScheme.error,
            tooltip: 'Remove page',
            onPressed: () => _removePage(_selectedIndex),
          ),
        IconButton(
          icon: const Icon(Icons.rotate_left_outlined, size: 20),
          tooltip: 'Rotate 90° Left',
          onPressed: () => _rotateCurrentPage(clockwise: false),
        ),
        IconButton(
          icon: const Icon(Icons.rotate_right_outlined, size: 20),
          tooltip: 'Rotate 90° Right',
          onPressed: () => _rotateCurrentPage(clockwise: true),
        ),
        IconButton(
          icon: const Icon(Icons.crop, size: 20),
          tooltip: 'Crop page',
          onPressed: _startCrop,
        ),
        if (!_compact) const Spacer(),
        const Text('Filter: ', style: TextStyle(fontSize: 12.5)),
        const SizedBox(width: 6),
        SegmentedButton<ScanFilter>(
          segments: ScanFilter.values
              .map(
                (f) => ButtonSegment(
                  value: f,
                  label: Text(f.label, style: const TextStyle(fontSize: 11.5)),
                ),
              )
              .toList(),
          selected: {_filters[_selectedIndex]},
          onSelectionChanged: (set) {
            setState(() {
              _filters[_selectedIndex] = set.first;
            });
          },
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.primaryEmeraldSubtle,
            selectedForegroundColor: AppColors.primaryEmerald,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ] else ...[
        const Text(
          'Drag the corners to adjust crop area',
          style: TextStyle(fontSize: 12, color: AppColors.primaryEmerald),
        ),
        if (!_compact) const Spacer(),
        TextButton(onPressed: _cancelCrop, child: const Text('Cancel Crop')),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _applyCrop,
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Apply Crop'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryEmeraldDark,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark
          ? AppColors.sidebarBackground
          : AppColors.lightElevatedSurface,
      child: _compact
          ? Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: children,
            )
          : Row(children: children),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.sidebarBackground
            : AppColors.lightElevatedSurface,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.borderSubtle
                : AppColors.lightBorderSubtle,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_pages.isNotEmpty)
            Text(
              '${_pages.length} page${_pages.length == 1 ? '' : 's'} scanned • '
              '${_pages.length == 1 ? 'Single Page JPEG' : 'Multi-Page PDF'}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          const Spacer(),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: (_pages.isEmpty || _isProcessing || _isScanning)
                ? null
                : _finishAndAttach,
            icon: const Icon(Icons.attach_file, size: 18),
            label: Text(
              _pages.length <= 1
                  ? 'Attach Scanned Document'
                  : 'Attach ${_pages.length} Pages (PDF)',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryEmeraldDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
