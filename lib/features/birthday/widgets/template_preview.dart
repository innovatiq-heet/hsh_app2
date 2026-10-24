import 'package:flutter/material.dart';

import '../controllers/admin_birthday_controller.dart';

/// WhatsApp-style preview of the birthday template with sample student data.
///
/// Listens to [templateController] directly, so it updates while the admin types.
class BirthdayTemplatePreview extends StatelessWidget {
  final TextEditingController templateController;
  final String title;

  const BirthdayTemplatePreview({
    super.key,
    required this.templateController,
    this.title = 'WhatsApp Preview Mockup',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECE5DD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1D7DB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_rounded, size: 14, color: Color(0xFF075E54)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF075E54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: templateController,
              builder: (context, value, _) {
                if (value.text.trim().isEmpty) {
                  return const Text(
                    'Start typing to see the message preview...',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF94A3B8),
                    ),
                  );
                }
                return Text(
                  AdminBirthdayController.fillTemplate(
                    value.text,
                    firstName: 'Rahul',
                    fullName: 'Rahul Sharma',
                    room: '306',
                    code: 'HSH-105',
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF1E293B),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
