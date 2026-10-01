import 'package:flutter/material.dart';
import '../complain_module/complain_module_screen.dart';

/// Complaint Solver dashboard — delegates directly to the modern
/// multi-tab [ComplainModuleScreen] matching the Laundry Module.
class ComplainSolverScreen extends StatelessWidget {
  const ComplainSolverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComplainModuleScreen();
  }
}
