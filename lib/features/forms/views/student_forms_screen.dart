import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/models/forms/form_models.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/empty_state.dart';
import '../controllers/student_forms_controller.dart';

/// Student → Dashboard → Polls & Forms.
/// Executive Hostel Design featuring deep navy orb header, search & filters,
/// amber section header, and squircle form cards.
class StudentFormsScreen extends StatefulWidget {
  const StudentFormsScreen({super.key});

  @override
  State<StudentFormsScreen> createState() => _StudentFormsScreenState();
}

class _StudentFormsScreenState extends State<StudentFormsScreen> {
  final controller = Get.find<StudentFormsController>();
  final searchController = TextEditingController();
  final searchText = ''.obs;
  final selectedFilter = 'All'.obs; // 'All', 'To Answer', 'Polls', 'Forms', 'Answered'

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<StudentForm> _filterItems(List<StudentForm> all) {
    var filtered = all;
    final f = selectedFilter.value;
    final now = DateTime.now().toUtc();

    if (f == 'To Answer') {
      filtered = filtered.where((item) {
        final closed = item.endTime != null && item.endTime!.isBefore(now);
        return !item.hasSubmitted && !closed;
      }).toList();
    } else if (f == 'Polls') {
      filtered = filtered.where((item) => item.kind == FormKind.poll).toList();
    } else if (f == 'Forms') {
      filtered = filtered.where((item) => item.kind == FormKind.form).toList();
    } else if (f == 'Answered') {
      filtered = filtered.where((item) => item.hasSubmitted).toList();
    }

    final query = searchText.value.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((item) {
        final title = item.title.toLowerCase();
        final desc = (item.description ?? '').toLowerCase();
        return title.contains(query) || desc.contains(query);
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
                          // Top Bar: Back button, pending pill, refresh
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
                                final pending = controller.pendingCount;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pending > 0
                                        ? const Color(0xFFD97706).withValues(alpha: 0.3)
                                        : Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: pending > 0
                                          ? const Color(0xFFFBBF24)
                                          : Colors.white.withValues(alpha: 0.28),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        pending > 0
                                            ? Icons.pending_actions_rounded
                                            : Icons.task_alt_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        pending > 0 ? '$pending to answer' : 'All done',
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
                            'Polls & Forms',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your say in hostel decisions, menus, and campus surveys',
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
                            hintText: 'Search polls, forms, questions...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF7C3AED),
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

                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Obx(() {
                          final cur = selectedFilter.value;
                          final allItems = controller.forms;
                          final now = DateTime.now().toUtc();
                          final toAnswerCount = allItems.where((i) {
                            final closed = i.endTime != null && i.endTime!.isBefore(now);
                            return !i.hasSubmitted && !closed;
                          }).length;
                          final pollsCount = allItems.where((i) => i.kind == FormKind.poll).length;
                          final formsCount = allItems.where((i) => i.kind == FormKind.form).length;
                          final answeredCount = allItems.where((i) => i.hasSubmitted).length;

                          return Row(
                            children: [
                              _FilterChip(
                                label: 'All',
                                count: allItems.length,
                                isSelected: cur == 'All',
                                onTap: () => selectedFilter.value = 'All',
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'To Answer',
                                count: toAnswerCount,
                                isSelected: cur == 'To Answer',
                                activeBadgeColor: const Color(0xFFD97706),
                                onTap: () => selectedFilter.value = 'To Answer',
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Polls',
                                count: pollsCount,
                                isSelected: cur == 'Polls',
                                onTap: () => selectedFilter.value = 'Polls',
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Forms',
                                count: formsCount,
                                isSelected: cur == 'Forms',
                                onTap: () => selectedFilter.value = 'Forms',
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Answered',
                                count: answeredCount,
                                isSelected: cur == 'Answered',
                                onTap: () => selectedFilter.value = 'Answered',
                              ),
                            ],
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),

              // Content Area
              Obx(() {
                if (controller.isLoading.value && controller.forms.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0284C7),
                        strokeWidth: 2.5,
                      ),
                    ),
                  );
                }

                if (controller.hasError.value && controller.forms.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load polls',
                      message: controller.errorMessage.value,
                      actionLabel: 'Retry',
                      onAction: controller.load,
                    ),
                  );
                }

                final items = _filterItems(controller.forms);

                if (items.isEmpty) {
                  final isSearching = searchText.value.isNotEmpty;
                  final filterName = selectedFilter.value;
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: isSearching ? Icons.search_off_rounded : Icons.how_to_vote_outlined,
                      title: isSearching
                          ? 'No matching polls or forms'
                          : (filterName == 'To Answer'
                              ? 'All caught up!'
                              : 'No polls open right now'),
                      message: isSearching
                          ? 'Try searching for different keywords or check spelling.'
                          : (filterName == 'To Answer'
                              ? 'You have answered all open polls and forms. Check back later!'
                              : 'Hostel surveys and opinion polls will appear here.'),
                      actionLabel: isSearching ? 'Clear Search' : null,
                      onAction: isSearching
                          ? () {
                              searchController.clear();
                              searchText.value = '';
                            }
                          : null,
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == 0) {
                          // Section header with amber dash
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
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
                                  'ACTIVE POLLS & FORMS (${items.length})',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final item = items[index - 1];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ExecutiveFormCard(
                            form: item,
                            onTap: () => Get.toNamed(Routes.studentFormFill, arguments: item.id),
                          ),
                        );
                      },
                      childCount: items.length + 1,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// Executive Form & Poll Card
class _ExecutiveFormCard extends StatelessWidget {
  final StudentForm form;
  final VoidCallback onTap;

