import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:uuid/uuid.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool initialized = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    initialized = true;
  } catch (e) {
    // Keep initialized as false; we'll show a config-needed screen.
  }
  runApp(KaiApp(firebaseReady: initialized));
}

class KaiApp extends StatelessWidget {
  final bool firebaseReady;
  const KaiApp({super.key, required this.firebaseReady});

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
      home: firebaseReady ? const Root() : const FirebaseConfigNeeded(),
    );
  }
}

class FirebaseConfigNeeded extends StatelessWidget {
  const FirebaseConfigNeeded({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.teal),
              const SizedBox(height: 12),
              const Text(
                'Firebase isn\'t configured yet.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Run `flutterfire configure` to generate firebase_options.dart, then restart the app.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        final user = snap.data;
        if (user == null) {
          return const SignInScreen();
        }
        return ChatScreen(user: user);
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFE1BEE7), Color(0xFFB2EBF2)],
    );
    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      ),
    );
  }
}

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  Future<void> _signIn(BuildContext context) async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return; // cancelled
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFE1BEE7), Color(0xFFB2EBF2)],
    );

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Image.asset('assets/appbar_Title.gif', height: 100, fit: BoxFit.contain),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 120,
                      child: Image.asset('assets/welcom_chatbot.gif', fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to Kai',
                    style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to start your calming chat. Your conversations are saved securely.',
                    style: GoogleFonts.montserrat(fontSize: 14, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () => _signIn(context),
                    icon: const FaIcon(FontAwesomeIcons.google, color: Colors.red, size: 20),
                    label: Text('Sign in with Google', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final String? assetPath; // optional image/gif asset
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, this.assetPath}) : timestamp = DateTime.now();
}

class ChatScreen extends StatefulWidget {
  final User user;
  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _conversationId;

  String _baseUrl() {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  @override
  void initState() {
    super.initState();
    _initConversation();
  }

  Future<void> _initConversation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final userMetaRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final userMetaSnap = await userMetaRef.get();
      final latestId = userMetaSnap.data()?['latestConversationId'] as String?;

      if (latestId != null && latestId.isNotEmpty) {
        final convSnap = await FirebaseFirestore.instance.collection('conversations').doc(latestId).get();
        if (convSnap.exists) {
          if (!mounted) return;
          setState(() {
            _conversationId = latestId;
          });
          return;
        }
      }

      // No valid existing conversation: create a new one and add the landing greeting message
      final cid = const Uuid().v4();
      final convRef = FirebaseFirestore.instance.collection('conversations').doc(cid);
      await convRef.set({
        'ownerUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await userMetaRef.set({
        'latestConversationId': cid,
        'latestUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final now = DateTime.now();
      final hour = now.hour;
      final tod = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
      final name = widget.user.displayName?.split(' ').first ?? 'there';
      final text = '$tod, $name. I\'m here to listen. How are you feeling today?';

      await convRef.collection('messages').add({
        'text': text,
        'isUser': false,
        'assetPath': 'assets/welcom_chatbot.gif',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _conversationId = cid;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _conversationId = _conversationId ?? const Uuid().v4();
        _messages.clear();
        final name = widget.user.displayName?.split(' ').first ?? 'there';
        _messages.add(ChatMessage(text: 'Welcome back, $name. Starting a new chat.', isUser: false));
      });
    }
  }

  Future<void> _saveMessage({required String text, required bool isUser, String? assetPath}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Ensure conversation id exists (generate before first send, pass to backend)
    _conversationId ??= const Uuid().v4();
    final convRef = FirebaseFirestore.instance.collection('conversations').doc(_conversationId);
    await convRef.set({
      'ownerUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await convRef.collection('messages').add({
      'text': text,
      'isUser': isUser,
      'assetPath': assetPath,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update user meta to resume this conversation next time
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'latestConversationId': _conversationId,
      'latestUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteConversation() async {
    final cid = _conversationId;
    if (cid == null) return;
    final convRef = FirebaseFirestore.instance.collection('conversations').doc(cid);
    final msgs = await convRef.collection('messages').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in msgs.docs) {
      batch.delete(d.reference);
    }
    batch.delete(convRef);
    await batch.commit();
    if (!mounted) return;
    // After deletion, start a fresh conversation and add greeting into Firestore
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final cidNew = const Uuid().v4();
    final convRefNew = FirebaseFirestore.instance.collection('conversations').doc(cidNew);
    await convRefNew.set({
      'ownerUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final now = DateTime.now();
    final hour = now.hour;
    final name = widget.user.displayName?.split(' ').first ?? 'there';
    final tod = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final text = '$tod, $name. I\'m here to listen. How are you feeling today?';
    await convRefNew.collection('messages').add({
      'text': text,
      'isUser': false,
      'assetPath': 'assets/welcom_chatbot.gif',
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    setState(() {
      _conversationId = cidNew;
      _messages.clear();
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Ensure we have a conversation id and pass it to backend
    _conversationId ??= const Uuid().v4();

    // Save immediately; UI will reflect via Firestore stream
    setState(() {
      _controller.clear();
      _isLoading = true;
    });
    await _saveMessage(text: text, isUser: true);

    FocusScope.of(context).unfocus();

    final url = Uri.parse('${_baseUrl()}/chat');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': text,
          'conversation_id': _conversationId, // always send our id so backend uses it
        }),
      );

      if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final reply = (data['reply'] ?? 'Sorry, I could not understand that.') as String;
      await _saveMessage(text: reply, isUser: false);
      } else {
      final errorMsg = 'Server error (${response.statusCode}). Please try again later.';
      await _saveMessage(text: errorMsg, isUser: false);
      }
    } catch (e) {
      final msg = 'Network error: $e';
      await _saveMessage(text: msg, isUser: false);
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
            height: 150,
            fit: BoxFit.contain,
          ),
          actions: [
            IconButton(
              tooltip: 'Delete conversation',
              onPressed: _deleteConversation,
              icon: const Icon(Icons.delete_outline, color: Colors.black87),
            ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              icon: const Icon(Icons.logout, color: Colors.black87),
            ),
          ],
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
                child: _conversationId == null
                    ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('conversations')
                            .doc(_conversationId)
                            .collection('messages')
                            .orderBy('timestamp')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Colors.teal));
                          }
                          final docs = snapshot.data?.docs ?? [];
                          final items = docs.map((d) {
                            final data = d.data();
                            return ChatMessage(
                              text: (data['text'] ?? '') as String,
                              isUser: (data['isUser'] ?? false) as bool,
                              assetPath: data['assetPath'] as String?,
                            );
                          }).toList();
                          return ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[items.length - 1 - index];
                              final bubble = ChatBubble(message: item, key: ValueKey(item.timestamp.millisecondsSinceEpoch));
                              return bubble
                                  .animate()
                                  .fadeIn(duration: 400.ms)
                                  .slideY(begin: 0.5, end: 0.0);
                            },
                          );
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
                    height: message.assetPath!.endsWith('welcom_chatbot.gif') ? 60 : 90,
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
