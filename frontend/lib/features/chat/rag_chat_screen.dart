import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RagChatScreen extends StatefulWidget {
  const RagChatScreen({Key? key}) : super(key: key);

  @override
  State<RagChatScreen> createState() => _RagChatScreenState();
}

class _RagChatScreenState extends State<RagChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _messages.add({'user': _controller.text.trim()});
      _isLoading = true;
    });
    final userMessage = _controller.text.trim();
    _controller.clear();
    try {
      // TODO: Replace with your actual backend IP if running on a device
      const backendUrl = 'http://10.0.2.2:5000/chat'; // 10.0.2.2 for Android emulator, localhost for web/desktop
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'question': userMessage,
          'landmark_id': 'sigiriya', // or make this dynamic
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
      appBar: AppBar(
        title: const Text('Heritage Chat'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final entry = _messages[index];
                  final isUser = entry.containsKey('user');
                  return Row(
                    mainAxisAlignment:
                        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isUser)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: CircleAvatar(
                            backgroundColor: Colors.green[200],
                            child: const Icon(Icons.android, color: Colors.white),
                            radius: 18,
                          ),
                        ),
                      Flexible(
                        child: Container(
                          margin: EdgeInsets.only(
                              top: 4,
                              bottom: 4,
                              left: isUser ? 40 : 0,
                              right: isUser ? 0 : 40),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.blueAccent : Colors.grey[200],
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isUser ? 18 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            entry.values.first,
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      if (isUser)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: CircleAvatar(
                            backgroundColor: Colors.blueAccent,
                            child: const Icon(Icons.person, color: Colors.white),
                            radius: 18,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Ask a heritage question...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: (_) => _sendMessage(),
                        enabled: !_isLoading,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send),
                      color: Colors.white,
                      onPressed: _isLoading ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
