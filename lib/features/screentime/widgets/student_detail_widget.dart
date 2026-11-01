import 'package:flutter/material.dart';
import '../controllers/student_detail_controller.dart';

/// Base for the cards of one student's Screen Time details: they all read the
/// opened student's [controller], which is passed down from the details page
/// (the controller belongs to that student alone and is not a global).
abstract class StudentDetailWidget extends StatelessWidget {
  final StudentDetailController controller;
  const StudentDetailWidget({super.key, required this.controller});
}
