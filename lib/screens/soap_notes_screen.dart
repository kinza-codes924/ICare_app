import 'package:flutter/material.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/services/clinical_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/icd_code_selector.dart';

class SoapNotesScreen extends StatefulWidget {
  final AppointmentDetail appointment;

  const SoapNotesScreen({super.key, required this.appointment});

  @override
  State<SoapNotesScreen> createState() => _SoapNotesScreenState();
}

class _SoapNotesScreenState extends State<SoapNotesScreen> {
  final _formKey = GlobalKey<FormState>();
  final ClinicalService _clinicalService = ClinicalService();

  final TextEditingController _subjectiveController = TextEditingController();
  final TextEditingController _objectiveController = TextEditingController();
  final TextEditingController _assessmentController = TextEditingController();
  final TextEditingController _planController = TextEditingController();

  final TextEditingController _referralReasonController =
      TextEditingController();
  String? _selectedSpecialty;

  List<Map<String, dynamic>> _selectedICDCodes = [];

  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingNotes();
  }

  Future<void> _loadExistingNotes() async {
    setState(() => _isLoading = true);
    final notes = await _clinicalService.getSoapNotes(
      widget.appointment.id ?? '',
    );
    if (mounted) {
      setState(() {
        _subjectiveController.text = notes['subjective'] ?? '';
        _objectiveController.text = notes['objective'] ?? '';
        _assessmentController.text = notes['assessment'] ?? '';
        _planController.text = notes['plan'] ?? '';
        if (notes['icdCodes'] != null) {
          _selectedICDCodes = List<Map<String, dynamic>>.from(notes['icdCodes']);
        }
      });
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveSoapNotes() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final notesData = {
        'subjective': _subjectiveController.text,
        'objective': _objectiveController.text,
        'assessment': _assessmentController.text,
        'plan': _planController.text,
        'icdCodes': _selectedICDCodes,
      };

      await _clinicalService.saveSoapNotes(
        widget.appointment.id ?? '',
        notesData,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOAP notes saved successfully!')),
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

  void _referPatient() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Refer Patient',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Refer to a specialist for further care.'),
            const SizedBox(height: 16),
            _buildDropdownField('Specialty', [
              'Cardiology',
              'Dermatology',
              'Neurology',
              'Orthopedics',
              'Pediatrics',
            ], (val) => _selectedSpecialty = val),
            const SizedBox(height: 12),
            _buildTextField(
              _referralReasonController,
              'Reason for referral',
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_selectedSpecialty == null ||
                  _referralReasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select specialty and provide reason'),
                  ),
                );
                return;
              }

              try {
                final referralData = {
                  'patientId': widget.appointment.patient?.id,
                  'specialty': _selectedSpecialty,
                  'reason': _referralReasonController.text,
                  'appointmentId': widget.appointment.id,
                };

                await _clinicalService.createReferral(referralData);

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Referral sent successfully!'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('Unable to submit. Please try again.')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Referral'),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
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
          'SOAP Notes',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _referPatient,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Refer'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryColor,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('S - Subjective', Icons.person_rounded),
              _buildTextField(
                _subjectiveController,
                'What does the patient report? (symptoms, concerns, duration)',
                maxLines: 5,
              ),

              const SizedBox(height: 32),
              _buildSectionHeader('O - Objective', Icons.visibility_rounded),
              _buildTextField(
                _objectiveController,
                'What do you observe? (vital signs, examination findings, results)',
                maxLines: 5,
              ),

              const SizedBox(height: 32),
              _buildSectionHeader('A - Assessment', Icons.assignment_rounded),
              _buildTextField(
                _assessmentController,
                'What is your clinical impression? (diagnosis, differential diagnosis)',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _buildICDCodesSection(),

              const SizedBox(height: 32),
              _buildSectionHeader('P - Plan', Icons.edit_note_rounded),
              _buildTextField(
                _planController,
                'What is the treatment plan? (medications, tests, follow-up, education)',
                maxLines: 5,
              ),

              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSoapNotes,
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
                          'Finalize SOAP Notes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
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
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        filled: true,
        fillColor: Colors.white,
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

  Widget _buildICDCodesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'ICD-10 Diagnosis Codes',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => ICDCodeSelector(
                    onCodeSelected: (code) {
                      setState(() {
                        if (!_selectedICDCodes.any((c) => c['code'] == code['code'])) {
                          _selectedICDCodes.add(code);
                        }
                      });
                    },
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('Add Code'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedICDCodes.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: const Color(0xFF94A3B8),
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'No diagnosis codes added yet',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedICDCodes.map((code) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        code['code'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        code['description'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedICDCodes.removeWhere((c) => c['code'] == code['code']);
                        });
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
