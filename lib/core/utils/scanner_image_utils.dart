import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

class Point2D {
  final double x;
  final double y;
  const Point2D(this.x, this.y);

  @override
  String toString() => 'Point2D(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

class DocumentBounds {
  const DocumentBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left + 1;

  int get height => bottom - top + 1;
}

class ScannerImageUtils {
  static const int _backgroundThreshold = 245;
  static const int _padding = 8;
  static const int _maxDimension = 2400;

  // Preserved for backward compatibility / tests
  static DocumentBounds? detectDocumentBounds(img.Image image) {
    var minX = image.width;
    var minY = image.height;
    var maxX = 0;
    var maxY = 0;
    var foundContent = false;

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final brightness = (((pixel.r * 77) + (pixel.g * 150) + (pixel.b * 29)) / 256).round();

        if (brightness < _backgroundThreshold) {
          foundContent = true;
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (!foundContent) {
      return null;
    }

    final left = (minX - _padding).clamp(0, image.width - 1);
    final top = (minY - _padding).clamp(0, image.height - 1);
    final right = (maxX + _padding).clamp(0, image.width - 1);
    final bottom = (maxY + _padding).clamp(0, image.height - 1);

    final width = right - left + 1;
    final height = bottom - top + 1;

    if (width < 16 || height < 16) {
      return null;
    }

    return DocumentBounds(left: left, top: top, right: right, bottom: bottom);
  }

  // Refactored enhanceForPdf (respects pre-processed images)
  static Future<Uint8List> enhanceForPdf(Uint8List bytes) async {
    final compressedBytes = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: _maxDimension,
      minHeight: _maxDimension,
      quality: 85,
    );
    
    return compressedBytes;
  }

  // --- NEW WORKFLOW IMPLEMENTATION: EDGE DETECTION & WARPING ---

  /// Deterministically detects the 4 corners of a sheet of paper (the document) in the image.
  /// Returns corners ordered as [TL, TR, BR, BL].
  static List<Point2D>? detectDocumentCorners(img.Image image) {
    // 1. Downscale the image to speed up calculation
    const maxD = 400;
    img.Image small;
    double scaleX, scaleY;
    if (image.width > maxD || image.height > maxD) {
      final scale = image.width > image.height
          ? maxD / image.width.toDouble()
          : maxD / image.height.toDouble();
      final w = (image.width * scale).round();
      final h = (image.height * scale).round();
      small = img.copyResize(image, width: w, height: h);
      scaleX = image.width / w.toDouble();
      scaleY = image.height / h.toDouble();
    } else {
      small = image;
      scaleX = 1.0;
      scaleY = 1.0;
    }

    final int width = small.width;
    final int height = small.height;

    // 2. Compute luminance map
    final lums = Float32List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = small.getPixel(x, y);
        lums[y * width + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      }
    }

