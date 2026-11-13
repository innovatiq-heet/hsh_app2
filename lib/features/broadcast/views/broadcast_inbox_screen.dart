import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/models/broadcasts/broadcast_models.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/student_contact_card.dart'
    show CelebrantLightChip, CornerWavePainter;
import '../controllers/broadcast_inbox_controller.dart';

/// Student → Dashboard → Announcements: official broadcasts from hostel office.
class BroadcastInboxScreen extends StatefulWidget {
  const BroadcastInboxScreen({super.key});

  @override
  State<BroadcastInboxScreen> createState() => _BroadcastInboxScreenState();
}

class _BroadcastInboxScreenState extends State<BroadcastInboxScreen> {
  final controller = Get.find<BroadcastInboxController>();
  late final Worker _openWorker;

  final searchController = TextEditingController();
  final searchText = ''.obs;
  final selectedFilter = 'All'.obs; // 'All', 'Unread', 'Read'

  @override
  void initState() {
    super.initState();
    // A push tap opens its message as soon as the list has it.
    _openWorker = ever<InboxBroadcast?>(controller.openRequest, (item) {
      if (item == null) return;
      controller.openRequest.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open(item);
      });
    });
  }

  @override
  void dispose() {
    _openWorker.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _open(InboxBroadcast item) {
    controller.markRead(item);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDF2F8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFBCFE8)),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.campaign_rounded,
                            color: Color(0xFFDB2777),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (item.senderName.isNotEmpty)
                                    CelebrantLightChip(
                                      icon: Icons.person_rounded,
                                      text: item.senderName,
                                      bgColor: const Color(0xFFF1F5F9),
                                      borderColor: const Color(0xFFE2E8F0),
                                      textColor: const Color(0xFF334155),
                                    ),
                                  if (item.createdAt != null)
                                    CelebrantLightChip(
                                      icon: Icons.schedule_rounded,
                                      text: DateFormatting.dateTime(item.createdAt!),
                                      bgColor: const Color(0xFFF8FAFC),
                                      borderColor: const Color(0xFFE2E8F0),
                                      textColor: const Color(0xFF64748B),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                    const SizedBox(height: 16),
                    SelectableText(
                      item.message,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF1E293B),
                        height: 1.55,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<InboxBroadcast> _filterItems(List<InboxBroadcast> all) {
    var filtered = all;
    final f = selectedFilter.value;
    if (f == 'Unread') {
      filtered = filtered.where((i) => !i.isRead).toList();
    } else if (f == 'Read') {
      filtered = filtered.where((i) => i.isRead).toList();
    }

    final query = searchText.value.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((i) {
        final title = i.title.toLowerCase();
        final msg = i.message.toLowerCase();
        final sender = i.senderName.toLowerCase();
        return title.contains(query) || msg.contains(query) || sender.contains(query);
      }).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: RefreshIndicator(
          onRefresh: () => controller.load(showLoading: false),
          color: const Color(0xFF0284C7),
          backgroundColor: Colors.white,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 300) controller.loadMore();
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                // Signature Deep Navy Executive Header
                SliverToBoxAdapter(
                  child: Container(
                    padding: EdgeInsets.fromLTRB(20, topPadding + 14, 20, 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF03192E),
                          Color(0xFF032B4F),
                          Color(0xFF025A8D),
                          Color(0xFF0369A1),
                        ],
                        stops: [0.0, 0.38, 0.75, 1.0],
                      ),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF03192E),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(child: CustomPaint(painter: _HeaderOrbPainter())),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Bar: Back button, unread pill, refresh
                            Row(
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => Navigator.of(context).maybePop(),
                                    borderRadius: BorderRadius.circular(24),
                                    child: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.16),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.25),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_back_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Obx(() {
                                  final unread = controller.unreadCount.value;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: unread > 0
                                          ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                                          : Colors.white.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: unread > 0
                                            ? const Color(0xFFF87171)
                                            : Colors.white.withValues(alpha: 0.28),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          unread > 0
                                              ? Icons.mark_email_unread_rounded
                                              : Icons.done_all_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          unread > 0 ? '$unread Unread' : 'All Read',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(width: 8),
                                Obx(() {
                                  final loading = controller.isLoading.value;
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: loading ? null : () => controller.load(showLoading: false),
                                      borderRadius: BorderRadius.circular(24),
                                      child: Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.16),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.25),
                                            width: 1,
                                          ),
                                        ),
                                        child: loading
                                            ? const Padding(
                                                padding: EdgeInsets.all(12),
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.refresh_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Hostel Announcements',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Official notices, updates, and circulars from the office',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Search & Filter Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search Box
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: searchController,
                            onChanged: (val) => searchText.value = val,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search announcements, notices, admin...',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w400,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: Color(0xFFDB2777),
                                size: 21,
                              ),
                              suffixIcon: Obx(() {
                                if (searchText.value.isEmpty) return const SizedBox.shrink();
                                return IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                                  onPressed: () {
                                    searchController.clear();
                                    searchText.value = '';
                                  },
                                );
                              }),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Filter Chips (All, Unread, Read)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Obx(() {
                            final cur = selectedFilter.value;
                            final unreadTotal = controller.unreadCount.value;

                            final filters = [
                              {'label': 'All', 'count': controller.items.length},
                              {'label': 'Unread', 'count': unreadTotal},
                              {'label': 'Read', 'count': controller.items.length - unreadTotal},
                            ];

                            return Row(
                              children: filters.map((item) {
                                final label = item['label'] as String;
                                final count = item['count'] as int;
                                final isSelected = cur == label;
                                const color = Color(0xFFDB2777);

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () => selectedFilter.value = label,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 7.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected ? color : Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isSelected ? color : const Color(0xFFE2E8F0),
                                            width: 1,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: color.withValues(alpha: 0.25),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              label,
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : const Color(0xFF475569),
                                                fontSize: 13,
                                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                              ),
                                            ),
                                            if (count >= 0) ...[
                                              const SizedBox(width: 5),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? Colors.white.withValues(alpha: 0.24)
                                                      : const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '$count',
                                                  style: TextStyle(
                                                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          }),
                        ),
                        const SizedBox(height: 16),

                        // Section Title with Amber Dash
                        Obx(() {
                          final count = _filterItems(controller.items).length;
                          return Row(
                            children: [
                              Container(
                                width: 20,
                                height: 3.5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ANNOUNCEMENTS ($count)',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF475569),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          );
                        }),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // Content Slivers
                Obx(() {
                  if (controller.isLoading.value) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                      ),
                    );
                  }
                  if (controller.hasError.value) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load announcements',
                        message: controller.errorMessage.value,
                        actionLabel: 'Retry',
                        onAction: controller.load,
                      ),
                    );
                  }

                  final filtered = _filterItems(controller.items);
                  if (filtered.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                        child: EmptyState(
                          icon: Icons.campaign_outlined,
                          title: searchText.value.isNotEmpty
                              ? 'No matching announcements'
                              : (selectedFilter.value == 'Unread'
                                  ? 'No unread announcements'
                                  : 'No announcements yet'),
                          message: searchText.value.isNotEmpty
                              ? 'Try searching for another keyword or clear active filter.'
                              : 'Messages from the hostel office will appear here.',
                          actionLabel: searchText.value.isNotEmpty || selectedFilter.value != 'All'
                              ? 'Clear Filters'
                              : null,
                          onAction: () {
                            searchController.clear();
                            searchText.value = '';
                            selectedFilter.value = 'All';
                          },
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                    sliver: SliverList.builder(
                      itemCount: filtered.length + (controller.hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == filtered.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                            ),
                          );
                        }
                        final item = filtered[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ExecutiveAnnouncementCard(
                            item: item,
                            onTap: () => _open(item),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Executive Announcement card matching the Phonebook / Student Contact styling
class _ExecutiveAnnouncementCard extends StatelessWidget {
  final InboxBroadcast item;
  final VoidCallback onTap;

  const _ExecutiveAnnouncementCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;
    const accentColor = Color(0xFFDB2777);
    const waveColor = Color(0xFFFCE7F3);

    return Container(
      decoration: BoxDecoration(
        color: unread ? const Color(0xFFFFF9FB) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: unread ? const Color(0xFFFBCFE8) : const Color(0xFFF1F5F9),
          width: unread ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: unread
                ? accentColor.withValues(alpha: 0.08)
                : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Bottom-right organic signature corner wave
              Positioned(
                bottom: 0,
                right: 0,
                child: CustomPaint(
                  size: const Size(110, 75),
                  painter: CornerWavePainter(
                    color: waveColor.withValues(alpha: unread ? 0.8 : 0.45),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: Squircle avatar + Title & time + Unread badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Squircle Campaign Icon
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: unread ? const Color(0xFFFDF2F8) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: unread
                                      ? const Color(0xFFFBCFE8)
                                      : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.campaign_rounded,
                                color: unread ? accentColor : const Color(0xFF94A3B8),
                                size: 23,
                              ),
                            ),
                            if (unread)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                                  fontSize: 15.5,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (item.senderName.isNotEmpty) ...[
                                    Text(
                                      item.senderName,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: unread ? accentColor : const Color(0xFF64748B),
                                      ),
                                    ),
                                    const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
                                  ],
                                  if (item.createdAt != null)
                                    Text(
                                      DateFormatting.relativeTime(item.createdAt!),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Message Preview Text
                    Text(
                      item.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF334155),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Metadata Light Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 4.5,
                      children: [
                        if (unread)
                          const CelebrantLightChip(
                            icon: Icons.mark_email_unread_rounded,
                            text: 'New Notice',
                            bgColor: Color(0xFFFDF2F8),
                            borderColor: Color(0xFFFBCFE8),
                            textColor: Color(0xFFDB2777),
                          )
                        else
                          const CelebrantLightChip(
                            icon: Icons.done_all_rounded,
                            text: 'Read',
                            bgColor: Color(0xFFF8FAFC),
                            borderColor: Color(0xFFE2E8F0),
                            textColor: Color(0xFF64748B),
                          ),
                        if (item.createdAt != null)
                          CelebrantLightChip(
                            icon: Icons.calendar_today_rounded,
                            text: DateFormatting.dateOnly(item.createdAt!),
                            bgColor: const Color(0xFFF8FAFC),
                            borderColor: const Color(0xFFE2E8F0),
                            textColor: const Color(0xFF475569),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ambient Orb Painter for the navy executive header
class _HeaderOrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.15), size.width * 0.45, fillPaint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.8), size.width * 0.35, fillPaint);

    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.38, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.62, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.86, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
