import 'package:flutter/material.dart';
import 'package:icare/models/user.dart';
import 'package:icare/services/referral_service.dart';
import 'package:icare/services/doctor_service.dart';
import 'package:icare/services/medical_record_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

class CreateReferralScreen extends StatefulWidget {
  final User? patient;
  final String? appointmentId;

  const CreateReferralScreen({
    super.key,
    required this.patient,
    this.appointmentId,
  });

  @override
  State<CreateReferralScreen> createState() => _CreateReferralScreenState();
}

class _CreateReferralScreenState extends State<CreateReferralScreen> {
  final _formKey = GlobalKey<FormState>();
  final ReferralService _referralService = ReferralService();
  final DoctorService _doctorService = DoctorService();
  final MedicalRecordService _medicalRecordService = MedicalRecordService();

  final _reasonController = TextEditingController();
  final _clinicalNotesController = TextEditingController();

  List<dynamic> _specialists = [];
  List<dynamic> _medicalRecords = [];
  dynamic _selectedSpecialist;
  final List<String> _selectedRecords = [];
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);

    // Load specialists
    final doctorsResult = await _doctorService.getAllDoctors();
    if (doctorsResult['success']) {
      _specialists = doctorsResult['doctors'];
    }

    // Load patient's medical records
    final recordsResult = await _medicalRecordService.getPatientRecords(
      widget.patient?.id ?? '',
    );
    if (recordsResult['success']) {
      _medicalRecords = recordsResult['records'];
    }

    setState(() => _isLoadingData = false);
  }

  Future<void> _createReferral() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSpecialist == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a specialist')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'patientId': widget.patient?.id ?? '',
      'referredTo': _selectedSpecialist['_id'],
      'reason': _reasonController.text,
      'clinicalNotes': _clinicalNotesController.text,
      'attachedRecords': _selectedRecords,
    };

    final result = await _referralService.createReferral(data);

    setState(() => _isLoading = false);

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referral created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to create referral'),
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
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Create Referral',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Gilroy-Bold',
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient Info Card
                    _buildPatientCard(),
                    const SizedBox(height: 24),

                    // Select Specialist
                    _buildSectionTitle('Select Specialist'),
                    const SizedBox(height: 12),
                    _buildSpecialistSelector(),
                    const SizedBox(height: 24),

                    // Reason for Referral
                    _buildSectionTitle('Reason for Referral'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter reason for referral...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter reason for referral';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Clinical Notes
                    _buildSectionTitle('Clinical Notes (Optional)'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _clinicalNotesController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Add relevant clinical information...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Attach Medical Records
                    _buildSectionTitle('Attach Medical Records (Optional)'),
                    const SizedBox(height: 12),
                    _buildMedicalRecordsSelector(),
                    const SizedBox(height: 32),

                    // Create Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createReferral,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Create Referral',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPatientCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryColor, Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                (widget.patient?.name ?? '?').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Patient',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.patient?.name ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.patient?.email ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildSpecialistSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          isExpanded: true,
          value: _selectedSpecialist,
          hint: const Text('Select a specialist'),
          items: _specialists.map((specialist) {
            return DropdownMenuItem<dynamic>(
              value: specialist,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    specialist['name'] ?? 'Doctor',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (specialist['specialization'] != null)
                    Text(
                      specialist['specialization'],
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedSpecialist = value);
          },
        ),
      ),
    );
  }

  Widget _buildMedicalRecordsSelector() {
    if (_medicalRecords.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          'No medical records available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: _medicalRecords.map((record) {
        final recordId = record['_id'] ?? '';
        final isSelected = _selectedRecords.contains(recordId);

        return CheckboxListTile(
          value: isSelected,
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                _selectedRecords.add(recordId);
              } else {
                _selectedRecords.remove(recordId);
              }
            });
          },
          title: Text(
            record['diagnosis'] ?? 'Medical Record',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'Date: ${record['createdAt'] != null ? DateTime.parse(record['createdAt']).toString().split(' ')[0] : 'N/A'}',
            style: const TextStyle(fontSize: 12),
          ),
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _clinicalNotesController.dispose();
    super.dispose();
  }
}
