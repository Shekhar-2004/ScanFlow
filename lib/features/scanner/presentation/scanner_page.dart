import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/document_session.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool _isFlashOn = false;
  bool _isProcessing = false;
  CameraController? _cameraController;
  Future<void>? _cameraInitFuture;
  List<CameraDescription> _cameras = const [];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        return;
      }

      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to use the in-app camera.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final camera = _cameras.first;
      _cameraController = CameraController(camera, ResolutionPreset.high, enableAudio: false);
      _cameraInitFuture = _cameraController!.initialize();
      await _cameraInitFuture;
      await _cameraController!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start the camera preview: $error')),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isProcessing) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      if (source == ImageSource.camera) {
        if (_cameraController == null || !(_cameraController!.value.isInitialized)) {
          await _initCamera();
        }

        if (_cameraController == null || !(_cameraController!.value.isInitialized)) {
          return;
        }

        final photo = await _cameraController!.takePicture();
        final savedPath = await _copyToDocuments(photo.path);
        _storePage(savedPath, 'Photo captured in-app.');
        return;
      }

      final permission = await Permission.photos.request();
      if (!permission.isGranted) {
        final storagePermission = await Permission.storage.request();
        if (!storagePermission.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gallery access is required to import existing images.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isEmpty) {
        return;
      }

      for (final pickedFile in pickedFiles) {
        final savedPath = await _copyToDocuments(pickedFile.path);
        DocumentSession.instance.addPage(savedPath);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${pickedFiles.length} photo${pickedFiles.length > 1 ? 's' : ''} imported from the gallery.'),
          backgroundColor: Colors.green,
        ),
      );

      context.push(AppConstants.routeEditor, extra: DocumentSession.instance.pages);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<String> _copyToDocuments(String sourcePath) async {
    Directory rootDir = await getApplicationDocumentsDirectory();

    final scanDir = Directory('${rootDir.path}${Platform.pathSeparator}ScanFirst');
    if (!await scanDir.exists()) {
      await scanDir.create(recursive: true);
    }

    final uniqueId = '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(100000)}';
    final fileName = 'scan_$uniqueId${sourcePath.toLowerCase().endsWith('.png') ? '.png' : '.jpg'}';
    final destination = File('${scanDir.path}/$fileName');
    await File(sourcePath).copy(destination.path);
    return destination.path;
  }

  void _storePage(String path, String message) {
    DocumentSession.instance.addPage(path);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );

    context.push(AppConstants.routeEditor, extra: DocumentSession.instance.pages);
  }

  Future<void> _toggleFlash() async {
    setState(() => _isFlashOn = !_isFlashOn);

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      await _cameraController!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFlashOn ? 'Flash enabled' : 'Flash disabled'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pageCount = DocumentSession.instance.pages.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Scan Document'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Preview Frame with Radius 24
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.only(bottom: 120), // Leave space for controls
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: _cameraController != null && _cameraController!.value.isInitialized
                      ? CameraPreview(_cameraController!)
                      : Container(
                          color: Colors.grey[900],
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  size: 80,
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: AppConstants.spacingM),
                                Text(
                                  'In-app camera preview is ready once permissions are granted.',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppConstants.spacingS),
                                Text(
                                  pageCount > 0
                                      ? '$pageCount page${pageCount == 1 ? '' : 's'} ready for the PDF'
                                      : 'No pages yet. Capture the first page to start.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
            
            // Bottom Controls (Symmetrical three-column)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 120,
              child: Container(
                color: Colors.black,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Flash (Left)
                    Expanded(
                      child: Center(
                        child: IconButton(
                          icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white, size: 28),
                          onPressed: _toggleFlash,
                        ),
                      ),
                    ),
                    
                    // Capture (Center)
                    Expanded(
                      child: Center(
                        child: _AnimatedCaptureButton(
                          onPressed: _isProcessing ? () {} : () => _pickImage(ImageSource.camera),
                        ),
                      ),
                    ),
                    
                    // Gallery (Right)
                    Expanded(
                      child: Center(
                        child: IconButton(
                          icon: const Icon(Icons.photo_library, color: Colors.white, size: 28),
                          tooltip: 'Choose from Gallery',
                          onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedCaptureButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _AnimatedCaptureButton({required this.onPressed});

  @override
  State<_AnimatedCaptureButton> createState() => _AnimatedCaptureButtonState();
}

class _AnimatedCaptureButtonState extends State<_AnimatedCaptureButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.mediumImpact();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
            width: _isPressed ? 50 : 60,
            height: _isPressed ? 50 : 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
