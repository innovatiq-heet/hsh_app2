import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/whatsapp/whatsapp_account.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../controllers/whatsapp_numbers_controller.dart';

/// Every WhatsApp number the server keeps connected. Link or disconnect each
/// one; admins also add, rename and delete numbers and choose which number the
/// scheduled birthday / anniversary runs send from.
class WhatsAppNumbersScreen extends GetView<WhatsAppNumbersController> {
  const WhatsAppNumbersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Obx(
        () => Scaffold(
          backgroundColor: PhonebookTheme.bg,
          body: AsyncStateView(
            isLoading: controller.isLoading.value,
            hasError: controller.hasError.value,
            errorMessage: controller.errorMessage.value,
            onRetry: controller.load,
            builder: (context) => Obx(() {
              final accounts = controller.accounts;
              final open = accounts.where((a) => a.isOpen).length;
              return AppRefreshIndicator(
                onRefresh: () => controller.load(showLoading: false),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: PhonebookHeaderDelegate(
                        overline: 'WhatsApp',
                        title: controller.isLeader ? 'My WhatsApp' : 'WhatsApp Numbers',
                        subtitle: controller.isLeader
                            ? 'Link your WhatsApp for group alumni, broadcasts & wishes'
                            : 'Link several numbers and pick which one sends',
                        topPadding: topPadding,
                        onLeadingTap: () => Navigator.of(context).pop(),
                        pills: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            PhonebookHeaderPill(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: '${accounts.length} number${accounts.length == 1 ? '' : 's'}',
                            ),
                            PhonebookHeaderPill(icon: Icons.check_circle_outline_rounded, label: '$open connected'),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          PhonebookSectionHeader(title: controller.isLeader ? 'My Linked Number' : 'Numbers'),
                          if (accounts.isEmpty)
                            _EmptyNumbers(isLeader: controller.isLeader)
                          else
                            for (final a in accounts)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _NumberCard(account: a, controller: controller),
                              ),
                          if (controller.isAdmin && accounts.length > 1) ...[
                            const SizedBox(height: 8),
                            const PhonebookSectionHeader(title: 'Scheduled daily messages'),
                            _DefaultsCard(controller: controller),
                          ],
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          floatingActionButton: controller.canAddAccount && !controller.isLoading.value && !controller.hasError.value
              ? FloatingActionButton.extended(
                  heroTag: 'add_wa_number_fab',
                  backgroundColor: PhonebookTheme.blue,
                  foregroundColor: Colors.white,
                  onPressed: () => _addNumber(context, controller),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    controller.isLeader ? 'Add my WhatsApp' : 'Add number',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

Future<void> _addNumber(BuildContext context, WhatsAppNumbersController controller) async {
  final label = await _askLabel(
    context,
    title: controller.isLeader ? 'Add my WhatsApp' : 'Add number',
    hint: controller.isLeader ? 'e.g. Personal / Param Leader' : 'e.g. Anniversary',
    action: 'Add',
    initial: controller.isLeader ? 'My WhatsApp' : '',
  );
  if (label == null) return;
  final id = await controller.add(label);
  if (id != null && context.mounted) await showLinkNumberSheet(context, controller, id);
}

Future<String?> _askLabel(
  BuildContext context, {
  required String title,
  required String hint,
  required String action,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _LabelDialog(title: title, hint: hint, action: action, initial: initial),
  );
}

/// Asks for a number's name. It owns its text controller, so the controller
/// lives until the dialog has finished closing (disposing it as soon as the
/// dialog returned broke the closing animation).
class _LabelDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String action;
  final String initial;

  const _LabelDialog({required this.title, required this.hint, required this.action, required this.initial});

  @override
  State<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<_LabelDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _ctrl.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: phonebookInputDecoration(hint: widget.hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: PhonebookTheme.blue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(widget.action),
        ),
      ],
    );
  }
}

class _EmptyNumbers extends StatelessWidget {
  final bool isLeader;
  const _EmptyNumbers({this.isLeader = false});

  @override
  Widget build(BuildContext context) {
    return PhonebookCard(
      child: Text(
        isLeader
            ? 'No WhatsApp linked yet. Tap Add my WhatsApp below to connect your own number for Auto Alumni Connect, Group Broadcasts, and Wishes.'
            : 'No WhatsApp numbers yet. Add one to start linking.',
        style: const TextStyle(color: PhonebookTheme.muted, fontWeight: FontWeight.w600),
      ),
    );
  }
}

Color _statusColor(WhatsAppAccount a) => switch (a.status) {
  'open' => PhonebookTheme.green,
  'connecting' || 'qr' || 'pairing' => PhonebookTheme.amber,
  _ => PhonebookTheme.muted,
};

/// Small read-only coloured label: soft fill, coloured text.
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _NumberCard extends StatelessWidget {
  final WhatsAppAccount account;
  final WhatsAppNumbersController controller;

  const _NumberCard({required this.account, required this.controller});

  @override
  Widget build(BuildContext context) {
    final a = account;
    final color = _statusColor(a);
    final busy = controller.isBusy(a.id);
    final phone = a.phone;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
                child: Icon(Icons.chat_rounded, color: color, size: 22),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: PhonebookTheme.ink,
                            ),
                          ),
                        ),
                        if (a.isMain) ...[
                          const SizedBox(width: 6),
                          const _StatusChip(label: 'Main', color: PhonebookTheme.blue),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone != null && phone.isNotEmpty ? '+$phone' : 'Not linked yet',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: PhonebookTheme.muted),
                    ),
                  ],
                ),
              ),
              if (controller.canManageAccounts)
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_vert_rounded, color: PhonebookTheme.muted),
                  onSelected: (v) async {
                    if (v == 'rename') {
                      final label = await _askLabel(
                        context,
                        title: 'Rename number',
                        hint: 'Name',
                        action: 'Save',
                        initial: a.label,
                      );
                      if (label != null) await controller.rename(a.id, label);
                    } else {
                      final ok = await _confirmDelete(context, a);
                      if (ok == true) await controller.remove(a.id);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    if (!a.isMain)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Remove', style: TextStyle(color: PhonebookTheme.red)),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatusChip(label: a.statusLabel, color: color),
              const Spacer(),
              if (busy)
                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              else if (a.isOpen)
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('Disconnect number?'),
                        content: Text('${a.label} will stop sending until it is linked again.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PhonebookTheme.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Disconnect'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await controller.disconnect(a.id);
                  },
                  icon: const Icon(Icons.link_off_rounded, size: 16),
                  label: const Text('Disconnect'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PhonebookTheme.red,
                    side: BorderSide(color: PhonebookTheme.red.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => showLinkNumberSheet(context, controller, a.id),
                  icon: Icon(a.isBusy ? Icons.qr_code_2_rounded : Icons.link_rounded, size: 16),
                  label: Text(a.isBusy ? 'Continue' : 'Link'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PhonebookTheme.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, WhatsAppAccount a) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Remove number?'),
      content: Text('${a.label} will be logged out and removed.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: PhonebookTheme.red, foregroundColor: Colors.white),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
}

/// Which number the scheduled (automatic) daily messages go out from.
class _DefaultsCard extends StatelessWidget {
  final WhatsAppNumbersController controller;

  const _DefaultsCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final d = controller.data.value;
    return PhonebookCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Messages the app sends by itself each day use these numbers. '
            'When you send by hand you choose the number at that time.',
            style: TextStyle(fontSize: 12.5, color: PhonebookTheme.muted, height: 1.35),
          ),
          const SizedBox(height: 12),
          _DefaultPicker(
            label: 'Birthday wishes sent from',
            accounts: d.accounts,
            value: d.birthdayDefault,
            onChanged: (v) => controller.setDefault('birthday', v),
          ),
          const SizedBox(height: 10),
          _DefaultPicker(
            label: 'Anniversary wishes sent from',
            accounts: d.accounts,
            value: d.anniversaryDefault,
            onChanged: (v) => controller.setDefault('anniversary', v),
          ),
        ],
      ),
    );
  }
}

