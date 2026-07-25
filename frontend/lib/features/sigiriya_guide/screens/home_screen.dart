// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../services/rag_service.dart';
import 'chat_screen.dart';

class HomeScreen extends StatelessWidget {
  final RagService? rag;
  const HomeScreen({super.key, this.rag});

  @override
  Widget build(BuildContext context) {
    return ChatScreen(rag: rag ?? RagService());
  }
}
