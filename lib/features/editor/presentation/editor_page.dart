import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/document_session.dart';
import '../../../core/utils/scanner_image_utils.dart';

List<Offset>? _isolateAutoCrop(Uint8List bytes) {
  var decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  decoded = img.bakeOrientation(decoded);
  final corners = ScannerImageUtils.detectDocumentCorners(decoded);
  if (corners == null || corners.length != 4) return null;

  return [
    Offset(corners[0].x / decoded.width, corners[0].y / decoded.height),
    Offset(corners[1].x / decoded.width, corners[1].y / decoded.height),
    Offset(corners[2].x / decoded.width, corners[2].y / decoded.height),
    Offset(corners[3].x / decoded.width, corners[3].y / decoded.height),
  ];
}

Uint8List? _isolateCropWarp(Map<String, dynamic> args) {
  final bytes = args['bytes'] as Uint8List;
  final pts = args['pts'] as List<Offset>;

  var decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  decoded = img.bakeOrientation(decoded);

  final tl = Point2D(pts[0].dx * decoded.width, pts[0].dy * decoded.height);
  final tr = Point2D(pts[1].dx * decoded.width, pts[1].dy * decoded.height);
  final br = Point2D(pts[2].dx * decoded.width, pts[2].dy * decoded.height);
  final bl = Point2D(pts[3].dx * decoded.width, pts[3].dy * decoded.height);

  final warped = ScannerImageUtils.perspectiveWarp(decoded, tl, tr, br, bl);
  return Uint8List.fromList(img.encodeJpg(warped, quality: 100));
}

Uint8List? _isolateApplyEdits(Map<String, dynamic> args) {
  final bytes = args['bytes'] as Uint8List;
  final angle = args['angle'] as double;
  final filter = args['filter'] as String;
  final intensity = args['intensity'] as double? ?? 1.0;

  var decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  if (angle > 0.0) {
    decoded = img.copyRotate(decoded, angle: angle.toInt());
  }

  if (filter == AppConstants.filterColorDocument) {
    decoded = ScannerImageUtils.applyColorDocumentFilter(decoded, intensity: intensity);
  } else if (filter == AppConstants.filterEnhancedColor) {
    decoded = ScannerImageUtils.applyEnhancedColorFilter(decoded, intensity: intensity);
  } else if (filter == AppConstants.filterGrayscale) {
    decoded = ScannerImageUtils.applyGrayscaleFilter(decoded, intensity: intensity);
  } else if (filter == AppConstants.filterHighContrast) {
    decoded = ScannerImageUtils.applyHighContrastFilter(decoded, intensity: intensity);
  } else if (filter == AppConstants.filterBlackAndWhite) {
    decoded = ScannerImageUtils.applyBlackAndWhiteFilter(decoded, intensity: intensity);
  }

  return Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
}

class EditorPage extends StatefulWidget {
  final List<String> imagePaths;

  const EditorPage({
    super.key,
    this.imagePaths = const <String>[],
  });

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  // Page-specific editing state
  final Map<int, List<Offset>> _cropPoints = {};
  final Map<int, String> _pageFilters = {};
  final Map<int, double> _pageFilterIntensities = {};
  final Map<int, double> _pageRotations = {};
  List<String> _originalPaths = [];
  List<String> _displayPaths = []; // Currently cropped preview images

  int _selectedPageIndex = 0;
  bool _isCropping = false;
  double? _dragIntensity;

  @override
  void initState() {
    super.initState();
    final pages = widget.imagePaths.isNotEmpty
        ? widget.imagePaths
        : DocumentSession.instance.pages;
    if (pages.isNotEmpty) {
      DocumentSession.instance.setPages(pages);
    }
    _originalPaths = List<String>.from(pages);
    _displayPaths = List<String>.from(pages);

    // Initialize crop points lazily for the first page
    if (_originalPaths.isNotEmpty) {
      _initCropPointsForPage(0);
    }
  }