class _DefaultPicker extends StatelessWidget {
  final String label;
  final List<WhatsAppAccount> accounts;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _DefaultPicker({required this.label, required this.accounts, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // The Main number is stored as null ("use the Main number").
    final current = value == WhatsAppAccount.mainId ? null : value;
    final known = current == null || accounts.any((a) => a.id == current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PhonebookTheme.slate)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          initialValue: known ? current : null,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: PhonebookTheme.bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PhonebookTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PhonebookTheme.border),
            ),
          ),
          items: [
            for (final a in accounts)
              DropdownMenuItem<String?>(
                value: a.isMain ? null : a.id,
                child: Text(
                  a.isMain ? 'Main number${a.label == 'Main' ? '' : ' (${a.label})'}' : a.label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Bottom sheet that links [id]: scan a QR, or get a pairing code for the phone.
Future<void> showLinkNumberSheet(BuildContext context, WhatsAppNumbersController controller, String id) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _LinkSheet(controller: controller, id: id),
  );
}

class _LinkSheet extends StatefulWidget {
  final WhatsAppNumbersController controller;
  final String id;

  const _LinkSheet({required this.controller, required this.id});

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  final _phone = TextEditingController();
  bool _usePhone = false;
  bool _slow = false;
  Worker? _worker;
  Timer? _slowTimer;
  bool _closed = false;

  WhatsAppNumbersController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.watch(widget.id);
    // QR is the default way: start it right away, unless this number is
    // already connecting or waiting for a scan (restarting would drop its QR).
    // Started after the first frame: these update observables the sheet is
    // built from, and doing that during the build throws before the request
    // is ever sent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = c.byId(widget.id);
      if (current == null || current.status == 'disconnected') {
        _startQr();
      } else if (!current.isOpen) {
        _armSlowHint();
        c.refreshQuietly();
      }
    });
    _worker = ever(c.data, (_) {
      final a = c.byId(widget.id);
      if (a != null && a.isOpen && !_closed && mounted) {
        _closed = true;
        AppSnackbar.success('WhatsApp Connected!', '${a.label} is linked${a.phone != null ? ' as +${a.phone}' : ''}.');
        Navigator.of(context).pop();
      }
    });
  }

  /// After 20 s without a QR, say so and offer the alternatives.
  void _armSlowHint() {
    _slowTimer?.cancel();
    if (_slow) setState(() => _slow = false);
    _slowTimer = Timer(const Duration(seconds: 20), () {
      if (mounted && c.byId(widget.id)?.qr == null) setState(() => _slow = true);
    });
  }

  void _startQr() {
    _armSlowHint();
    c.connect(widget.id);
  }

  @override
  void dispose() {
    _worker?.dispose();
    _slowTimer?.cancel();
    c.unwatch(widget.id);
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Obx(() {
          final a = c.byId(widget.id);
          final label = a?.label ?? 'WhatsApp number';
          return Column(
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
                    decoration: BoxDecoration(
                      color: PhonebookTheme.greenSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.link_rounded, color: PhonebookTheme.green, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LINK A NUMBER',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: PhonebookTheme.amber,
                          ),
                        ),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PhonebookTheme.blueSoft.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Step(n: 1, text: 'Open WhatsApp on the phone with this number'),
                    SizedBox(height: 6),
                    _Step(n: 2, text: 'Settings → Linked devices → Link a device'),
                    SizedBox(height: 6),
                    _Step(n: 3, text: 'Scan the QR below, or use a pairing code'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ModeTab(
                      label: 'QR code',
                      icon: Icons.qr_code_2_rounded,
                      selected: !_usePhone,
                      onTap: () {
                        setState(() => _usePhone = false);
                        _startQr();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ModeTab(
                      label: 'Pairing code',
                      icon: Icons.password_rounded,
                      selected: _usePhone,
                      onTap: () => setState(() => _usePhone = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_usePhone) _pairing() else _qr(a),
              const SizedBox(height: 12),
              _statusLine(a),
            ],
          );
        }),
      ),
    );
  }

  /// What the server says about this number right now, and its last error,
  /// so a stuck link shows why.
  Widget _statusLine(WhatsAppAccount? a) {
    final error = c.lastErrors[widget.id];
    final status = a?.statusLabel ?? 'Unknown';
    final color = a == null ? PhonebookTheme.muted : _statusColor(a);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(
              'Server: $status',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        if (error != null && error.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: PhonebookTheme.redSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PhonebookTheme.red.withValues(alpha: 0.25)),
            ),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PhonebookTheme.red),
            ),
          ),
        ],
      ],
    );
  }

  Widget _qr(WhatsAppAccount? a) {
    final qr = a?.qr;
    return Column(
      children: [
        Container(
          width: 244,
          height: 244,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: PhonebookTheme.border, width: 1.4),
            boxShadow: [
              BoxShadow(color: PhonebookTheme.ink.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: qr != null
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: QrImageView(data: qr, backgroundColor: Colors.white, padding: EdgeInsets.zero),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_slow) ...[
                        const CircularProgressIndicator(strokeWidth: 2.6, color: PhonebookTheme.blue),
                        const SizedBox(height: 14),
                        const Text(
                          'Preparing QR code…',
                          style: TextStyle(color: PhonebookTheme.slate, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'This can take a few seconds',
                          style: TextStyle(fontSize: 12, color: PhonebookTheme.muted),
                        ),
                      ] else ...[
                        const Icon(Icons.hourglass_bottom_rounded, size: 30, color: PhonebookTheme.amber),
                        const SizedBox(height: 10),
                        const Text(
                          'The QR is taking longer than usual',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: PhonebookTheme.slate, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap "New QR code", or use a pairing code instead.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: PhonebookTheme.muted),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: c.isBusy(widget.id) ? null : _startQr,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('New QR code'),
          style: OutlinedButton.styleFrom(
            foregroundColor: PhonebookTheme.blue,
            side: BorderSide(color: PhonebookTheme.blue.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _pairing() {
    final code = c.pairingCodes[widget.id];
    final busy = c.isBusy(widget.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: phonebookInputDecoration(
            label: 'WhatsApp number on that phone',
            hint: '98765 43210',
            prefixIcon: const Icon(Icons.phone_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: busy ? null : () => c.pair(widget.id, _phone.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: PhonebookTheme.blue,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Get pairing code', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Getting a code from WhatsApp can take up to 20 seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: PhonebookTheme.muted),
            ),
          ),
        if (code != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
            decoration: BoxDecoration(
              color: PhonebookTheme.blueSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: PhonebookTheme.blue.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                SelectableText(
                  code,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 5,
                    color: PhonebookTheme.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Copied. In WhatsApp choose "Link with phone number instead" and type this code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: PhonebookTheme.slate, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => Clipboard.setData(ClipboardData(text: code)),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
              ),
              TextButton.icon(
                onPressed: () async {
                  for (final url in ['whatsapp://', 'https://wa.me/']) {
                    try {
                      if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) return;
                    } catch (_) {}
                  }
                  AppSnackbar.warning('Could Not Open WhatsApp', 'Open WhatsApp yourself, then go to Linked devices.');
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open WhatsApp'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String text;

  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: PhonebookTheme.blue, shape: BoxShape.circle),
          child: Text('$n', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: PhonebookTheme.slate),
          ),
        ),
      ],
    );
  }
}

/// Full-width segmented choice: QR code or pairing code.
class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? PhonebookTheme.blue : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? PhonebookTheme.blue : PhonebookTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : PhonebookTheme.slate),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : PhonebookTheme.slate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
