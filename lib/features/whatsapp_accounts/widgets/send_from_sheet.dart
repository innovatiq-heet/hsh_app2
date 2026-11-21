// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/models/whatsapp/whatsapp_account.dart';
import '../../../core/network/repository/whatsapp/whatsapp_accounts_repository.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';

/// The number a message goes out from.
class SendFromChoice {
  /// Sent as `accountId`. Null: let the server use its default.
  final String? accountId;
  final String label;

  /// The numbers could not be listed (older server) or there is only one, so
  /// the caller keeps its own "is WhatsApp linked?" check.
  final bool legacy;

  const SendFromChoice({this.accountId, this.label = 'Main', this.legacy = false});
}

/// Asks which WhatsApp number to send [purpose] (`birthday` / `anniversary`)
/// from, and returns the choice, or null when the user cancelled or no number
/// is connected.
///
/// With a single number (or when the numbers cannot be loaded) nothing is
/// asked and a [SendFromChoice.legacy] choice comes back, so sending behaves
/// as it did before multi-number support.
Future<SendFromChoice?> pickSendFromAccount({
  required String purpose,
  WhatsAppAccountsRepository? repo,
}) async {
  final WhatsAppAccountsData data;
  try {
    data = await (repo ?? WhatsAppAccountsRepository()).fetch();
  } catch (_) {
    return const SendFromChoice(legacy: true);
  }
  if (data.accounts.length <= 1) return const SendFromChoice(legacy: true);

  final context = Get.context;
  if (context == null) return const SendFromChoice(legacy: true);

  final fallback = data.defaultFor(purpose);
  // Preselect the default when it can send, else the first number that can.
  final preselected = (fallback != null && fallback.isOpen)
      ? fallback.id
      : data.accounts.where((a) => a.isOpen).map((a) => a.id).firstOrNull;
  return showModalBottomSheet<SendFromChoice>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => SendFromSheet(
      accounts: data.accounts,
      defaultId: fallback?.id,
      preselectedId: preselected,
      purpose: purpose,
    ),
  );
}

/// "919712977261" → "+91 97129 77261" (Indian numbers); others get a "+".
String formatWhatsAppPhone(String digits) {
  final d = digits.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('91')) {
    return '+91 ${d.substring(2, 7)} ${d.substring(7)}';
  }
  return '+$d';
}

/// "Send from" list: connected numbers can be picked (the default is
/// preselected), others are greyed with their status so it is clear why they
/// cannot be chosen. Nothing is sent until **Send** is tapped.
class SendFromSheet extends StatefulWidget {
  final List<WhatsAppAccount> accounts;
  final String? defaultId;
  final String? preselectedId;
  final String purpose;

  const SendFromSheet({
    super.key,
    required this.accounts,
    this.defaultId,
    this.preselectedId,
    this.purpose = 'birthday',
  });

  @override
  State<SendFromSheet> createState() => _SendFromSheetState();
}

class _SendFromSheetState extends State<SendFromSheet> {
  late String? _selected = widget.preselectedId;

  WhatsAppAccount? get _selectedAccount {
    for (final a in widget.accounts) {
      if (a.id == _selected) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final anyOpen = widget.accounts.any((a) => a.isOpen);
    final what = widget.purpose == 'anniversary' ? 'anniversary wish' : 'birthday wish';
    final chosen = _selectedAccount;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(color: PhonebookTheme.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: PhonebookTheme.greenSoft, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.send_rounded, color: PhonebookTheme.green, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SEND FROM',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: PhonebookTheme.amber,
                        ),
                      ),
                      Text(
                        anyOpen ? 'Choose a WhatsApp number' : 'No number is connected',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: PhonebookTheme.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              anyOpen
                  ? 'The $what goes out from the number you pick.'
                  : 'Link a WhatsApp number first, then send again.',
              style: const TextStyle(fontSize: 12.5, color: PhonebookTheme.muted),
            ),
            const SizedBox(height: 16),
            for (final a in widget.accounts) ...[
              _Row(
                account: a,
                isDefault: a.id == widget.defaultId,
                selected: a.id == _selected,
                onTap: a.isOpen ? () => setState(() => _selected = a.id) : null,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: chosen == null || !chosen.isOpen
                    ? null
                    : () => Navigator.of(context).pop(SendFromChoice(accountId: chosen.id, label: chosen.label)),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  chosen == null ? 'Send' : 'Send from ${chosen.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PhonebookTheme.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: PhonebookTheme.border,
                  disabledForegroundColor: PhonebookTheme.muted,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Get.toNamed(Routes.whatsappNumbers);
              },
              icon: const Icon(Icons.settings_outlined, size: 17),
              label: const Text('Manage numbers', style: TextStyle(fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(foregroundColor: PhonebookTheme.slate),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final WhatsAppAccount account;
  final bool isDefault;
  final bool selected;
  final VoidCallback? onTap;

  const _Row({required this.account, required this.isDefault, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = account;
    final enabled = onTap != null;
    final accent = enabled ? PhonebookTheme.green : PhonebookTheme.muted;
    final phone = a.phone;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(
              color: selected ? PhonebookTheme.blueSoft.withValues(alpha: 0.55) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? PhonebookTheme.blue : PhonebookTheme.border,
                width: selected ? 1.6 : 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
                  child: Icon(Icons.chat_rounded, color: accent, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              a.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: PhonebookTheme.ink,
                              ),
                            ),
                          ),
                          if (isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: PhonebookTheme.amberSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Default',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: PhonebookTheme.amber),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              enabled
                                  ? (phone != null && phone.isNotEmpty ? formatWhatsAppPhone(phone) : 'Connected')
                                  : a.statusLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: PhonebookTheme.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? PhonebookTheme.blue : Colors.white,
                    border: Border.all(
                      color: selected ? PhonebookTheme.blue : PhonebookTheme.border,
                      width: 2,
                    ),
                  ),
                  child: selected ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
