import 'package:flutter/material.dart';
import 'complaint_module_screen.dart';

/// Complaint Solver dashboard â€” delegates directly to the modern
/// multi-tab [ComplainModuleScreen] matching the Laundry Module.
class ComplainSolverScreen extends StatelessWidget {
  const ComplainSolverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComplainModuleScreen();
  }
}
