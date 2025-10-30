// lib/features/ocr_scan/presentation/pages/scan_page.dart
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
import '../../domain/parse_receipt_text.dart';
import '../../domain/parsed_row.dart';

enum ScanMode { receipt, groceryList, text }

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

  Future<void> _openResultSheet({required File imageFile}) async {
    // If you want to capture the returned items, await here:
    // final result = await showModalBottomSheet<List<ParsedRow>>( ... );
    // if (result != null) { /* add to inventory in caller */ }
    await showModalBottomSheet<List<ParsedRow>>(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCoverCamera(),
          Positioned(top: 8, left: 0, right: 0, child: _buildTopSegment()),
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

    final previewW = ps.height; // camera plugin swaps for portrait
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

  Widget _buildTopSegment() {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _Glass(
            blur: 14,
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: SegmentedButton<ScanMode>(
              showSelectedIcon: false,
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: ScanMode.receipt,
                  icon: Icon(Icons.receipt_long),
                  label: Text('Receipt'),
                ),
                ButtonSegment(
                  value: ScanMode.groceryList,
                  icon: Icon(Icons.checklist),
                  label: Text('Grocery List'),
                ),
                ButtonSegment(
                  value: ScanMode.text,
                  icon: Icon(Icons.edit_note),
                  label: Text('Text'),
                ),
              ],
              selected: <ScanMode>{_mode},
              onSelectionChanged: (set) {
                setState(() => _mode = set.first);
              },
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
                      color: Colors.black.withValues(alpha: 0.10),
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

// -------------------- Result Sheet: ONLY shows final list + actions ----------

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
    required this.lines,
    required this.items,
  });
  final String rawText;      // logged only
  final List<String> lines;  // logged only
  final List<ParsedRow> items; // shown & returned
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

  void _logParsed({required String raw, required List<String> lines}) {
    final snippet = raw.length > 1200 ? '${raw.substring(0, 1200)}…' : raw;
    debugPrint('==== OCR RAW (snippet) ====');
    debugPrint(snippet);
    debugPrint('==== PARSED LINES (${lines.length}) ====');
    for (final l in lines) {
      debugPrint('• $l');
    }
  }

  Future<_ParsedBundle> _compute() async {
    final path = widget.imageFile.path;

    switch (widget.mode) {
      case ScanMode.receipt:
      case ScanMode.groceryList:
        {
          Uint8List? prep = await preprocessForOcr(path);
          prep ??= await File(path).readAsBytes();

          final text = await _visionFirstThenLocal(
            preparedBytes: prep,
            originalPath: path,
          );

          final rows = widget.mode == ScanMode.receipt
              ? parseReceiptText(text)
              : parseNoteText(text);

          final lines = rows.map((r) => '${r.name} ${r.qty} ${r.unit}').toList();
          _logParsed(raw: text, lines: lines);
          return _ParsedBundle(rawText: text, lines: lines, items: rows);
        }
      case ScanMode.text:
        return _ParsedBundle(rawText: '', lines: const [], items: const []);
    }
  }

  void _onRetake() {
    Navigator.of(context).pop(); // back to camera view
  }

  void _onAddToInventory(_ParsedBundle b) {
    // Log & return items to the caller (ScanPage) if it awaits the result.
    debugPrint('=== ADD TO INVENTORY (${b.items.length}) ===');
    for (final it in b.items) {
      debugPrint('- ${it.name}  qty=${it.qty}  unit=${it.unit}');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Items added to inventory')),
    );
    Navigator.of(context).pop<List<ParsedRow>>(b.items);
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
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  FutureBuilder<_ParsedBundle>(
                    future: _future,
                    builder: (_, s) {
                      final count = s.hasData ? s.data!.items.length : 0;
                      return Text('($count)',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.6),
                          ));
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 16),

            // List area
            Expanded(
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
                  return _buildList(b);
                },
              ),
            ),

            // Bottom action bar
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: FutureBuilder<_ParsedBundle>(
                  future: _future,
                  builder: (_, snap) {
                    final b = snap.data;
                    return Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _onRetake,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Retake photo'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: b == null
                                ? null
                                : () => _onAddToInventory(b),
                            icon: const Icon(Icons.add_task_rounded),
                            label: const Text('Add to inventory'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(_ParsedBundle b) {
    // extra bottom padding so the list doesn't hide behind the action bar
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        itemCount: b.items.length,
        itemBuilder: (_, i) {
          final it = b.items[i];
          return Card(
            key: ValueKey(it),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
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
                          FocusScope.of(context).unfocus(),
                      onEditingComplete: () =>
                          FocusScope.of(context).unfocus(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 56,
                    child: TextFormField(
                      initialValue: it.qty.toString(),
                      textInputAction: TextInputAction.done,
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
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).unfocus(),
                      onEditingComplete: () =>
                          FocusScope.of(context).unfocus(),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        b.items.remove(it);
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

// -------------------------- Manual text composer -----------------------------

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
                  color: Colors.black.withValues(alpha: 0.12),
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
                    hintText:
                    'One item per line (e.g.,\nMilk 2L\nBread 1 loaf\nEggs 12 pcs)',
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
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) {
                      final items = rows;
                      return ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24)),
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
                                      color: Colors.black.withValues(alpha: 0.06)),
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
                                        width: 56,
                                        child: TextFormField(
                                          initialValue: it.qty.toString(),
                                          keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                          decoration: const InputDecoration(
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
                                        underline: const SizedBox.shrink(),
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

// ----------------------------- Small UI helpers ------------------------------

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
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: child,
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
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
