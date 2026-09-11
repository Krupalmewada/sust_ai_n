import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ChatService {
  ChatService() {
    _apiKey = dotenv.env['chatBotApiKey'] ?? '';
  }

  late final String _apiKey;

  static const _apiUri = 'https://api.openai.com/v1/chat/completions';

  static const _systemPrompt =
      "You are a helpful assistant called FoodBot. You should only talk about "
      "topics related to food storage, shelf life, expiry dates, preservation "
      "methods, and food freshness tips. If a user asks something unrelated to "
      "food storage or expiry, politely remind them that you can only assist "
      "with food storage and expiry-related questions.";

  final List<Map<String, String>> _messages = [
    {"role": "system", "content": _systemPrompt},
  ];

  Future<String> chatGPTAPI(String prompt) async {
    if (_apiKey.isEmpty) {
      return 'FoodBot is not configured. Add chatBotApiKey to assets/keys.env.';
    }

    _messages.add({"role": "user", "content": prompt});

    try {
      final response = await http.post(
        Uri.parse(_apiUri),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": _messages,
          "temperature": 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content =
            (data['choices'][0]['message']['content'] as String).trim();
        _messages.add({'role': 'assistant', 'content': content});
        return content;
      }

      if (kDebugMode) {
        debugPrint('OpenAI ${response.statusCode}: ${response.body}');
      }
      _messages.removeLast();
      return 'Sorry, I could not reach FoodBot right now. Please try again.';
    } catch (e) {
      if (kDebugMode) debugPrint('OpenAI exception: $e');
      _messages.removeLast();
      return 'Sorry, something went wrong. Please check your connection.';
    }
  }
}
