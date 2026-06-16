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
    final theme = Theme.of(context);
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
        appBar: AppBar(
          title: const Text('Share Document'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              context.go(AppConstants.routeHome);
            },
          ),
        ),
        body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success Header
              // Premium File Representation
              Center(
                child: Container(
                  height: 160,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.picture_as_pdf_rounded, size: 64, color: Colors.red[700]),
                      const SizedBox(height: 16),
                      Text(
                        'PDF Document',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spacingXL),

              // File Information Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spacingL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FILE INFORMATION',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingM),
                      _buildInfoRow(context, 'File Name', fileName),
                      const Divider(height: 24),
                      _buildInfoRow(context, 'Format', 'PDF (A4 Document)'),
                      const Divider(height: 24),
                      _buildInfoRow(context, 'File Size', fileSize),
                      const Divider(height: 24),
                      _buildInfoRow(context, 'Storage Location', fileExists ? pdfPath : 'Saved locally once generated'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spacingXL),

              Text(
                'Share using the Android system sheet',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              Text(
                'This opens the standard Android share dialog so you can send the PDF to any app.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppConstants.spacingXL),

              ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('SHARE PDF'),
                onPressed: () async {
                  if (!fileExists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('The PDF file could not be found. Save it first.')),
                    );
                    return;
                  }

                  await SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(pdfPath)],
                      text: 'Here is the scanned PDF generated by ScanFirst.',
                    ),
                  );
                },
              ),
              const Spacer(),

              // Done Button
              OutlinedButton.icon(
                icon: const Icon(Icons.home),
                label: const Text('BACK TO HOME'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  ),
                ),
                onPressed: () {
                  // Navigate back to home and clear history stack
                  context.go(AppConstants.routeHome);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
