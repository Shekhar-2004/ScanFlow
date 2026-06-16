import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/document_session.dart';
import '../../../core/services/pdf_metadata_store.dart';

class DocumentViewerPage extends StatefulWidget {
  final String pdfPath;

  const DocumentViewerPage({
    super.key,
    required this.pdfPath,
  });

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  String get _fileName {
    final uri = Uri.file(widget.pdfPath);
    return uri.pathSegments.last;
  }

  Future<void> _editDocument() async {
    final images = await PdfMetadataStore.getImagePaths(widget.pdfPath);

    if (images == null || images.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Original page images not found for this PDF. Editing is unavailable.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Load images and PDF path into the session
    DocumentSession.instance.reset();
    DocumentSession.instance.setPages(images);
    DocumentSession.instance.currentPdfPath = widget.pdfPath;

    if (!mounted) return;
    context.push(AppConstants.routeEditor, extra: images);
  }

  Future<void> _shareDocument() async {
    final file = File(widget.pdfPath);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(widget.pdfPath)],
        text: 'Sharing $_fileName',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing document: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteDocument() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Are you sure you want to permanently delete "$_fileName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final file = File(widget.pdfPath);
      if (await file.exists()) {
        await file.delete();
      }

      await PdfMetadataStore.deleteMetadata(widget.pdfPath);
      DocumentSession.instance.notifyDocumentsChanged();

      // Return to home screen
      context.go(AppConstants.routeHome);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting document: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _downloadDocument() async {
    try {
      final sourceFile = File(widget.pdfPath);
      if (!await sourceFile.exists()) {
        throw StateError('Source PDF file not found.');
      }

      // Public Downloads directory on Android
      final downloadDir = Directory('/storage/emulated/0/Download/ScanFirst');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final destinationFile = File('${downloadDir.path}/$_fileName');
      await sourceFile.copy(destinationFile.path);

      if (!mounted) return;
      // Silently succeed
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving to Downloads: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            tooltip: 'Edit PDF',
            onPressed: _editDocument,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share PDF',
            onPressed: _shareDocument,
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download PDF',
            onPressed: _downloadDocument,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete PDF',
            onPressed: _deleteDocument,
          ),
        ],
      ),
      body: SafeArea(
        child: PdfPreview(
          build: (format) => File(widget.pdfPath).readAsBytes(),
          allowPrinting: false,
          allowSharing: false,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          maxPageWidth: 800,
          scrollViewDecoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          loadingWidget: const Center(
            child: CircularProgressIndicator(),
          ),
          onError: (context, error) => Center(
            child: Text(
              'Unable to load PDF preview:\n$error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }
}
