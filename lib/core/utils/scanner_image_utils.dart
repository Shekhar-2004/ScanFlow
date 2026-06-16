import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

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

/// Indicates whether an image is likely a document/text page or a general photo.
enum ImageClass { document, photo }

// ---------------------------------------------------------------------------
// ScannerImageUtils
// ---------------------------------------------------------------------------

class ScannerImageUtils {
  static const int _backgroundThreshold = 245;
  static const int _padding = 8;
  static const int _maxDimension = 2480;

  // -------------------------------------------------------------------------
  // Legacy / shared utilities (preserved for backward compatibility)
  // -------------------------------------------------------------------------

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

  static Future<Uint8List> enhanceForPdf(Uint8List bytes) async {
    final compressedBytes = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: _maxDimension,
      minHeight: _maxDimension,
      quality: 92,
    );

    return compressedBytes;
  }

  // -------------------------------------------------------------------------
  // Document corner detection & perspective warp (unchanged)
  // -------------------------------------------------------------------------

  /// Deterministically detects the 4 corners of a sheet of paper in the image.
  /// Returns corners ordered as [TL, TR, BR, BL].
  static List<Point2D>? detectDocumentCorners(img.Image image) {
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

    final lums = Float32List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = small.getPixel(x, y);
        lums[y * width + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      }
    }

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

    final edgeThreshold = maxEdge * 0.15;

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

    final targetW = ((dist(tl, tr) + dist(bl, br)) / 2.0).round().clamp(64, 4096);
    final targetH = ((dist(tl, bl) + dist(tr, br)) / 2.0).round().clamp(64, 4096);

    final dest = img.Image(width: targetW, height: targetH);

    for (var dy = 0; dy < targetH; dy++) {
      final v = dy / (targetH - 1.0);
      for (var dx = 0; dx < targetW; dx++) {
        final u = dx / (targetW - 1.0);

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

  // =========================================================================
  // NEW: Private pipeline helpers
  // =========================================================================

  // ---------------------------------------------------------------------------
  // Helper: build integral image over a Float32List luminance map
  // ---------------------------------------------------------------------------
  static Float64List _buildIntegral(Float32List lums, int width, int height) {
    final integral = Float64List((width + 1) * (height + 1));
    for (var y = 0; y < height; y++) {
      var rowSum = 0.0;
      for (var x = 0; x < width; x++) {
        rowSum += lums[y * width + x];
        integral[(y + 1) * (width + 1) + (x + 1)] =
            integral[y * (width + 1) + (x + 1)] + rowSum;
      }
    }
    return integral;
  }

  static double _integralWindowSum(
      Float64List integral, int width, int x1, int y1, int x2, int y2) {
    final idxA = y1 * (width + 1) + x1;
    final idxB = y1 * (width + 1) + (x2 + 1);
    final idxC = (y2 + 1) * (width + 1) + x1;
    final idxD = (y2 + 1) * (width + 1) + (x2 + 1);
    return integral[idxD] - integral[idxB] - integral[idxC] + integral[idxA];
  }

  // ---------------------------------------------------------------------------
  // P4 — Illumination normalisation (shadow removal)
  //
  // Strategy: estimate the local background brightness using a large box blur
  // (via integral image). Divide each pixel luminance by its local background
  // to normalise lighting, then remap to [0, 255].
  // ---------------------------------------------------------------------------
  static Float32List _normaliseIllumination(
      Float32List lums, int width, int height) {
    // Kernel radius ~8% of the shorter dimension, minimum 40
    final int radius = (math.min(width, height) * 0.08).round().clamp(40, 200);

    final integral = _buildIntegral(lums, width, height);
    final out = Float32List(width * height);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final x1 = (x - radius).clamp(0, width - 1);
        final y1 = (y - radius).clamp(0, height - 1);
        final x2 = (x + radius).clamp(0, width - 1);
        final y2 = (y + radius).clamp(0, height - 1);

        final count = (x2 - x1 + 1) * (y2 - y1 + 1).toDouble();
        final sum = _integralWindowSum(integral, width, x1, y1, x2, y2);
        final localBg = (sum / count).clamp(20.0, 255.0);

        // Normalise: bright background becomes 255, text stays dark
        final norm = (lums[y * width + x] / localBg) * 255.0;
        out[y * width + x] = norm.clamp(0.0, 255.0);
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // P2 — Fast approximate bilateral denoising
  //
  // 5×5 spatial window. Range weight is a step function: skip pixels whose
  // luminance differs by more than sigmaR (preserves text edges while smoothing
  // noise in flat background regions).
  // ---------------------------------------------------------------------------
  static Float32List _bilateralDenoise(
      Float32List lums, int width, int height) {
    const int halfKernel = 2; // 5×5 window
    const double sigmaR = 25.0; // luminance range tolerance
    const double sigmaS = 2.0; // spatial sigma for Gaussian weight

    final out = Float32List(width * height);

    // Pre-compute spatial Gaussian weights for the 5×5 window
    final spatialWeights = List.generate(2 * halfKernel + 1, (dy) {
      return List.generate(2 * halfKernel + 1, (dx) {
        final ddy = dy - halfKernel;
        final ddx = dx - halfKernel;
        return math.exp(-(ddy * ddy + ddx * ddx) / (2.0 * sigmaS * sigmaS));
      });
    });

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final centerLum = lums[y * width + x];
        var weightedSum = 0.0;
        var totalWeight = 0.0;

        for (var ky = -halfKernel; ky <= halfKernel; ky++) {
          final ny = (y + ky).clamp(0, height - 1);
          for (var kx = -halfKernel; kx <= halfKernel; kx++) {
            final nx = (x + kx).clamp(0, width - 1);
            final neighbourLum = lums[ny * width + nx];

            final diff = (neighbourLum - centerLum).abs();
            if (diff > sigmaR * 2) continue; // hard cut-off to protect edges

            final rangeWeight = math.exp(-(diff * diff) / (2.0 * sigmaR * sigmaR));
            final spatialWeight =
                spatialWeights[ky + halfKernel][kx + halfKernel];
            final w = spatialWeight * rangeWeight;

            weightedSum += neighbourLum * w;
            totalWeight += w;
          }
        }

        out[y * width + x] =
            totalWeight > 0.0 ? weightedSum / totalWeight : centerLum;
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // P6 — Adaptive threshold
  //
  // Returns a binary Uint8List: 0 = foreground (ink), 255 = background (paper).
  // Uses integral image for fast mean computation.
  // Block size = 21 (radius = 10), constant C = 11.
  // ---------------------------------------------------------------------------
  static Uint8List _adaptiveThreshold(
      Float32List lums, int width, int height,
      {int blockRadius = 10, double C = 11.0}) {
    final integral = _buildIntegral(lums, width, height);
    final binary = Uint8List(width * height);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final x1 = (x - blockRadius).clamp(0, width - 1);
        final y1 = (y - blockRadius).clamp(0, height - 1);
        final x2 = (x + blockRadius).clamp(0, width - 1);
        final y2 = (y + blockRadius).clamp(0, height - 1);

        final count = (x2 - x1 + 1) * (y2 - y1 + 1).toDouble();
        final sum = _integralWindowSum(integral, width, x1, y1, x2, y2);
        final mean = sum / count;

        // Pixel is foreground (ink) if it's darker than local mean minus C
        binary[y * width + x] = lums[y * width + x] < (mean - C) ? 0 : 255;
      }
    }
    return binary;
  }

  // ---------------------------------------------------------------------------
  // P7 — Morphological operations (erosion, dilation, opening, closing)
  //
  // Binary map convention: 0 = foreground (ink), 255 = background (paper).
  // 3×3 structuring element.
  // ---------------------------------------------------------------------------
  static Uint8List _morphErode(Uint8List binary, int width, int height) {
    final out = Uint8List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        // A foreground pixel remains foreground only if ALL 3×3 neighbours
        // are foreground (0). If binary value is already 255 (background), skip.
        if (binary[y * width + x] == 255) {
          out[y * width + x] = 255;
          continue;
        }
        var allFg = true;
        outer:
        for (var ky = -1; ky <= 1; ky++) {
          final ny = (y + ky).clamp(0, height - 1);
          for (var kx = -1; kx <= 1; kx++) {
            final nx = (x + kx).clamp(0, width - 1);
            if (binary[ny * width + nx] != 0) {
              allFg = false;
              break outer;
            }
          }
        }
        out[y * width + x] = allFg ? 0 : 255;
      }
    }
    return out;
  }

  static Uint8List _morphDilate(Uint8List binary, int width, int height) {
    final out = Uint8List.fromList(binary); // start with copy (all background)
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (binary[y * width + x] != 0) continue; // only propagate from FG
        // Set all 3×3 neighbours to foreground
        for (var ky = -1; ky <= 1; ky++) {
          final ny = (y + ky).clamp(0, height - 1);
          for (var kx = -1; kx <= 1; kx++) {
            final nx = (x + kx).clamp(0, width - 1);
            out[ny * width + nx] = 0;
          }
        }
      }
    }
    return out;
  }

  /// Opening = erode then dilate (removes isolated speckles).
  static Uint8List _morphOpen(Uint8List binary, int width, int height) {
    return _morphDilate(_morphErode(binary, width, height), width, height);
  }

  /// Closing = dilate then erode (repairs broken strokes).
  static Uint8List _morphClose(Uint8List binary, int width, int height) {
    return _morphErode(_morphDilate(binary, width, height), width, height);
  }

  // ---------------------------------------------------------------------------
  // P5 — Border cleanup
  //
  // Force a margin band around all 4 edges to background (255).
  // Margin = max(4, 1.5% of min dimension).
  // ---------------------------------------------------------------------------
  static Uint8List _cleanBorders(Uint8List binary, int width, int height) {
    final margin = math.max(4, (math.min(width, height) * 0.015).round());
    final out = Uint8List.fromList(binary);

    // Top & bottom bands
    for (var y = 0; y < margin; y++) {
      for (var x = 0; x < width; x++) {
        out[y * width + x] = 255;
        out[(height - 1 - y) * width + x] = 255;
      }
    }
    // Left & right bands
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < margin; x++) {
        out[y * width + x] = 255;
        out[y * width + (width - 1 - x)] = 255;
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // P9 — Notebook line suppression
  //
  // Detects horizontal rows where >75% of pixels across the full width are
  // foreground pixels — these are almost certainly ruled lines. Those pixels
  // are promoted to background (255) to prevent lines from dominating the scan.
  // Handwriting that crosses the line is protected because it creates non-uniform
  // horizontal runs.
  // ---------------------------------------------------------------------------
  static Uint8List _suppressNotebookLines(
      Uint8List binary, int width, int height) {
    final out = Uint8List.fromList(binary);

    for (var y = 0; y < height; y++) {
      var fgCount = 0;
      for (var x = 0; x < width; x++) {
        if (binary[y * width + x] == 0) fgCount++;
      }

      final ratio = fgCount / width;
      // If >72% of this row is foreground and the row is not nearly all black
      // (which would indicate actual content, not a thin line), treat it as
      // a ruled line and suppress it.
      if (ratio > 0.72 && ratio < 0.96) {
        for (var x = 0; x < width; x++) {
          // Only suppress if the local column is not part of a dense vertical
          // foreground region (heuristic: check pixel above and below).
          final above = y > 0 ? binary[(y - 1) * width + x] : 255;
          final below = y < height - 1 ? binary[(y + 1) * width + x] : 255;
          // If this pixel has no vertical neighbours it's isolated line pixel
          if (above == 255 && below == 255) {
            out[y * width + x] = 255; // suppress
          }
        }
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // P8 — Unsharp mask (foreground-only)
  //
  // Sharpens text edges while leaving the pure-white background untouched.
  // Applied on the final luminance values before compositing.
  //
  // amount: how much sharpening to apply (0.0–1.0, default 0.5)
  // blurRadius: box-blur half-kernel used for the blurred reference (default 1)
  // ---------------------------------------------------------------------------
  static Float32List _unsharpMaskForeground(
      Float32List lums, Uint8List binary, int width, int height,
      {double amount = 0.5, int blurRadius = 1}) {
    // Compute a small box blur of the luminance map
    final blurred = Float32List(width * height);
    final integral = _buildIntegral(lums, width, height);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final x1 = (x - blurRadius).clamp(0, width - 1);
        final y1 = (y - blurRadius).clamp(0, height - 1);
        final x2 = (x + blurRadius).clamp(0, width - 1);
        final y2 = (y + blurRadius).clamp(0, height - 1);
        final count = (x2 - x1 + 1) * (y2 - y1 + 1).toDouble();
        final sum = _integralWindowSum(integral, width, x1, y1, x2, y2);
        blurred[y * width + x] = sum / count;
      }
    }

    final out = Float32List.fromList(lums);
    for (var i = 0; i < width * height; i++) {
      // Only sharpen foreground pixels to avoid halo on white background
      if (binary[i] == 0) {
        final sharpened = lums[i] - amount * (blurred[i] - lums[i]);
        out[i] = sharpened.clamp(0.0, 255.0);
      }
    }
    return out;
  }

  // =========================================================================
  // PUBLIC: Document / Photo Classifier
  // =========================================================================

  /// Classifies [src] as [ImageClass.document] or [ImageClass.photo].
  ///
  /// Documents (notebooks, receipts, printed pages) typically have:
  ///   - A large fraction of near-white pixels (paper background).
  ///   - A bimodal luminance distribution (paper + ink).
  ///
  /// Photos have a more spread-out luminance distribution without a dominant
  /// bright-white peak.
  static ImageClass classifyImage(img.Image src) {
    // Downscale to speed up
    const maxD = 200;
    final img.Image small;
    if (src.width > maxD || src.height > maxD) {
      final scale = src.width > src.height
          ? maxD / src.width.toDouble()
          : maxD / src.height.toDouble();
      small = img.copyResize(src,
          width: (src.width * scale).round(),
          height: (src.height * scale).round());
    } else {
      small = src;
    }

    final int total = small.width * small.height;
    var nearWhiteCount = 0;
    var darkCount = 0;

    for (var y = 0; y < small.height; y++) {
      for (var x = 0; x < small.width; x++) {
        final p = small.getPixel(x, y);
        final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        if (lum >= 210) nearWhiteCount++;
        if (lum < 80) darkCount++;
      }
    }

    final nearWhiteRatio = nearWhiteCount / total;
    final darkRatio = darkCount / total;

    // Document heuristic:
    //  - At least 35% of pixels are near-white (paper background)
    //  - Less than 30% dark pixels (most documents aren't fully inked)
    //  - Strong bimodal: nearWhite and dark together cover most of the histogram
    final bimodalStrength = nearWhiteRatio + darkRatio;

    if (nearWhiteRatio >= 0.35 && darkRatio < 0.35 && bimodalStrength >= 0.42) {
      return ImageClass.document;
    }

    return ImageClass.photo;
  }

  // =========================================================================
  // PUBLIC: Document scan filters
  // =========================================================================

  // ---------------------------------------------------------------------------
  // Color Document — adaptive background whitening + colour preservation
  // Now includes denoising and illumination normalisation pre-pass.
  // ---------------------------------------------------------------------------
  static img.Image applyColorDocumentFilter(img.Image src,
      {double intensity = 1.0}) {
    if (intensity <= 0.0) return src.clone();
    final int width = src.width;
    final int height = src.height;
    final dest = img.Image(width: width, height: height);

    // Build raw luminance map
    final rawLums = Float32List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = src.getPixel(x, y);
        rawLums[y * width + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      }
    }

    // P4: Illumination normalisation
    final normLums = _normaliseIllumination(rawLums, width, height);

    // P2: Bilateral denoising
    final denoisedLums = _bilateralDenoise(normLums, width, height);

    // Compute integral for local mean window (colour normalisation)
    final integral = _buildIntegral(denoisedLums, width, height);

    final int rRadius = (width / 16.0).round().clamp(16, 120);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = src.getPixel(x, y);

        final x1 = (x - rRadius).clamp(0, width - 1);
        final y1 = (y - rRadius).clamp(0, height - 1);
        final x2 = (x + rRadius).clamp(0, width - 1);
        final y2 = (y + rRadius).clamp(0, height - 1);

        final double count = (x2 - x1 + 1) * (y2 - y1 + 1).toDouble();
        final double sum = _integralWindowSum(integral, width, x1, y1, x2, y2);
        final double mean = sum / count;

        final double meanVal = mean.clamp(20.0, 255.0);

        final double normR = (p.r / meanVal) * 245.0;
        final double normG = (p.g / meanVal) * 245.0;
        final double normB = (p.b / meanVal) * 245.0;
        final double normLumPx = 0.299 * normR + 0.587 * normG + 0.114 * normB;

        int nr, ng, nb;
        if (normLumPx > 190.0) {
          final double factor = ((normLumPx - 190.0) / 55.0).clamp(0.0, 1.0);
          nr = (normR + (255.0 - normR) * factor).round().clamp(0, 255);
          ng = (normG + (255.0 - normG) * factor).round().clamp(0, 255);
          nb = (normB + (255.0 - normB) * factor).round().clamp(0, 255);
        } else {
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

  // ---------------------------------------------------------------------------
  // Enhanced Color — aggressive colour boost + background whitening
  // Now includes denoising and illumination normalisation pre-pass.
  // ---------------------------------------------------------------------------
  static img.Image applyEnhancedColorFilter(img.Image src,
      {double intensity = 1.0}) {
    if (intensity <= 0.0) return src.clone();
    final int width = src.width;
    final int height = src.height;
    final dest = img.Image(width: width, height: height);

    // Build raw luminance map
    final rawLums = Float32List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = src.getPixel(x, y);
        rawLums[y * width + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      }
    }

    // P4: Illumination normalisation
    final normLums = _normaliseIllumination(rawLums, width, height);

    // P2: Bilateral denoising
    final denoisedLums = _bilateralDenoise(normLums, width, height);

    final integral = _buildIntegral(denoisedLums, width, height);
    final int rRadius = (width / 16.0).round().clamp(16, 120);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = src.getPixel(x, y);

        final x1 = (x - rRadius).clamp(0, width - 1);
        final y1 = (y - rRadius).clamp(0, height - 1);
        final x2 = (x + rRadius).clamp(0, width - 1);
        final y2 = (y + rRadius).clamp(0, height - 1);

        final double count = (x2 - x1 + 1) * (y2 - y1 + 1).toDouble();
        final double sum = _integralWindowSum(integral, width, x1, y1, x2, y2);
        final double mean = sum / count;

        final double meanVal = mean.clamp(20.0, 255.0);

        final double normR = (p.r / meanVal) * 245.0;
        final double normG = (p.g / meanVal) * 245.0;
        final double normB = (p.b / meanVal) * 245.0;
        final double normLumPx = 0.299 * normR + 0.587 * normG + 0.114 * normB;

        int nr, ng, nb;
        if (normLumPx > 185.0) {
          nr = 255; ng = 255; nb = 255;
        } else {
          final double nrBoost = normLumPx + (normR - normLumPx) * 1.6;
          final double ngBoost = normLumPx + (normG - normLumPx) * 1.6;
          final double nbBoost = normLumPx + (normB - normLumPx) * 1.6;
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

  // ---------------------------------------------------------------------------
  // Grayscale — adaptive whitening, now with denoising + shadow removal.
  // ---------------------------------------------------------------------------
  static img.Image applyGrayscaleFilter(img.Image src,
      {double intensity = 1.0}) {
    if (intensity <= 0.0) return src.clone();
    final int width = src.width;
    final int height = src.height;
    final dest = img.Image(width: width, height: height);

    // Raw luminance
    final rawLums = Float32List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = src.getPixel(x, y);
        rawLums[y * width + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      }
    }

    // P4: Illumination normalisation
    final normLums = _normaliseIllumination(rawLums, width, height);

    // P2: Bilateral denoising
    final lums = _bilateralDenoise(normLums, width, height);

    // Adaptive local normalisation (existing logic, on improved luminance)
    final integral = _buildIntegral(lums, width, height);
    final int rRadius = (width / 16.0).round().clamp(16, 120);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final double lum = lums[y * width + x];
        final double origLum = rawLums[y * width + x];

        final x1 = (x - rRadius).clamp(0, width - 1);
        final y1 = (y - rRadius).clamp(0, height - 1);
        final x2 = (x + rRadius).clamp(0, width - 1);
        final y2 = (y + rRadius).clamp(0, height - 1);

        final double count = (x2 - x1 + 1) * (y2 - y1 + 1).toDouble();
        final double sum = _integralWindowSum(integral, width, x1, y1, x2, y2);
        final double mean = sum / count;

        final double meanVal = mean.clamp(20.0, 255.0);
        final double normLumPx = (lum / meanVal) * 245.0;

        final int val =
            normLumPx > 190.0 ? 255 : (normLumPx * 0.88).round().clamp(0, 255);

        if (intensity < 1.0) {
          final iv = (val * intensity + origLum * (1.0 - intensity)).round();
          dest.setPixel(x, y, img.ColorRgb8(iv, iv, iv));
        } else {
          dest.setPixel(x, y, img.ColorRgb8(val, val, val));
        }
      }
    }

    return dest;
  }

  // ---------------------------------------------------------------------------
  // High Contrast — unchanged (photo-safe, not document-specific)
  // ---------------------------------------------------------------------------
  static img.Image applyHighContrastFilter(img.Image src,
      {double intensity = 1.0}) {
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

  // ---------------------------------------------------------------------------
  // Black & White — FULL 9-STEP DOCUMENT PIPELINE
  //
  // Step 1: Illumination normalisation (P4 — shadow removal)
  // Step 2: Bilateral denoising (P2 — noise removal)
  // Step 3: Adaptive Gaussian threshold → binary mask (P6)
  // Step 4: Morphological opening 3×3 (P7 — remove speckles)
  // Step 5: Morphological closing 3×3 (P7 — repair strokes)
  // Step 6: Border cleanup (P5 — edge contamination)
  // Step 7: Notebook line suppression (P9)
  // Step 8: Unsharp mask on foreground only (P8 — preserve text)
  // Step 9: Composite — foreground=black, background=pure white (P1 + P3)
  // ---------------------------------------------------------------------------
  static img.Image applyBlackAndWhiteFilter(img.Image src,
      {double intensity = 1.0}) {
    if (intensity <= 0.0) return src.clone();

    final int width = src.width;
    final int height = src.height;

    // ── Step 0: Build raw luminance map ──────────────────────────────────────
    final rawLums = Float32List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = src.getPixel(x, y);
        rawLums[y * width + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      }
    }

    // ── Step 1: Illumination normalisation (P4) ──────────────────────────────
    final normLums = _normaliseIllumination(rawLums, width, height);

    // ── Step 2: Bilateral denoising (P2) ─────────────────────────────────────
    final denoisedLums = _bilateralDenoise(normLums, width, height);

    // ── Step 3: Adaptive threshold → binary mask (P6) ───────────────────────
    // Block radius = 10 (≈ block size 21), C = 11
    var binary = _adaptiveThreshold(denoisedLums, width, height,
        blockRadius: 10, C: 11.0);

    // ── Step 4: Morphological opening — remove isolated speckles (P7) ────────
    binary = _morphOpen(binary, width, height);

    // ── Step 5: Morphological closing — repair broken strokes (P7) ───────────
    binary = _morphClose(binary, width, height);

    // ── Step 6: Border cleanup (P5) ──────────────────────────────────────────
    binary = _cleanBorders(binary, width, height);

    // ── Step 7: Notebook line suppression (P9) ───────────────────────────────
    binary = _suppressNotebookLines(binary, width, height);

    // ── Step 8: Unsharp mask on foreground only (P8) ─────────────────────────
    final sharpLums =
        _unsharpMaskForeground(denoisedLums, binary, width, height,
            amount: 0.5, blurRadius: 1);

    // ── Step 9: Composite — pure-white background + black ink (P1 + P3) ──────
    final dest = img.Image(width: width, height: height);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final idx = y * width + x;
        final isForeground = binary[idx] == 0;

        int finalVal;
        if (isForeground) {
          // Foreground: use sharpened luminance, boosted contrast toward black
          final sharpened = sharpLums[idx];
          finalVal = (sharpened * 0.7).round().clamp(0, 180);
        } else {
          // Background: pure white (RGB 255)
          finalVal = 255;
        }

        if (intensity < 1.0) {
          final origLum = rawLums[idx];
          final blended =
              (finalVal * intensity + origLum * (1.0 - intensity)).round();
          dest.setPixel(x, y, img.ColorRgb8(blended, blended, blended));
        } else {
          dest.setPixel(x, y, img.ColorRgb8(finalVal, finalVal, finalVal));
        }
      }
    }

    return dest;
  }
}
