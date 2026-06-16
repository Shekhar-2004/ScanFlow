import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;

import 'scanner_image_utils.dart';
import '../services/pdf_metadata_store.dart';

Future<Uint8List> _isolateGeneratePdf(List<Uint8List> pages) async {
  final pdf = pw.Document();

  for (final enhancedBytes in pages) {
    final decoded = img.decodeImage(enhancedBytes);
    double width = decoded?.width.toDouble() ?? PdfPageFormat.a4.width;
    double height = decoded?.height.toDouble() ?? PdfPageFormat.a4.height;

    const double maxDimension = 842.0;
    if (width > maxDimension || height > maxDimension) {
      final scale = maxDimension / (width > height ? width : height);
      width *= scale;
      height *= scale;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(width, height),
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context context) {
          return pw.Image(
            pw.MemoryImage(enhancedBytes),
            fit: pw.BoxFit.fill,
          );
        },
      ),
    );
  }

  return await pdf.save();
}

class PdfUtils {
  static Future<bool> ensureStoragePermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final storageStatus = await Permission.storage.request();
    final photosStatus = await Permission.photos.request();
    final manageStatus = await Permission.manageExternalStorage.request();

    return storageStatus.isGranted || photosStatus.isGranted || manageStatus.isGranted;
  }

  static Future<Directory> _documentsDirectory() async {
    Directory rootDir;
    if (Platform.isAndroid) {
      final publicDocs = Directory('/storage/emulated/0/Documents');
      if (await publicDocs.exists()) {
        rootDir = publicDocs;
      } else {
        final externalDirs = await getExternalStorageDirectories(type: StorageDirectory.documents);
        rootDir = externalDirs?.isNotEmpty == true
            ? externalDirs!.first
            : await getApplicationDocumentsDirectory();
      }
    } else {
      rootDir = await getApplicationDocumentsDirectory();
    }

    final scanDir = Directory('${rootDir.path}${Platform.pathSeparator}ScanFirst');
    if (!await scanDir.exists()) {
      await scanDir.create(recursive: true);
    }

    return scanDir;
  }

  static Future<List<File>> listRecentPdfs() async {
    final dir = await _documentsDirectory();
    if (!await dir.exists()) {
      return <File>[];
    }

    final files = dir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.pdf'))
        .toList()
      ..sort((a, b) {
        final aTime = a.statSync().modified.millisecondsSinceEpoch;
        final bTime = b.statSync().modified.millisecondsSinceEpoch;
        return bTime.compareTo(aTime);
      });

    return files;
  }

  static bool validatePageCount(List<String> imagePaths) {
    final cleanPages = imagePaths.where((path) => path.trim().isNotEmpty).toList();

    if (cleanPages.isEmpty) {
      throw ArgumentError('At least one page is required to create a PDF.');
    }

    return true;
  }

  static Future<File> generatePdf({
    required List<String> imagePaths,
    required String documentName,
  }) async {
    validatePageCount(imagePaths);

    final hasPermission = await ensureStoragePermission();
    if (!hasPermission) {
      throw StateError('Storage permission is required to save PDFs to the device.');
    }

    final pageBytesList = <Uint8List>[];

    for (final imagePath in imagePaths.where((path) => path.trim().isNotEmpty)) {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw ArgumentError('The selected image could not be found: $imagePath');
      }

      final bytes = await file.readAsBytes();
      final enhancedBytes = await ScannerImageUtils.enhanceForPdf(bytes);
      pageBytesList.add(enhancedBytes);
    }

    final pdfBytes = await compute(_isolateGeneratePdf, pageBytesList);

    final safeName = documentName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    final outputDir = await _documentsDirectory();
    final outputFile = File('${outputDir.path}${Platform.pathSeparator}${safeName.isNotEmpty ? safeName : 'ScanFlow'}.pdf');

    await outputFile.writeAsBytes(pdfBytes);
    await PdfMetadataStore.saveMetadata(outputFile.path, imagePaths);
    return outputFile;
  }
}
