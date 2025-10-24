import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Minimal Google Cloud Vision wrapper for DOCUMENT_TEXT_DETECTION.
class CloudVisionService {
  CloudVisionService({required this.apiKey});
  final String apiKey;

  Future<String> ocrBytes(Uint8List jpgBytes) async {
    final uri = Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey');

    final body = {
      'requests': [
        {
          'image': {'content': base64Encode(jpgBytes)},
          'features': [
            {'type': 'DOCUMENT_TEXT_DETECTION'}
          ]
        }
      ]
    };

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception('Vision API error: ${res.statusCode} ${res.body}');
    }

    final data = (jsonDecode(res.body) as Map<String, dynamic>);
    final responses = (data['responses'] as List?) ?? const [];
    if (responses.isEmpty) return '';
    final text = ((responses.first as Map<String, dynamic>)['fullTextAnnotation']
    as Map<String, dynamic>?)?['text']
    as String?;
    return (text ?? '').trim();
  }
}
