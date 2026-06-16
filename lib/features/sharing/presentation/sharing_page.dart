import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';

class SharingPage extends StatefulWidget {
  final String pdfPath;

  const SharingPage({
    super.key,
    required this.pdfPath,
  });

  @override
  State<SharingPage> createState() => _SharingPageState();
}

class _SharingPageState extends State<SharingPage> {
  bool _hasSaved = false;

  @override
  Widget build(BuildContext context) {
    final fileName = widget.pdfPath.split('/').last;
    final file = File(widget.pdfPath);
    final fileExists = file.existsSync();
    final fileSize = fileExists ? _formatBytes(file.lengthSync()) : 'Not available';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go(AppConstants.routeHome);
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Share Document'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(AppConstants.routeHome),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                      // File Info Block
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color ?? colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorScheme.outline, width: 1),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.picture_as_pdf, color: colorScheme.error, size: 40),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fileName,
                                      style: theme.textTheme.titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$fileSize • PDF Document',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Bottom Toolbar: Grid of Share Targets (Simulated as elevated button for native share sheet + home)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.share),
                                label: const Text('Share Options', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                onPressed: () async {
                                  if (!fileExists) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('The PDF file could not be found.')),
                                    );
                                    return;
                                  }

                                  await SharePlus.instance.share(
                                    ShareParams(
                                      files: [XFile(widget.pdfPath)],
                                      text: 'Here is the scanned PDF.',
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  if (_hasSaved) {
                                    context.go(AppConstants.routeHome);
                                  } else {
                                    if (fileExists) {
                                      await SharePlus.instance.share(
                                        ShareParams(
                                          files: [XFile(widget.pdfPath)],
                                          text: 'Here is the scanned PDF.',
                                        ),
                                      );
                                      if (mounted) {
                                        setState(() => _hasSaved = true);
                                      }
                                    }
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  side: BorderSide(color: _hasSaved ? theme.colorScheme.primary : colorScheme.outline),
                                ),
                                child: Text(
                                  _hasSaved ? 'Back to Home' : 'Save to Files',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    const units = <String>['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var index = 0;

    while (size >= 1024 && index < units.length - 1) {
      size /= 1024;
      index += 1;
    }

    return '${size.toStringAsFixed(size >= 10 || index == 0 ? 0 : 1)} ${units[index]}';
  }
}
