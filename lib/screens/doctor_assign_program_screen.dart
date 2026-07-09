import 'package:flutter/material.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/models/course.dart';
import 'package:icare/services/course_service.dart';
import 'package:icare/services/instructor_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';

class DoctorAssignProgramScreen extends StatefulWidget {
  final AppointmentDetail appointment;

  const DoctorAssignProgramScreen({super.key, required this.appointment});

  @override
  State<DoctorAssignProgramScreen> createState() =>
      _DoctorAssignProgramScreenState();
}

class _DoctorAssignProgramScreenState extends State<DoctorAssignProgramScreen> {
  final InstructorService _instructorService = InstructorService();
  final CourseService _courseService = CourseService();

  Course? _selectedProgram;
  List<Course> _availablePrograms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    try {
      // Fetch public health programs (LMS courses categorized for patients)
      final programs = await _courseService.getHealthPrograms();
      setState(() {
        _availablePrograms = programs;
        _isLoading = false;
        if (_availablePrograms.isNotEmpty) {
          _selectedProgram = _availablePrograms.first;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _assignProgram() async {
    if (_selectedProgram == null) return;

    try {
      await _instructorService.assignCourse(
        _selectedProgram!.id,
        widget.appointment.patient!.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Care Plan assigned successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Login failed. Please check your credentials.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Prescribe Care Plan',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPatientHeader(),
            const SizedBox(height: 32),
            const Text(
              'Select Health Program',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const Text(
              'Assign a structured care plan to support the treatment.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_availablePrograms.isEmpty)
              const Text('No health programs available in the library.')
            else
              _buildProgramList(),

            const SizedBox(height: 40),
            CustomButton(
              label: 'Assign to Patient',
              onPressed: _selectedProgram != null ? _assignProgram : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryColor,
            child: Text(
              widget.appointment.patient?.name[0] ?? 'P',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.appointment.patient?.name ?? 'Patient',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Text(
                'Digital Health Record Active',
                style: TextStyle(fontSize: 12, color: AppColors.primaryColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgramList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _availablePrograms.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final program = _availablePrograms[i];
        final isSelected = _selectedProgram?.id == program.id;
        return ListTile(
          onTap: () => setState(() => _selectedProgram = program),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? AppColors.primaryColor
                  : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
          ),
          tileColor: Colors.white,
          leading: Icon(
            Icons.health_and_safety_rounded,
            color: isSelected
                ? AppColors.primaryColor
                : const Color(0xFF64748B),
          ),
          title: Text(
            program.title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          trailing: isSelected
              ? const Icon(Icons.check_circle, color: AppColors.primaryColor)
              : null,
        );
      },
    );
  }
}
