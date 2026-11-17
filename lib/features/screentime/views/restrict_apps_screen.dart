import '../widgets/app_limit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/app_button.dart';
import '../controllers/screen_time_utils.dart';
import '../controllers/student_detail_controller.dart';
import '../widgets/app_brand_icon.dart';
import '../widgets/screen_time_page.dart';

/// Block apps for one student, on their own screen: common presets as
/// tappable tiles, the apps this student actually used today, and a custom
/// package fallback.
class RestrictAppsScreen extends StatefulWidget {
  final StudentDetailController controller;
  const RestrictAppsScreen({super.key, required this.controller});

  static Future<void> open(BuildContext context, StudentDetailController controller) =>
      ScreenTimePage.push(context, RestrictAppsScreen(controller: controller));

  @override
  State<RestrictAppsScreen> createState() => _RestrictAppsScreenState();
}

class _RestrictAppsScreenState extends State<RestrictAppsScreen> {
  StudentDetailController get controller => widget.controller;
  final _pkgCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _showCustom = false;
  bool _multiSelect = false;
  final Set<String> _selectedPkgs = {};
  final Map<String, String> _pkgToName = {};

  @override
  void dispose() {
    _pkgCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _toggleSelect(String pkg, String name) {
    setState(() {
      if (_selectedPkgs.contains(pkg)) {
        _selectedPkgs.remove(pkg);
        _pkgToName.remove(pkg);
      } else {
        _selectedPkgs.add(pkg);
        _pkgToName[pkg] = name;
      }
    });
  }

  Future<void> _handleBulkAction(bool block) async {
    final list = _selectedPkgs
        .map((pkg) => (packageName: pkg, appName: _pkgToName[pkg] ?? pkg))
        .toList();
    setState(() {
      _selectedPkgs.clear();
      _pkgToName.clear();
      _multiSelect = false;
    });
    await controller.batchSetAppBlocks(list, block);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenTimePage(
      title: 'Restrict apps',
      subtitle: ScreenTimePage.studentLine(controller.selectedStudent.value),
      bottomNavigationBar: _multiSelect && _selectedPkgs.isNotEmpty
          ? Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    '${_selectedPkgs.length} selected',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _handleBulkAction(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.successGreen,
                      side: const BorderSide(color: AppColors.successGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Allow All', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _handleBulkAction(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cancelledRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.block_rounded, size: 16),
                    label: const Text('Block All', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ],
              ),
            )
          : null,
      body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _multiSelect
                    ? 'Select apps to apply rules in bulk.'
                    : 'Tap to block or allow. Long-press to set a daily time limit.',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _multiSelect = !_multiSelect;
                  if (!_multiSelect) {
                    _selectedPkgs.clear();
                    _pkgToName.clear();
                  }
                });
              },
              icon: Icon(
                _multiSelect ? Icons.close : Icons.checklist_rounded,
                size: 16,
                color: _multiSelect ? AppColors.cancelledRed : AppColors.primary,
              ),
              label: Text(
                _multiSelect ? 'Cancel' : 'Select Multi',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _multiSelect ? AppColors.cancelledRed : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.gapLg),
        Obx(() {
          final blocked = controller.blockedPackages;
          // Apps seen on the device that aren't already in the presets.
          final presetPkgs = StudentDetailController.presetDistractingApps.map((p) => p['pkg']).toSet();
          final used = controller.currentDayRawApps
              .whereType<Map>()
              .map((a) => (
                    pkg: (a['packageName'] ?? a['package_name'] ?? '').toString(),
                    name: (a['appName'] ?? a['app_name'] ?? '').toString(),
                  ))
              .where((a) => a.pkg.isNotEmpty && !presetPkgs.contains(a.pkg))
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Common distractions', style: AppTextStyles.subtitle),
              const SizedBox(height: 10),
              _grid([
                for (final p in StudentDetailController.presetDistractingApps)
                  _AppTile(
                    pkg: p['pkg']!,
                    name: p['name']!,
                    blocked: blocked.contains(p['pkg']),
                    limitMinutes: controller.appLimits[p['pkg']!] ?? 0,
                    isSelected: _selectedPkgs.contains(p['pkg']!),
                    isSelectionMode: _multiSelect,
                    onTap: _multiSelect
                        ? () => _toggleSelect(p['pkg']!, p['name']!)
                        : () => controller.toggleAppBlock(p['pkg']!, p['name']!, !blocked.contains(p['pkg'])),
                    onLongPress: _multiSelect
                        ? null
                        : () => AppLimitSheet.show(
                              context,
                              controller: controller,
                              packageName: p['pkg']!,
                              appName: p['name']!,
                              currentLimit: controller.appLimits[p['pkg']!] ?? 0,
                              currentUsage: controller.usedTodayMinutes(p['pkg']!),
                            ),
                  ),
              ]),
              if (used.isNotEmpty) ...[
                const SizedBox(height: AppDimens.gapXl),
                Text('Used on this phone', style: AppTextStyles.subtitle),
                const SizedBox(height: 10),
                _grid([
                  for (final a in used)
                    _AppTile(
                      pkg: a.pkg,
                      name: a.name.isNotEmpty ? a.name : a.pkg.split('.').last,
                      blocked: blocked.contains(a.pkg),
                      limitMinutes: controller.appLimits[a.pkg] ?? 0,
                      isSelected: _selectedPkgs.contains(a.pkg),
                      isSelectionMode: _multiSelect,
                      onTap: _multiSelect
                          ? () => _toggleSelect(a.pkg, a.name.isNotEmpty ? a.name : a.pkg.split('.').last)
                          : () => controller.toggleAppBlock(a.pkg, a.name, !blocked.contains(a.pkg)),
                      onLongPress: _multiSelect
                          ? null
                          : () => AppLimitSheet.show(
                                context,
                                controller: controller,
                                packageName: a.pkg,
                                appName: a.name.isNotEmpty ? a.name : a.pkg.split('.').last,
                                currentLimit: controller.appLimits[a.pkg] ?? 0,
                                currentUsage: controller.usedTodayMinutes(a.pkg),
                              ),
                    ),
                ]),
              ],
            ],
          );
        }),
        const SizedBox(height: AppDimens.gapXl),

        // Custom package (collapsed by default — it's the rare path)
        InkWell(
          onTap: () => setState(() => _showCustom = !_showCustom),
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text('Block by package name', style: AppTextStyles.subtitle),
                const Spacer(),
                Icon(_showCustom ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _showCustom ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('App name', 'e.g. Free Fire'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pkgCtrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: _dec('Package name', 'e.g. com.dts.freefireth'),
              ),
              const SizedBox(height: 4),
              Text(
                'Find it in the Play Store link: play.google.com/store/apps/details?id=<package>',
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Block this app',
                icon: Icons.block_rounded,
                variant: AppButtonVariant.danger,
                onPressed: () {
                  final pkg = _pkgCtrl.text.trim();
                  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$').hasMatch(pkg)) {
                    AppSnackbar.warning('Invalid package', 'Package names look like com.company.app');
                    return;
                  }
                  controller.addCustomBlockedApp(pkg, _nameCtrl.text.trim());
                  _pkgCtrl.clear();
                  _nameCtrl.clear();
                  setState(() => _showCustom = false);
                },
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }

  Widget _grid(List<Widget> tiles) => GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
        children: tiles,
      );

  InputDecoration _dec(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimens.radiusMd)),
      );
}

class _AppTile extends StatelessWidget {
  final String pkg;
  final String name;
  final bool blocked;
  final int limitMinutes;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _AppTile({
    required this.pkg,
    required this.name,
    required this.blocked,
    this.limitMinutes = 0,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? const Color(0xFF0284C7)
        : (blocked ? AppColors.cancelledRed.withValues(alpha: 0.5) : AppColors.borderLight);
    final bgColor = isSelected
        ? const Color(0xFFE0F2FE)
        : (blocked ? AppColors.cancelledRed.withValues(alpha: 0.08) : AppColors.surfaceMuted);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.0 : (blocked ? 1.5 : 1),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppBrandIcon(packageName: pkg, appName: name, size: 40, isBlocked: blocked),
                const SizedBox(height: 6),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFF0284C7)
                        : (blocked ? AppColors.cancelledRed : AppColors.textPrimary),
                  ),
                ),
                if (limitMinutes > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${formatMinutes(limitMinutes)} limit',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 9,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelectionMode)
              Positioned(
                top: 0,
                right: 2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0284C7) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
