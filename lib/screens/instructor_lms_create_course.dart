import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';

// Helper: get signed Cloudinary upload params from backend then upload directly
Future<String?> _signedCloudinaryUpload({
  required Uint8List bytes,
  required String filename,
  required String folder,
  String resourceType = 'auto',
}) async {
  final signRes = await ApiService().get('/upload/sign?folder=$folder&resource_type=$resourceType');
  if (signRes.data['success'] != true) throw Exception('Could not get upload signature');
  final cloudName = signRes.data['cloud_name']?.toString() ?? 'dzlcnyxgb';
  final formData = FormData.fromMap({
    'file': MultipartFile.fromBytes(bytes, filename: filename),
    'signature': signRes.data['signature'],
    'timestamp': signRes.data['timestamp'].toString(),
    'api_key': signRes.data['api_key'],
    'folder': folder,
  });
  final res = await Dio().post(
    'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload',
    data: formData,
    options: Options(validateStatus: (s) => s != null && s < 600),
  );
  if (res.statusCode == 200 && res.data['secure_url'] != null) {
    return res.data['secure_url'] as String;
  }
  throw Exception('Upload failed: ${res.data}');
}

/// Course Creation Wizard - Google Classroom/Moodle style
class InstructorLmsCreateCourseScreen extends StatefulWidget {
  const InstructorLmsCreateCourseScreen({super.key});

  @override
  State<InstructorLmsCreateCourseScreen> createState() => _InstructorLmsCreateCourseScreenState();
}

class _InstructorLmsCreateCourseScreenState extends State<InstructorLmsCreateCourseScreen> {
  final LmsService _lmsService = LmsService();
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  
  int _currentStep = 0;
  bool _isSubmitting = false;
  
  // Course data
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _thumbnailController = TextEditingController();
  String _category = 'HealthProgram';
  String _targetAudience = 'Patient';
  String _difficulty = 'Beginner';
  final _durationDaysController = TextEditingController();
  final _durationWeeksController = TextEditingController();
  final _durationMonthsController = TextEditingController();
  DateTime? _startDate;
  String _courseType = 'self-paced'; // 'self-paced' or 'pragmatic'
  bool _isPublished = false;
  bool _uploadingThumbnail = false;
  String? _thumbnailUrl;

  // Pricing
  bool _isFree = true;
  final _priceController = TextEditingController();
  int _discountPercent = 0;
  final _voucherController = TextEditingController();

  // Modules
  final List<Map<String, dynamic>> _modules = [];