  void _syncPages() {
    final sessionPages = DocumentSession.instance.pages;

    if (_originalPaths.length != sessionPages.length) {
      final newOriginals = <String>[];
      final newDisplays = <String>[];
      for (var i = 0; i < sessionPages.length; i++) {
        if (i < _originalPaths.length) {
          newOriginals.add(_originalPaths[i]);
          newDisplays.add(_displayPaths[i]);
        } else {
          newOriginals.add(sessionPages[i]);
          newDisplays.add(sessionPages[i]);
        }
      }
      setState(() {
        _originalPaths = newOriginals;
        _displayPaths = newDisplays;
      });
    }
  }

  Future<void> _initCropPointsForPage(int index) async {
    if (_cropPoints.containsKey(index)) return;

    final path = _originalPaths[index];
    final file = File(path);
    if (!await file.exists()) return;

    try {
      final bytes = await file.readAsBytes();
      var decoded = img.decodeImage(bytes);
      if (decoded == null) return;
      decoded = img.bakeOrientation(decoded);

      final corners = ScannerImageUtils.detectDocumentCorners(decoded);
      if (corners != null && corners.length == 4) {
        final tl = Offset(corners[0].x / decoded.width, corners[0].y / decoded.height);
        final tr = Offset(corners[1].x / decoded.width, corners[1].y / decoded.height);
        final br = Offset(corners[2].x / decoded.width, corners[2].y / decoded.height);
        final bl = Offset(corners[3].x / decoded.width, corners[3].y / decoded.height);

        setState(() {
          _cropPoints[index] = [tl, tr, br, bl];
        });
      } else {
        _setDefaultCropPoints(index);
      }
    } catch (e) {
      _setDefaultCropPoints(index);
    }
  }

  void _setDefaultCropPoints(int index) {
    setState(() {
      _cropPoints[index] = [
        const Offset(0.05, 0.05),
        const Offset(0.95, 0.05),
        const Offset(0.95, 0.95),
        const Offset(0.05, 0.95),
      ];
    });
  }

  void _rotateImage() {
    final currentAngle = _pageRotations[_selectedPageIndex] ?? 0.0;
    setState(() {
      _pageRotations[_selectedPageIndex] = (currentAngle + 90) % 360;
    });
  }

  Future<void> _autoCropCurrentPage() async {
    if (_originalPaths.isEmpty) return;

    final originalPath = _originalPaths[_selectedPageIndex];
    final file = File(originalPath);
    if (!await file.exists()) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final bytes = await file.readAsBytes();
      final corners = await compute(_isolateAutoCrop, bytes);
      
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // Close loading indicator
      }

