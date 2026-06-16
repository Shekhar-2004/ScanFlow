import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:scanflow/core/utils/scanner_image_utils.dart';

void main() {
  group('ScannerImageUtils', () {
    test('detects a document bounding box from a simple image', () {
      final image = img.Image(width: 120, height: 80);
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          image.setPixel(x, y, img.ColorRgb8(255, 255, 255));
        }
      }

      for (var y = 10; y < 70; y++) {
        for (var x = 18; x < 102; x++) {
          image.setPixel(x, y, img.ColorRgb8(10, 20, 30));
        }
      }

      final bounds = ScannerImageUtils.detectDocumentBounds(image);

      expect(bounds, isNotNull);
      expect(bounds!.left, lessThan(40));
      expect(bounds.top, lessThan(30));
      expect(bounds.width, greaterThan(60));
      expect(bounds.height, greaterThan(40));
    });

    test('enhances image bytes into a valid PDF-ready buffer', () async {
      final image = img.Image(width: 80, height: 100);
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          image.setPixel(x, y, img.ColorRgb8(255, 255, 255));
        }
      }
      for (var y = 15; y < 85; y++) {
        for (var x = 10; x < 70; x++) {
          image.setPixel(x, y, img.ColorRgb8(30, 40, 50));
        }
      }

      final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 95));
      final enhanced = await ScannerImageUtils.enhanceForPdf(bytes);

      expect(enhanced, isNotEmpty);
      expect(enhanced.length, greaterThan(0));
    });
  });
}