  Future<void> _pickAndUploadThumbnail() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _uploadingThumbnail = true);
      // Get signed upload params from backend then upload directly to Cloudinary
      final signRes = await ApiService().get('/upload/sign?folder=icare/thumbnails');
      final signature = signRes.data['signature']?.toString() ?? '';
      final timestamp = signRes.data['timestamp']?.toString() ?? '';
      final apiKey = signRes.data['api_key']?.toString() ?? '';
      final cloudName = signRes.data['cloud_name']?.toString() ?? 'dzlcnyxgb';
      final folder = signRes.data['folder']?.toString() ?? 'icare/thumbnails';
      if (signature.isEmpty) throw Exception('Could not get upload signature');

      final dio = Dio();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
        'signature': signature,
        'timestamp': timestamp,
        'api_key': apiKey,
        'folder': folder,
      });
      final response = await dio.post(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
        data: formData,
        options: Options(validateStatus: (s) => s != null && s < 600),
      );
      if (response.statusCode == 200 && response.data['secure_url'] != null) {
        final url = response.data['secure_url'] as String;
        setState(() {
          _thumbnailUrl = url;
          _thumbnailController.text = url;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thumbnail uploaded successfully'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception(response.data['message'] ?? 'Upload failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingThumbnail = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _thumbnailController.dispose();
    _pageController.dispose();
    _priceController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _submitCourse() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmitting = true);
    
    try {
      final courseData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'thumbnail': _thumbnailController.text.isNotEmpty ? _thumbnailController.text : null,
        'category': _category,
        'targetAudience': _targetAudience,
        'difficulty': _difficulty,
        'duration': (int.tryParse(_durationDaysController.text) ?? 0) +
            (int.tryParse(_durationWeeksController.text) ?? 0) * 7 +
            (int.tryParse(_durationMonthsController.text) ?? 0) * 30,
        if (_startDate != null) 'startDate': _startDate!.toIso8601String(),
        'courseType': _courseType,
        'isPublished': _isPublished,
        'modules': _modules,
        // Pricing
        'isFree': _isFree,
        if (!_isFree) 'price': double.tryParse(_priceController.text) ?? 0,
        if (!_isFree && _discountPercent > 0) 'discountPercent': _discountPercent,
        if (!_isFree && _discountPercent > 0) 'discountedPrice': _discountedPrice,
      };
      
      await _lmsService.createCourse(courseData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course created successfully!')),
        );
        Navigator.pop(context); // Return to LMS dashboard
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _submitCourse();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Create New Course',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),
          
          // Form content
          Expanded(
            child: Form(
              key: _formKey,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildBasicInfoStep(isDesktop),
                  _buildDetailsStep(isDesktop),
                  _buildModulesStep(isDesktop),
                ],
              ),
            ),
          ),
          
          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          _buildStepIndicator(0, 'Basic Info'),
          Expanded(child: _buildStepLine(0)),
          _buildStepIndicator(1, 'Details'),
          Expanded(child: _buildStepLine(1)),
          _buildStepIndicator(2, 'Modules'),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryColor : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? AppColors.primaryColor : Colors.grey[600],
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    final isActive = _currentStep > step;
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 30),
      color: isActive ? AppColors.primaryColor : Colors.grey[300],
    );
  }

  Widget _buildBasicInfoStep(bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Basic Information',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Let\'s start with the basics of your course',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 32),
              
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Course Title *',
                  hintText: 'e.g., Introduction to Diabetes Management',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a course title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Course Description *',
                  hintText: 'Describe what students will learn...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // ── Thumbnail Upload ──────────────────────────────
              const Text('Course Thumbnail (optional)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              const SizedBox(height: 8),
              // Preview
              if (_thumbnailUrl != null && _thumbnailUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _thumbnailUrl!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 120,
                      color: const Color(0xFFF1F5F9),
                      child: const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _thumbnailController,
                      onChanged: (v) => setState(() => _thumbnailUrl = v.trim().isEmpty ? null : v.trim()),
                      decoration: const InputDecoration(
                        labelText: 'Paste image URL',
                        hintText: 'https://example.com/image.jpg',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link_rounded),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _uploadingThumbnail
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : ElevatedButton.icon(
                          onPressed: _pickAndUploadThumbnail,
                          icon: const Icon(Icons.upload_rounded, size: 16),
                          label: const Text('Upload'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsStep(bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Course Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Configure course settings and audience',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 32),
              
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'HealthProgram', child: Text('Health Program')),
                  DropdownMenuItem(value: 'FCPSPart1', child: Text('FCPS Part 1')),
                  DropdownMenuItem(value: 'Medical Training', child: Text('Medical Training (For health care professionals only)')),
                  DropdownMenuItem(value: 'Wellness', child: Text('Wellness')),
                  DropdownMenuItem(value: 'Nutrition', child: Text('Nutrition')),
                  DropdownMenuItem(value: 'Mental Health', child: Text('Mental Health')),
                ],
                onChanged: (value) => setState(() => _category = value!),
              ),
              const SizedBox(height: 20),
              
              DropdownButtonFormField<String>(
                initialValue: _targetAudience,
                decoration: const InputDecoration(
                  labelText: 'Target Audience',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Patient', child: Text('Patients')),
                  DropdownMenuItem(value: 'Doctor', child: Text('Healthcare Professionals')),
                  DropdownMenuItem(value: 'All', child: Text('Everyone')),
                ],
                onChanged: (value) => setState(() => _targetAudience = value!),
              ),
              const SizedBox(height: 20),
              
              DropdownButtonFormField<String>(
                initialValue: _difficulty,
                decoration: const InputDecoration(
                  labelText: 'Difficulty Level',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Beginner', child: Text('Beginner')),
                  DropdownMenuItem(value: 'Intermediate', child: Text('Intermediate')),
                  DropdownMenuItem(value: 'Advanced', child: Text('Advanced')),
                ],
                onChanged: (value) => setState(() => _difficulty = value!),
              ),
              const SizedBox(height: 20),
              
              const Text(
                'Course Duration',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _durationDaysController,
                      decoration: const InputDecoration(labelText: 'Days', border: OutlineInputBorder(), suffixText: 'd'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _durationWeeksController,
                      decoration: const InputDecoration(labelText: 'Weeks', border: OutlineInputBorder(), suffixText: 'w'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _durationMonthsController,
                      decoration: const InputDecoration(labelText: 'Months', border: OutlineInputBorder(), suffixText: 'm'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Course Start Date
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _startDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: _startDate != null ? AppColors.primaryColor : const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(4),
                    color: _startDate != null ? AppColors.primaryColor.withValues(alpha: 0.04) : Colors.white,
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_outlined, size: 18, color: _startDate != null ? AppColors.primaryColor : const Color(0xFF94A3B8)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      _startDate != null
                          ? 'Start Date: ${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                          : 'Course Start Date (optional)',
                      style: TextStyle(fontSize: 14, color: _startDate != null ? AppColors.primaryColor : const Color(0xFF94A3B8)),
                    )),
                    if (_startDate != null) GestureDetector(
                      onTap: () => setState(() => _startDate = null),
                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                    ),
                  ]),
                ),
              ),
              // Auto-calculated end date preview
              if (_startDate != null) ...[
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final totalDays = (int.tryParse(_durationDaysController.text) ?? 0) +
                      (int.tryParse(_durationWeeksController.text) ?? 0) * 7 +
                      (int.tryParse(_durationMonthsController.text) ?? 0) * 30;
                  if (totalDays == 0) return const SizedBox.shrink();
                  final endDate = _startDate!.add(Duration(days: totalDays));
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.timeline_rounded, size: 16, color: AppColors.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Timeline: ${_startDate!.day}/${_startDate!.month}/${_startDate!.year} → ${endDate.day}/${endDate.month}/${endDate.year} ($totalDays days)',
                        style: const TextStyle(fontSize: 12, color: AppColors.primaryColor, fontWeight: FontWeight.w500),
                      ),
                    ]),
                  );
                }),
              ],
              const SizedBox(height: 20),
              
              // Course type
              const Text('Course Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _courseType = 'self-paced'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: _courseType == 'self-paced' ? const Color(0xFF10B981).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                      border: Border.all(color: _courseType == 'self-paced' ? const Color(0xFF10B981) : const Color(0xFFE2E8F0), width: _courseType == 'self-paced' ? 2 : 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(children: [
                      Icon(Icons.self_improvement_rounded, color: _courseType == 'self-paced' ? const Color(0xFF10B981) : const Color(0xFF94A3B8), size: 24),
                      const SizedBox(height: 6),
                      Text('Self-paced', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _courseType == 'self-paced' ? const Color(0xFF10B981) : const Color(0xFF64748B))),
                      const SizedBox(height: 3),
                      const Text('Student unlocks next module on completion', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)), textAlign: TextAlign.center),
                    ]),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _courseType = 'pragmatic'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: _courseType == 'pragmatic' ? const Color(0xFF6366F1).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                      border: Border.all(color: _courseType == 'pragmatic' ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0), width: _courseType == 'pragmatic' ? 2 : 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(children: [
                      Icon(Icons.timeline_rounded, color: _courseType == 'pragmatic' ? const Color(0xFF6366F1) : const Color(0xFF94A3B8), size: 24),
                      const SizedBox(height: 6),
                      Text('Pragmatic', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _courseType == 'pragmatic' ? const Color(0xFF6366F1) : const Color(0xFF64748B))),
                      const SizedBox(height: 3),
                      const Text('Next module unlocks only on scheduled date', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)), textAlign: TextAlign.center),
                    ]),
                  ),
                )),
              ]),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Publish immediately'),
                subtitle: const Text('Make this course visible to students'),
                value: _isPublished,
                onChanged: (value) => setState(() => _isPublished = value),
                activeThumbColor: AppColors.primaryColor,
              ),

              const SizedBox(height: 24),
              // ── PRICING SECTION ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.payments_rounded, color: AppColors.primaryColor, size: 20),
                      SizedBox(width: 8),
                      Text('Course Pricing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    ]),
                    const SizedBox(height: 16),

                    // Mark as Free checkbox
                    CheckboxListTile(
                      value: _isFree,
                      onChanged: (v) => setState(() { _isFree = v!; }),
                      title: const Text('Mark as Free', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Students can enroll at no cost'),
                      activeColor: AppColors.primaryColor,
                      contentPadding: EdgeInsets.zero,
                    ),

                    if (!_isFree) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Course Price (PKR)',
                              hintText: 'e.g. 10000',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.currency_exchange_rounded),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _discountPercent,
                            decoration: const InputDecoration(
                              labelText: 'Discount',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.discount_rounded),
                            ),
                            items: [
                              const DropdownMenuItem(value: 0, child: Text('No discount')),
                              ...([10,20,30,40,50,60,70,80,90,100].map((p) =>
                                DropdownMenuItem(value: p, child: Text('$p% off')))),
                            ],
                            onChanged: (v) => setState(() => _discountPercent = v!),
                          ),
                        ),
                      ]),
                      if (_discountPercent > 0 && _priceController.text.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(children: [
                            const Icon(Icons.local_offer_rounded, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Original: PKR ${_priceController.text}',
                                  style: const TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough, color: Color(0xFF64748B))),
                              Text('After discount: PKR ${_discountedPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.green)),
                            ]),
                          ]),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get _discountedPrice {
    final price = double.tryParse(_priceController.text) ?? 0;
    return price - (price * _discountPercent / 100);
  }

  Widget _buildModulesStep(bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Course Modules',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add modules and lessons (you can add more later)',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _addModule,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add Module'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              if (_modules.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No modules yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add your first module to organize course content',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _modules.length,
                  itemBuilder: (context, index) {
                    return _buildModuleCard(index);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Calculate timeline start for a module based on its index and previous module durations
  DateTime? _moduleStartDate(int index) {
    if (_startDate == null) return null;
    int offset = 0;
    for (int i = 0; i < index; i++) {
      offset += (_modules[i]['durationDays'] as int? ?? 0);
    }
    return _startDate!.add(Duration(days: offset));
  }

  Widget _buildModuleCard(int index) {
    final module = _modules[index];
    final lessons = module['lessons'] as List;
    final moduleStart = _moduleStartDate(index);
    final durationDays = module['durationDays'] as int? ?? 0;
    final moduleEnd = moduleStart != null && durationDays > 0 ? moduleStart.add(Duration(days: durationDays)) : null;
    final timelineText = moduleStart != null && moduleEnd != null
        ? '${moduleStart.day}/${moduleStart.month}/${moduleStart.year} → ${moduleEnd.day}/${moduleEnd.month}/${moduleEnd.year}'
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryColor,
          child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
        ),
        title: Text(module['title'] ?? 'Module ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${lessons.length} lesson${lessons.length == 1 ? '' : 's'}${durationDays > 0 ? ' · $durationDays days' : ''}'),
            if (timelineText != null)
              Text(timelineText, style: const TextStyle(fontSize: 11, color: AppColors.primaryColor)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primaryColor, size: 20),
              tooltip: 'Edit Module',
              onPressed: () => _editModule(index),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              tooltip: 'Delete Module',
              onPressed: () => setState(() => _modules.removeAt(index)),
            ),
          ],
        ),
        children: [
          if (lessons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((module['description'] ?? '').toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(module['description'], style: const TextStyle(color: Color(0xFF64748B))),
                    ),
                  ...lessons.asMap().entries.map((e) {
                    final lesson = e.value as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(radius: 12, backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1), child: Text('${e.key + 1}', style: const TextStyle(fontSize: 10, color: AppColors.primaryColor))),
                      title: Text(lesson['title'] ?? '', style: const TextStyle(fontSize: 13)),
                      subtitle: Row(children: [
                        if ((lesson['duration'] ?? 0) > 0) Text('${lesson['duration']} min', style: const TextStyle(fontSize: 11)),
                        if (lesson['videoUrl'] != null && (lesson['videoUrl'] as String).isNotEmpty) ...[const SizedBox(width: 8), const Icon(Icons.videocam_rounded, size: 14, color: Color(0xFF3B82F6))],
                        if (lesson['documentUrl'] != null && (lesson['documentUrl'] as String).isNotEmpty) ...[const SizedBox(width: 6), const Icon(Icons.description_outlined, size: 14, color: Color(0xFF10B981))],
                      ]),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addModule() async {
    final module = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const _ModuleEditorPage()),
    );
    if (module != null) setState(() => _modules.add(module));
  }

  Future<void> _editModule(int index) async {
    final module = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => _ModuleEditorPage(existingModule: _modules[index])),
    );
    if (module != null) setState(() => _modules[index] = module);
  }

  Widget _buildNavigationButtons() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _previousStep,
              child: const Text('Back'),
            )
          else
            const SizedBox(),
          
          ElevatedButton(
            onPressed: _isSubmitting ? null : _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(_currentStep < 2 ? 'Next' : 'Create Course'),
          ),
        ],
      ),
    );
  }
}

