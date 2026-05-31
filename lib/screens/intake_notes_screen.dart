import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/services/clinical_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

class IntakeNotesScreen extends StatefulWidget {
  final AppointmentDetail appointment;
  final bool isReadOnly;

  const IntakeNotesScreen({super.key, required this.appointment, this.isReadOnly = false});

  @override
  State<IntakeNotesScreen> createState() => _IntakeNotesScreenState();
}

class _IntakeNotesScreenState extends State<IntakeNotesScreen> {
  final _formKey = GlobalKey<FormState>();
  final ClinicalService _clinicalService = ClinicalService();

  final TextEditingController _complaintController = TextEditingController();
  final TextEditingController _historyController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _familyHistoryController =
      TextEditingController();

  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingNotes();
  }

  Future<void> _loadExistingNotes() async {
    setState(() => _isLoading = true);
    final notes = await _clinicalService.getIntakeNotes(
      widget.appointment.id ?? '',
    );
    if (notes != null && mounted) {
      setState(() {
        _complaintController.text = notes['chiefComplaint'] ?? '';
        _historyController.text = notes['historyOfIllness'] ?? '';
        _medicationsController.text = notes['currentMedications'] ?? '';
        _allergiesController.text = notes['allergies'] ?? '';
        _familyHistoryController.text = notes['familyHistory'] ?? '';
      });
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveIntakeNotes() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final notesData = {
        'chiefComplaint': _complaintController.text,
        'historyOfIllness': _historyController.text,
        'currentMedications': _medicationsController.text,
        'allergies': _allergiesController.text,
        'familyHistory': _familyHistoryController.text,
      };

      await _clinicalService.saveIntakeNotes(
        widget.appointment.id ?? '',
        notesData,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intake notes saved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Something went wrong. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          'Intake Notes',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: widget.isReadOnly
            ? [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_rounded, size: 14, color: Color(0xFF64748B)),
                      SizedBox(width: 6),
                      Text('Read Only', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      'Chief Complaint',
                      Icons.medical_information_rounded,
                    ),
                    _buildTextField(
                      _complaintController,
                      'What is the main reason for your visit?',
                      maxLines: 3,
                    ),

                    const SizedBox(height: 32),
                    _buildSectionHeader(
                      'History of Present Illness',
                      Icons.history_rounded,
                    ),
                    _buildTextField(
                      _historyController,
                      'Provide details about your symptoms and when they started.',
                      maxLines: 5,
                    ),

                    const SizedBox(height: 32),
                    _buildSectionHeader(
                      'Current Medications',
                      Icons.medication_rounded,
                    ),
                    _buildTextField(
                      _medicationsController,
                      'List any medications you are currently taking.',
                      maxLines: 3,
                    ),

                    const SizedBox(height: 32),
                    _buildSectionHeader(
                      'Allergies',
                      Icons.warning_amber_rounded,
                    ),
                    _buildTextField(
                      _allergiesController,
                      'List any known allergies (medication, food, etc.).',
                      maxLines: 2,
                    ),

                    const SizedBox(height: 32),
                    _buildSectionHeader('Family History', Icons.people_rounded),
                    _buildTextField(
                      _familyHistoryController,
                      'Any relevant family medical history?',
                      maxLines: 3,
                    ),

                    if (!widget.isReadOnly) ...[
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveIntakeNotes,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isSaving
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Save Intake Notes',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryColor, size: 20),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    final readOnly = widget.isReadOnly;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(
        hintText: controller.text.isEmpty ? (readOnly ? 'Not provided' : hint) : null,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        filled: true,
        fillColor: readOnly ? const Color(0xFFF8FAFC) : Colors.white,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
        ),
      ),
    );
  }
}
