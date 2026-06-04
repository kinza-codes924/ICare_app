import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../services/laboratory_service.dart';
import '../widgets/back_button.dart';

class LabResultEntryScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const LabResultEntryScreen({super.key, required this.booking});

  @override
  State<LabResultEntryScreen> createState() => _LabResultEntryScreenState();
}

class _LabResultEntryScreenState extends State<LabResultEntryScreen>
    with SingleTickerProviderStateMixin {
  final LaboratoryService _labService = LaboratoryService();
  late TabController _tabController;
  bool _isSubmitting = false;

  // Step-by-step manual entry (3 steps)
  int _currentStep = 0; // 0=Verify, 1=Results, 2=Approve&Submit

  // Manual entry
  final List<Map<String, TextEditingController>> _parameters = [];

  // File upload
  PlatformFile? _selectedFile;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _specimenIdController = TextEditingController();

  // Doctor approval
  String? _selectedDoctor;
  List<Map<String, String>> _doctors = [];

  static const Color primaryColor = Color(0xFF0B2D6E);
  static const Color backgroundColor = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _addParameter(); // Start with one row
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    try {
      final profile = await _labService.getProfile();
      final list = (profile['doctors'] as List<dynamic>? ?? []);
      if (mounted) {
        setState(() {
          _doctors = list
              .map((d) => {
                    'name': d['name']?.toString() ?? '',
                    'qualification': d['education']?.toString() ?? '',
                    'designation': d['designation']?.toString() ?? '',
                  })
              .where((d) => d['name']!.isNotEmpty)
              .toList();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    _specimenIdController.dispose();
    for (final p in _parameters) {
      for (var c in p.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _addParameter() {
    setState(() {
      _parameters.add({
        'parameter': TextEditingController(),
        'value': TextEditingController(),
        'unit': TextEditingController(),
        'range': TextEditingController(),
      });
    });
  }

  void _removeParameter(int index) {
    if (_parameters.length <= 1) return;
    for (var c in _parameters[index].values) {
      c.dispose();
    }
    setState(() => _parameters.removeAt(index));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null) setState(() => _selectedFile = result.files.first);
  }

  Future<void> _submitManualEntry() async {
    final hasData = _parameters.any((p) => p['parameter']!.text.trim().isNotEmpty);
    if (!hasData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one test parameter'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final results = _parameters
          .where((p) => p['parameter']!.text.trim().isNotEmpty)
          .map((p) => {
                'testParameter': p['parameter']!.text.trim(),
                'value': p['value']!.text.trim(),
                'unit': p['unit']!.text.trim(),
                'referenceRange': p['range']!.text.trim(),
                'severity': 'normal',
              })
          .toList();
      await _labService.updateBooking(widget.booking['_id'], {
        'status': 'reporting_done',
        'results': results,
        'reportNotes': _notesController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Results submitted — patient & doctor notified ✅'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to submit results. Please try again.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitFileUpload() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a report file first'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final bytes = await File(_selectedFile!.path!).readAsBytes();
      await _labService.uploadReport(widget.booking['_id'], bytes, _selectedFile!.name);
      await _labService.updateBooking(widget.booking['_id'], {
        'status': 'reporting_done',
        'reportNotes': _notesController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report uploaded — patient & doctor notified ✅'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to upload report. Please try again.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final testName = booking['test_type'] ?? booking['testName'] ?? 'Lab Test';
    final date = DateTime.tryParse(booking['test_date'] ?? booking['date'] ?? booking['createdAt'] ?? '') ?? DateTime.now();
    final status = booking['status'] ?? 'pending';
    // Try multiple fields for patient name
    final patientName = booking['patient_name'] 
        ?? booking['patientName']
        ?? booking['patient']?['name']
        ?? booking['patient']?['username']
        ?? 'Unknown Patient';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          'Result Entry',
          style: TextStyle(fontSize: 18, fontFamily: 'Gilroy-Bold', fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.edit_note_rounded), text: 'Manual Entry'),
            Tab(icon: Icon(Icons.upload_file_rounded), text: 'Upload Report'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildBookingInfo(testName, patientName, date, status),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildManualEntryTab(),
                _buildUploadTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingInfo(String testName, String patientName, DateTime date, String status) {
    final statusColor = status == 'completed'
        ? Colors.green
        : status == 'confirmed'
        ? Colors.blue
        : Colors.orange;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF5), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.biotech_rounded, color: primaryColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(testName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text(
                  'Patient: $patientName',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntryTab() {
    return Column(
      children: [
        _buildStepIndicator(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _currentStep == 0
                  ? _buildStep1()
                  : _currentStep == 1
                      ? _buildStep2()
                      : _buildStep3(),
            ),
          ),
        ),
        _buildStepNavigation(),
      ],
    );
  }

  Widget _buildStepIndicator() {
    const steps = ['Sample Verify', 'Enter Results', 'Approve & Submit'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final i = entry.key;
          final label = entry.value;
          final isDone = i < _currentStep;
          final isActive = i == _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: isDone ? const Color(0xFF22C55E) : isActive ? primaryColor : const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                              : Text('${i + 1}', style: TextStyle(
                                  color: isActive ? Colors.white : const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(label, style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: isActive ? primaryColor : isDone ? const Color(0xFF22C55E) : const Color(0xFF94A3B8))),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Container(height: 2, width: 12, color: i < _currentStep ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStep1() {
    final booking = widget.booking;
    final patientName = booking['patient_name'] ?? booking['patientName'] ?? booking['patient']?['name'] ?? 'Patient';
    final testName = booking['test_type'] ?? booking['testName'] ?? 'Lab Test';
    final collectionType = (booking['collectionType'] ?? booking['collection_type'] ?? 'In-Lab').toString();
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Booking Verification', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const Divider(height: 20),
              _infoRow(Icons.person_rounded, 'Patient', patientName),
              _infoRow(Icons.biotech_rounded, 'Test', testName),
              _infoRow(Icons.location_on_rounded, 'Collection', collectionType),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sample Receipt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              TextFormField(
                controller: _specimenIdController,
                decoration: InputDecoration(
                  labelText: 'Specimen ID / Barcode',
                  hintText: 'Scan or type specimen ID',
                  prefixIcon: const Icon(Icons.qr_code_rounded, color: primaryColor, size: 20),
                  filled: true, fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor, width: 2)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF86EFAC))),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Confirm sample is received and ready for testing', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)))),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(children: [
          const Text('Test Parameters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const Spacer(),
          TextButton.icon(
            onPressed: _addParameter,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('Add Row'),
            style: TextButton.styleFrom(foregroundColor: primaryColor),
          ),
        ]),
        const SizedBox(height: 8),
        ..._parameters.asMap().entries.map((entry) => _buildParameterRow(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      key: const ValueKey('step3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('Approved by Doctor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8ECF5))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDoctor,
              hint: const Text('Select verifying doctor', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down_rounded, color: primaryColor),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              items: _doctors.map((doctor) => DropdownMenuItem<String>(
                value: doctor['name'],
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(doctor['name']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Text('${doctor['qualification']} - ${doctor['designation']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ]),
              )).toList(),
              onChanged: (value) => setState(() => _selectedDoctor = value),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Notes (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8ECF5))),
          child: TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Any additional observations or notes...',
              hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(14),
            ),
          ),
        ),
        if (_selectedDoctor != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.verified_rounded, color: primaryColor, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Electronic Verification', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text(
                  'Report verified by ${_doctors.firstWhere((d) => d['name'] == _selectedDoctor)['name']}, ${_doctors.firstWhere((d) => d['name'] == _selectedDoctor)['qualification']}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                ),
              ])),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitManualEntry,
            icon: _isSubmitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, color: Colors.white),
            label: Text(_isSubmitting ? 'Submitting...' : 'Submit Results & Notify Patient',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _buildStepNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep--),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: primaryColor),
                foregroundColor: primaryColor,
              ),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        if (_currentStep < 2)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _currentStep++),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
              label: Text(_currentStep == 0 ? 'Proceed to Entry' : 'Review & Submit',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildParameterRow(int index, Map<String, TextEditingController> p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Parameter ${index + 1}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primaryColor)),
              const Spacer(),
              if (_parameters.length > 1)
                GestureDetector(
                  onTap: () => _removeParameter(index),
                  child: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFEF4444), size: 20),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(flex: 3, child: _buildMiniField(p['parameter']!, 'Test Parameter', 'e.g., Hemoglobin')),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _buildMiniField(p['value']!, 'Value', 'e.g., 13.5')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(flex: 2, child: _buildMiniField(p['unit']!, 'Unit', 'e.g., g/dL')),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: _buildMiniField(p['range']!, 'Normal Range', 'e.g., 12–16')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniField(TextEditingController controller, String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8ECF5))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8ECF5))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryColor, width: 2)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upload Report File', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          const Text('Upload a scanned or digital PDF/image report', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: _selectedFile != null ? primaryColor.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedFile != null ? primaryColor : const Color(0xFFCBD5E1),
                  width: _selectedFile != null ? 2 : 1.5,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_rounded,
                    size: 48,
                    color: _selectedFile != null ? primaryColor : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFile != null ? _selectedFile!.name : 'Tap to select a file',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _selectedFile != null ? primaryColor : const Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_selectedFile == null) ...[
                    const SizedBox(height: 4),
                    const Text('PDF, JPG, PNG supported', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ],
                ],
              ),
            ),
          ),
          if (_selectedFile != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() => _selectedFile = null),
              icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFEF4444)),
              label: const Text('Remove file', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
            ),
          ],
          const SizedBox(height: 20),
          const Text('Approved by Doctor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8ECF5)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDoctor,
                hint: const Text('Select verifying doctor', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down_rounded, color: primaryColor),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                items: _doctors.map((doctor) {
                  return DropdownMenuItem<String>(
                    value: doctor['name'],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(doctor['name']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        Text('${doctor['qualification']} - ${doctor['designation']}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedDoctor = value);
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Notes (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8ECF5)),
            ),
            child: TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Any additional observations or notes...',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
          if (_selectedDoctor != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_rounded, color: primaryColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Electronic Report Verification',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'This is an electronically generated report verified by ${_doctors.firstWhere((d) => d['name'] == _selectedDoctor)['name']}, ${_doctors.firstWhere((d) => d['name'] == _selectedDoctor)['qualification']}, ${_doctors.firstWhere((d) => d['name'] == _selectedDoctor)['designation']}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitFileUpload,
              icon: _isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.upload_rounded, color: Colors.white),
              label: Text(_isSubmitting ? 'Uploading...' : 'Upload & Notify Patient',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