// ─── Full-page Module Editor with inline lesson forms ────────────────────────

class _LmsLessonForm {
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController contentCtrl = TextEditingController();
  final TextEditingController durationCtrl = TextEditingController();
  String? videoUrl;
  String? documentUrl;
  String? documentName;

  _LmsLessonForm({Map<String, dynamic>? existing}) {
    if (existing != null) {
      titleCtrl.text = existing['title']?.toString() ?? '';
      contentCtrl.text = existing['content']?.toString() ?? '';
      durationCtrl.text = existing['duration']?.toString() ?? '';
      videoUrl = existing['videoUrl']?.toString();
      documentUrl = existing['documentUrl']?.toString();
      documentName = existing['documentName']?.toString();
    }
  }

  Map<String, dynamic> toMap(int order) => {
        'title': titleCtrl.text.trim(),
        'content': contentCtrl.text.trim(),
        'duration': int.tryParse(durationCtrl.text.trim()) ?? 0,
        'order': order,
        if (videoUrl != null && videoUrl!.isNotEmpty) 'videoUrl': videoUrl,
        if (documentUrl != null && documentUrl!.isNotEmpty) 'documentUrl': documentUrl,
        if (documentName != null) 'documentName': documentName,
      };

  void dispose() {
    titleCtrl.dispose();
    contentCtrl.dispose();
    durationCtrl.dispose();
  }
}

