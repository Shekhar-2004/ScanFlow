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
            icon: Icon(widget.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _AnimatedCTA(
        onPressed: () async {
          DocumentSession.instance.reset();
          await context.push(AppConstants.routeScanner);
          if (mounted) {
            _loadRecentDocuments();
          }
        },
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingL, vertical: AppConstants.spacingS),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Documents',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppConstants.spacingM),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : recentDocs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              size: 64,
                              color: Color(0xFFE5E5EA),
                            ),
                            const SizedBox(height: AppConstants.spacingM),
                            Text(
                              'No Scanned Documents',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppConstants.spacingXS),
                            Text(
                              'Your captured items will appear here securely.',
                              style: theme.textTheme.bodySmall,
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
                                color: const Color(0xFFFF3B30),
                                borderRadius: BorderRadius.circular(16),
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
                            child: _AnimatedCard(
                              onTap: () async {
                                await context.push(
                                  AppConstants.routePdfViewer,
                                  extra: doc.path,
                                );
                                if (mounted) {
                                  _loadRecentDocuments();
                                }
                              },
                              child: Container(
                                height: 72,
                                margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.picture_as_pdf_rounded,
                                        color: theme.colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            fileName,
                                            style: theme.textTheme.titleMedium,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${modified.toLocal().toString().split('.').first} • PDF',
                                            style: theme.textTheme.labelMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 80), // Padding for Floating CTA
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedCTA extends StatefulWidget {
  final VoidCallback onPressed;

  const _AnimatedCTA({required this.onPressed});

  @override
  State<_AnimatedCTA> createState() => _AnimatedCTAState();
}

class _AnimatedCTAState extends State<_AnimatedCTA> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 180,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFF0066FF),
            borderRadius: BorderRadius.circular(27),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'New Scan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _AnimatedCard({required this.child, required this.onTap});

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
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
