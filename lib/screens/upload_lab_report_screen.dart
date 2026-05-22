import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/laboratory_service.dart';
import '../widgets/back_button.dart';
import 'package:dotted_border/dotted_border.dart';
import 'dart:io';

class UploadLabReportScreen extends StatefulWidget {
  final Map<String, dynamic> booking;

  const UploadLabReportScreen({super.key, required this.booking});

  @override
  State<UploadLabReportScreen> createState() => _UploadLabReportScreenState();
}

class _UploadLabReportScreenState extends State<UploadLabReportScreen> {
  final LaboratoryService _labService = LaboratoryService();
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  final TextEditingController _notesController = TextEditingController();

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick file')),
      );
    }
  }

  Future<void> _uploadReport() async {
    if (_selectedFile == null) return;

    setState(() => _isUploading = true);

    try {
      // 1. Upload the file
      final bytes = await File(_selectedFile!.path!).readAsBytes();
      await _labService.uploadReport(
        widget.booking['_id'],
        bytes,
        _selectedFile!.name,
      );

      // 2. Update status and add notes if provided
      await _labService.updateBooking(widget.booking['_id'], {
        'status': 'completed',
        'reportNotes': _notesController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report uploaded and sent to doctor/patient'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Unable to load data. Please try again.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: const Text(
          'Upload Test Report',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBookingSummary(),
            const SizedBox(height: 32),
            const Text(
              'Select Report File',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            _buildFilePicker(),
            const SizedBox(height: 32),
            const Text(
              'Result Summary / Notes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Add summary of results or any notes for the doctor/patient...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_selectedFile == null || _isUploading) ? null : _uploadReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B2D6E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Upload & Complete Request',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingSummary() {
    final patient = widget.booking['patient'];
    final testName = widget.booking['testName'] ?? 'General Test';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B2D6E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: Color(0xFF0B2D6E),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      testName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'For: ${patient?['name'] ?? 'Unknown Patient'}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilePicker() {
    return GestureDetector(
      onTap: _pickFile,
      child: DottedBorder(
        options: RoundedRectDottedBorderOptions(
          radius: const Radius.circular(16),
          color: const Color(0xFF0B2D6E).withValues(alpha: 0.3),
          strokeWidth: 2,
          dashPattern: const [8, 4],
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          decoration: BoxDecoration(
            color: _selectedFile != null
                ? const Color(0xFF0B2D6E).withValues(alpha: 0.02)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              if (_selectedFile == null) ...[
                const Icon(
                  Icons.cloud_upload_outlined,
                  size: 48,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tap to select report file',
                  style: TextStyle(
                    color: Color(0xFF0B2D6E),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'PDF, PNG, JPG (Max 5MB)',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ] else ...[
                const Icon(
                  Icons.insert_drive_file_rounded,
                  size: 48,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedFile!.name,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _pickFile,
                  child: const Text('Change File'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
