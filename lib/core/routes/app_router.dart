import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../services/document_session.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/scanner/presentation/scanner_page.dart';
import '../../features/editor/presentation/editor_page.dart';
import '../../features/pdf_preview/presentation/pdf_preview_page.dart';
import '../../features/sharing/presentation/sharing_page.dart';
import '../../features/viewer/presentation/document_viewer_page.dart';

class AppRouter {
  static GoRouter createRouter({
    required VoidCallback onToggleTheme,
    required bool isDarkMode,
  }) {
    return GoRouter(
      initialLocation: AppConstants.routeHome,
      routes: [
        GoRoute(
          path: AppConstants.routeHome,
          builder: (context, state) => HomePage(
            onToggleTheme: onToggleTheme,
            isDarkMode: isDarkMode,
          ),
        ),
        GoRoute(
          path: AppConstants.routeScanner,
          builder: (context, state) => const ScannerPage(),
        ),
        GoRoute(
          path: AppConstants.routeEditor,
          builder: (context, state) {
            final extra = state.extra;
            final imagePaths = extra is List<String>
                ? extra
                : extra is String && extra.isNotEmpty
                    ? <String>[extra]
                    : DocumentSession.instance.pages;

            return EditorPage(imagePaths: imagePaths);
          },
        ),
        GoRoute(
          path: AppConstants.routePdfPreview,
          builder: (context, state) {
            final extra = state.extra;
            final imagePaths = extra is List<String>
                ? extra
                : extra is String && extra.isNotEmpty
                    ? <String>[extra]
                    : DocumentSession.instance.pages;

            return PdfPreviewPage(imagePaths: imagePaths);
          },
        ),
        GoRoute(
          path: AppConstants.routeShare,
          builder: (context, state) {
            final pdfPath = state.extra as String? ?? '';
            return SharingPage(pdfPath: pdfPath);
          },
        ),
        GoRoute(
          path: AppConstants.routePdfViewer,
          builder: (context, state) {
            final pdfPath = state.extra as String? ?? '';
            return DocumentViewerPage(pdfPath: pdfPath);
          },
        ),
      ],
    );
  }
}
