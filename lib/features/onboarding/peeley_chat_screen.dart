
// lib/screens/peeley_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:sust_ai_n/features/onboarding/peeley_models.dart';
import 'package:sust_ai_n/features/onboarding/peeley_service.dart';

class PeleyChatScreen extends StatefulWidget {
  final List<FoodItem> inventory;

  const PeleyChatScreen({Key? key, required this.inventory}) : super(key: key);

  @override
  State<PeleyChatScreen> createState() => _PeleyChatScreenState();
}

class _PeleyChatScreenState extends State<PeleyChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> messages = [];
  final PeeleyService peeleyService = PeeleyService();

  @override
  void initState() {
    super.initState();
    _addPeeleyMessage('Hi! I\'m Peeley 🌱 your food advisor. How can I help you today?\n\n'
        'Try asking:\n'
        '• "What\'s expiring?"\n'
        '• "Suggest a recipe"\n'
        '• "How to store milk?"\n'
        '• "Tell me a fun fact"');
  }

  void _addPeeleyMessage(String text) {
    setState(() {
      messages.add(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  void _addUserMessage(String text) {
    setState(() {
      messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
  }

  void _handleSendMessage() {
    if (_controller.text.isEmpty) return;

    String userMessage = _controller.text;
    _addUserMessage(userMessage);

    String response = peeleyService.processPeeleyResponse(userMessage, widget.inventory);
    _addPeeleyMessage(response);

    _controller.clear();
  }

  void _quickAction(String query) {
    _controller.text = query;
    _handleSendMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peeley 🌱'),
        backgroundColor: Colors.green[700],
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[messages.length - 1 - index];
                return Align(
                  alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: message.isUser ? Colors.green[600] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUser ? Colors.white : Colors.black,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                _QuickActionButton(
                  label: 'Expiring?',
                  onPressed: () => _quickAction("What's expiring?"),
                ),
                _QuickActionButton(
                  label: 'Recipe',
                  onPressed: () => _quickAction('Suggest a recipe'),
                ),
                _QuickActionButton(
                  label: 'Storage Tips',
                  onPressed: () => _quickAction('How to store items?'),
                ),
                _QuickActionButton(
                  label: 'Fun Fact',
                  onPressed: () => _quickAction('Tell me a fun fact'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask Peeley...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Colors.green),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _handleSendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _handleSendMessage,
                  backgroundColor: Colors.green[600],
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _QuickActionButton({
    Key? key,
    required this.label,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[600],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

