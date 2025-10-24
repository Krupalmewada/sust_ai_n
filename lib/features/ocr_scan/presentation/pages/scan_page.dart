// Verdanza Tech – Sustain
// Scan page (NO external doc scanner):
// - One-tap capture with CameraController for Receipt/Note
// - OCR with google_mlkit_text_recognition
// - Barcode scan + OpenFoodFacts lookup -> ParsedRow
// - Handwritten parsing -> clean item list
// - Refined camera UI (chips, scrim, finder, floating shutter)

import 'dart:io';
import 'dart:math' show max;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../ocr_scan/domain/detector_service.dart';
import '../../../ocr_scan/domain/parse_receipt_text.dart';
import '../../../ocr_scan/domain/parsed_row.dart';
import '../../../ocr_scan/domain/product_lookup_service.dart';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import '../../../ocr_scan/domain/cloud_vision_service.dart';




/// Manual scan modes
enum ScanMode { receipt, note, barcode, text }

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class EditableItem {
  String name;
  double qty;
  String unit;
  EditableItem({required this.name, this.qty = 1, this.unit = 'pcs'});
}


class _ScanPageState extends State<ScanPage> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // Camera
  CameraController? _cam;
  bool _flashOn = false;

  void _onModeChange(ScanMode m) {
    setState(() => _mode = m);
    if (m == ScanMode.text) {
      // Open the text dialog right away
      // microtask avoids setState + dialog in the same frame warning
      Future.microtask(_enterTextManually);
    }
  }

  List<EditableItem> _toEditableItemsFromCurrent() {
    if (_mode == ScanMode.receipt && _parsedReceipt.isNotEmpty) {
      return _parsedReceipt
          .map((r) => EditableItem(
        name: r.name,
        qty: r.qty,
        unit: r.unit.isEmpty ? 'pcs' : r.unit,
      ))
          .toList();
    }
    if ((_mode == ScanMode.note || _mode == ScanMode.text) && _parsedItems.isNotEmpty) {
      return _parsedItems.map((n) => EditableItem(name: n, qty: 1, unit: 'pcs')).toList();
    }
    if (_mode == ScanMode.barcode && _parsedReceipt.isNotEmpty) {
      final r = _parsedReceipt.first;
      return [EditableItem(name: r.name, qty: r.qty, unit: r.unit.isEmpty ? 'pcs' : r.unit)];
    }
    return [];
  }

  Future<void> _openEditorIfAny() async {
    final items = _toEditableItemsFromCurrent();
    if (items.isEmpty) return;

    final updated = await showModalBottomSheet<List<EditableItem>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => _EditItemsSheet(initial: items),
    );

    if (updated != null) {
      // If you want to keep the edited list around in the page state, you can
      // map it back into _parsedReceipt/_parsedItems here. For now we just show a toast.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Items ready to add to inventory (dummy).')),
      );
    }
  }


  // UI & data
  bool _busy = false;
  String _raw = '';
  List<ParsedRow> _parsedReceipt = const []; // for receipts and barcode mapped rows
  List<String> _parsedItems = const [];      // for handwritten note/text
  ScanMode _mode = ScanMode.receipt;

  // Services
  final _detector = DetectorService();
  final _products = ProductLookupService();
  final _picker = ImagePicker();
  // NOTE: move to secure storage / env in production.
  static const String _visionApiKey = 'AIzaSyBZCJKX9X4YJ2taycS8cJQ6Bfz2AKwHwAY';
  late final CloudVisionService _vision = CloudVisionService(apiKey: _visionApiKey);


  final TextRecognizer _textRecognizer =
  TextRecognizer(script: TextRecognitionScript.latin);

  // Product details (barcode mode)
  // ignore: unused_field
  ProductInfo? _product;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final cam = cams.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      _cam = CameraController(cam, ResolutionPreset.high, enableAudio: false);
      await _cam!.initialize();
      if (mounted) setState(() {});
    } catch (_) {/* ignore */}
  }

  // ---------- Actions ----------

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final XFile? x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (x == null) return;

      if (_mode == ScanMode.barcode) {
        await _runBarcodeOnly(x.path);
      } else if (_mode == ScanMode.note) {
        await _doNoteOcr(x.path);
      } else {
        await _ocrWithFallback(x.path); // your existing local OCR for receipt/text
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _snapButtonAction() async {
    switch (_mode) {
      case ScanMode.text:
        await _enterTextManually();
        break;
      case ScanMode.barcode:
        await _snapAndDetectBarcode();
        break;
      case ScanMode.receipt:
        await _snapAndOcrSingleFrame(); // your local receipt OCR
        break;
      case ScanMode.note:
      // One-tap capture, then Cloud OCR.
        if (_busy || _cam == null || !_cam!.value.isInitialized) {
          // fallback: pick from gallery
          return _pickFromGallery();
        }
        setState(() => _busy = true);
        try {
          await _cam!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
          final file = await _cam!.takePicture();
          await _doNoteOcr(file.path);
        } finally {
          if (mounted) setState(() => _busy = false);
        }
        break;
    }
  }

  /// Downscale and JPEG-encode for Cloud Vision (keeps natural look).
  Future<Uint8List> _prepareForCloud(String path) async {
    final bytes = await File(path).readAsBytes();
    img.Image? src = img.decodeImage(bytes);
    if (src == null) return bytes;

    // Respect EXIF and cap the longer side ~1600px (enough for handwriting).
    src = img.bakeOrientation(src);
    final int longSide = src.width > src.height ? src.width : src.height;
    if (longSide > 1600) {
      final scale = 1600 / longSide;
      src = img.copyResize(src,
          width: (src.width * scale).round(),
          height: (src.height * scale).round());
    }

    // Gentle grayscale improves compression a bit (optional).
    src = img.grayscale(src);

    // JPEG ~85 gives good quality vs size.
    return Uint8List.fromList(img.encodeJpg(src, quality: 85));
  }

  /// Always-accurate path for Note mode: Cloud Vision first, local OCR as fallback.
  Future<void> _doNoteOcr(String originalPath) async {
    String text = '';

    // Pass 1: Cloud Vision (best for handwriting)
    try {
      final jpg = await _prepareForCloud(originalPath);
      text = await _vision.ocrBytes(jpg);
    } catch (_) {
      // ignore errors; we'll fallback
    }

    // Pass 2: fallback to local OCR if cloud empty/unavailable
    if (text.trim().isEmpty) {
      try {
        // You already have this method; it includes preprocessing if you kept it.
        final input = InputImage.fromFilePath(originalPath);
        final recognized = await _textRecognizer.processImage(input);
        text = recognized.text;
      } catch (_) {/* ignore */}
    }

    _product = null;
    _raw = text;

    // Parse to list using your existing heuristic
    _parsedReceipt = const [];
    _parsedItems = _extractItemsFromHandwritten(text);

    if (text.trim().isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text recognized. Try flash or get closer.')),
      );
    }
    await _openEditorIfAny();
    setState(() {});
  }

  /// Preprocess image to improve OCR (deskew-lite, denoise, contrast, binarize)
  /// Works with image ^4.x without using sharpen()/threshold() helpers.
  Future<String> _preprocessForOcr(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      img.Image? src = img.decodeImage(bytes);
      if (src == null) return path;

      // Fix EXIF orientation
      src = img.bakeOrientation(src);

      // Upscale small images (helps handwriting)
      if (src.width < 1200) {
        final scale = 1200 / src.width;
        src = img.copyResize(src, width: (src.width * scale).round());
      }

      // Grayscale
      src = img.grayscale(src);

      // Mild denoise
      src = img.gaussianBlur(src, radius: 1);

      // Slight contrast boost
      src = img.adjustColor(src, contrast: 1.15, brightness: 0);

      // Adaptive threshold (Otsu)
      final t = _otsuThreshold(src);
      for (int y = 0; y < src.height; y++) {
        for (int x = 0; x < src.width; x++) {
          final px = src.getPixel(x, y); // Pixel
          final int lum = ((px.r * 299 + px.g * 587 + px.b * 114) / 1000).round();
          final int v = lum < t ? 0 : 255;
          src.setPixelRgba(x, y, v, v, v, 255);
        }
      }

      final out = File('${Directory.systemTemp.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.png');
      await out.writeAsBytes(img.encodePng(src));
      return out.path;
    } catch (_) {
      // Any failure → use original
      return path;
    }
  }

  int _otsuThreshold(img.Image g) {
    // Build histogram (0..255)
    final hist = List<int>.filled(256, 0);
    for (int y = 0; y < g.height; y++) {
      for (int x = 0; x < g.width; x++) {
        final p = g.getPixel(x, y);
        final int lum = ((p.r * 299 + p.g * 587 + p.b * 114) / 1000).round();
        hist[lum]++;
      }
    }

    final int total = g.width * g.height;
    double sum = 0;
    for (int i = 0; i < 256; i++) {
      sum += i * hist[i];
    }

    int wB = 0;
    double sumB = 0;
    double maxVar = -1;
    int threshold = 128;

    for (int t = 0; t < 256; t++) {
      wB += hist[t];
      if (wB == 0) continue;
      final wF = total - wB;
      if (wF == 0) break;

      sumB += t * hist[t];
      final mB = sumB / wB;
      final mF = (sum - sumB) / wF;
      final between = wB * wF * (mB - mF) * (mB - mF);

      if (between > maxVar) {
        maxVar = between;
        threshold = t;
      }
    }
    // Nudge threshold slightly darker for handwriting
    return (threshold - 10).clamp(0, 255);
  }

  /// One-tap capture from our own camera, then OCR (for Receipt/Note)
  Future<void> _snapAndOcrSingleFrame() async {
    if (_busy || _cam == null || !_cam!.value.isInitialized) {
      // graceful fallback if camera isn’t ready
      return _pickFromGallery();
    }
    setState(() => _busy = true);
    try {
      await _cam!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
      final file = await _cam!.takePicture();
      await _ocrWithFallback(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  Future<void> _snapAndDetectBarcode() async {
    if (_busy || _cam == null || !_cam!.value.isInitialized) return;
    setState(() => _busy = true);
    try {
      await _cam!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
      final file = await _cam!.takePicture();
      await _runBarcodeOnly(file.path);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runBarcodeOnly(String path) async {
    final res = await _detector.detectFromFile(path);

    final code = res.barcode ?? '';
    _product = null;

    _raw = code.isEmpty
        ? 'No barcode found.'
        : 'BARCODE: ${res.symbology}\n\n$code';

    // Clear previous parsed results
    _parsedReceipt = const [];
    _parsedItems = const [];

    if (code.isNotEmpty) {
      try {
        final p = await _products.fetchByBarcode(code); // ProductInfo? from OpenFoodFacts
        _product = p;
        _parsedReceipt = [_rowFromProduct(p, code: code)]; // 1 row, qty=1
      } catch (_) {
        _parsedReceipt = [_rowFromProduct(null, code: code)]; // fallback row
      }
    }
    await _openEditorIfAny();
    setState(() {});
  }

  Future<void> _ocrWithFallback(String originalPath) async {
    String? text;

    // Pass 1: preprocessed
    try {
      final pre = await _preprocessForOcr(originalPath);
      text = await _runOcr(pre);
    } catch (_) {/* ignore */}

    // Pass 2: fallback to original if empty
    if (text == null || text.trim().isEmpty) {
      try {
        text = await _runOcr(originalPath);
      } catch (_) {/* ignore */}
    }

    text ??= '';

    _product = null;
    _raw = text;

    if (_mode == ScanMode.receipt && text.isNotEmpty) {
      _parsedReceipt = parseReceiptText(text);
      _parsedItems = _parsedReceipt.map((r) => r.name).toList(growable: false);
    } else if (_mode == ScanMode.note || _mode == ScanMode.text) {
      _parsedReceipt = const [];
      _parsedItems = _extractItemsFromHandwritten(text);
    } else {
      _parsedReceipt = const [];
      _parsedItems = const [];
    }

    if (text.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text recognized. Try flash or get closer.')),
      );
    }
    await _openEditorIfAny();

    setState(() {});
  }

  Future<String> _runOcr(String path) async {
    final input = InputImage.fromFilePath(path);
    final recognized = await _textRecognizer.processImage(input);
    return recognized.text;
  }


  Future<void> _enterTextManually() async {
    final controller = TextEditingController(text: _raw.isNotEmpty ? _raw : '');
    final txt = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter text'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(hintText: 'Paste or type items here...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Use')),
        ],
      ),
    );
    if (txt == null || txt.trim().isEmpty) return;

    _product = null;
    _raw = txt.trim();
    _parsedReceipt = const [];
    _parsedItems = _extractItemsFromHandwritten(_raw);
    setState(() {});
  }

  @override
  void dispose() {
    _cam?.dispose();
    _detector.dispose();
    _textRecognizer.close();
    _tab.dispose();
    super.dispose();
  }

  // ---------- Helpers ----------

  /// Map a looked-up product into a single ParsedRow (qty = 1).
  ParsedRow _rowFromProduct(ProductInfo? p, {required String code}) {
    final candidates = <String>[
      p?.name?.trim() ?? '',
      [p?.brand?.trim() ?? '', p?.quantity?.trim() ?? '']
          .where((s) => s.isNotEmpty)
          .join(' ')
          .trim(),
    ].where((s) => s.isNotEmpty).toList();

    final displayName = candidates.isNotEmpty ? candidates.first : 'Product $code';

    // tiny heuristic for nicer unit
    final q = (p?.quantity ?? '').toLowerCase();
    final unit = q.contains('can')
        ? 'can'
        : q.contains('bottle')
        ? 'bottle'
        : 'pcs';

    return ParsedRow(
      name: displayName,
      qty: 1,
      unit: unit,
      unitPrice: null,
      lineTotal: null,
      needsReview: p == null,
      raw: 'barcode:$code',
    );
  }

  /// From OCR text -> clean item list for handwritten notes.
  List<String> _extractItemsFromHandwritten(String raw) {
    final lines = raw
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final cleaned = <String>[];
    final bullet = RegExp(r'^[\-\*\u2022\u25CF\u00B7\+]+\s*'); // -, *, •, ●, ·, +
    final leadNum = RegExp(r'^\d+[\.\)\:\-]?\s*');             // "1.", "2)", "3 -"
    final qtyUnit =
    RegExp(r'\b(\d+(\.\d+)?)\s*(kg|g|gm|grams?|ml|ltr|l|pack|pcs?|x)\b', caseSensitive: false);

    for (var line in lines) {
      for (var seg in line.split(',')) {
        var t = seg.trim();
        if (t.isEmpty) continue;

        t = t.replaceFirst(bullet, '');
        t = t.replaceFirst(leadNum, '');
        t = t.replaceAll(qtyUnit, '');
        t = t.replaceAll(RegExp(r'\b(\d+x|x\d+)\b', caseSensitive: false), '').trim();
        t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

        if (t.isNotEmpty) cleaned.add(t);
      }
    }

    final seen = <String>{};
    final unique = <String>[];
    for (final e in cleaned) {
      final k = e.toLowerCase();
      if (seen.add(k)) unique.add(e);
    }
    return unique;
  }

  // ---------- UI ----------

  Widget _modeSegmented() {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .30),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SegmentChip(
                label: 'Receipt',
                selected: _mode == ScanMode.receipt,
                onTap: () => _onModeChange(ScanMode.receipt),
              ),
              _SegmentChip(
                label: 'Note',
                selected: _mode == ScanMode.note,
                onTap: () => _onModeChange(ScanMode.note),
              ),
              _SegmentChip(
                label: 'Barcode',
                selected: _mode == ScanMode.barcode,
                onTap: () => _onModeChange(ScanMode.barcode),
              ),
              _SegmentChip(
                label: 'Text',
                selected: _mode == ScanMode.text,
                onTap: () => _onModeChange(ScanMode.text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _floatingBottomControls(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: max(12.0, bottom) + 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundButton(
            icon: Icons.photo_library_outlined,
            label: 'Gallery',
            onTap: _pickFromGallery,
          ),
          RawMaterialButton(
            onPressed: _snapButtonAction,
            shape: const CircleBorder(),
            constraints: const BoxConstraints.tightFor(width: 72, height: 72),
            elevation: 4,
            fillColor: Colors.white,
            child: Icon(
              _mode == ScanMode.text ? Icons.edit_outlined : Icons.camera_alt_outlined,
              size: 30,
              color: Colors.black,
            ),
          ),
          _RoundButton(
            icon: _flashOn ? Icons.flash_on : Icons.flash_off,
            label: _flashOn ? 'Flash' : 'No flash',
            onTap: () async {
              if (_cam == null || !(_cam!.value.isInitialized)) return;
              setState(() => _flashOn = !_flashOn);
              await _cam!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Type text',
            onPressed: _enterTextManually,
            icon: const Icon(Icons.text_fields_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Full-screen camera
          Positioned.fill(
            child: (_cam?.value.isInitialized ?? false)
                ? CameraPreview(_cam!)
                : const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
          // Top scrim + mode chips
          Positioned(
            top: 0, left: 0, right: 0,
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Color(0xAA000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          _modeSegmented(),
          // Finder frame
          Positioned.fill(child: IgnorePointer(ignoring: true, child: CustomPaint(painter: _FinderPainter(_mode)))),
          // Bottom controls
          _floatingBottomControls(context),
        ],
      ),
    );
  }
  // ignore: unused_element - might come in handy
  String _formatSubtitle(ParsedRow r) {
    final qty = r.qty.toStringAsFixed(r.qty.truncateToDouble() == r.qty ? 0 : 2);
    final up  = r.unitPrice != null ? '@ \$${r.unitPrice!.toStringAsFixed(2)}' : '';
    final lt  = r.lineTotal != null ? ' ⇒ \$${r.lineTotal!.toStringAsFixed(2)}' : '';
    return '$qty ${r.unit}  $up  $lt'.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

// ---------- Small UI atoms ----------

class _SegmentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegmentChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.white : Colors.transparent;
    final fg = selected ? Colors.black : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkResponse(
          onTap: onTap,
          radius: 28,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .92),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.black),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}

class _FinderPainter extends CustomPainter {
  _FinderPainter(this.mode);
  final ScanMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    // Reserve some space for shutter row so caption stays visible
    const double bottomReservedPx = 140; // ≈ height used by controls
    const double upShiftFactor = 0.04;   // nudge frame up a bit

    // --- SIZE PER MODE ---
    late double w, h;
    switch (mode) {
      case ScanMode.receipt:
      // 🔁 swapped: receipt uses the bigger "old note" size
        w = size.width * 0.94;
        h = size.height * 0.76;
        break;
      case ScanMode.note:
      // 🔁 swapped: note uses the smaller "old receipt" size
        w = size.width * 0.94;
        h = size.height * 0.70;
        break;
      case ScanMode.barcode:
        w = size.width * 0.82;
        final targetH = w / 1.8;                    // ~1.8:1
        final maxH = size.height * 0.32;
        h = targetH.clamp(80.0, maxH);
        break;
      case ScanMode.text:
        return; // no guide
    }

    // --- POSITION (centered, then slightly up) ---
    double x = (size.width - w) / 2;
    double y = (size.height - h) / 2;

    // nudge up a bit
    y -= size.height * upShiftFactor;

    // ensure the caption will still fit above the shutter row
    final captionHeightEstimate = 18.0;
    final captionGap = 10.0;
    final maxY =
        size.height - bottomReservedPx - captionGap - captionHeightEstimate - h;
    if (y > maxY) y = maxY;
    if (y < 12) y = 12; // keep some top margin

    // --- DRAW ---
    final radius = switch (mode) {
      ScanMode.barcode => 12.0,
      ScanMode.note => 24.0,
      ScanMode.receipt => 22.0,
      _ => 18.0,
    };

    final rrect =
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(radius));

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = Colors.black.withValues(alpha: 0.25);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.95);

    canvas.drawRRect(rrect, glow);
    canvas.drawRRect(rrect, stroke);

    // --- CAPTION ---
    final label = switch (mode) {
      ScanMode.receipt => 'Fit the receipt inside the frame',
      ScanMode.note => 'Position the list inside the box',
      ScanMode.barcode => 'Align the barcode here',
      _ => null,
    };

    if (label != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * 0.94);

      // place just below the frame, but keep above the control row
      double cy = y + h + captionGap;
      final maxCy = size.height - bottomReservedPx - tp.height;
      if (cy > maxCy) cy = maxCy;
      tp.paint(canvas, Offset((size.width - tp.width) / 2, cy));
    }
  }

  @override
  bool shouldRepaint(covariant _FinderPainter old) => old.mode != mode;
}

// ignore: unused_element
class _ProductCard extends StatelessWidget {
  final ProductInfo info;
  final VoidCallback onAdd;
  const _ProductCard({required this.info, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: info.imageUrl != null
                ? Image.network(info.imageUrl!, width: 64, height: 64, fit: BoxFit.cover)
                : Container(width: 64, height: 64, color: Colors.grey[200], child: const Icon(Icons.inventory_2_outlined)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(info.name ?? 'Unknown product', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text([info.brand, info.quantity].where((e) => (e ?? '').isNotEmpty).join(' • '), style: const TextStyle(color: Colors.black54)),
              Text('Barcode: ${info.code}', style: const TextStyle(color: Colors.black45, fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: onAdd, child: const Text('Add')),
        ],
      ),
    );
  }
}

class _EditItemsSheet extends StatefulWidget {
  final List<EditableItem> initial;
  const _EditItemsSheet({required this.initial});

  @override
  State<_EditItemsSheet> createState() => _EditItemsSheetState();
}

class _EditItemsSheetState extends State<_EditItemsSheet> {
  late List<EditableItem> items;

  @override
  void initState() {
    super.initState();
    // clone to avoid mutating caller list
    items = widget.initial
        .map((e) => EditableItem(name: e.name, qty: e.qty, unit: e.unit))
        .toList();
  }

  void _addRow() {
    setState(() => items.add(EditableItem(name: '', qty: 1, unit: 'pcs')));
  }

  void _removeItem(EditableItem it) {
    setState(() => items.remove(it)); // delete by identity (correct row)
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: media.size.height * 0.9,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Edit items'),
              automaticallyImplyLeading: false,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  // Keep reordering but NO swipe-to-delete
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final it = items.removeAt(oldIndex);
                        items.insert(newIndex, it);
                      });
                    },
                    itemBuilder: (context, i) {
                      final it = items[i];
                      return Card(
                        key: ValueKey(it), // stable key = object identity
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Drag handle (so users know they can reorder)
                              const Padding(
                                padding: EdgeInsets.only(top: 16, right: 8),
                                child: Icon(Icons.drag_indicator, color: Colors.black45),
                              ),
                              Expanded(
                                flex: 5,
                                child: TextFormField(
                                  initialValue: it.name,
                                  decoration: const InputDecoration(labelText: 'Item name'),
                                  onChanged: (v) => it.name = v,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: it.qty.toStringAsFixed(
                                    it.qty.truncateToDouble() == it.qty ? 0 : 2,
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Qty'),
                                  onChanged: (v) {
                                    final d = double.tryParse(v);
                                    if (d != null) it.qty = d;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: it.unit,
                                  decoration: const InputDecoration(labelText: 'Unit'),
                                  onChanged: (v) =>
                                  it.unit = v.trim().isEmpty ? 'pcs' : v.trim(),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove',
                                onPressed: () => _removeItem(it),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _addRow,
                        icon: const Icon(Icons.add),
                        label: const Text('Add item'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {
                          // TODO: wire to inventory later
                          Navigator.pop(context, items);
                        },
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('Add to inventory'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


