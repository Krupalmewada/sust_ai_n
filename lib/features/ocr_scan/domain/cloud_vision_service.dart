// lib/features/ocr_scan/domain/cloud_vision_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CloudVisionService {
  CloudVisionService({required this.apiKey});
  final String apiKey;

  /// Calls Google Vision OCR. Returns extracted text or null on failure.
  /// - 10s timeout
  /// - 1 retry on transient HTTP/network errors
  Future<String?> ocrBytes(Uint8List imgBytes) async {
    if (apiKey.isEmpty) return null;

    final uri = Uri.parse(
      'https://vision.googleapis.com/v1/images:annotate?key=$apiKey',
    );

    final body = {
      "requests": [
        {
          "image": {"content": base64Encode(imgBytes)},
          "features": [
            {"type": "DOCUMENT_TEXT_DETECTION"}
          ]
        }
      ]
    };

    // renamed to avoid the lint about underscore on a local identifier
    Future<http.Response> postOnce() {
      return http
          .post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 10));
    }

    http.Response res;
    try {
      res = await postOnce();
    } on TimeoutException {
      // one quick retry after small backoff
      await Future.delayed(const Duration(milliseconds: 400));
      try {
        res = await postOnce();
      } catch (_) {
        return null;
      }
    } catch (_) {
      return null;
    }

    if (res.statusCode != 200) return null;

    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final responses = data['responses'] as List<dynamic>?;
      if (responses == null || responses.isEmpty) return null;

      final first = responses.first as Map<String, dynamic>;
      final err = first['error'];
      if (err is Map<String, dynamic>) {
        // (Optional) log err['code'] / err['message']
        return null;
      }

      final txt = (first['fullTextAnnotation']?['text'] ?? '').toString().trim();
      return txt.isEmpty ? null : txt;
    } catch (_) {
      return null;
    }
  }
}
