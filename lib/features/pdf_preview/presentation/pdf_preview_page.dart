import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/document_session.dart';
import '../../../core/utils/pdf_utils.dart';

class PdfPreviewPage extends StatefulWidget {
  final List<String> imagePaths;

  const PdfPreviewPage({
    super.key,
    this.imagePaths = const <String>[],
  });

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  late TextEditingController _nameController;
  bool _isSaved = false;
  bool _isGenerating = false;
  String _generatedPdfPath = '';

  @override
  void initState() {
    super.initState();
    final currentPath = DocumentSession.instance.currentPdfPath;
    String defaultName = 'ScanFlow_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    if (currentPath != null) {
      final uri = Uri.file(currentPath);
      final base = uri.pathSegments.last;
      defaultName = base.toLowerCase().endsWith('.pdf')
          ? base.substring(0, base.length - 4)
          : base;
    }
    _nameController = TextEditingController(text: defaultName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _downloadPdf() async {
    try {
      if (_generatedPdfPath.isEmpty) return;
      final file = File(_generatedPdfPath);
      final destDir = Directory('/storage/emulated/0/Download');
      if (await destDir.exists()) {
        final destPath = '${destDir.path}/${file.path.split('/').last}';
        await file.copy(destPath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Downloaded PDF to Downloads folder'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveAsJpeg() async {
    try {
      final pages = widget.imagePaths.isNotEmpty
          ? widget.imagePaths
          : DocumentSession.instance.pages;
      
      final destDir = Directory('/storage/emulated/0/Pictures/ScanFlow');
      if (!await destDir.exists()) await destDir.create(recursive: true);

      for (int i = 0; i < pages.length; i++) {
        final file = File(pages[i]);
        if (await file.exists()) {
          final dest = '${destDir.path}/Page_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await file.copy(dest);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved ${pages.length} JPEGs to Pictures/ScanFlow'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save JPEGs: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveDocument() async {
    final pages = widget.imagePaths.isNotEmpty
        ? widget.imagePaths
        : DocumentSession.instance.pages;

    setState(() {
      _isGenerating = true;
    });

    try {
      PdfUtils.validatePageCount(pages);

      final file = await PdfUtils.generatePdf(
        imagePaths: pages,
        documentName: _nameController.text.trim().isEmpty
            ? 'ScanFlow_Document'
            : _nameController.text.trim(),
      );

      if (!mounted || !context.mounted) return;

      setState(() {
        _generatedPdfPath = file.path;
        _isSaved = true;
      });

      DocumentSession.instance.notifyDocumentsChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document saved to ${file.path}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save PDF: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = widget.imagePaths.isNotEmpty
        ? widget.imagePaths
        : DocumentSession.instance.pages;

    return PopScope(
      canPop: !_isSaved,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSaved) {
          context.go(AppConstants.routeHome);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PDF Preview'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_isSaved) {
                context.go(AppConstants.routeHome);
              } else {
                context.pop();
              }
            },
          ),
        ),
        body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Rename Input Field
              Text(
                'Document Name',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              Text(
                'Use a clear name so the PDF is easy to find later in Recent Documents.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter document name',
                  suffixText: '.pdf',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _nameController.clear(),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spacingXL),

              // PDF Preview Container
              Text(
                'Page Preview (${pages.length} page${pages.length == 1 ? '' : 's'})',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              Container(
                height: 380,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1 / 1.4142, // A4 aspect ratio
                    child: Container(
                      margin: const EdgeInsets.all(AppConstants.spacingL),
                      color: Colors.white,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.picture_as_pdf,
                            color: Colors.red[700],
                            size: 60,
                          ),
                          const SizedBox(height: AppConstants.spacingM),
                          Text(
                            'ScanFlow Document',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppConstants.spacingS),
                          Text(
                            'Size: generated locally on save',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: AppConstants.spacingS),
                          Text(
                            pages.isEmpty
                                ? 'Add at least one page before creating a PDF.'
                                : 'Ready to save ${pages.length} page${pages.length == 1 ? '' : 's'} offline.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spacingXXL),

              // Action Buttons
              Column(
                children: [
                  ElevatedButton.icon(
                    icon: _isGenerating 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(_isSaved ? Icons.check_circle : Icons.save_alt),
                    label: Text(_isGenerating ? 'Processing in Background...' : (_isSaved ? 'SAVED SUCCESSFULLY' : 'SAVE DOCUMENT')),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: _isSaved ? Colors.green : theme.colorScheme.primary,
                      foregroundColor: _isSaved ? Colors.white : theme.colorScheme.onPrimary,
                      elevation: _isSaved || _isGenerating ? 0 : 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusM),
                      ),
                    ),
                    onPressed: (_isSaved || _isGenerating) ? null : _saveDocument,
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  
                  if (_isSaved)
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.share_rounded),
                                label: const Text('SHARE'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                                  ),
                                ),
                                onPressed: () {
                                  context.push(
                                    AppConstants.routeShare,
                                    extra: _generatedPdfPath,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: AppConstants.spacingM),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.home_rounded),
                                label: const Text('HOME'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                                  ),
                                ),
                                onPressed: () {
                                  context.go(AppConstants.routeHome);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppConstants.spacingM),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.download_rounded),
                                label: const Text('DOWNLOAD'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                                  ),
                                ),
                                onPressed: _downloadPdf,
                              ),
                            ),
                            const SizedBox(width: AppConstants.spacingM),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.image_rounded),
                                label: const Text('SAVE JPEG'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                                  ),
                                ),
                                onPressed: _saveAsJpeg,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ));
  }
}
