import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_routes.dart';
import '../student_profile/student_profile_controller.dart';

/// Vehicle registration is now just a field on the student profile (spec
/// §5.11) — this route exists only so old deep links / shortcuts still
/// land somewhere sensible, by forwarding straight into the profile editor.
class VehicleRedirectScreen extends StatelessWidget {
  const VehicleRedirectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = Get.find<StudentProfileController>().profile.value;
      Get.offNamed(Routes.studentProfileEdit, arguments: profile);
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