  const _ExecutiveFormCard({
    required this.form,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final f = form;
    final isPoll = f.kind == FormKind.poll;
    final now = DateTime.now().toUtc();
    final isClosed = f.endTime != null && f.endTime!.isBefore(now);
    final needsAnswer = !f.hasSubmitted && !isClosed;

    final kindColor = isPoll ? const Color(0xFF7C3AED) : const Color(0xFF0D9488);
    final kindBg = isPoll ? const Color(0xFFF5F3FF) : const Color(0xFFF0FDFA);
    final kindBorder = isPoll ? const Color(0xFFDDD6FE) : const Color(0xFF99F6E4);
    final waveColor = isPoll ? const Color(0xFFEDE9FE) : const Color(0xFFCCFBF1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: needsAnswer && f.isMandatory
              ? const Color(0xFFFCD34D)
              : const Color(0xFFF1F5F9),
          width: needsAnswer && f.isMandatory ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Decorative subtle wave in bottom right corner
            Positioned(
              bottom: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(90, 60),
                painter: _CornerWavePainter(color: waveColor),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Squircle icon, kind chip, status chips, chevron
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: kindBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: kindBorder),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              isPoll ? Icons.how_to_vote_rounded : Icons.assignment_rounded,
                              color: kindColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _CelebrantLightChip(
                                      icon: isPoll ? Icons.how_to_vote_rounded : Icons.assignment_rounded,
                                      text: isPoll ? 'Poll' : 'Form',
                                      bgColor: kindBg,
                                      borderColor: kindBorder,
                                      textColor: kindColor,
                                    ),
                                    if (f.hasSubmitted)
                                      const _CelebrantLightChip(
                                        icon: Icons.check_circle_rounded,
                                        text: 'Answered',
                                        bgColor: Color(0xFFDCFCE7),
                                        borderColor: Color(0xFF86EFAC),
                                        textColor: Color(0xFF16A34A),
                                      )
                                    else if (isClosed)
                                      const _CelebrantLightChip(
                                        icon: Icons.event_busy_rounded,
                                        text: 'Closed',
                                        bgColor: Color(0xFFF1F5F9),
                                        borderColor: Color(0xFFE2E8F0),
                                        textColor: Color(0xFF64748B),
                                      )
                                    else if (f.isMandatory)
                                      const _CelebrantLightChip(
                                        icon: Icons.priority_high_rounded,
                                        text: 'Required',
                                        bgColor: Color(0xFFFFE4E6),
                                        borderColor: Color(0xFFFDA4AF),
                                        textColor: Color(0xFFE11D48),
                                      )
                                    else
                                      const _CelebrantLightChip(
                                        icon: Icons.schedule_rounded,
                                        text: 'Open',
                                        bgColor: Color(0xFFE0F2FE),
                                        borderColor: Color(0xFFBAE6FD),
                                        textColor: Color(0xFF0284C7),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Title
                      Text(
                        f.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                          height: 1.25,
                        ),
                      ),

                      // Description
                      if (f.description != null && f.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          f.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      const Divider(color: Color(0xFFF1F5F9), height: 1),
                      const SizedBox(height: 10),

                      // Footer: Questions count & End time / Mandatory notice
                      Row(
                        children: [
                          _CelebrantLightChip(
                            icon: Icons.quiz_outlined,
                            text: '${f.fields.length} ${f.fields.length == 1 ? 'question' : 'questions'}',
                            bgColor: const Color(0xFFF8FAFC),
                            borderColor: const Color(0xFFE2E8F0),
                            textColor: const Color(0xFF64748B),
                          ),
                          if (f.endTime != null) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: _CelebrantLightChip(
                                icon: Icons.event_outlined,
                                text: 'Closes ${DateFormatting.dateTime(f.endTime!)}',
                                bgColor: const Color(0xFFF8FAFC),
                                borderColor: const Color(0xFFE2E8F0),
                                textColor: isClosed ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                              ),
                            ),
                          ] else
                            const Spacer(),
                          if (needsAnswer && f.isMandatory) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFCD34D)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFB45309)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Mandatory',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filter chip for the horizontal categories list
class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color? activeBadgeColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    this.activeBadgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF032B4F) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF032B4F) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: const Color(0xFF032B4F).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              else
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (activeBadgeColor ?? Colors.white.withValues(alpha: 0.22))
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
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

/// Celebrant light chip for metadata pills
class _CelebrantLightChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;

  const _CelebrantLightChip({
    required this.icon,
    required this.text,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: textColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ambient glowing orbs in the header background
class _HeaderOrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final orb1 = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.2), 65, orb1);

    final orb2 = Paint()
      ..color = const Color(0xFF7C3AED).withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.8), 75, orb2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Subtle corner wave decoration for executive cards
class _CornerWavePainter extends CustomPainter {
  final Color color;
  const _CornerWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(size.width * 0.45, size.height * 0.85, size.width * 0.6, size.height * 0.4);
    path.quadraticBezierTo(size.width * 0.75, 0, size.width, 0);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
