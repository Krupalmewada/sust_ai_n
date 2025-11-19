import 'dart:io';
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/material.dart' show Rect;

import 'image_preprocess.dart' show preprocessForOcr, IntRect;

/// Capture a photo from the live camera and OCR it as a handwritten list.
/// [cropRectInImage] is an optional UI Rect in **image pixels**; it will be
/// rounded to ints and clamped before preprocessing.
Future<List<String>> captureHandwrittenList({
  required CameraController camera,
  Rect? cropRectInImage,
}) async {
  final file = await camera.takePicture();
  return recognizeHandwrittenFromPath(
    imagePath: file.path,
    cropRectInImage: cropRectInImage,
  );
}

/// OCR a still image (file path) as a handwritten list.
Future<List<String>> recognizeHandwrittenFromPath({
  required String imagePath,
  Rect? cropRectInImage,
}) async {
  // Adapt UI Rect? -> IntRect?
  final IntRect? intCrop = cropRectInImage == null
      ? null
      : IntRect(
    left: cropRectInImage.left.round(),
    top: cropRectInImage.top.round(),
    width: cropRectInImage.width.round(),
    height: cropRectInImage.height.round(),
  );

  // Preprocess (crop, enhance, etc.) with handwriting boosters
  final bytes = await preprocessForOcr(
    imagePath,
    cropRectInImage: intCrop,
    useAdaptiveThreshold: true, // handwriting: stronger separation
    useSharpen: true,
    useMorphClose: false, // can set true if strokes are broken
  );
  if (bytes == null) return const [];

  // Write a temp file for ML Kit
  File? temp;
  try {
    temp = File(
      '${Directory.systemTemp.path}/hw_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await temp.writeAsBytes(bytes, flush: true);

    final input = InputImage.fromFile(temp);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText r = await recognizer.processImage(input);

      // Heuristic: one item per line; clean bullets/numbers.
      final cleaned = <String>[];

      // Expanded qty/unit stripping (supports fractions and common synonyms)
      final qtyUnit = RegExp(
        r'(?<=^|\s)(\d+(?:\.\d+)?|\d+/\d+|½|¼|¾)\s*'
        r'(kg|g|gm|grams?|ml|ltr|l|pack|packs?|packet|pkt|pcs?|x|dozen|dz)\b',
        caseSensitive: false,
      );

      final bullet = RegExp(r'^[\-\*\u2022\u25CF\u00B7\+]+\s*');
      final leadNum = RegExp(r'^\d+[\.\)\:\-]?\s*');
      final multX = RegExp(r'\b(\d+x|x\d+)\b', caseSensitive: false);

      for (final block in r.blocks) {
        for (final line in block.lines) {
          String t = line.text.trim();
          if (t.isEmpty) continue;

          // split by commas for "milk, eggs"
          for (final seg in t.split(',')) {
            var s = seg.trim();
            if (s.isEmpty) continue;

            s = s.replaceFirst(bullet, '');
            s = s.replaceFirst(leadNum, '');
            s = s.replaceAll(qtyUnit, '');
            s = s.replaceAll(multX, '');
            s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

            // Normalize casing: capitalize first letter of every word
            if (s.isNotEmpty) {
              s = _titleCaseWords(s);
              cleaned.add(s);
            }
          }
        }
      }

      // dedupe (case-insensitive)
      final seen = <String>{};
      final out = <String>[];
      for (final e in cleaned) {
        final k = e.toLowerCase();
        if (seen.add(k)) out.add(e);
      }
      return out;
    } finally {
      await recognizer.close();
    }
  } finally {
    try {
      if (temp != null && await temp.exists()) {
        await temp.delete();
      }
    } catch (_) {
      // ignore cleanup errors
    }
  }
}

/// Title-case helper: Capitalize first letter of each token, rest lowercase.
/// Keeps basic punctuation separators.
String _titleCaseWords(String input) {
  if (input.isEmpty) return input;

  String cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  String capCompound(String token) {
    // Handle apostrophes
    final apost = token.split(RegExp(r"[’']")).map(cap).join("'");
    // Handle hyphens
    final hy = apost.split('-').map(cap).join('-');
    // Handle slashes
    final sl = hy.split('/').map(cap).join('/');
    return sl;
  }

  return input
      .split(RegExp(r'\s+'))
      .map(capCompound)
      .join(' ')
      .trim();
}
