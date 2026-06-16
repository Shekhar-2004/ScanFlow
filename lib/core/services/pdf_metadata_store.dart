import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PdfMetadataStore {
  static Future<Directory> _getMetadataDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final metadataDir = Directory('${appDir.path}/metadata');
    if (!await metadataDir.exists()) {
      await metadataDir.create(recursive: true);
    }
    return metadataDir;
  }

  static String _getFileName(String pdfPath) {
    // Extract base filename without extension
    final uri = Uri.file(pdfPath);
    final base = uri.pathSegments.last;
    if (base.toLowerCase().endsWith('.pdf')) {
      return base.substring(0, base.length - 4);
    }
    return base;
  }

  /// Saves the list of original/cropped image paths associated with the generated PDF.
  static Future<void> saveMetadata(String pdfPath, List<String> imagePaths) async {
    try {
      final dir = await _getMetadataDir();
      final name = _getFileName(pdfPath);
      final file = File('${dir.path}/$name.json');

      final data = {
        'pdfPath': pdfPath,
        'imagePaths': imagePaths,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      // Fail silently or log
    }
  }

  /// Retrieves the list of image paths associated with the given PDF.
  static Future<List<String>?> getImagePaths(String pdfPath) async {
    try {
      final dir = await _getMetadataDir();
      final name = _getFileName(pdfPath);
      final file = File('${dir.path}/$name.json');

      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(content);
      final List<dynamic> paths = data['imagePaths'] ?? [];
      return paths.cast<String>();
    } catch (e) {
      return null;
    }
  }

  /// Deletes the metadata file associated with the given PDF.
  static Future<void> deleteMetadata(String pdfPath) async {
    try {
      final dir = await _getMetadataDir();
      final name = _getFileName(pdfPath);
      final file = File('${dir.path}/$name.json');

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Fail silently
    }
  }
}
