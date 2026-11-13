import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/ai_service.dart';

/// A simple chat screen where the user talks to the SALLAH AI assistant
/// (not a human) — answers questions about how the app works, guides
/// them, and redirects to the emergency button or human support when
/// needed. Requires ai_backend.py running locally on port 8001.
class AiSupportChatScreen extends StatefulWidget {
  const AiSupportChatScreen({super.key});

  @override
  State<AiSupportChatScreen> createState() => _AiSupportChatScreenState();
}

class _ChatBubble {
  const _ChatBubble({required this.text, required this.isUser});
  final String text;
  final bool isUser;
}

class _AiSupportChatScreenState extends State<AiSupportChatScreen> {
  final _aiService = AiService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatBubble> _messages = [
    const _ChatBubble(
      text:
          'سلام 👋 أنا المساعد الذكي ديال BRIKOL. كيفاش نقدر نعاونك اليوم؟\n\n'
          '(كيفاش نطلب خدمة، مشكل فالدفع، أو أي سؤال آخر)',
      isUser: false,
    ),
  ];
  bool _sending = false;
  String? _error;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatBubble(text: text, isUser: true));
      _controller.clear();
      _sending = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final history = _messages
          .where((m) => m != _messages.last) // exclude the one just added
          .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
          .toList();
      final reply = await _aiService.sendSupportMessage(history: history, message: text);
      if (mounted) {
        setState(() {
          _messages.add(_ChatBubble(text: reply, isUser: false));
          _sending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'الخدمة الذكية غير متاحة حاليا. تأكد أن ai_backend.py خدام. ($e)';
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                  color: AppColors.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy_rounded,
                  size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            const Text('المساعد الذكي BRIKOL',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final msg = _messages[i];
                return Align(
                  alignment:
                      msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: msg.isUser ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: msg.isUser
                          ? null
                          : Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: msg.isUser ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.danger)),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                          hintText: 'اكتب سؤالك هنا…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}