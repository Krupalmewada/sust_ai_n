import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<types.Message> _messages = [];
  late types.User _user;
  final _bot = const types.User(id: '82091008-a484-4a89-ae75-a22bf8d6f3bd');

  bool isDataLoading = false;
  final ChatService chatService = ChatService();

  String? _userPhotoUrl;
  String? _userName;
  bool _isLoadingUserData = true;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        final uid = currentUser.uid;

        // Fetch user data from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          _userPhotoUrl = userData?['profile']?['info']?['photoUrl'];
          _userName = userData?['profile']?['info']?['name'] ?? 'User';
        }

        // Initialize the user object
        _user = types.User(
          id: uid,
          firstName: _userName,
          imageUrl: _userPhotoUrl,
        );
      } else {
        // Fallback if no user is logged in
        _user = const types.User(
          id: '82091008-a484-4a89-ae75-a22bf8d6f3ac',
          firstName: 'User',
        );
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      // Fallback user
      _user = const types.User(
        id: '82091008-a484-4a89-ae75-a22bf8d6f3ac',
        firstName: 'User',
      );
    } finally {
      setState(() => _isLoadingUserData = false);
    }
  }

  void _addMessage(types.Message message) {
    setState(() => _messages.insert(0, message));
  }

  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: SizedBox(
          height: 144,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleImageSelection();
                },
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('Photo'),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleFileSelection();
                },
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('File'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result != null && result.files.single.path != null) {
      final message = types.FileMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        mimeType: lookupMimeType(result.files.single.path!),
        name: result.files.single.name,
        size: result.files.single.size,
        uri: result.files.single.path!,
      );

      _addMessage(message);
    }
  }

  void _handleImageSelection() async {
    final result = await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );

    if (result != null) {
      final bytes = await result.readAsBytes();
      final image = await decodeImageFromList(bytes);

      final message = types.ImageMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        height: image.height.toDouble(),
        id: const Uuid().v4(),
        name: result.name,
        size: bytes.length,
        uri: result.path,
        width: image.width.toDouble(),
      );

      _addMessage(message);
    }
  }

  void _handleMessageTap(BuildContext _, types.Message message) async {
    if (message is types.FileMessage) {
      var localPath = message.uri;

      if (message.uri.startsWith('http')) {
        try {
          final index = _messages.indexWhere((m) => m.id == message.id);
          final updatedMessage = (_messages[index] as types.FileMessage)
              .copyWith(isLoading: true);

          setState(() => _messages[index] = updatedMessage);

          final client = http.Client();
          final request = await client.get(Uri.parse(message.uri));
          final bytes = request.bodyBytes;
          final documentsDir = (await getApplicationDocumentsDirectory()).path;
          localPath = '$documentsDir/${message.name}';

          if (!File(localPath).existsSync()) {
            await File(localPath).writeAsBytes(bytes);
          }
        } finally {
          final index = _messages.indexWhere((m) => m.id == message.id);
          final updatedMessage = (_messages[index] as types.FileMessage)
              .copyWith(isLoading: null);

          setState(() => _messages[index] = updatedMessage);
        }
      }

      await OpenFilex.open(localPath);
    }
  }

  void _handlePreviewDataFetched(
      types.TextMessage message,
      types.PreviewData previewData,
      ) {
    final index = _messages.indexWhere((m) => m.id == message.id);
    final updatedMessage = (_messages[index] as types.TextMessage).copyWith(
      previewData: previewData,
    );
    setState(() => _messages[index] = updatedMessage);
  }

  Future<void> _handleSendPressed(types.PartialText message) async {
    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: message.text,
    );

    setState(() => isDataLoading = true);

    final aiResponse = await chatService.chatGPTAPI(message.text);

    final botMessage = types.TextMessage(
      author: _bot,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: aiResponse,
    );

    _addMessage(textMessage);
    setState(() => isDataLoading = false);
    _addMessage(botMessage);
  }

  void _loadMessages() async {
    final response = await rootBundle.loadString('assets/messages.json');
    final messages = (jsonDecode(response) as List)
        .map((e) => types.Message.fromJson(e as Map<String, dynamic>))
        .toList();

    setState(() => _messages = messages);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUserData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('lib/assets/Peelie best version.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'PEELY - Your Food AI',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Chat(
          isAttachmentUploading: isDataLoading,
          l10n: ChatL10nEn(
            emptyChatPlaceholder: 'Hi ${_userName ?? 'there'} !! I am PEELY. Ask me anything about Food',
          ),
          messages: _messages,
          onAttachmentPressed: _handleAttachmentPressed,
          onMessageTap: _handleMessageTap,
          onPreviewDataFetched: _handlePreviewDataFetched,
          onSendPressed: _handleSendPressed,
          showUserAvatars: true,
          showUserNames: true,
          user: _user,
          avatarBuilder: (types.User user) {
            if (user.id == _bot.id) {
              return const CircleAvatar(
                backgroundImage: AssetImage('lib/assets/Peelie best version.png'),
              );
            }
            // User avatar from Firestore
            if (user.imageUrl != null && user.imageUrl!.isNotEmpty) {
              return CircleAvatar(
                backgroundImage: NetworkImage(user.imageUrl!),
                onBackgroundImageError: (_, __) {
                  debugPrint('Error loading user avatar');
                },
                child: null,
              );
            }
            // Fallback avatar
            return CircleAvatar(
              backgroundColor: Colors.green,
              child: Text(
                user.firstName?.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(color: Colors.white),
              ),
            );
          },
        ),
      ),
    );
  }
}