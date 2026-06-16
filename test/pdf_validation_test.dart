import 'package:flutter_test/flutter_test.dart';

import 'package:scan_first/core/utils/pdf_utils.dart';

void main() {
  group('PdfUtils', () {
    test('rejects empty page list before generating a PDF', () {
      expect(
        () => PdfUtils.validatePageCount(<String>[]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts a real page list', () {
      expect(PdfUtils.validatePageCount(['page1.jpg']), isTrue);
    });
  });
}