      if (corners != null) {
        setState(() {
          _cropPoints[_selectedPageIndex] = corners;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document edges auto-detected!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw StateError("No clear document edges detected.");
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Edge detection failed: ${e.toString()}'),
          backgroundColor: Colors.orange,
        ),
      );
      // Reset to default
      _setDefaultCropPoints(_selectedPageIndex);
    }
  }

  void _resetCrop() {
    setState(() {
      _cropPoints[_selectedPageIndex] = [
        const Offset(0.0, 0.0),
        const Offset(1.0, 0.0),
        const Offset(1.0, 1.0),
        const Offset(0.0, 1.0),
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Crop area reset to full image.')),
    );
  }

  Future<void> _enterCroppingMode() async {
    await _initCropPointsForPage(_selectedPageIndex);
    setState(() {
      _isCropping = true;
    });
  }

  Future<void> _applyCropWarp() async {
    if (_originalPaths.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(AppConstants.spacingXL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: AppConstants.spacingL),
                Text('Applying crop and alignment...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final originalPath = _originalPaths[_selectedPageIndex];
      final file = File(originalPath);
      final bytes = await file.readAsBytes();
      final pts = _cropPoints[_selectedPageIndex] ?? [
        const Offset(0.0, 0.0),
        const Offset(1.0, 0.0),
        const Offset(1.0, 1.0),
        const Offset(0.0, 1.0),
      ];

      final warpedBytes = await compute(_isolateCropWarp, {
        'bytes': bytes,
        'pts': pts,
      });

      if (warpedBytes == null) throw StateError("Unable to decode or crop image");

      final tempDir = await getTemporaryDirectory();
      final outputFile = File(
        '${tempDir.path}/scanflow_cropped_${_selectedPageIndex}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await outputFile.writeAsBytes(warpedBytes);

      setState(() {
        _displayPaths[_selectedPageIndex] = outputFile.path;
        _isCropping = false;
      });

      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // Close dialog
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perspective crop applied successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Crop alignment failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addMorePages() {
    _syncPages();
    DocumentSession.instance.setPages(_displayPaths);
    context.push(AppConstants.routeScanner);
  }

  void _deleteCurrentPage() {
    if (_displayPaths.isEmpty) return;

    final index = _selectedPageIndex;

    if (_displayPaths.length == 1) {
      DocumentSession.instance.reset();
      context.go(AppConstants.routeHome);
      return;
    }

    setState(() {
      _displayPaths.removeAt(index);
      _originalPaths.removeAt(index);

      _reindexMap(_cropPoints, index);
      _reindexMap(_pageFilters, index);
      _reindexMap(_pageRotations, index);

      if (_selectedPageIndex >= _displayPaths.length) {
        _selectedPageIndex = _displayPaths.length - 1;
      }
    });

    DocumentSession.instance.setPages(_displayPaths);
  }

  void _reindexMap<T>(Map<int, T> map, int deletedIndex) {
    final newMap = <int, T>{};
    map.forEach((key, value) {
      if (key < deletedIndex) {
        newMap[key] = value;
      } else if (key > deletedIndex) {
        newMap[key - 1] = value;
      }
    });
    map.clear();
    map.addAll(newMap);
  }

  void _onReorderPages(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;

    setState(() {
      final displayPath = _displayPaths.removeAt(oldIndex);
      _displayPaths.insert(newIndex, displayPath);

      final originalPath = _originalPaths.removeAt(oldIndex);
      _originalPaths.insert(newIndex, originalPath);

      _reindexMapForReorder(_cropPoints, oldIndex, newIndex);
      _reindexMapForReorder(_pageFilters, oldIndex, newIndex);
      _reindexMapForReorder(_pageRotations, oldIndex, newIndex);

      if (_selectedPageIndex == oldIndex) {
        _selectedPageIndex = newIndex;
      } else if (_selectedPageIndex > oldIndex && _selectedPageIndex <= newIndex) {
        _selectedPageIndex -= 1;
      } else if (_selectedPageIndex < oldIndex && _selectedPageIndex >= newIndex) {
        _selectedPageIndex += 1;
      }
    });

    DocumentSession.instance.setPages(_displayPaths);
  }

  void _reindexMapForReorder<T>(Map<int, T> map, int oldIndex, int newIndex) {
    if (map.isEmpty) return;

    final newMap = <int, T>{};
    map.forEach((key, value) {
      if (key == oldIndex) {
        newMap[newIndex] = value;
      } else if (oldIndex < newIndex) {
        if (key > oldIndex && key <= newIndex) {
          newMap[key - 1] = value;
        } else {
          newMap[key] = value;
        }
      } else {
        if (key >= newIndex && key < oldIndex) {
          newMap[key + 1] = value;
        } else {
          newMap[key] = value;
        }
      }
    });
    map.clear();
    map.addAll(newMap);
  }

  Future<void> _applyEditsAndProceed() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(AppConstants.spacingXL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: AppConstants.spacingL),
                Text('Processing scan flow pages...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final processedPaths = <String>[];

      for (var i = 0; i < _originalPaths.length; i++) {
        // Read either the cropped image or the original image
        final sourcePath = _displayPaths[i];
        final file = File(sourcePath);
        if (!await file.exists()) {
          processedPaths.add(sourcePath);
          continue;
        }

        var bytes = await file.readAsBytes();
        final angle = _pageRotations[i] ?? 0.0;
        final filter = _pageFilters[i] ?? AppConstants.filterOriginal;

        // 1. Fast Native Scale, Rotate, and initial Compression
        var processedBytes = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 2400,
          minHeight: 2400,
          quality: filter == AppConstants.filterOriginal ? 85 : 100, 
          rotate: angle.toInt(),
        );

        // 2. Pure Dart Color Filtering (only if necessary)
        // Since the image is now max 2400px, this pure-Dart operation will be significantly faster.
        if (filter != AppConstants.filterOriginal) {
          final filteredBytes = await compute(_isolateApplyEdits, {
            'bytes': processedBytes,
            'angle': 0.0, // Already rotated natively!
            'filter': filter,
            'intensity': _pageFilterIntensities[i] ?? 1.0,
          });
          
          if (filteredBytes != null) {
            processedBytes = filteredBytes;
          }
        }

        final tempDir = await getTemporaryDirectory();
        final outputFile = File(
          '${tempDir.path}/scanflow_final_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await outputFile.writeAsBytes(processedBytes);
        processedPaths.add(outputFile.path);
      }

      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // Close loading dialog
      }

      DocumentSession.instance.setPages(processedPaths);

      context.push(
        AppConstants.routePdfPreview,
        extra: processedPaths,
      );
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processing failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncPages();

    final theme = Theme.of(context);
    final currentPage = _displayPaths.isNotEmpty
        ? _displayPaths[_selectedPageIndex.clamp(0, _displayPaths.length - 1)]
        : '';
    final originalPage = _originalPaths.isNotEmpty
        ? _originalPaths[_selectedPageIndex.clamp(0, _originalPaths.length - 1)]
        : '';

    // Apply color styling to container depending on active filter
    final activeFilter = _pageFilters[_selectedPageIndex] ?? AppConstants.filterOriginal;
    final rotationAngle = _pageRotations[_selectedPageIndex] ?? 0.0;

    double saturation = 1.0;
    double contrast = 1.0;

    final currentIntensity = _dragIntensity ?? _pageFilterIntensities[_selectedPageIndex] ?? 1.0;

    if (activeFilter == AppConstants.filterGrayscale) {
      saturation = 1.0 - currentIntensity;
    } else if (activeFilter == AppConstants.filterColorDocument) {
      contrast = 1.0 + (0.12 * currentIntensity);
    } else if (activeFilter == AppConstants.filterEnhancedColor) {
      contrast = 1.0 + (0.25 * currentIntensity);
    } else if (activeFilter == AppConstants.filterHighContrast) {
      contrast = 1.0 + (1.0 * currentIntensity);
    } else if (activeFilter == AppConstants.filterBlackAndWhite) {
      saturation = 1.0 - currentIntensity;
      contrast = 1.0 + (2.0 * currentIntensity);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          _isCropping ? 'Crop & Align' : 'Edit Document',
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: const SizedBox.shrink(), // Hidden default back button, handled by Cancel
        actions: _isCropping
            ? [
                IconButton(
                  icon: const Icon(Icons.auto_fix_high),
                  tooltip: 'Auto Snap',
                  onPressed: _autoCropCurrentPage,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset',
                  onPressed: _resetCrop,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.crop),
                  tooltip: 'Crop',
                  onPressed: _enterCroppingMode,
                ),
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate),
                  tooltip: 'Add more pages',
                  onPressed: _addMorePages,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Delete page',
                  onPressed: _deleteCurrentPage,
                ),
              ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                child: Center(
                  child: _isCropping
                        ? InteractiveCropView(
                            imagePath: originalPage,
                            points: _cropPoints[_selectedPageIndex] ?? [
                              const Offset(0.05, 0.05),
                              const Offset(0.95, 0.05),
                              const Offset(0.95, 0.95),
                              const Offset(0.05, 0.95),
                            ],
                            onPointsChanged: (pts) {
                              setState(() {
                                _cropPoints[_selectedPageIndex] = pts;
                              });
                            },
                            onDragStateChanged: (pt, dragging) {},
                          )
                        : Stack(
                            children: [
                              AnimatedRotation(
                                turns: rotationAngle / 360.0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: currentPage.isNotEmpty
                                    ? ColorFiltered(
                                        colorFilter: ColorFilter.matrix(
                                          _getColorMatrix(saturation, contrast),
                                        ),
                                        child: Image.file(
                                          File(currentPage),
                                          key: ValueKey(currentPage),
                                          fit: BoxFit.contain,
                                          width: double.infinity,
                                          height: double.infinity,
                                          errorBuilder: (context, error, stackTrace) => Center(
                                            child: Text(
                                              'Unable to load this page image.',
                                              textAlign: TextAlign.center,
                                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          'Scan your first page to preview it here.',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                                        ),
                                      ),
                              ),
                              if (activeFilter != AppConstants.filterOriginal)
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: FloatingActionButton.small(
                                    heroTag: 'apply_to_all_btn',
                                    backgroundColor: const Color(0xFF222222).withValues(alpha: 0.8),
                                    onPressed: () {
                                      setState(() {
                                        final currentFilter = _pageFilters[_selectedPageIndex] ?? AppConstants.filterOriginal;
                                        final currentIntensity = _pageFilterIntensities[_selectedPageIndex] ?? 1.0;
                                        for (int i = 0; i < _originalPaths.length; i++) {
                                          _pageFilters[i] = currentFilter;
                                          _pageFilterIntensities[i] = currentIntensity;
                                        }
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Applied to all pages')),
                                      );
                                    },
                                    tooltip: 'Apply to All',
                                    child: const Icon(Icons.done_all, color: Colors.white, size: 20),
                                  ),
                                ),
                            ],
                          ),
                ),
              ),
            ),
            
            // Pagination slider
            if (!_isCropping && _displayPaths.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingL),
                child: Row(
                  children: [
                    Text(
                      'Page ${_selectedPageIndex + 1} of ${_displayPaths.length}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.touch_app_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Long press to reorder',
                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              SizedBox(
                height: 72,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingL),
                  itemCount: _displayPaths.length,
                  onReorderItem: _onReorderPages,
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      elevation: 8,
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                      child: child,
                    );
                  },
                  itemBuilder: (context, index) {
                    final path = _displayPaths[index];
                    final selected = index == _selectedPageIndex;
                    return _AnimatedCard(
                      key: ValueKey(path),
                      onTap: () => setState(() => _selectedPageIndex = index),
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppConstants.spacingS),
                        child: Container(
                          width: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppConstants.radiusS),
                            border: Border.all(
                              color: selected ? const Color(0xFF0066FF) : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppConstants.radiusS - 2),
                            child: Image.file(
                              File(path),
                              key: ValueKey('thumb_$path'),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Icon(Icons.broken_image_outlined, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppConstants.spacingM),
            ],

            // Filter Carousel
            if (!_isCropping) ...[
              if (activeFilter != AppConstants.filterOriginal)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingL),
                  child: Row(
                    children: [
                      const Icon(Icons.tune, size: 16, color: Colors.white),
                      Expanded(
                        child: Slider(
                          value: _dragIntensity ?? _pageFilterIntensities[_selectedPageIndex] ?? 1.0,
                          activeColor: const Color(0xFF0066FF),
                          min: 0.0,
                          max: 1.0,
                          onChanged: (val) {
                            setState(() {
                              _dragIntensity = val;
                            });
                          },
                          onChangeEnd: (val) {
                            setState(() {
                              _pageFilterIntensities[_selectedPageIndex] = val;
                              _dragIntensity = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 48),

              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingL),
                  itemCount: 4, // 4 core filters
                  itemBuilder: (context, index) {
                    final coreFilters = [
                      AppConstants.filterOriginal,
                      AppConstants.filterGrayscale,
                      AppConstants.filterHighContrast,
                      AppConstants.filterBlackAndWhite,
                    ];
                    final filter = coreFilters[index];
                    final isSelected = filter == activeFilter;
                    return _AnimatedCard(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _pageFilters[_selectedPageIndex] = filter;
                        });
                      },
                      child: Container(
                        width: 80,
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? const Color(0xFF0066FF) : const Color(0xFF222222),
                              ),
                              child: Icon(
                                _getFilterIcon(filter),
                                color: isSelected ? Colors.white : const Color(0xFF6C757D),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              filter,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? const Color(0xFF0066FF) : const Color(0xFF6C757D),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppConstants.spacingL),
            ],

            // Bottom Toolbar (Cancel, Rotate, Apply)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppConstants.spacingL, 0, AppConstants.spacingL, AppConstants.spacingL),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      if (_isCropping) {
                        setState(() => _isCropping = false);
                      } else {
                        context.pop();
                      }
                    },
                    child: const Text('Cancel', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.rotate_right, color: Colors.white),
                    onPressed: _rotateImage,
                    tooltip: 'Rotate',
                  ),
                  TextButton(
                    onPressed: () {
                      if (_isCropping) {
                        _applyCropWarp();
                      } else {
                        _applyEditsAndProceed();
                      }
                    },
                    child: const Text(
                      'Apply & Continue',
                      style: TextStyle(color: Color(0xFF0066FF), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case AppConstants.filterOriginal:
        return Icons.photo;
      case AppConstants.filterColorDocument:
        return Icons.document_scanner_outlined;
      case AppConstants.filterEnhancedColor:
        return Icons.auto_fix_high;
      case AppConstants.filterGrayscale:
        return Icons.color_lens_outlined;
      case AppConstants.filterHighContrast:
        return Icons.exposure;
      case AppConstants.filterBlackAndWhite:
        return Icons.filter_b_and_w;
      default:
        return Icons.filter;
    }
  }

  // Generates a matrix for Flutter's ColorFiltered matrix preview
  List<double> _getColorMatrix(double saturation, double contrast) {
    double r = (1.0 - saturation) * 0.2126 + saturation;
    double g = (1.0 - saturation) * 0.7152;
    double b = (1.0 - saturation) * 0.0722;

    double gr = (1.0 - saturation) * 0.2126;
    double gg = (1.0 - saturation) * 0.7152 + saturation;
    double gb = (1.0 - saturation) * 0.0722;

    double br = (1.0 - saturation) * 0.2126;
    double bg = (1.0 - saturation) * 0.7152;
    double bb = (1.0 - saturation) * 0.0722 + saturation;

    double translate = (-0.5 * contrast + 0.5) * 255.0;

    return [
      r * contrast, g * contrast, b * contrast, 0, translate,
      gr * contrast, gg * contrast, gb * contrast, 0, translate,
      br * contrast, bg * contrast, bb * contrast, 0, translate,
      0, 0, 0, 1, 0,
    ];
  }
}

class InteractiveCropView extends StatefulWidget {
  final String imagePath;
  final List<Offset> points;
  final ValueChanged<List<Offset>> onPointsChanged;
  final Function(Offset activePoint, bool dragging) onDragStateChanged;

  const InteractiveCropView({
    super.key,
    required this.imagePath,
    required this.points,
    required this.onPointsChanged,
    required this.onDragStateChanged,
  });

  @override
  State<InteractiveCropView> createState() => _InteractiveCropViewState();
}

class _InteractiveCropViewState extends State<InteractiveCropView> {
  int _activePointIndex = -1;
  int? _imageWidth;
  int? _imageHeight;
  Offset? _currentTouchPoint;

  @override
  void initState() {
    super.initState();
    _loadImageDimensions();
  }

  @override
  void didUpdateWidget(covariant InteractiveCropView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _loadImageDimensions();
    }
  }

  Future<void> _loadImageDimensions() async {
    final file = File(widget.imagePath);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      var decoded = img.decodeImage(bytes);
      if (decoded != null && mounted) {
        decoded = img.bakeOrientation(decoded);
        setState(() {
          _imageWidth = decoded!.width;
          _imageHeight = decoded.height;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageWidth == null || _imageHeight == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double containerWidth = constraints.maxWidth;
        final double containerHeight = constraints.maxHeight;

        final double imageRatio = _imageWidth! / _imageHeight!;
        final double containerRatio = containerWidth / containerHeight;

        double displayedWidth;
        double displayedHeight;
        if (imageRatio > containerRatio) {
          displayedWidth = containerWidth;
          displayedHeight = containerWidth / imageRatio;
        } else {
          displayedHeight = containerHeight;
          displayedWidth = containerHeight * imageRatio;
        }

        final double offsetX = (containerWidth - displayedWidth) / 2;
        final double offsetY = (containerHeight - displayedHeight) / 2;

        final Rect displayedImageRect = Rect.fromLTWH(offsetX, offsetY, displayedWidth, displayedHeight);

        // Map normalized points to screen coordinates
        final screenPoints = widget.points.map((p) {
          return Offset(
            displayedImageRect.left + p.dx * displayedImageRect.width,
            displayedImageRect.top + p.dy * displayedImageRect.height,
          );
        }).toList();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            final touchPoint = details.localPosition;
            var closestIndex = -1;
            var minDistance = double.maxFinite;

            for (var i = 0; i < screenPoints.length; i++) {
              final d = (touchPoint - screenPoints[i]).distance;
              if (d < 35.0 && d < minDistance) {
                minDistance = d;
                closestIndex = i;
              }
            }

            if (closestIndex != -1) {
              setState(() {
                _activePointIndex = closestIndex;
                _currentTouchPoint = touchPoint;
              });
              widget.onDragStateChanged(widget.points[closestIndex], true);
            }
          },
          onPanUpdate: (details) {
            if (_activePointIndex == -1) return;

            final touchPoint = details.localPosition;

            // Boundary check: Clamp coordinates to remain strictly within the image bounding box
            final double lx = touchPoint.dx.clamp(displayedImageRect.left, displayedImageRect.right);
            final double ly = touchPoint.dy.clamp(displayedImageRect.top, displayedImageRect.bottom);

            final double u = (lx - displayedImageRect.left) / displayedImageRect.width;
            final double v = (ly - displayedImageRect.top) / displayedImageRect.height;

            final updatedPoints = List<Offset>.from(widget.points);
            updatedPoints[_activePointIndex] = Offset(u, v);
            widget.onPointsChanged(updatedPoints);

            setState(() {
              _currentTouchPoint = Offset(lx, ly);
            });

            widget.onDragStateChanged(updatedPoints[_activePointIndex], true);
          },
          onPanEnd: (_) {
            if (_activePointIndex != -1) {
              widget.onDragStateChanged(Offset.zero, false);
              setState(() {
                _activePointIndex = -1;
                _currentTouchPoint = null;
              });
            }
          },
          child: SizedBox(
            width: containerWidth,
            height: containerHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Display original image aspect-fitted
                Positioned(
                  left: displayedImageRect.left,
                  top: displayedImageRect.top,
                  width: displayedImageRect.width,
                  height: displayedImageRect.height,
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.fill,
                  ),
                ),

                // Overlay Painter
                Positioned.fill(
                  child: CustomPaint(
                    painter: DocumentCropPainter(
                      points: screenPoints,
                      primaryColor: theme.colorScheme.primary,
                      handleColor: theme.colorScheme.secondary,
                    ),
                  ),
                ),

                // Magnifier Zoom Glass (RawMagnifier with premium UI)
                if (_activePointIndex != -1 && _currentTouchPoint != null)
                  Positioned(
                    left: _currentTouchPoint!.dx - 90.0,
                    top: _currentTouchPoint!.dy >= 180.0
                        ? _currentTouchPoint!.dy - 220.0
                        : _currentTouchPoint!.dy + 40.0,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: RawMagnifier(
                              size: const Size(180, 180),
                              magnificationScale: 3.0,
                              focalPointOffset: _currentTouchPoint!.dy >= 180.0
                                  ? const Offset(0.0, 130.0)
                                  : const Offset(0.0, -130.0),
                            ),
                          ),
                          Center(
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.red, width: 1.5),
                              ),
                            ),
                          ),
                          Center(
                            child: Container(
                              width: 1,
                              height: 32,
                              color: Colors.red.withValues(alpha: 0.7),
                            ),
                          ),
                          Center(
                            child: Container(
                              width: 32,
                              height: 1,
                              color: Colors.red.withValues(alpha: 0.7),
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
      },
    );
  }
}

class DocumentCropPainter extends CustomPainter {
  final List<Offset> points;
  final Color primaryColor;
  final Color handleColor;

  DocumentCropPainter({
    required this.points,
    required this.primaryColor,
    required this.handleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 4) return;

    // 1. Draw semi-transparent overlay outside the crop polygon (inverted clipping)
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..close();
    overlayPath.fillType = PathFillType.evenOdd;
    canvas.drawPath(
      overlayPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..style = PaintingStyle.fill,
    );

    // 2. Draw border lines
    final linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(points[0].dx, points[0].dy)
        ..lineTo(points[1].dx, points[1].dy)
        ..lineTo(points[2].dx, points[2].dy)
        ..lineTo(points[3].dx, points[3].dy)
        ..close(),
      linePaint,
    );

    // 3. Draw corner handles
    final handleOuterPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleInnerPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    for (var point in points) {
      canvas.drawCircle(point, 13.0, handleOuterPaint);
      canvas.drawCircle(point, 9.0, handleInnerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant DocumentCropPainter oldDelegate) => true;
}

class _AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _AnimatedCard({super.key, required this.child, required this.onTap});

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
