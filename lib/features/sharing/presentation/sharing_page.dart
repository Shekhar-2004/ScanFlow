import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';

class SharingPage extends StatelessWidget {
  final String pdfPath;

  const SharingPage({
    super.key,
    required this.pdfPath,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = pdfPath.split('/').last;
    final file = File(pdfPath);
    final fileExists = file.existsSync();
    final fileSize = fileExists ? _formatBytes(file.lengthSync()) : 'Not available';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go(AppConstants.routeHome);
      },
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.5), // Semi-transparent backdrop
        body: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () => context.go(AppConstants.routeHome),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.3,
                color: Colors.transparent,
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Drag Handle
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Title
                      const Text(
                        'Share Document',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 24),

                      // File Info Block
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.picture_as_pdf, color: Colors.red[700], size: 40),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fileName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$fileSize • PDF Document',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
                                      files: [XFile(pdfPath)],
                                      text: 'Here is the scanned PDF.',
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0066FF),
                                  foregroundColor: Colors.white,
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
                                onPressed: () {
                                  context.go(AppConstants.routeHome);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Back to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
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
          ],
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
