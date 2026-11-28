import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/student_locations_controller.dart';
import '../widgets/campus_map_view.dart';
import '../widgets/student_locations_list_body.dart';

/// Modern, executive view of every student's last reported phone location,
/// styled with the signature deep navy header, sky-blue accents, and slate card styling
/// from the Phonebook screen.
///
/// Just the shell that switches between the two view modes; the actual
/// content lives in [CampusMapView] (map) and [StudentLocationsListBody]
/// (list, header, search, filters, cards).
class StudentLocationsScreen extends GetView<StudentLocationsController> {
  const StudentLocationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Obx(() => PopScope(
        canPop: !controller.isMapView.value,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (controller.isMapView.value) {
            controller.toggleViewMode();
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: controller.isMapView.value
              ? null
              : FloatingActionButton.extended(
                  heroTag: 'campus_map_fab',
                  onPressed: controller.toggleViewMode,
                  backgroundColor: const Color(0xFF0369A1),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  icon: const Icon(Icons.radar_rounded, size: 20),
                  label: const Text(
                    'Campus Map View',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
          body: controller.isMapView.value
              ? CampusMapView(controller: controller)
              : StudentLocationsListBody(controller: controller),
        ),
      )),
    );
  }
}
