import 'dart:async';
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
  Completer<String>? _pdfCompleter;

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

    if (_isGenerating || _isSaved) return;

    setState(() {
      _isGenerating = true;
      _isSaved = true; // Pseudo success
    });

    _pdfCompleter = Completer<String>();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document saving in background...'),
        backgroundColor: Colors.green,
      ),
    );

    try {
      PdfUtils.validatePageCount(pages);

      final name = _nameController.text.trim().isEmpty
          ? 'ScanFlow_Document'
          : _nameController.text.trim();

      PdfUtils.generatePdf(
        imagePaths: pages,
        documentName: name,
      ).then((file) {
        if (mounted) {
          setState(() {
            _generatedPdfPath = file.path;
            _isGenerating = false;
          });
          DocumentSession.instance.notifyDocumentsChanged();
          _pdfCompleter?.complete(file.path);
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _isGenerating = false;
            _isSaved = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to save PDF: $error'),
              backgroundColor: Colors.red,
            ),
          );
          _pdfCompleter?.completeError(error);
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _isSaved = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to start save: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: const Color(0xFFF2F2F7), // Apple Notes Light Grey
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('PDF Preview', style: TextStyle(color: Colors.black)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              if (_isSaved) {
                context.go(AppConstants.routeHome);
              } else {
                context.pop();
              }
            },
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              onSelected: (value) async {
                if (value == 'jpeg') {
                  await _saveAsJpeg();
                } else if (value == 'home') {
                  context.go(AppConstants.routeHome);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'jpeg', child: Text('Save as JPEG')),
                const PopupMenuItem(value: 'home', child: Text('Go to Home')),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Filename Card
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingL),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: Colors.red[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ),
                      const Icon(Icons.edit, color: Colors.grey, size: 20),
                    ],
                  ),
                ),
              ),

              // Document Preview (Single continuous scroll)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingL, vertical: AppConstants.spacingS),
                  itemCount: pages.length,
                  itemBuilder: (context, index) {
                    final path = pages[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppConstants.spacingL),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(path),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const SizedBox(
                            height: 200,
                            child: Center(child: Icon(Icons.broken_image)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingL),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE5E5EA))),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      // Share Button (Blue)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!_isSaved) {
                              await _saveDocument();
                            }
                            if (_isGenerating && _pdfCompleter != null) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Waiting for PDF to finish generating...')),
                              );
                              try {
                                await _pdfCompleter!.future;
                              } catch (e) {
                                return;
                              }
                            }
                            if (_isSaved && context.mounted) {
                              context.push(AppConstants.routeShare, extra: _generatedPdfPath);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0066FF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isGenerating 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Share', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingM),
                      // Save to Files Button (Grey)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!_isSaved) {
                              await _saveDocument();
                            }
                            if (_isGenerating && _pdfCompleter != null) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Waiting for PDF to finish generating...')),
                              );
                              try {
                                await _pdfCompleter!.future;
                              } catch (e) {
                                return;
                              }
                            }
                            await _downloadPdf();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE5E5EA),
                            foregroundColor: Colors.black87,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Save to Files', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
