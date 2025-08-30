import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

void main() {
  runApp(const AuraApp());
}

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.montserratTextTheme();

    return MaterialApp(
      title: 'Kai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: baseTextTheme,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final String? assetPath; // optional image/gif asset to show with the message
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, this.assetPath})
      : timestamp = DateTime.now();
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _insertLandingGreeting();
  }

  void _insertLandingGreeting() {
    if (_messages.isNotEmpty) return;
    final now = DateTime.now();
    final hour = now.hour;
    String tod;
    if (hour < 12) {
      tod = 'Good morning';
    } else if (hour < 17) {
      tod = 'Good afternoon';
    } else {
      tod = 'Good evening';
    }
    final text = '$tod. I\'m here to listen. How are you feeling today?';
    _messages.add(ChatMessage(
      text: text,
      isUser: false,
      assetPath: 'assets/welcom_chatbot.gif',
    ));
  }

  String _baseUrl() {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _controller.clear();
      _isLoading = true;
    });

    FocusScope.of(context).unfocus();

    final url = Uri.parse('${_baseUrl()}/chat');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': text,
          if (_conversationId != null) 'conversation_id': _conversationId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = (data['reply'] ?? 'Sorry, I could not understand that.') as String;
        setState(() {
          _conversationId = (data['conversation_id'] as String?) ?? _conversationId;
          _messages.add(ChatMessage(text: reply, isUser: false));
        });
      } else {
        final errorMsg = 'Server error (${response.statusCode}). Please try again later.';
        setState(() {
          _messages.add(ChatMessage(text: errorMsg, isUser: false));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Network error: $e',
          isUser: false,
        ));
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFE1BEE7), // Soft purple
        Color(0xFFB2EBF2), // Gentle blue
      ],
    );

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Image.asset(
            'assets/appbar_Title.gif',
            height: 200,
            fit: BoxFit.contain,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_isLoading)
                const LinearProgressIndicator(
                  color: Colors.teal,
                  minHeight: 2,
                ),
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final item = _messages[_messages.length - 1 - index];
                    final bubble = ChatBubble(message: item, key: ValueKey(item.timestamp.millisecondsSinceEpoch));
                    return bubble
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.5, end: 0.0);
                  },
                ),
              ),
              _InputBar(
                controller: _controller,
                onSend: _sendMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    final Radius r20 = const Radius.circular(20);
    final BorderRadius radius = BorderRadius.only(
      topLeft: r20,
      topRight: r20,
      bottomLeft: Radius.circular(isUser ? 20 : 6),
      bottomRight: Radius.circular(isUser ? 6 : 20),
    );

    final BoxDecoration decoration = isUser
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.teal.shade400,
                Colors.teal.shade600,
              ],
            ),
            borderRadius: radius,
          )
        : BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          );

    final Color textColor = isUser ? Colors.white : Colors.black87;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: decoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.assetPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: message.assetPath!.endsWith('welcom_chatbot.gif') ? 50 : 60,
                    child: Image.asset(
                      message.assetPath!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              if (message.text.isNotEmpty) ...[
                if (message.assetPath != null) const SizedBox(height: 8),
                Text(
                  message.text,
                  style: TextStyle(color: textColor, fontSize: 16, height: 1.35),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: "Share what's on your mind...",
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.teal,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: onSend,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
