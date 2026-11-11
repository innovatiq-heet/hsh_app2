import 'package:get/get.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/models/forms/form_models.dart';
import '../../../core/network/repository/forms/forms_repository.dart';
import 'forms_manager_gate.dart';

/// Operator → Forms & Polls → Results. Route argument: a [HostelForm] or id.
class FormAnalyticsController extends GetxController with LoadStateMixin, FormsManagerGate {
  FormAnalyticsController({FormsRepository? repository, int? formId})
      : _repo = repository ?? Get.find<FormsRepository>(),
        _id = formId;

  final FormsRepository _repo;
  int? _id;

  final analytics = Rxn<FormAnalytics>();

  /// Title to show before the results arrive.
  final title = ''.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (_id == null) {
      if (args is HostelForm) {
        _id = args.id;
        title.value = args.title;
      } else {
        _id = int.tryParse(args?.toString() ?? '');
      }
    }
    _start();
  }

  Future<void> _start() async {
    if (await ensureManager()) {
      await load();
    } else {
      isLoading.value = false;
    }
  }

  Future<void> load({bool showLoading = true}) => guard(() async {
        final id = _id;
        if (id == null) throw StateError('No form id');
        final result = await _repo.analytics(id);
        analytics.value = result;
        if (result.form.title.isNotEmpty) title.value = result.form.title;
      }, showLoading: showLoading);
}
