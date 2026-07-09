import 'package:flutter/material.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';

import 'package:icare/services/medical_record_service.dart';

class RecordVitalsScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  const RecordVitalsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<RecordVitalsScreen> createState() => _RecordVitalsScreenState();
}

class _RecordVitalsScreenState extends State<RecordVitalsScreen> {
  final _formKey = GlobalKey<FormState>();
  final MedicalRecordService _medicalRecordService = MedicalRecordService();

  final _bpSystolicController = TextEditingController();
  final _bpDiastolicController = TextEditingController();
  final _tempController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _spo2Controller = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _respiratoryRateController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _tempController.dispose();
    _heartRateController.dispose();
    _spo2Controller.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _respiratoryRateController.dispose();
    super.dispose();
  }

  void _saveVitals() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final vitalsData = {
        'patientId': widget.patientId,
        'vitals': {
          'bloodPressure':
              '${_bpSystolicController.text}/${_bpDiastolicController.text}',
          'temperature': _tempController.text,
          'heartRate': _heartRateController.text,
          'spO2': _spo2Controller.text,
          'weight': _weightController.text,
          'height': _heightController.text,
          'respiratoryRate': _respiratoryRateController.text,
        },
        'recordedAt': DateTime.now().toIso8601String(),
      };

      final result = await _medicalRecordService.createMedicalRecord({
        'patientId': widget.patientId,
        'type': 'vitals',
        'content': vitalsData,
      });

      if (result['success'] && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vitals recorded successfully in DHR'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Something went wrong. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
          'Record Patient Vitals',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPatientHeader(),
              const SizedBox(height: 32),
              _buildSectionTitle('Circulatory System'),
              Row(
                children: [
                  Expanded(
                    child: _buildVitalField(
                      'BP Systolic',
                      _bpSystolicController,
                      'mmHg',
                      Icons.speed_rounded,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildVitalField(
                      'BP Diastolic',
                      _bpDiastolicController,
                      'mmHg',
                      Icons.speed_rounded,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildVitalField(
                'Heart Rate',
                _heartRateController,
                'bpm',
                Icons.favorite_rounded,
                Colors.pink,
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Respiratory & Temperature'),
              Row(
                children: [
                  Expanded(
                    child: _buildVitalField(
                      'SpO2',
                      _spo2Controller,
                      '%',
                      Icons.air_rounded,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildVitalField(
                      'Resp. Rate',
                      _respiratoryRateController,
                      'br/m',
                      Icons.air_rounded,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildVitalField(
                'Temperature',
                _tempController,
                '°F',
                Icons.thermostat_rounded,
                Colors.orange,
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Body Metrics'),
              Row(
                children: [
                  Expanded(
                    child: _buildVitalField(
                      'Weight',
                      _weightController,
                      'kg',
                      Icons.monitor_weight_rounded,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildVitalField(
                      'Height',
                      _heightController,
                      'cm',
                      Icons.height_rounded,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  label: _isSaving ? 'Recording...' : 'Save Vitals to Record',
                  onPressed: _isSaving ? null : _saveVitals,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.patientName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Text(
                'Digital Health Record #8821',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildVitalField(
    String label,
    TextEditingController controller,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            decoration: InputDecoration(
              suffixText: unit,
              suffixStyle: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
              ),
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              hintText: '00',
              hintStyle: TextStyle(color: Colors.grey[300]),
            ),
          ),
        ],
      ),
    );
  }
}