    // 3. Simple edge detection (gradient magnitude)
    final edges = Float32List(width * height);
    double maxEdge = 0.0;
    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        final dx = lums[y * width + (x + 1)] - lums[y * width + (x - 1)];
        final dy = lums[(y + 1) * width + x] - lums[(y - 1) * width + x];
        final mag = dx * dx + dy * dy;
        edges[y * width + x] = mag;
        if (mag > maxEdge) maxEdge = mag;
      }
    }

    // Threshold for strong edges
    final edgeThreshold = maxEdge * 0.15;

    // 4. Find extreme edge points
    var tlX = width / 2, tlY = height / 2, tlVal = double.maxFinite;
    var trX = width / 2, trY = height / 2, trVal = double.maxFinite;
    var brX = width / 2, brY = height / 2, brVal = double.maxFinite;
    var blX = width / 2, blY = height / 2, blVal = double.maxFinite;

    var found = false;
    final marginW = (width * 0.03).round();
    final marginH = (height * 0.03).round();

    for (var y = marginH; y < height - marginH; y++) {
      for (var x = marginW; x < width - marginW; x++) {
        if (edges[y * width + x] > edgeThreshold) {
          found = true;
          final valTL = x.toDouble() + y.toDouble();
          if (valTL < tlVal) { tlVal = valTL; tlX = x.toDouble(); tlY = y.toDouble(); }

          final valTR = (width - x) + y.toDouble();
          if (valTR < trVal) { trVal = valTR; trX = x.toDouble(); trY = y.toDouble(); }

          final valBR = (width - x) + (height - y).toDouble();
          if (valBR < brVal) { brVal = valBR; brX = x.toDouble(); brY = y.toDouble(); }

          final valBL = x + (height - y).toDouble();
          if (valBL < blVal) { blVal = valBL; blX = x.toDouble(); blY = y.toDouble(); }
        }
      }
    }

    if (!found) return null;

    final areaWidth = (trX - tlX + brX - blX) / 2.0;
    final areaHeight = (blY - tlY + brY - trY) / 2.0;
    if (areaWidth < width * 0.15 || areaHeight < height * 0.15) {
      return null;
    }

    return [
      Point2D(tlX * scaleX, tlY * scaleY),
      Point2D(trX * scaleX, trY * scaleY),
      Point2D(brX * scaleX, brY * scaleY),
      Point2D(blX * scaleX, blY * scaleY),
    ];
  }

  /// Performs bilinear perspective mapping to warp a quad into a flat rectangular image.
  static img.Image perspectiveWarp(
    img.Image src,
    Point2D tl,
    Point2D tr,
    Point2D br,
    Point2D bl,
  ) {
    double dist(Point2D a, Point2D b) {
      final dx = a.x - b.x;
      final dy = a.y - b.y;
      return math.sqrt(dx * dx + dy * dy);
    }

    // Average top/bottom edge lengths to find target width
    final targetW = ((dist(tl, tr) + dist(bl, br)) / 2.0).round().clamp(64, 4096);
    // Average left/right edge lengths to find target height
    final targetH = ((dist(tl, bl) + dist(tr, br)) / 2.0).round().clamp(64, 4096);

    final dest = img.Image(width: targetW, height: targetH);

    for (var dy = 0; dy < targetH; dy++) {
      final v = dy / (targetH - 1.0);
      for (var dx = 0; dx < targetW; dx++) {
        final u = dx / (targetW - 1.0);

        // Bilinear mapping coordinates in source image space
        final sx = (1.0 - u) * (1.0 - v) * tl.x +
            u * (1.0 - v) * tr.x +
            u * v * br.x +
            (1.0 - u) * v * bl.x;

        final sy = (1.0 - u) * (1.0 - v) * tl.y +
            u * (1.0 - v) * tr.y +
            u * v * br.y +
            (1.0 - u) * v * bl.y;

        final pixel = _sampleBilinear(src, sx, sy);
        dest.setPixel(dx, dy, pixel);
      }
    }

    return dest;
  }

  static img.Color _sampleBilinear(img.Image src, double x, double y) {
    final x0 = x.floor().clamp(0, src.width - 1);
    final x1 = (x0 + 1).clamp(0, src.width - 1);
    final y0 = y.floor().clamp(0, src.height - 1);
    final y1 = (y0 + 1).clamp(0, src.height - 1);

    final dx = x - x0;
    final dy = y - y0;

    final p00 = src.getPixel(x0, y0);
    final p10 = src.getPixel(x1, y0);
    final p01 = src.getPixel(x0, y1);
    final p11 = src.getPixel(x1, y1);

    final r = _interpolateChannel(p00.r, p10.r, p01.r, p11.r, dx, dy);
    final g = _interpolateChannel(p00.g, p10.g, p01.g, p11.g, dx, dy);
    final b = _interpolateChannel(p00.b, p10.b, p01.b, p11.b, dx, dy);
    final a = _interpolateChannel(p00.a, p10.a, p01.a, p11.a, dx, dy);

    return img.ColorRgba8(r, g, b, a);
  }

  static int _interpolateChannel(num c00, num c10, num c01, num c11, double dx, double dy) {
    final val = c00 * (1.0 - dx) * (1.0 - dy) +
        c10 * dx * (1.0 - dy) +
        c01 * (1.0 - dx) * dy +
        c11 * dx * dy;
    return val.clamp(0, 255).round();
  }

  // --- DOCUMENT SCANNED FILTERS ---

  static img.Image applyColorDocumentFilter(img.Image src, {double intensity = 1.0}) {
    if (intensity <= 0.0) return src.clone();
    final int width = src.width;
    final int height = src.height;
    final dest = img.Image(width: width, height: height);

    // Compute luminance map
    final lums = Float32List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = src.getPixel(x, y);
        lums[y * width + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      }
    }

    // Compute Integral Image
    final integral = Float64List((width + 1) * (height + 1));
    for (var y = 0; y < height; y++) {
      var rowSum = 0.0;
      for (var x = 0; x < width; x++) {
        rowSum += lums[y * width + x];
        integral[(y + 1) * (width + 1) + (x + 1)] = integral[y * (width + 1) + (x + 1)] + rowSum;
      }
    }

    double getWindowSum(int x1, int y1, int x2, int y2) {
      final int idxA = y1 * (width + 1) + x1;
      final int idxB = y1 * (width + 1) + (x2 + 1);
      final int idxC = (y2 + 1) * (width + 1) + x1;
      final int idxD = (y2 + 1) * (width + 1) + (x2 + 1);
      return integral[idxD] - integral[idxB] - integral[idxC] + integral[idxA];
    }

    // Self-scaling window radius (approx 12.5% of width)
    final int rRadius = (width / 16.0).round().clamp(16, 120);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = src.getPixel(x, y);

        final x1 = (x - rRadius).clamp(0, width - 1);
        final y1 = (y - rRadius).clamp(0, height - 1);
        final x2 = (x + rRadius).clamp(0, width - 1);
        final y2 = (y + rRadius).clamp(0, height - 1);

        final double count = (x2 - x1 + 1) * (y2 - y1 + 1).toDouble();
        final double sum = getWindowSum(x1, y1, x2, y2);
        final double mean = sum / count;

        final double meanVal = mean.clamp(20.0, 255.0);
        
        // Division-based normalization to flatten background
        final double normR = (p.r / meanVal) * 245.0;
        final double normG = (p.g / meanVal) * 245.0;
        final double normB = (p.b / meanVal) * 245.0;
        final double normLum = 0.299 * normR + 0.587 * normG + 0.114 * normB;

        int nr, ng, nb;
        if (normLum > 190.0) {
          // Smooth transition to pure paper-white background
          final double factor = ((normLum - 190.0) / 55.0).clamp(0.0, 1.0);
          nr = (normR + (255.0 - normR) * factor).round().clamp(0, 255);
          ng = (normG + (255.0 - normG) * factor).round().clamp(0, 255);
          nb = (normB + (255.0 - normB) * factor).round().clamp(0, 255);
        } else {
          // Darken text to increase readability/contrast
          const double scale = 0.90;
          nr = (normR * scale).round().clamp(0, 255);
          ng = (normG * scale).round().clamp(0, 255);
          nb = (normB * scale).round().clamp(0, 255);
        }

        if (intensity < 1.0) {
          final ir = (nr * intensity + p.r * (1.0 - intensity)).round();
          final ig = (ng * intensity + p.g * (1.0 - intensity)).round();
          final ib = (nb * intensity + p.b * (1.0 - intensity)).round();
          dest.setPixel(x, y, img.ColorRgb8(ir, ig, ib));
        } else {
          dest.setPixel(x, y, img.ColorRgb8(nr, ng, nb));
        }
      }
    }

    return dest;
  }

  static img.Image applyEnhancedColorFilter(img.Image src, {double intensity = 1.0}) {
    if (intensity <= 0.0) return src.clone();
    final int width = src.width;
    final int height = src.height;
    final dest = img.Image(width: width, height: height);

    // Compute luminance map
    final lums = Float32List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = src.getPixel(x, y);
        lums[y * width + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      }
    }

    // Compute Integral Image
    final integral = Float64List((width + 1) * (height + 1));
    for (var y = 0; y < height; y++) {
      var rowSum = 0.0;
      for (var x = 0; x < width; x++) {
        rowSum += lums[y * width + x];
        integral[(y + 1) * (width + 1) + (x + 1)] = integral[y * (width + 1) + (x + 1)] + rowSum;
      }
    }

    double getWindowSum(int x1, int y1, int x2, int y2) {
      final int idxA = y1 * (width + 1) + x1;
      final int idxB = y1 * (width + 1) + (x2 + 1);
      final int idxC = (y2 + 1) * (width + 1) + x1;
      final int idxD = (y2 + 1) * (width + 1) + (x2 + 1);
      return integral[idxD] - integral[idxB] - integral[idxC] + integral[idxA];
    }

    // Self-scaling window radius (approx 12.5% of width)
    final int rRadius = (width / 16.0).round().clamp(16, 120);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = src.getPixel(x, y);

        final x1 = (x - rRadius).clamp(0, width - 1);
        final y1 = (y - rRadius).clamp(0, height - 1);
        final x2 = (x + rRadius).clamp(0, width - 1);
        final y2 = (y + rRadius).clamp(0, height - 1);

        final double count = (x2 - x1 + 1) * (y2 - y1 + 1).toDouble();
        final double sum = getWindowSum(x1, y1, x2, y2);
        final double mean = sum / count;

        final double meanVal = mean.clamp(20.0, 255.0);
        
        // Division-based normalization to flatten background
        final double normR = (p.r / meanVal) * 245.0;
        final double normG = (p.g / meanVal) * 245.0;
        final double normB = (p.b / meanVal) * 245.0;
        final double normLum = 0.299 * normR + 0.587 * normG + 0.114 * normB;

        int nr, ng, nb;
        if (normLum > 185.0) {
          nr = 255; ng = 255; nb = 255;
        } else {
          final double nrBoost = normLum + (normR - normLum) * 1.6;
          final double ngBoost = normLum + (normG - normLum) * 1.6;
          final double nbBoost = normLum + (normB - normLum) * 1.6;
          const double scale = 0.85;
          nr = (nrBoost * scale).round().clamp(0, 255);
          ng = (ngBoost * scale).round().clamp(0, 255);
          nb = (nbBoost * scale).round().clamp(0, 255);
        }

        if (intensity < 1.0) {
          final ir = (nr * intensity + p.r * (1.0 - intensity)).round();
          final ig = (ng * intensity + p.g * (1.0 - intensity)).round();
          final ib = (nb * intensity + p.b * (1.0 - intensity)).round();
          dest.setPixel(x, y, img.ColorRgb8(ir, ig, ib));
        } else {
          dest.setPixel(x, y, img.ColorRgb8(nr, ng, nb));
        }
      }
    }

    return dest;
  }

  static img.Image applyGrayscaleFilter(img.Image src, {double intensity = 1.0}) {
    if (intensity <= 0.0) return src.clone();
    final int width = src.width;
    final int height = src.height;
    final dest = img.Image(width: width, height: height);

    // Compute luminance map
    final lums = Float32List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = src.getPixel(x, y);
        lums[y * width + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      }
    }

    // Compute Integral Image
    final integral = Float64List((width + 1) * (height + 1));
    for (var y = 0; y < height; y++) {
      var rowSum = 0.0;
      for (var x = 0; x < width; x++) {
        rowSum += lums[y * width + x];
        integral[(y + 1) * (width + 1) + (x + 1)] = integral[y * (width + 1) + (x + 1)] + rowSum;
      }
    }

    double getWindowSum(int x1, int y1, int x2, int y2) {
      final int idxA = y1 * (width + 1) + x1;
      final int idxB = y1 * (width + 1) + (x2 + 1);
      final int idxC = (y2 + 1) * (width + 1) + x1;
      final int idxD = (y2 + 1) * (width + 1) + (x2 + 1);
      return integral[idxD] - integral[idxB] - integral[idxC] + integral[idxA];
    }

    // Self-scaling window radius (approx 12.5% of width)
    final int rRadius = (width / 16.0).round().clamp(16, 120);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final double lum = lums[y * width + x];

        final x1 = (x - rRadius).clamp(0, width - 1);
        final y1 = (y - rRadius).clamp(0, height - 1);
        final x2 = (x + rRadius).clamp(0, width - 1);
        final y2 = (y + rRadius).clamp(0, height - 1);

        final double count = (x2 - x1 + 1) * (y2 - y1 + 1).toDouble();
        final double sum = getWindowSum(x1, y1, x2, y2);
        final double mean = sum / count;

        final double meanVal = mean.clamp(20.0, 255.0);
        final double normLum = (lum / meanVal) * 245.0;

        final int val = normLum > 190.0 ? 255 : (normLum * 0.88).round().clamp(0, 255);

        if (intensity < 1.0) {
          final iv = (val * intensity + lum * (1.0 - intensity)).round();
          dest.setPixel(x, y, img.ColorRgb8(iv, iv, iv));
        } else {
          dest.setPixel(x, y, img.ColorRgb8(val, val, val));
        }
      }
    }

    return dest;
  }

  static img.Image applyHighContrastFilter(img.Image src, {double intensity = 1.0}) {
    if (intensity <= 0.0) return src.clone();
    final dest = img.Image(width: src.width, height: src.height);
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        
        final nr = (((p.r - 128.0) * 1.6) + 128.0).clamp(0.0, 255.0).round();
        final ng = (((p.g - 128.0) * 1.6) + 128.0).clamp(0.0, 255.0).round();
        final nb = (((p.b - 128.0) * 1.6) + 128.0).clamp(0.0, 255.0).round();
        
        if (intensity < 1.0) {
          final ir = (nr * intensity + p.r * (1.0 - intensity)).round();
          final ig = (ng * intensity + p.g * (1.0 - intensity)).round();
          final ib = (nb * intensity + p.b * (1.0 - intensity)).round();
          dest.setPixel(x, y, img.ColorRgb8(ir, ig, ib));
        } else {
          dest.setPixel(x, y, img.ColorRgb8(nr, ng, nb));
        }
      }
    }
    return dest;
  }

  static img.Image applyBlackAndWhiteFilter(img.Image src, {double intensity = 1.0}) {
    if (intensity <= 0.0) return src.clone();
    final dest = img.Image(width: src.width, height: src.height);
    
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        
        final double lum = 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b;
        final int val = lum > 128 ? 255 : 0;
        
        if (intensity < 1.0) {
          final iv = (val * intensity + lum * (1.0 - intensity)).round();
          dest.setPixel(x, y, img.ColorRgb8(iv, iv, iv));
        } else {
          dest.setPixel(x, y, img.ColorRgb8(val, val, val));
        }
      }
    }

    return dest;
  }
}
