import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/document_session.dart';
import '../../../core/services/pdf_metadata_store.dart';
import '../../../core/utils/pdf_utils.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const HomePage({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<File> _recentDocs = <File>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DocumentSession.instance.addListener(_onDocumentsChanged);
    _loadRecentDocuments();
  }

  @override
  void dispose() {
    DocumentSession.instance.removeListener(_onDocumentsChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onDocumentsChanged() {
    if (mounted) {
      _loadRecentDocuments();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRecentDocuments();
    }
  }

  Future<void> _loadRecentDocuments() async {
    try {
      await PdfUtils.ensureStoragePermission();
      final docs = await PdfUtils.listRecentPdfs();
      if (!mounted) return;
      setState(() {
        _recentDocs = docs;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _recentDocs = <File>[];
        _isLoading = false;
      });
      debugPrint('Unable to load recent PDFs: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recentDocs = _recentDocs;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Theme',
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // New Scan card
              InkWell(
                borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                onTap: () async {
                  DocumentSession.instance.reset();
                  await context.push(AppConstants.routeScanner);
                  if (mounted) {
                    _loadRecentDocuments();
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConstants.spacingXL),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppConstants.spacingM),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: theme.colorScheme.onPrimary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingL),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Scan',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppConstants.spacingXS),
                            Text(
                              'Capture, crop, and export a professional PDF in seconds.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spacingXL),

              // Recent Documents Section
              Text(
                'Recent Documents',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : recentDocs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.document_scanner_outlined,
                              size: 64,
                              color: theme.colorScheme.outline.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: AppConstants.spacingM),
                            Text(
                              'No scanned documents yet.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: AppConstants.spacingS),
                            Text(
                              'Tap New Scan to create your first document.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: recentDocs.length,
                        itemBuilder: (context, index) {
                          final doc = recentDocs[index];
                          final fileName = doc.path.split(Platform.pathSeparator).last;
                          final modified = doc.statSync().modified;
                          return Dismissible(
                            key: Key(doc.path),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Document?'),
                                  content: Text('Are you sure you want to permanently delete "$fileName"?'),
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
                              ) ?? false;
                            },
                            background: Container(
                              margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(AppConstants.radiusM),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: AppConstants.spacingL),
                              child: const Icon(Icons.delete_outline, color: Colors.white),
                            ),
                            onDismissed: (direction) async {
                              final path = doc.path;
                              setState(() {
                                recentDocs.removeAt(index);
                              });
                              if (await doc.exists()) {
                                await doc.delete();
                              }
                              await PdfMetadataStore.deleteMetadata(path);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Deleted $fileName')),
                                );
                              }
                            },
                            child: Card(
                              margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
                              child: ListTile(
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                                  ),
                                  child: Icon(
                                    Icons.picture_as_pdf_rounded,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                title: Text(
                                  fileName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${modified.toLocal().toString().split('.').first} • PDF',
                                  style: theme.textTheme.bodySmall,
                                ),
                                trailing: Icon(
                                  Icons.chevron_right,
                                  color: theme.colorScheme.primary,
                                ),
                                 onTap: () async {
                                  await context.push(
                                    AppConstants.routePdfViewer,
                                    extra: doc.path,
                                  );
                                  if (mounted) {
                                    _loadRecentDocuments();
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: AppConstants.spacingM),
            ],
          ),
        ),
      ),
    );
  }
}
