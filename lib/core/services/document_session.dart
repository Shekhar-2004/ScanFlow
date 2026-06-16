import 'package:flutter/foundation.dart';

class DocumentSession extends ChangeNotifier {
  DocumentSession._();

  static final DocumentSession instance = DocumentSession._();

  final List<String> _pages = <String>[];
  String? currentPdfPath;

  List<String> get pages => List.unmodifiable(_pages);

  void reset() {
    _pages.clear();
    currentPdfPath = null;
  }

  void addPage(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty || _pages.contains(normalized)) {
      return;
    }
    _pages.add(normalized);
  }

  void setPages(List<String> paths) {
    _pages
      ..clear()
      ..addAll(paths.where((path) => path.trim().isNotEmpty));
  }

  void notifyDocumentsChanged() {
    notifyListeners();
  }
}
