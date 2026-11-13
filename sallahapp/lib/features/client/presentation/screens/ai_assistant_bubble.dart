import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'ai_support_chat_screen.dart';

/// A small, always-visible floating bubble: robot icon + a short
/// invitation to chat. Tapping it opens the AI assistant chat screen.
/// Drop this into a Stack alongside the home screen's main content.
class AiAssistantBubble extends StatelessWidget {
  const AiAssistantBubble({super.key, this.label = 'Une question ? Demandez à l\'IA'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(30),
        elevation: 6,
        shadowColor: AppColors.primary.withOpacity(0.4),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AiSupportChatScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.smart_toy_rounded,
                      size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 9),
                Text(
                  label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}