class _ModuleEditorPage extends StatefulWidget {
  final Map<String, dynamic>? existingModule;
  const _ModuleEditorPage({this.existingModule});

  @override
  State<_ModuleEditorPage> createState() => _ModuleEditorPageState();
}

class _ModuleEditorPageState extends State<_ModuleEditorPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durationDaysCtrl = TextEditingController();
  final List<_LmsLessonForm> _lessonForms = [];

  @override
  void initState() {
    super.initState();
    final m = widget.existingModule;
    if (m != null) {
      _titleCtrl.text = m['title']?.toString() ?? '';
      _descCtrl.text = m['description']?.toString() ?? '';
      _durationDaysCtrl.text = m['durationDays']?.toString() ?? '';
      final existing = (m['lessons'] as List?) ?? [];
      for (final l in existing) {
        _lessonForms.add(_LmsLessonForm(existing: l as Map<String, dynamic>));
      }
    }
    if (_lessonForms.isEmpty) _lessonForms.add(_LmsLessonForm());
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter module title')));
      return;
    }
    final lessons = <Map<String, dynamic>>[];
    for (int i = 0; i < _lessonForms.length; i++) {
      if (_lessonForms[i].titleCtrl.text.trim().isNotEmpty) {
        lessons.add(_lessonForms[i].toMap(i + 1));
      }
    }
    Navigator.of(context).pop({
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'durationDays': int.tryParse(_durationDaysCtrl.text.trim()) ?? 0,
      'lessons': lessons,
      'order': 0,
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _durationDaysCtrl.dispose();
    for (final f in _lessonForms) { f.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
        title: Text(widget.existingModule == null ? 'Add Module' : 'Edit Module',
            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save Module', style: TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Module Title *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Module Description (optional)', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _durationDaysCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Module Duration (days) — for timeline',
                    border: OutlineInputBorder(),
                    suffixText: 'days',
                    hintText: 'e.g. 7',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 28),
                Row(children: [
                  const Icon(Icons.play_lesson_rounded, color: AppColors.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  const Text('Lessons', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('${_lessonForms.length} added', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ]),
                const SizedBox(height: 12),
                ..._lessonForms.asMap().entries.map((entry) {
                  final i = entry.key;
                  final form = entry.value;
                  return _LmsInlineLessonWidget(
                    key: ObjectKey(form),
                    form: form,
                    number: i + 1,
                    onRemove: _lessonForms.length > 1 ? () => setState(() { form.dispose(); _lessonForms.removeAt(i); }) : null,
                    onChanged: () => setState(() {}),
                  );
                }),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _lessonForms.add(_LmsLessonForm())),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Another Lesson'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryColor,
                      side: const BorderSide(color: AppColors.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Module', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Inline lesson widget for LMS wizard ─────────────────────────────────────

class _LmsInlineLessonWidget extends StatefulWidget {
  final _LmsLessonForm form;
  final int number;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _LmsInlineLessonWidget({
    super.key,
    required this.form,
    required this.number,
    this.onRemove,
    required this.onChanged,
  });

  @override
  State<_LmsInlineLessonWidget> createState() => _LmsInlineLessonWidgetState();
}

class _LmsInlineLessonWidgetState extends State<_LmsInlineLessonWidget> {
  bool _uploadingVideo = false;
  bool _uploadingDoc = false;

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false, withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      if (file.size > 100 * 1024 * 1024) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max 100MB for videos'), backgroundColor: Colors.red));
        return;
      }
      setState(() => _uploadingVideo = true);
      final url = await _signedCloudinaryUpload(bytes: file.bytes!, filename: file.name, folder: 'icare/lessons/videos');
      if (url != null) {
        setState(() { widget.form.videoUrl = url; _uploadingVideo = false; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Video uploaded!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _uploadingVideo = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red));
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      if (file.size > 50 * 1024 * 1024) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max 50MB for documents'), backgroundColor: Colors.red));
        return;
      }
      setState(() => _uploadingDoc = true);
      final url = await _signedCloudinaryUpload(bytes: file.bytes!, filename: file.name, folder: 'icare/lessons/docs', resourceType: 'raw');
      if (url != null) {
        setState(() { widget.form.documentUrl = url; widget.form.documentName = file.name; _uploadingDoc = false; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Document uploaded!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _uploadingDoc = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.form;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(children: [
              CircleAvatar(radius: 13, backgroundColor: AppColors.primaryColor, child: Text('${widget.number}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
              const SizedBox(width: 10),
              const Text('Lesson', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryColor)),
              const Spacer(),
              if (widget.onRemove != null) GestureDetector(onTap: widget.onRemove, child: const Icon(Icons.close_rounded, size: 18, color: Colors.red)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: f.titleCtrl, decoration: const InputDecoration(labelText: 'Lesson Title *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: f.contentCtrl, decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()), maxLines: 3),
              const SizedBox(height: 12),
              TextField(controller: f.durationCtrl, decoration: const InputDecoration(labelText: 'Duration (minutes)', border: OutlineInputBorder(), suffixText: 'min'), keyboardType: TextInputType.number),
              const SizedBox(height: 14),
              _uploadTile(icon: Icons.play_circle_outline_rounded, color: const Color(0xFF3B82F6), title: 'Video', subtitle: f.videoUrl ?? 'YouTube, Vimeo, or upload .mp4', has: f.videoUrl != null, loading: _uploadingVideo, onTap: _pickVideo, onClear: () => setState(() { f.videoUrl = null; })),
              const SizedBox(height: 10),
              _uploadTile(icon: Icons.description_outlined, color: const Color(0xFF10B981), title: 'Document', subtitle: f.documentName ?? (f.documentUrl != null ? 'Attached' : 'PDF, DOC, PPT, XLS (max 50MB)'), has: f.documentUrl != null, loading: _uploadingDoc, onTap: _pickDocument, onClear: () => setState(() { f.documentUrl = null; f.documentName = null; })),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _uploadTile({required IconData icon, required Color color, required String title, required String subtitle, required bool has, required bool loading, required VoidCallback onTap, required VoidCallback onClear}) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: has ? color.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: has ? color.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: has ? color : const Color(0xFF1E293B))),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
          ])),
          if (loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else if (has) GestureDetector(onTap: onClear, child: const Icon(Icons.close_rounded, size: 16, color: Colors.red))
          else Icon(Icons.add_circle_outline_rounded, color: color, size: 18),
        ]),
      ),
    );
  }
}
