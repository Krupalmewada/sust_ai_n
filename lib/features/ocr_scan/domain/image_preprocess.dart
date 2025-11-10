import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as im;

/// Int-only rectangle to avoid double→int warnings everywhere.
class IntRect {
  final int left;
  final int top;
  final int width;
  final int height;

  const IntRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  int get right => left + width;
  int get bottom => top + height;
  bool get isValid => width > 0 && height > 0;
}

/// Preprocess an image for OCR and return a JPEG as bytes.
/// - [cropRectInImage] must be in **image pixels** (ints).
/// - Steps: optional crop → resize → grayscale → contrast stretch → (optional)
///   adaptive threshold → (optional) morphology close → (optional) unsharp.
Future<Uint8List?> preprocessForOcr(
    String srcPath, {
      IntRect? cropRectInImage,
      int maxDim = 1600,
      bool useAdaptiveThreshold = false,
      bool useSharpen = true,
      double unsharpAmount = 0.85,
      bool useMorphClose = false,
    }) async {
  try {
    final bytes = await File(srcPath).readAsBytes();
    final input = im.decodeImage(bytes);
    if (input == null) return null;

    // 1) Crop (int rect)
    im.Image work = input;
    if (cropRectInImage != null && cropRectInImage.isValid) {
      final r = _clampIntRectToImage(cropRectInImage, input.width, input.height);
      if (r.isValid) {
        work = im.copyCrop(
          input,
          x: r.left,
          y: r.top,
          width: r.width,
          height: r.height,
        );
      }
    }

    // 2) Resize (limit the longer side to maxDim)
    final int w = work.width;
    final int h = work.height;
    final int longer = (w > h) ? w : h;
    if (longer > maxDim) {
      final int targetW = ((w * maxDim) / longer).round();
      work = im.copyResize(work, width: targetW); // keeps aspect ratio
    }

    // 3) Grayscale
    work = im.grayscale(work);

    // 4) Contrast stretch (1% clip)
    _contrastStretchInPlace(work, clipPercent: 1);

    // 5) Optional adaptive threshold (boosts handwriting legibility)
    if (useAdaptiveThreshold) {
      // block must be odd; c is small subtraction from local mean
      work = _adaptiveThresholdFast(work, block: 21, c: 6);
    }

    // 6) Optional morphology close: dilate then erode to connect broken strokes
    if (useMorphClose) {
      work = _morphClose3x3(work); // local fallback (no package funcs)
    }


    // 7) Optional gentle unsharp
    if (useSharpen) {
      work = _unsharp(work, radius: 1, amount: unsharpAmount);
    }

    final out = im.encodeJpg(work, quality: 90);
    return Uint8List.fromList(out);
  } catch (_) {
    return null;
  }
}

/// Same as [preprocessForOcr] but writes a temp jpg and returns the path.
Future<String?> preprocessForOcrToTemp(
    String srcPath, {
      IntRect? cropRectInImage,
      int maxDim = 1600,
      bool useAdaptiveThreshold = false,
      bool useSharpen = true,
      double unsharpAmount = 0.85,
      bool useMorphClose = false,
    }) async {
  final data = await preprocessForOcr(
    srcPath,
    cropRectInImage: cropRectInImage,
    maxDim: maxDim,
    useAdaptiveThreshold: useAdaptiveThreshold,
    useSharpen: useSharpen,
    unsharpAmount: unsharpAmount,
    useMorphClose: useMorphClose,
  );
  if (data == null) return null;

  final String outPath =
      '${Directory.systemTemp.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg';
  await File(outPath).writeAsBytes(data, flush: true);
  return outPath;
}

// ----------------------- helpers -----------------------

IntRect _clampIntRectToImage(IntRect r, int w, int h) {
  int left = r.left;
  int top = r.top;
  int right = r.right;
  int bottom = r.bottom;

  if (left < 0) left = 0;
  if (top < 0) top = 0;
  if (right > w) right = w;
  if (bottom > h) bottom = h;

  final int width = right - left;
  final int height = bottom - top;

  if (width <= 0 || height <= 0) {
    return IntRect(left: 0, top: 0, width: w, height: h);
  }
  return IntRect(left: left, top: top, width: width, height: height);
}

/// Contrast stretch with tail clipping (clipPercent as whole percent).
void _contrastStretchInPlace(im.Image img, {int clipPercent = 1}) {
  final List<int> hist = List<int>.filled(256, 0);

  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      final p = img.getPixel(x, y);
      // getLuminance returns num on some versions; force int
      final int lum = im.getLuminance(p).toInt();
      hist[lum] += 1;
    }
  }

  final int total = img.width * img.height;
  final int clip = ((total * clipPercent) / 100).round();

  // low
  int acc = 0;
  int low = 0;
  for (int i = 0; i < 256; i++) {
    acc += hist[i];
    if (acc >= clip) {
      low = i;
      break;
    }
  }
  // high
  acc = 0;
  int high = 255;
  for (int i = 255; i >= 0; i--) {
    acc += hist[i];
    if (acc >= clip) {
      high = i;
      break;
    }
  }
  if (high <= low) return;

  final double scale = 255.0 / (high - low);

  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      final p = img.getPixel(x, y);
      final int lum = im.getLuminance(p).toInt();

      int v = lum - low;
      if (v < 0) v = 0;
      if (v > 255) v = 255;

      int nv = (v * scale).round();
      if (nv < 0) nv = 0;
      if (nv > 255) nv = 255;

      img.setPixelRgba(x, y, nv, nv, nv, p.a);
    }
  }
}

