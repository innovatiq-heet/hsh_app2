import 'package:flutter/material.dart';
import '../shared/widgets/empty_state.dart';

/// Chat has no v2 API contract yet (spec §5.9) — placeholder until the
/// backend team defines one.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: const EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'Chat is not available yet',
        message:
            'This feature is pending a backend contract and will be added in a future update.',
      ),
    );
  }
}
