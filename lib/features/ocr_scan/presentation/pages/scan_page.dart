// lib/features/ocr_scan/presentation/pages/scan_page.dart
//
// Full-screen camera UI + real OCR wiring to your domain layer:
//
// Receipt  -> preprocessForOcr -> CloudVision (if key) -> fallback ML Kit -> parseReceiptText
// Note     -> light preprocess  -> CloudVision (if key) -> fallback ML Kit -> parseNoteText
// Barcode  -> ML Kit barcode -> OpenFoodFacts -> single ParsedRow
// Text     -> manual composer -> parseNoteText
//
// Requires --dart-define=VISION_API_KEY=YOUR_KEY when running.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../domain/image_preprocess.dart';
import '../../domain/cloud_vision_service.dart';
import '../../domain/detector_service.dart';
import '../../domain/detection_result.dart';
import '../../domain/parse_receipt_text.dart'; // contains parseReceiptText + parseNoteText
import '../../domain/parsed_row.dart';
import '../../domain/product_lookup_service.dart';

enum ScanMode { receipt, note, barcode, text }

/// Read your Google Vision API key from --dart-define.
const String _visionApiKey =
String.fromEnvironment('VISION_API_KEY', defaultValue: '');

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  CameraController? _cam;
  bool _initializing = true;
  bool _flashOn = false;
  ScanMode _mode = ScanMode.receipt;

  XFile? _lastShot;

  // Services
  final _vision = CloudVisionService(apiKey: _visionApiKey);
  final _detector = DetectorService();
  final _products = ProductLookupService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    _detector.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _cam;
    if (cam == null) return;
    if (state == AppLifecycleState.inactive) {
      cam.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final rear = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        rear,
        ResolutionPreset.max,
        imageFormatGroup: ImageFormatGroup.jpeg,
        enableAudio: false,
      );

      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);

      if (!mounted) return;
      setState(() {
        _cam = controller;
        _initializing = false;
        _flashOn = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _initializing = false);
    }
  }

  Future<void> _onShutter() async {
    if (_mode == ScanMode.text) {
      _openTextComposer();
      return;
    }
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized || cam.value.isTakingPicture) {
      return;
    }
    try {
      final shot = await cam.takePicture();
      if (!mounted) return;
      setState(() => _lastShot = shot);
      _openResultSheet(imageFile: File(shot.path));
    } catch (_) {}
  }

  Future<void> _onPickFromGallery() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (img == null || !mounted) return;
    setState(() => _lastShot = img);
    _openResultSheet(imageFile: File(img.path));
  }

  Future<void> _toggleFlash() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) return;
    _flashOn = !_flashOn;
    await cam.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
    if (!mounted) return;
    setState(() {});
  }

  void _openTextComposer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ManualTextSheet(),
    );
  }

  void _openResultSheet({required File imageFile}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResultSheet(
        imageFile: imageFile,
        mode: _mode,
        vision: _vision,
        detector: _detector,
        products: _products,
      ),
    );
  }

  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCoverCamera(),
          Positioned(top: 8, left: 0, right: 0, child: _buildTopIcons()),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
        ],
      ),
    );
  }

  Widget _buildCoverCamera() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) {
      return const SizedBox.expand();
    }
    final ps = cam.value.previewSize;
    if (ps == null) return CameraPreview(cam);

    // Swap for portrait; cover without letterboxing.
    final previewW = ps.height;
    final previewH = ps.width;

    return FittedBox(
      fit: BoxFit.cover,
      alignment: Alignment.center,
      child: SizedBox(
        width: previewW,
        height: previewH,
        child: CameraPreview(cam),
      ),
    );
  }

  Widget _buildTopIcons() {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _Glass(
            blur: 14,
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                _ModeIcon(
                  icon: Icons.receipt_long_rounded,
                  selected: _mode == ScanMode.receipt,
                  tooltip: 'Receipt',
                  onTap: () => setState(() => _mode = ScanMode.receipt),
                ),
                _ModeIcon(
                  icon: Icons.edit_note_rounded,
                  selected: _mode == ScanMode.note,
                  tooltip: 'Note',
                  onTap: () => setState(() => _mode = ScanMode.note),
                ),
                _ModeIcon(
                  icon: Icons.qr_code_scanner_rounded,
                  selected: _mode == ScanMode.barcode,
                  tooltip: 'Barcode',
                  onTap: () => setState(() => _mode = ScanMode.barcode),
                ),
                _ModeIcon(
                  icon: Icons.subject_rounded,
                  selected: _mode == ScanMode.text,
                  tooltip: 'Text',
                  onTap: () => setState(() => _mode = ScanMode.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _GlassButton(
              icon: Icons.photo_library_rounded,
              label: 'Gallery',
              onTap: _onPickFromGallery,
            ),
            SizedBox(
              width: 84,
              height: 84,
              child: RawMaterialButton(
                onPressed: _onShutter,
                elevation: 6,
                shape: const CircleBorder(),
                fillColor: Colors.white,
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withOpacity(0.10),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            _GlassButton(
              icon: _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              label: _flashOn ? 'Flash' : 'No flash',
              onTap: _toggleFlash,
            ),
          ],
        ),
      ),
    );
  }
}

