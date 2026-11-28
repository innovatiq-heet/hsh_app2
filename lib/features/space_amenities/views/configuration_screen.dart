import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/models/space_amenities/space_amenity_models.dart';
import '../../../core/network/repository/space_amenities/space_amenities_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_sliver_header.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../utils/space_amenity_access.dart';

class SpaceConfigurationScreen extends StatefulWidget {
  const SpaceConfigurationScreen({super.key});

  @override
  State<SpaceConfigurationScreen> createState() => _SpaceConfigurationScreenState();
}

class _SpaceConfigurationScreenState extends State<SpaceConfigurationScreen> {
  final _repo = Get.find<SpaceAmenitiesRepository>();
  SpaceConfigResponse? _config;
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) setState(() { _loading = true; _error = null; });
    try {
      final res = await _repo.config();
      if (mounted) setState(() { _config = res; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _addSpaceTypeDialog({SpaceTypeModel? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final capCtrl = TextEditingController(text: existing?.defaultCapacity?.toString() ?? '');
    bool isRoom = existing?.isStudentRoom ?? false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'New Space Type' : 'Edit Space Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *')),
              const SizedBox(height: 10),
              TextField(controller: capCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Default Capacity')),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: isRoom,
                onChanged: (v) => setS(() => isRoom = v ?? false),
                title: const Text('Student room type'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
          ],
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    final cap = int.tryParse(capCtrl.text.trim());
    nameCtrl.dispose();
    capCtrl.dispose();
    if (ok != true || name.isEmpty) return;
    try {
      await _repo.saveSpaceType(existing?.id, {
        'name': name,
        'default_capacity': cap,
        'is_student_room': isRoom,
      });
      AppSnackbar.success('Saved', '$name saved.');
      _load(showLoading: false);
    } catch (e) {
      AppSnackbar.error('Failed', e.toString());
    }
  }

  Future<void> _addCategoryDialog({AmenityCategoryModel? existing}) async {
    final ctrl = TextEditingController(text: existing?.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'New Amenity Category' : 'Edit Category'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Category Name *')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
        ],
      ),
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || name.isEmpty) return;
    try {
      await _repo.saveCategory(existing?.id, {'name': name});
      AppSnackbar.success('Saved', '$name saved.');
      _load(showLoading: false);
    } catch (e) {
      AppSnackbar.error('Failed', e.toString());
    }
  }

  Future<void> _addAmenityTypeDialog({AmenityTypeModel? existing}) async {
    final cfg = _config;
    if (cfg == null || cfg.categories.isEmpty) return;
    int catId = existing?.categoryId ?? cfg.categories.first.id;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final prefixCtrl = TextEditingController(text: existing?.codePrefix ?? '');
    final lifeCtrl = TextEditingController(text: existing?.defaultLifeMonths?.toString() ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'New Amenity Type' : 'Edit Amenity Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: catId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [for (final c in cfg.categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                onChanged: (v) { if (v != null) setS(() => catId = v); },
              ),
              const SizedBox(height: 10),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Type Name *', hintText: 'e.g. Solar Panel')),
              const SizedBox(height: 10),
              TextField(controller: prefixCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Code Prefix *', hintText: 'e.g. SLR')),
              const SizedBox(height: 10),
              TextField(controller: lifeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Expected Life (months, optional)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
          ],
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    final prefix = prefixCtrl.text.trim();
    final life = int.tryParse(lifeCtrl.text.trim());
    nameCtrl.dispose();
    prefixCtrl.dispose();
    lifeCtrl.dispose();
    if (ok != true || name.isEmpty) return;
    try {
      await _repo.saveAmenityType(existing?.id, {
        'category_id': catId,
        'name': name,
        'code_prefix': prefix,
        'default_life_months': ?life,
      });
      AppSnackbar.success('Saved', '$name saved.');
      _load(showLoading: false);
    } catch (e) {
      AppSnackbar.error('Failed', e.toString());
    }
  }

  Future<void> _addScheduleDialog() async {
    final titleCtrl = TextEditingController();
    final daysCtrl = TextEditingController(text: '90');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Preventive Schedule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Schedule Title *', hintText: 'e.g. AC Filter Cleaning')),
            const SizedBox(height: 10),
            TextField(controller: daysCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Interval (days)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
        ],
      ),
    );
    final title = titleCtrl.text.trim();
    final days = int.tryParse(daysCtrl.text.trim()) ?? 90;
    titleCtrl.dispose();
    daysCtrl.dispose();
    if (ok != true || title.isEmpty) return;
    try {
      await _repo.saveSchedule(null, {'title': title, 'interval_days': days});
      AppSnackbar.success('Saved', 'Preventive schedule added.');
      _load(showLoading: false);
    } catch (e) {
      AppSnackbar.error('Failed', e.toString());
    }
  }

  Future<void> _editWarrantyDays(int currentDays) async {
    final ctrl = TextEditingController(text: '$currentDays');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Warranty Reminder Window'),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Days before expiry')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
        ],
      ),
    );
    final days = int.tryParse(ctrl.text.trim());
    ctrl.dispose();
    if (ok != true || days == null) return;
    try {
      await _repo.saveSettings({'warranty_reminder_days': days});
      AppSnackbar.success('Updated', 'Warranty reminder set to $days days.');
      _load(showLoading: false);
    } catch (e) {
      AppSnackbar.error('Failed', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SpaceAmenityAccess.canConfigure) {
      return Scaffold(
        backgroundColor: PhonebookTheme.bg,
        body: CustomScrollView(
          slivers: [
            NavySliverHeader(
              title: 'Configuration',
              subtitle: 'Spaces, inventory types & maintenance rules',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.lock_outline,
                title: 'Restricted',
                message: 'Configuration is available to administrators and wardens.',
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: PhonebookTheme.bg,
      body: AsyncStateView(
        isLoading: _loading && _config == null,
        hasError: _error != null && _config == null,
        errorMessage: _error ?? '',
        onRetry: _load,
        loadingWidget: const SafeArea(child: SkeletonList()),
        builder: (_) {
          final cfg = _config!;
          final q = _search.trim().toLowerCase();
          final spaceTypes = cfg.spaceTypes.where((t) => q.isEmpty || t.name.toLowerCase().contains(q)).toList();
          final categories = cfg.categories.where((c) => q.isEmpty || c.name.toLowerCase().contains(q)).toList();
          final types = cfg.types.where((t) => q.isEmpty || t.name.toLowerCase().contains(q) || t.categoryName.toLowerCase().contains(q)).toList();
          final reminderDays = (cfg.settings['warranty_reminder_days'] as num?)?.toInt() ?? 30;

          return AppRefreshIndicator(
            onRefresh: () => _load(showLoading: false),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                NavySliverHeader(
                  title: 'Configuration',
                  subtitle: 'Spaces, inventory types & maintenance rules',
                  onBack: () => Navigator.of(context).pop(),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding, AppDimens.gapLg, AppDimens.screenPadding, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          onChanged: (v) => setState(() => _search = v),
                          decoration: InputDecoration(
                            hintText: 'Search configuration…',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: AppDimens.gapLg),
                        const PhonebookSectionHeader(title: 'Space Configuration'),
                        PhonebookCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.layers_outlined, color: PhonebookTheme.blue),
                                title: const Text('Floors & Spaces', style: TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: const Text('Navigate back to Overview → Hostel Floors to manage spaces per floor'),
                                trailing: const Icon(Icons.arrow_back_rounded, size: 18),
                                onTap: () => Navigator.of(context).pop(),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.category_outlined, color: PhonebookTheme.blue),
                                title: Text('Space Types (${spaceTypes.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle_outline_rounded, color: PhonebookTheme.blue),
                                  onPressed: () => _addSpaceTypeDialog(),
                                ),
                              ),
                              for (final st in spaceTypes)
                                ListTile(
                                  dense: true,
                                  title: Text(st.name),
                                  subtitle: Text(st.isStudentRoom ? 'Student room type' : 'Common / special space'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    onPressed: () => _addSpaceTypeDialog(existing: st),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimens.gapLg),
                        const PhonebookSectionHeader(title: 'Inventory Configuration'),
                        PhonebookCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.folder_outlined, color: PhonebookTheme.blue),
                                title: Text('Amenity Categories (${categories.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle_outline_rounded, color: PhonebookTheme.blue),
                                  onPressed: () => _addCategoryDialog(),
                                ),
                              ),
                              for (final c in categories)
                                ListTile(
                                  dense: true,
                                  title: Text(c.name),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    onPressed: () => _addCategoryDialog(existing: c),
                                  ),
                                ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.inventory_2_outlined, color: PhonebookTheme.blue),
                                title: Text('Amenity Types (${types.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle_outline_rounded, color: PhonebookTheme.blue),
                                  onPressed: () => _addAmenityTypeDialog(),
                                ),
                              ),
                              for (final t in types)
                                ListTile(
                                  dense: true,
                                  title: Text('${t.name} (${t.codePrefix})'),
                                  subtitle: Text(t.categoryName),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    onPressed: () => _addAmenityTypeDialog(existing: t),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimens.gapLg),
                        const PhonebookSectionHeader(title: 'Maintenance Configuration'),
                        PhonebookCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.event_repeat_outlined, color: PhonebookTheme.blue),
                                title: Text('Preventive Maintenance Schedules (${cfg.schedules.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle_outline_rounded, color: PhonebookTheme.blue),
                                  onPressed: _addScheduleDialog,
                                ),
                              ),
                              for (final s in cfg.schedules)
                                ListTile(
                                  dense: true,
                                  title: Text('${s['title'] ?? ''}'),
                                  subtitle: Text('Every ${s['interval_days'] ?? 90} days'),
                                ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.manage_accounts_outlined, color: PhonebookTheme.blue),
                                title: const Text('Maintenance & Solver Permissions', style: TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: const Text('Assign complaint categories to complaint solvers in Manage Users'),
                                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                                onTap: () => Get.toNamed(Routes.operatorManageUsers),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.notifications_active_outlined, color: PhonebookTheme.blue),
                                title: const Text('Warranty Reminders', style: TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text('Alert $reminderDays days before expiry'),
                                trailing: const Icon(Icons.edit_outlined, size: 18),
                                onTap: () => _editWarrantyDays(reminderDays),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
