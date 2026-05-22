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

  // Manual entry
  final List<Map<String, TextEditingController>> _parameters = [];

  // File upload
  PlatformFile? _selectedFile;
  final TextEditingController _notesController = TextEditingController();

  // Doctor approval
  String? _selectedDoctor;
  final List<Map<String, String>> _doctors = [
    {'name': 'Dr. Ahmed Khan', 'qualification': 'MBBS, FCPS', 'designation': 'Pathologist'},
    {'name': 'Dr. Sarah Ali', 'qualification': 'MBBS, MPhil', 'designation': 'Clinical Pathologist'},
    {'name': 'Dr. Usman Malik', 'qualification': 'MBBS, FCPS', 'designation': 'Consultant Pathologist'},
  ];

  static const Color primaryColor = Color(0xFF0B2D6E);
  static const Color secondaryColor = Color(0xFF1565C0);
  static const Color backgroundColor = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _addParameter(); // Start with one row
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Test Parameters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              const Spacer(),
              TextButton.icon(
                onPressed: _addParameter,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('Add Row'),
                style: TextButton.styleFrom(foregroundColor: primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._parameters.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            return _buildParameterRow(i, p);
          }),
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
          const SizedBox(height: 80),
        ],
      ),
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
