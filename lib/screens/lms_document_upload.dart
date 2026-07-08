import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:icare/screens/lms_limited_dashboard.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

/// Document Upload Screen for LMS Verification
/// Students upload ID/certificates for admin verification
/// After upload, they get limited access (only purchased course)
/// Full access granted after admin approval
class LmsDocumentUpload extends StatefulWidget {
  final String courseId;

  const LmsDocumentUpload({super.key, required this.courseId});

  @override
  State<LmsDocumentUpload> createState() => _LmsDocumentUploadState();
}

class _LmsDocumentUploadState extends State<LmsDocumentUpload> {
  final ApiService _api = ApiService();

  final List<Map<String, dynamic>> _documents = [];
  bool _isUploading = false;
  final bool _canSkip = true; // Allow skip for now, can be made mandatory later

  final List<String> _documentTypes = [
    'ID Card',
    'Student ID',
    'Professional License',
    'Certificate',
    'Other',
  ];

  Future<void> _pickDocument(String type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty || result.files.first.bytes == null) {
        return;
      }

      final file = result.files.first;
      setState(() {
        _documents.add({
          'type': type,
          'bytes': file.bytes!,
          'name': file.name,
          'uploaded': false,
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick document: $e')),
        );
      }
    }
  }

  Future<void> _uploadDocuments() async {
    if (_documents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one document')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final types = _documents.map((d) => d['type'] as String).toList();
      final formData = FormData.fromMap({
        'documentTypes': jsonEncode(types),
        'documents': _documents.map((doc) {
          return MultipartFile.fromBytes(
            doc['bytes'] as List<int>,
            filename: doc['name'] as String,
          );
        }).toList(),
      });

      final response = await _api.postMultipart('/verification/upload', formData);
      final body = response.data is String ? jsonDecode(response.data) : response.data;

      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Upload failed');
      }

      setState(() {
        for (var doc in _documents) {
          doc['uploaded'] = true;
        }
      });

      if (mounted) {
        _navigateToLimitedDashboard();
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToLimitedDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LmsLimitedDashboard(courseId: widget.courseId),
      ),
      (route) => false,
    );
  }

  void _removeDocument(int index) {
    setState(() {
      _documents.removeAt(index);
    });
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
          'Verify Your Identity',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            _buildInfoCard(),
            const SizedBox(height: 24),
            
            // Document Type Selection
            const Text(
              'Upload Documents',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            _buildDocumentTypeButtons(),
            const SizedBox(height: 24),
            
            // Uploaded Documents List
            if (_documents.isNotEmpty) ...[
              const Text(
                'Selected Documents',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              _buildDocumentsList(),
              const SizedBox(height: 24),
            ],
            
            // Upload Button
            _buildUploadButton(),
            const SizedBox(height: 16),
            
            // Skip Button (if allowed)
            if (_canSkip) _buildSkipButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1).withValues(alpha: 0.1),
            const Color(0xFF8B5CF6).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.verified_user,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Why do we need this?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'To ensure the quality and security of our learning community, we verify all students. Upload any government-issued ID or relevant certificate.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Course access unlocks once an admin reviews and approves your documents',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFB45309),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTypeButtons() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _documentTypes.map((type) {
        return ElevatedButton.icon(
          onPressed: () => _pickDocument(type),
          icon: const Icon(Icons.upload_file, size: 18),
          label: Text(type),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF6366F1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFF6366F1)),
            ),
            elevation: 0,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDocumentsList() {
    return Column(
      children: _documents.asMap().entries.map((entry) {
        final index = entry.key;
        final doc = entry.value;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              // Document Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description,
                  color: Color(0xFF6366F1),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // Document Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc['type'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doc['name'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Remove Button
              IconButton(
                onPressed: () => _removeDocument(index),
                icon: const Icon(Icons.close, color: Colors.red),
                iconSize: 20,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUploadButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isUploading ? null : _uploadDocuments,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isUploading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Upload & Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: _navigateToLimitedDashboard,
        child: const Text(
          'Skip for now (verify later)',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
