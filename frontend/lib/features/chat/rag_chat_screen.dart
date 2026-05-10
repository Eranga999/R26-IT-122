import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_theme.dart';

class RagChatScreen extends StatefulWidget {
  final String? landmarkName;
  const RagChatScreen({Key? key, this.landmarkName}) : super(key: key);

  @override
  State<RagChatScreen> createState() => _RagChatScreenState();
}

class _RagChatScreenState extends State<RagChatScreen> {
  final TextEditingController _controller = TextEditingController();
  late final List<Map<String, String>> _messages;
  bool _isLoading = false;
  late final List<String> _suggestions;

  @override
  void initState() {
    super.initState();
    _messages = [
      {
        'bot':
            'Greetings! 🏛️ I am your Heritage Guide. I can tell you all about the history, architecture, and hidden secrets of Sigiriya. How can I help you today?'
      }
    ];
    _suggestions = [
      'Who built Sigiriya?',
      'Tell me about the frescoes',
      'How many steps are there?',
      'What is the Lion Gate?'
    ];
  }

  void _sendSuggestedMessage(String msg) {
    if (_isLoading) return;
    _controller.text = msg;
    _sendMessage();
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _messages.add({'user': _controller.text.trim()});
      _isLoading = true;
    });
    final userMessage = _controller.text.trim();
    _controller.clear();
    try {
      const backendUrl = 'http://10.0.2.2:5001/chat';
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'question': userMessage,
          'landmark_id': 'sigiriya',
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add({'bot': data['answer'] ?? 'No answer.'});
        });
      } else {
        setState(() {
          _messages.add({'bot': 'Error: Backend returned ${response.statusCode}'});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'bot': 'Error: Could not connect to backend. Make sure the server is running.'});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text(
          'Heritage Guide',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3E1D0A),
                Color(0xFF8D4E1A),
              ],
            ),
          ),
        ),
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final entry = _messages[index];
                  final isUser = entry.containsKey('user');
                  return _buildMessageBubble(entry.values.first, isUser);
                },
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(color: AppTheme.secondary),
              ),
            _buildSuggestions(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestions.length,
        itemBuilder: (context, i) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                _suggestions[i],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              onPressed: () => _sendSuggestedMessage(_suggestions[i]),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 2,
              shadowColor: Colors.black26,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: AppTheme.primary.withOpacity(0.1)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(String message, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _buildBotAvatar(),
          Flexible(
            child: Container(
              margin: EdgeInsets.only(
                  left: isUser ? 50 : 8,
                  right: isUser ? 8 : 50),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF4E342E),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildBotAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.secondary, AppTheme.accent],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondary.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.account_balance, color: Colors.white, size: 20),
    );
  }

  Widget _buildUserAvatar() {
    return const CircleAvatar(
      backgroundColor: AppTheme.primary,
      radius: 18,
      child: Icon(Icons.person, color: Colors.white, size: 20),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Ask your heritage guide...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
