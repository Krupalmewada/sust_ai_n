// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/cloud_vision_service.dart';
import '../../domain/image_preprocess.dart';
import '../../domain/parse_receipt_text.dart';
import '../../domain/parsed_row.dart';

// NOTE: Text mode removed
enum ScanMode { receipt, note }

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

  final _vision = CloudVisionService(apiKey: _visionApiKey);

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

  Future<void> _toggleFlash() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) return;
    _flashOn = !_flashOn;
    await cam.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _onShutter() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized || cam.value.isTakingPicture) {
      return;
    }
    try {
      final shot = await cam.takePicture();
      if (!mounted) return;
      _openResultSheet(imageFile: File(shot.path));
    } catch (_) {}
  }

  Future<void> _onPickFromGallery() async {
    final picker = ImagePicker();
    final img =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (img == null || !mounted) return;
    _openResultSheet(imageFile: File(img.path));
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
      ),
    );
  }

  // ----------------------------- UI ------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCamera(),
          Positioned(top: 16, left: 0, right: 0, child: _buildTopRibbon()),
          Positioned(bottom: 26, left: 0, right: 0, child: _buildBottomBar()),
        ],
      ),
    );
  }

  Widget _buildCamera() {
    if (_initializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) {
      return const SizedBox.expand();
    }
    final ps = cam.value.previewSize;
    if (ps == null) return CameraPreview(cam);

    // Fill portrait without letterboxing.
    final previewW = ps.height;
    final previewH = ps.width;
    return FittedBox(
      fit: BoxFit.cover,
      alignment: Alignment.center,
      child:
      SizedBox(width: previewW, height: previewH, child: CameraPreview(cam)),
    );
  }

  // ---------- TOP RIBBON (two chips, no overflow) ----------
  Widget _buildTopRibbon() {
    const double chipHeight = 36.0;
    const double gap = 6.0;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(48),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(48),
                border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: _SegmentChipFlex(
                      height: chipHeight,
                      label: 'Receipt',
                      icon: Icons.receipt_long_rounded,
                      selected: _mode == ScanMode.receipt,
                      onTap: () => setState(() => _mode = ScanMode.receipt),
                    ),
                  ),
                  const SizedBox(width: gap),
                  Expanded(
                    child: _SegmentChipFlex(
                      height: chipHeight,
                      label: 'Grocery List',
                      icon: Icons.playlist_add_check_rounded,
                      selected: _mode == ScanMode.note,
                      onTap: () => setState(() => _mode = ScanMode.note),
                    ),
                  ),
                ],
              ),
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _CircleGlassButton(
              icon: Icons.photo_library_rounded,
              onTap: _onPickFromGallery,
            ),
            SizedBox(
              width: 88,
              height: 88,
              child: InkResponse(
                radius: 56,
                highlightShape: BoxShape.circle,
                onTap: _onShutter,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.camera_alt_rounded,
                        size: 34, color: Colors.black87),
                  ),
                ),
              ),
            ),
            _CircleGlassButton(
              icon: _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              onTap: _toggleFlash,
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleGlassButton extends StatelessWidget {
  const _CircleGlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.black.withValues(alpha: 0.30),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Center(
                child: Icon(icon, size: 26, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ====================== Result Sheet (list-only UI) ===========================

class _ResultSheet extends StatefulWidget {
  const _ResultSheet({
    required this.imageFile,
    required this.mode,
    required this.vision,
  });

  final File imageFile;
  final ScanMode mode;
  final CloudVisionService vision;

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ParsedBundle {
  _ParsedBundle({
    required this.rawText,
    required this.items,
  });
  final String rawText;
  final List<ParsedRow> items;
}

class _ResultSheetState extends State<_ResultSheet> {
  late Future<_ParsedBundle> _future;

  final TextRecognizer _localOcr =
  TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void initState() {
    super.initState();
    _future = _compute();
  }

  @override
  void dispose() {
    _localOcr.close();
    super.dispose();
  }

  Future<String> _ocrLocal(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final result = await _localOcr.processImage(input);
    return result.text;
  }

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
      case ScanMode.receipt:
        Uint8List? prep = await preprocessForOcr(path);
        prep ??= await File(path).readAsBytes();
        final text =
        await _visionFirstThenLocal(preparedBytes: prep, originalPath: path);
        final rows = parseReceiptText(text);

        debugPrint('==== OCR RAW (<=600 chars) ====\n'
            '${text.substring(0, text.length.clamp(0, 600))}');
        debugPrint('==== PARSED (${rows.length}) ====');
        for (final r in rows) {
          debugPrint('- ${r.name} ${r.qty} ${r.unit}');
        }

        return _ParsedBundle(rawText: text, items: rows);

      case ScanMode.note:
        final maybe = await preprocessForOcr(path);
        final byts = maybe ?? await File(path).readAsBytes();
        final text =
        await _visionFirstThenLocal(preparedBytes: byts, originalPath: path);
        final rows = parseNoteText(text);

        debugPrint('==== OCR RAW (<=600 chars) ====\n'
            '${text.substring(0, text.length.clamp(0, 600))}');
        debugPrint('==== PARSED (${rows.length}) ====');
        for (final r in rows) {
          debugPrint('- ${r.name} ${r.qty} ${r.unit}');
        }

        return _ParsedBundle(rawText: text, items: rows);
    }
  }

  void _onAddToInventory(_ParsedBundle b) {
    debugPrint('=== ADD TO INVENTORY (${b.items.length}) ===');
    for (final it in b.items) {
      debugPrint('- ${it.name}  qty=${it.qty}  unit=${it.unit}');
    }
    Navigator.of(context).pop<List<ParsedRow>>(b.items);
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        color: bg,
        height: MediaQuery.of(context).size.height * 0.82,
        child: FutureBuilder<_ParsedBundle>(
          future: _future,
          builder: (_, snap) {
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final b = snap.data!;
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(height: 8),

                // Add item button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Add item'),
                      onPressed: () {
                        setState(() {
                          b.items.add(ParsedRow(name: '', qty: 1, unit: 'pcs'));
                        });
                      },
                    ),
                  ),
                ),

                Expanded(child: _buildList(b)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Retake photo'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.playlist_add_check_rounded),
                          label: const Text('Add to inventory'),
                          onPressed: () => _onAddToInventory(b),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(_ParsedBundle b) {
    final items = b.items;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final it = items[i];
          return Card(
            key: ValueKey(it), // keep row identity stable
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.black.withValues(alpha: 0.07)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: it.name,
                      decoration: const InputDecoration(
                        labelText: 'Item name',
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => it.name = v,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 64,
                    child: TextFormField(
                      initialValue: it.qty.toString(),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Qty',
                        border: InputBorder.none,
                      ),
                      onChanged: (v) {
                        final n = double.tryParse(v.replaceAll(',', '.'));
                        if (n != null) it.qty = n;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
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
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() {
                        // remove the exact object next to the trash icon
                        items.remove(it);
                      });
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

// ---------------- Small UI helper: pill chip (two-state) ----------------
class _SegmentChipFlex extends StatelessWidget {
  const _SegmentChipFlex({
    required this.height,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final double height;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = selected ? Colors.black : Colors.white;
    final Color fg = selected ? Colors.white : Colors.black87;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(40),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: selected ? Colors.transparent : Colors.black.withValues(alpha: 0.22),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: .1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