/// Adaptive threshold via local mean using an integral image.
/// Keeps alpha; outputs strict black/white (0 or 255).
im.Image _adaptiveThresholdFast(im.Image src, {int block = 21, int c = 6}) {
  final w = src.width, h = src.height;
  if (block < 3) block = 3;
  if (block % 2 == 0) block += 1; // must be odd

  // Build integral image of luminance for O(1) window sums
  final integ = List<int>.filled((w + 1) * (h + 1), 0);
  int idx(int x, int y) => y * (w + 1) + x;

  for (int y = 1; y <= h; y++) {
    int rowSum = 0;
    for (int x = 1; x <= w; x++) {
      final lum = im.getLuminance(src.getPixel(x - 1, y - 1)).toInt();
      rowSum += lum;
      integ[idx(x, y)] = integ[idx(x, y - 1)] + rowSum;
    }
  }

  final rad = block ~/ 2;
  final out = im.Image.from(src);

  for (int y = 0; y < h; y++) {
    int y0 = (y - rad); if (y0 < 0) y0 = 0;
    int y1 = (y + rad); if (y1 >= h) y1 = h - 1;

    for (int x = 0; x < w; x++) {
      int x0 = (x - rad); if (x0 < 0) x0 = 0;
      int x1 = (x + rad); if (x1 >= w) x1 = w - 1;

      final area = (x1 - x0 + 1) * (y1 - y0 + 1);
      final sum =
          integ[idx(x1 + 1, y1 + 1)] - integ[idx(x0, y1 + 1)]
              - integ[idx(x1 + 1, y0)] + integ[idx(x0, y0)];
      final mean = (sum ~/ area);

      final lum = im.getLuminance(src.getPixel(x, y)).toInt();
      final th = mean - c; // local threshold
      final v = (lum > th) ? 255 : 0;

      final a = src.getPixel(x, y).a;
      out.setPixelRgba(x, y, v, v, v, a);
    }
  }
  return out;
}

/// Unsharp via blur-subtract.
/// [radius] is **int** (to match image package signature).
im.Image _unsharp(im.Image src, {required int radius, required double amount}) {
  final im.Image blurred = im.gaussianBlur(src, radius: radius);
  final im.Image out = im.Image.from(src);

  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final a = src.getPixel(x, y);
      final b = blurred.getPixel(x, y);

      final int aLum = im.getLuminance(a).toInt();
      final int bLum = im.getLuminance(b).toInt();

      final double hp = (aLum - bLum).toDouble();
      int v = (aLum + hp * amount).round();
      if (v < 0) v = 0;
      if (v > 255) v = 255;

      out.setPixelRgba(x, y, v, v, v, a.a);
    }
  }
  return out;
}

/// Simple 3x3 morphology close (dilate then erode) for grayscale images.
/// Works on 0..255 luminance; preserves alpha.
im.Image _morphClose3x3(im.Image src) {
  final dilated = _dilate3x3(src);
  final eroded  = _erode3x3(dilated);
  return eroded;
}

im.Image _dilate3x3(im.Image src) {
  final w = src.width, h = src.height;
  final out = im.Image.from(src);

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      int maxV = 0;
      final a = src.getPixel(x, y).a;
      for (int dy = -1; dy <= 1; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= h) continue;
        for (int dx = -1; dx <= 1; dx++) {
          final xx = x + dx;
          if (xx < 0 || xx >= w) continue;
          final lum = im.getLuminance(src.getPixel(xx, yy)).toInt();
          if (lum > maxV) maxV = lum;
        }
      }
      out.setPixelRgba(x, y, maxV, maxV, maxV, a);
    }
  }
  return out;
}

im.Image _erode3x3(im.Image src) {
  final w = src.width, h = src.height;
  final out = im.Image.from(src);

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      int minV = 255;
      final a = src.getPixel(x, y).a;
      for (int dy = -1; dy <= 1; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= h) continue;
        for (int dx = -1; dx <= 1; dx++) {
          final xx = x + dx;
          if (xx < 0 || xx >= w) continue;
          final lum = im.getLuminance(src.getPixel(xx, yy)).toInt();
          if (lum < minV) minV = lum;
        }
      }
      out.setPixelRgba(x, y, minV, minV, minV, a);
    }
  }
  return out;
}