// ====================== Result Sheet =========================================

class _ResultSheet extends StatefulWidget {
  const _ResultSheet({
    required this.imageFile,
    required this.mode,
    required this.vision,
    required this.detector,
    required this.products,
  });

  final File imageFile;
  final ScanMode mode;
  final CloudVisionService vision;
  final DetectorService detector;
  final ProductLookupService products;

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ParsedBundle {
  _ParsedBundle({
    required this.rawText,
    required this.lines,
    required this.items,
  });
  final String rawText;
  final List<String> lines;    // for the "Parsed" tab (human-readable)
  final List<ParsedRow> items; // for the editable "List" tab
}

class _ResultSheetState extends State<_ResultSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late Future<_ParsedBundle> _future;

  // Local OCR for fallback / fast path
  final TextRecognizer _localOcr =
  TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _future = _compute();
  }

  @override
  void dispose() {
    _tab.dispose();
    _localOcr.close();
    super.dispose();
  }

  Future<String> _ocrLocal(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final result = await _localOcr.processImage(input);
    return result.text;
  }

  /// Prefer Cloud Vision (if key present). If it returns empty,
  /// fallback to local ML Kit on the original image path.
  Future<String> _visionFirstThenLocal({
    required Uint8List preparedBytes,
    required String originalPath,
  }) async {
    String text = '';
    if (_visionApiKey.isNotEmpty) {
      try {
        text = await widget.vision.ocrBytes(preparedBytes) ?? '';
      } catch (_) {}
    }
    if (text.trim().isEmpty) {
      try {
        text = await _ocrLocal(originalPath);
      } catch (_) {}
    }
    return text.trim();
  }

  Future<_ParsedBundle> _compute() async {
    final path = widget.imageFile.path;

    switch (widget.mode) {
      case ScanMode.receipt: {
        // Strong preprocess -> Vision -> fallback local ML Kit -> parseReceiptText
        Uint8List? prep = await preprocessForOcr(path);
        prep ??= await File(path).readAsBytes();

        final text = await _visionFirstThenLocal(
          preparedBytes: prep,
          originalPath: path,
        );

        final rows = parseReceiptText(text);
        final lines = rows.map((r) => '${r.name} ${r.qty} ${r.unit}').toList();
        return _ParsedBundle(rawText: text, lines: lines, items: rows);
      }

      case ScanMode.note: {
        // Handwriting: light preprocess (same helper) -> Vision -> fallback local -> parseNoteText
        final maybe = await preprocessForOcr(path);
        final byts = maybe ?? await File(path).readAsBytes();

        final text = await _visionFirstThenLocal(
          preparedBytes: byts,
          originalPath: path,
        );

        final rows = parseNoteText(text);
        final lines = rows.map((r) => '${r.name} ${r.qty} ${r.unit}').toList();
        return _ParsedBundle(rawText: text, lines: lines, items: rows);
      }

      case ScanMode.barcode: {
        // Barcode first; if found, look up product; else OCR note fallback
        final det = await widget.detector.detectFromFile(path);
        if (det.type == DetectedType.barcode && det.barcode != null) {
          final info = await widget.products.fetchByBarcode(det.barcode!);
          final name = info?.name ?? info?.brand ?? det.barcode!;
          // Extract qty/unit if OFF string has it; default pcs:1
          final m = RegExp(r'(\d+(?:\.\d+)?)\s*(kg|g|lb|oz|l|ml)', caseSensitive: false)
              .firstMatch(info?.quantity ?? '');
          final qty = m != null
              ? double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 1.0
              : 1.0;
          final unit = (m?.group(2)?.toLowerCase() ?? 'pcs');

          final item = ParsedRow(name: name ?? det.barcode!, qty: qty, unit: unit);
          return _ParsedBundle(
            rawText:
            'Barcode: ${det.barcode}\nSymbology: ${det.symbology}\nName: ${info?.name ?? '-'}\nBrand: ${info?.brand ?? '-'}\nQuantity: ${info?.quantity ?? '-'}',
            lines: <String>[
              'code: ${det.barcode}',
              if (info?.name != null) 'name: ${info!.name}',
              if (info?.brand != null) 'brand: ${info!.brand}',
              if (info?.quantity != null) 'qty: ${info!.quantity}',
            ],
            items: [item],
          );
        }

        // No barcode → try OCR as a note fallback.
        final text2 = await _ocrLocal(path);
        final rows2 = parseNoteText(text2);
        final lines2 = rows2.map((r) => '${r.name} ${r.qty} ${r.unit}').toList();
        return _ParsedBundle(rawText: text2, lines: lines2, items: rows2);
      }

      case ScanMode.text:
      // Not used here; handled by manual composer sheet.
        return _ParsedBundle(rawText: '', lines: const [], items: const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tab,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.black54,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [Tab(text: 'Raw'), Tab(text: 'Parsed'), Tab(text: 'List')],
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<_ParsedBundle>(
                future: _future,
                builder: (_, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final b = snap.data!;
                  return TabBarView(
                    controller: _tab,
                    children: [
                      _buildRaw(),     // image
                      _buildParsed(b), // pretty lines
                      _buildList(b),   // editable items
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRaw() =>
      InteractiveViewer(child: Image.file(widget.imageFile, fit: BoxFit.contain));

  Widget _buildParsed(_ParsedBundle b) {
    if (b.lines.isEmpty && b.rawText.isNotEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(b.rawText, style: const TextStyle(fontSize: 16, height: 1.35)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (_, i) =>
          Text(b.lines[i], style: const TextStyle(fontSize: 16, height: 1.35)),
      separatorBuilder: (_, __) => const Divider(height: 16),
      itemCount: b.lines.length,
    );
  }

  Widget _buildList(_ParsedBundle b) {
    // `b.items` is a mutable List<ParsedRow>; we'll edit/remove in-place.
    return GestureDetector(
      // Tap outside a field to dismiss keyboard
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: b.items.length,
        itemBuilder: (_, i) {
          final it = b.items[i];
          return Card(
            key: ValueKey(it),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.black.withOpacity(0.06)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Item name
                  Expanded(
                    child: TextFormField(
                      initialValue: it.name,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Item name',
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => it.name = v,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).unfocus(), // hide keyboard
                      onEditingComplete: () =>
                          FocusScope.of(context).unfocus(), // also hide
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Qty
                  SizedBox(
                    width: 56,
                    child: TextFormField(
                      initialValue: it.qty.toString(),
                      textInputAction: TextInputAction.done,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Qty',
                        border: InputBorder.none,
                      ),
                      onChanged: (v) {
                        final n = double.tryParse(v.replaceAll(',', '.'));
                        if (n != null) it.qty = n;
                      },
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).unfocus(),
                      onEditingComplete: () =>
                          FocusScope.of(context).unfocus(),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Unit
                  DropdownButton<String>(
                    value: it.unit,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                      DropdownMenuItem(value: 'kg', child: Text('kg')),
                      DropdownMenuItem(value: 'g', child: Text('g')),
                      DropdownMenuItem(value: 'lb', child: Text('lb')),
                      DropdownMenuItem(value: 'oz', child: Text('oz')),
                      DropdownMenuItem(value: 'L', child: Text('L')),
                      DropdownMenuItem(value: 'ml', child: Text('ml')),
                      DropdownMenuItem(value: 'pack', child: Text('pack')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => it.unit = v);
                    },
                  ),

                  // Delete button
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() {
                        b.items.remove(it);
                      });
                      // Also dismiss keyboard if this row was focused
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

}

// ==================== Manual TEXT composer ===================================

class _ManualTextSheet extends StatefulWidget {
  const _ManualTextSheet();

  @override
  State<_ManualTextSheet> createState() => _ManualTextSheetState();
}

class _ManualTextSheetState extends State<_ManualTextSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        height: MediaQuery.of(context).size.height * 0.82 + kb,
        padding: EdgeInsets.only(bottom: kb),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Type your grocery list',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'One item per line (e.g.,\nMilk 2L\nBread 1 loaf\nEggs 12 pcs)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton.icon(
                icon: const Icon(Icons.check_rounded),
                label: const Text('Create list'),
                onPressed: () {
                  final text = _controller.text.trim();
                  final rows = parseNoteText(text);
                  // Show editable list in a simple sheet
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) {
                      final items = rows;
                      return ClipRRect(
                        borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                        child: Container(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          height: MediaQuery.of(context).size.height * 0.82,
                          child: ListView.builder(
                            padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 100),
                            itemCount: items.length,
                            itemBuilder: (_, i) {
                              final it = items[i];
                              return Card(
                                key: ValueKey(it),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                      color:
                                      Colors.black.withOpacity(0.06)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: it.name,
                                          decoration:
                                          const InputDecoration(
                                            labelText: 'Item name',
                                            border: InputBorder.none,
                                          ),
                                          onChanged: (v) => it.name = v,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: 56,
                                        child: TextFormField(
                                          initialValue: it.qty.toString(),
                                          keyboardType:
                                          const TextInputType
                                              .numberWithOptions(
                                              decimal: true),
                                          decoration:
                                          const InputDecoration(
                                            labelText: 'Qty',
                                            border: InputBorder.none,
                                          ),
                                          onChanged: (v) {
                                            final n = double.tryParse(
                                                v.replaceAll(',', '.'));
                                            if (n != null) it.qty = n;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      DropdownButton<String>(
                                        value: it.unit,
                                        underline:
                                        const SizedBox.shrink(),
                                        items: const [
                                          DropdownMenuItem(
                                              value: 'pcs',
                                              child: Text('pcs')),
                                          DropdownMenuItem(
                                              value: 'kg',
                                              child: Text('kg')),
                                          DropdownMenuItem(
                                              value: 'g',
                                              child: Text('g')),
                                          DropdownMenuItem(
                                              value: 'lb',
                                              child: Text('lb')),
                                          DropdownMenuItem(
                                              value: 'oz',
                                              child: Text('oz')),
                                          DropdownMenuItem(
                                              value: 'L',
                                              child: Text('L')),
                                          DropdownMenuItem(
                                              value: 'ml',
                                              child: Text('ml')),
                                          DropdownMenuItem(
                                              value: 'pack',
                                              child: Text('pack')),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) it.unit = v;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Small UI helpers =======================================

class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.blur = 12,
    this.radius = 20,
    this.padding,
  });

  final double blur;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ModeIcon extends StatelessWidget {
  const _ModeIcon({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? Colors.white.withOpacity(0.92)
        : Colors.white.withOpacity(0.10);
    final fg = selected ? Colors.black87 : Colors.white;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: fg, size: 20),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      blur: 10,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
