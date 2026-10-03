import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/app_button.dart';
import '../controllers/student_screen_time_controller.dart';
import 'app_brand_icon.dart';
import 'sheet_scaffold.dart';

/// Bottom sheet to block apps: common presets as tappable tiles, the apps
/// this student actually used today, and a custom package fallback.
class RestrictAppSheet extends StatefulWidget {
  const RestrictAppSheet({super.key});

  static Future<void> show(BuildContext context) => Get.bottomSheet(
        const RestrictAppSheet(),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );

  @override
  State<RestrictAppSheet> createState() => _RestrictAppSheetState();
}

class _RestrictAppSheetState extends State<RestrictAppSheet> {
  final controller = Get.find<StudentScreenTimeController>();
  final _pkgCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _showCustom = false;

  @override
  void dispose() {
    _pkgCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Restrict apps',
      subtitle: 'Tap an app to block or allow it on the student\'s phone.',
      children: [
        Obx(() {
          final blocked = controller.blockedPackages;
          // Apps seen on the device that aren't already in the presets.
          final presetPkgs = StudentScreenTimeController.presetDistractingApps.map((p) => p['pkg']).toSet();
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
                for (final p in StudentScreenTimeController.presetDistractingApps)
                  _AppTile(
                    pkg: p['pkg']!,
                    name: p['name']!,
                    blocked: blocked.contains(p['pkg']),
                    onTap: () => controller.toggleAppBlock(p['pkg']!, p['name']!, !blocked.contains(p['pkg'])),
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
                      onTap: () => controller.toggleAppBlock(a.pkg, a.name, !blocked.contains(a.pkg)),
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
  final VoidCallback onTap;

  const _AppTile({required this.pkg, required this.name, required this.blocked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: blocked ? AppColors.cancelledRed.withValues(alpha: 0.08) : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(
            color: blocked ? AppColors.cancelledRed.withValues(alpha: 0.5) : AppColors.borderLight,
            width: blocked ? 1.5 : 1,
          ),
        ),
        child: Column(
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
                color: blocked ? AppColors.cancelledRed : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
