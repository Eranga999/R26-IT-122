// lib/widgets/chat_bubble.dart
import 'package:flutter/material.dart';
import '../models/location_model.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isUser
                ? gold.withOpacity(0.15)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            border: Border.all(
              color: isUser ? gold.withOpacity(0.4) : const Color(0xFF5C3D1E),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon for bot messages
              if (!isUser) ...[
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: gold),
                    const SizedBox(width: 6),
                    Text(
                      'Sigiriya Guide',
                      style: TextStyle(
                        color: gold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Message content (with simple markdown)
              _buildContent(context, message.text, isUser),

              // Timestamp
              const SizedBox(height: 6),
              Text(
                _formatTime(message.timestamp),
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, String text, bool isUser) {
    final gold = Theme.of(context).colorScheme.primary;
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              line.substring(3),
              style: TextStyle(
                color: gold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (line.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Text(
              line.substring(4),
              style: TextStyle(
                color: gold.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: gold, fontSize: 13)),
                Expanded(child: _RichLine(line.substring(2), isUser: isUser)),
              ],
            ),
          ),
        );
      } else if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 4));
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: _RichLine(line, isUser: isUser),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _RichLine extends StatelessWidget {
  final String text;
  final bool isUser;
  const _RichLine(this.text, {required this.isUser});

  @override
  Widget build(BuildContext context) {
    final parts = text.split('**');
    if (parts.length == 1) {
      return Text(
        text,
        style: TextStyle(
          color: isUser ? Colors.white : Colors.white70,
          fontSize: 13,
          height: 1.5,
        ),
      );
    }
    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      spans.add(
        TextSpan(
          text: parts[i],
          style: TextStyle(
            fontWeight: i.isOdd ? FontWeight.bold : FontWeight.normal,
            color: i.isOdd
                ? Colors.white
                : (isUser ? Colors.white : Colors.white70),
          ),
        ),
      );
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, height: 1.5),
        children: spans,
      ),
    );
  }
}
