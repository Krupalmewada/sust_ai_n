import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../domain/parse_receipt_text.dart';
import '../../domain/parsed_row.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with SingleTickerProviderStateMixin {
  bool _loading = false;
  String _text = 'No text yet';
  List<ParsedRow> _rows = [];
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this); // Raw | Parsed
  }

  Future<void> _pickAndScan(ImageSource source) async {
    try {
      setState(() => _loading = true);

      final picked = await ImagePicker().pickImage(source: source);
      if (picked == null) {
        setState(() { _loading = false; _text = 'Scan canceled'; _rows = []; });
        return;
      }

      final input = InputImage.fromFile(File(picked.path));
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final result = await recognizer.processImage(input);
      await recognizer.close();

      final raw = result.text;
      final rows = parseReceiptText(raw);

      setState(() {
        _loading = false;
        _text = raw.isEmpty ? 'No text detected' : raw;
        _rows = rows;
        _tab.index = 1; // switch to Parsed tab automatically
      });
    } catch (e) {
      setState(() { _loading = false; _text = 'Error: $e'; _rows = []; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        bottom: TabBar(
          controller: _tab,
            tabs: const [
              Tab(text: 'Raw'),
              Tab(text: 'Parsed'),
            ]
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () => _pickAndScan(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Use camera'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickAndScan(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Pick from gallery'),
              ),
            ],
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // RAW
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(_text, style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                ),
                // PARSED
                _ParsedList(rows: _rows),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParsedList extends StatelessWidget {
  final List<ParsedRow> rows;
  const _ParsedList({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('No items parsed yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = rows[i];
        return ListTile(
          leading: Checkbox(
            value: true, // placeholder; selection will come later
            onChanged: (_) {},
          ),
          title: Text(
            r.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: r.needsReview ? Colors.orange : null,
            ),
          ),
          subtitle: Text(
            '${r.qty} ${r.unit}  '
                '${r.unitPrice != null ? ' @ \$${r.unitPrice!.toStringAsFixed(2)}' : ''}'
                '${r.lineTotal != null ? '  ⇒ \$${r.lineTotal!.toStringAsFixed(2)}' : ''}',
          ),
          trailing: r.needsReview
              ? const Chip(label: Text('Review'), visualDensity: VisualDensity.compact)
              : null,
        );
      },
    );
  }
}
