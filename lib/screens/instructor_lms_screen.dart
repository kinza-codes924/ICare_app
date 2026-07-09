import 'package:flutter/material.dart';
import 'package:icare/screens/instructor_lms_dashboard.dart';

// This file is the entry point for the LMS from the instructor's main dashboard.
// It simply renders InstructorLmsDashboard (the Google Classroom-style shell).
class InstructorLmsScreen extends StatelessWidget {
  const InstructorLmsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InstructorLmsDashboard();
  }
}
