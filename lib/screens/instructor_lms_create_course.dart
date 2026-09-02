import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

// Helper: get signed Cloudinary upload params from backend then upload directly
Future<String?> _signedCloudinaryUpload({
  required Uint8List bytes,
  required String filename,
  required String folder,
  String resourceType = 'auto',
}) async {
  // Step 1: get signature from backend
  final signRes = await ApiService().get(
    '/upload/sign?folder=${Uri.encodeQueryComponent(folder)}&resource_type=$resourceType',
  );
  if (signRes.data['success'] != true) {
    throw Exception(
      'Backend sign error: ${signRes.data['message'] ?? signRes.data}',
    );
  }

  final cloudName = signRes.data['cloud_name']?.toString() ?? 'dzlcnyxgb';
  final signature = signRes.data['signature']?.toString() ?? '';
  final timestamp = signRes.data['timestamp']?.toString() ?? '';
  final apiKey = signRes.data['api_key']?.toString() ?? '';
  // Use the folder value that the backend actually signed (may differ from requested)
  final signedFolder = signRes.data['folder']?.toString() ?? folder;

  if (signature.isEmpty || apiKey.isEmpty) {
    throw Exception('Backend returned empty signature or api_key');
  }

  // Step 2: upload directly to Cloudinary — no extra fields beyond what was signed
  final formData = FormData.fromMap({
    'file': MultipartFile.fromBytes(bytes, filename: filename),
    'api_key': apiKey,
    'timestamp': timestamp,
    'signature': signature,
    'folder': signedFolder,
  });

  final res = await Dio().post(
    'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload',
    data: formData,
    options: Options(validateStatus: (s) => s != null && s < 600),
  );

  if (res.statusCode == 200 && res.data['secure_url'] != null) {
    return res.data['secure_url'] as String;
  }

  // Extract Cloudinary error message for clear diagnostics
  final cloudinaryError = res.data is Map
      ? (res.data['error']?['message'] ?? res.data.toString())
      : res.data.toString();
  throw Exception('Cloudinary ${res.statusCode}: $cloudinaryError');
}

/// Course Creation Wizard - Google Classroom/Moodle style
class InstructorLmsCreateCourseScreen extends StatefulWidget {
  const InstructorLmsCreateCourseScreen({super.key});

  @override
  State<InstructorLmsCreateCourseScreen> createState() =>
      _InstructorLmsCreateCourseScreenState();
}

class _InstructorLmsCreateCourseScreenState
    extends State<InstructorLmsCreateCourseScreen> {
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
  List<Map<String, dynamic>> _categories = [];
  final _durationDaysController = TextEditingController();
  final _durationWeeksController = TextEditingController();
  final _durationMonthsController = TextEditingController();
  DateTime? _startDate;
  String _courseType = 'self-paced'; // 'self-paced' or 'pragmatic'
  bool _isPublished = true;
  bool _uploadingThumbnail = false;
  String? _thumbnailUrl;

  // Pricing
  bool _isFree = true;
  final _priceController = TextEditingController();
  int _discountPercent = 0;
  final _voucherController = TextEditingController();

  // Early Bird discount
  bool _earlyBirdEnabled = false;
  final _earlyBirdAmountController = TextEditingController();
  String _earlyBirdMode = 'days'; // 'days' | 'date'
  final _earlyBirdDaysController = TextEditingController();
  DateTime? _earlyBirdDate;

  // Installment plan — instructor adds each installment manually: an amount
  // plus (for installments 2+) how many days after enrollment it's due.
  // Installment 1 is the on-enrollment purchase (days fixed at 0). The amounts
  // must total the effective (after early-bird) course price.
  bool _installmentPlanEnabled = false;
  final List<_InstallmentRow> _installments = [
    _InstallmentRow(), // installment 1 (on enrollment)
    _InstallmentRow(), // installment 2
  ];

  /// Course price after the early-bird flat discount — the installments must
  /// sum to this. Mirrors the server's computeEffectivePrice.
  double get _effectivePrice {
    final price = double.tryParse(_priceController.text) ?? 0;
    final eb = _earlyBirdEnabled
        ? (double.tryParse(_earlyBirdAmountController.text) ?? 0)
        : 0;
    final v = price - eb;
    return v > 0 ? v : 0;
  }

  double get _installmentsTotal {
    double sum = 0;
    for (final r in _installments) {
      sum += double.tryParse(r.amount.text) ?? 0;
    }
    return sum;
  }

  List<Widget> _buildInstallmentRows() {
    return [
      for (int i = 0; i < _installments.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Installment number badge
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF0FF),
                  shape: BoxShape.circle,
                ),
                child: Text('${i + 1}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6366F1))),
              ),
              const SizedBox(width: 10),
              // Amount
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _installments[i].amount,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Amount (PKR)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Days after enrollment — first installment is fixed at 0.
              Expanded(
                flex: 3,
                child: i == 0
                    ? const InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Due',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        child: Text('On enrollment',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF64748B))),
                      )
                    : TextField(
                        controller: _installments[i].days,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Days after enrollment',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
              ),
              // Remove (keep at least 2 installments)
              if (i > 0 && _installments.length > 2)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      color: Color(0xFFEF4444), size: 20),
                  onPressed: () => setState(() {
                    _installments[i].dispose();
                    _installments.removeAt(i);
                  }),
                )
              else
                const SizedBox(width: 40),
            ],
          ),
        ),
    ];
  }

  // Modules
  final List<Map<String, dynamic>> _modules = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await _lmsService.getCourseCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
        // If current _category isn't in fetched list, keep it; else use first
        if (cats.isNotEmpty && !cats.any((c) => c['value'] == _category)) {
          _category = cats.first['value']?.toString() ?? _category;
        }
      });
    }
  }

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
      final signRes = await ApiService().get(
        '/upload/sign?folder=icare/thumbnails',
      );
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
            const SnackBar(
              content: Text('Thumbnail uploaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(response.data['message'] ?? 'Upload failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
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
    _earlyBirdAmountController.dispose();
    _earlyBirdDaysController.dispose();
    for (final r in _installments) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _submitCourse() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isFree && _earlyBirdEnabled) {
      final amt = double.tryParse(_earlyBirdAmountController.text) ?? 0;
      final price = double.tryParse(_priceController.text) ?? 0;
      if (amt <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter an Early Bird discount amount')),
        );
        return;
      }
      if (amt >= price) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Early Bird amount must be less than the course price',
            ),
          ),
        );
        return;
      }
      if (_earlyBirdMode == 'days' &&
          (int.tryParse(_earlyBirdDaysController.text) ?? 0) <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter how many days the Early Bird offer lasts'),
          ),
        );
        return;
      }
      if (_earlyBirdMode == 'date' && _earlyBirdDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick an Early Bird deadline date')),
        );
        return;
      }
    }
    if (!_isFree && _installmentPlanEnabled) {
      String? err;
      if (_installments.length < 2) {
        err = 'Add at least 2 installments';
      } else {
        int prevDays = -1;
        for (int i = 0; i < _installments.length; i++) {
          final amt = double.tryParse(_installments[i].amount.text) ?? 0;
          final days = i == 0 ? 0 : (int.tryParse(_installments[i].days.text) ?? -1);
          if (amt <= 0) { err = 'Installment ${i + 1}: enter an amount'; break; }
          if (i > 0 && days <= prevDays) {
            err = 'Installment ${i + 1}: days must be more than the previous one';
            break;
          }
          prevDays = days;
        }
      }
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final courseData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'thumbnail': _thumbnailController.text.isNotEmpty
            ? _thumbnailController.text
            : null,
        'thumbnail_url': _thumbnailController.text.isNotEmpty
            ? _thumbnailController.text
            : null,
        'category': _category,
        'targetAudience': _targetAudience,
        'difficulty': _difficulty,
        'duration':
            (int.tryParse(_durationDaysController.text) ?? 0) +
            (int.tryParse(_durationWeeksController.text) ?? 0) * 7 +
            (int.tryParse(_durationMonthsController.text) ?? 0) * 30,
        if (_startDate != null) 'startDate': _startDate!.toIso8601String(),
        'courseType': _courseType,
        'isPublished': _isPublished,
        'modules': _modules,
        // Pricing
        'isFree': _isFree,
        if (!_isFree) 'price': double.tryParse(_priceController.text) ?? 0,
        if (!_isFree && _discountPercent > 0)
          'discountPercent': _discountPercent,
        if (!_isFree && _discountPercent > 0)
          'discountedPrice': _discountedPrice,
        if (!_isFree && _earlyBirdEnabled) 'earlyBirdEnabled': true,
        if (!_isFree && _earlyBirdEnabled)
          'earlyBirdAmount':
              double.tryParse(_earlyBirdAmountController.text) ?? 0,
        if (!_isFree && _earlyBirdEnabled)
          'earlyBirdDeadline':
              (_earlyBirdMode == 'days'
                      ? DateTime.now().add(
                          Duration(
                            days:
                                int.tryParse(_earlyBirdDaysController.text) ??
                                0,
                          ),
                        )
                      : (_earlyBirdDate ?? DateTime.now()))
                  .toIso8601String(),
        if (!_isFree && _installmentPlanEnabled) 'installmentPlanEnabled': true,
        if (!_isFree && _installmentPlanEnabled)
          'installmentPlan': [
            for (int i = 0; i < _installments.length; i++)
              {
                'amount': double.tryParse(_installments[i].amount.text) ?? 0,
                'daysAfterEnrollment':
                    i == 0 ? 0 : (int.tryParse(_installments[i].days.text) ?? 0),
              },
          ],
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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

  Widget _categoryLabel(String name) {
    final isMedicalTraining = name.trim().toLowerCase() == 'medical training';
    if (!isMedicalTraining) return Text(name);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '(for healthcare professionals only)',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFEFF4FF),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 16,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page header ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF0F172A),
                    ),
                    onPressed: () => goBackOrHome(context),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New Course',
                        style: TextStyle(
                          fontSize: isDesktop ? 28 : 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Add a new course to your learning platform',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Card containing step indicator + form + nav buttons ──
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildProgressIndicator(),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      _buildNavigationButtons(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Shared left-side illustration panel used by every step, mirroring the
  // step's title + short description in a visual, non-form-field way.
  Widget _stepIllustrationPanel({
    required IconData icon,
    required String title,
    required String description,
    required int step,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: AppColors.primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  width: i == step ? 20 : 8,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == step
                        ? AppColors.primaryColor
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          _buildStepIndicator(0, 'Basic Info', 'Course basics'),
          Expanded(child: _buildStepLine(0)),
          _buildStepIndicator(1, 'Details', 'Course details'),
          Expanded(child: _buildStepLine(1)),
          _buildStepIndicator(2, 'Modules', 'Add modules'),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, String subtitle) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryColor : const Color(0xFFE2E8F0),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isCurrent
                    ? AppColors.primaryColor
                    : (isActive
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF94A3B8)),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    final isActive = _currentStep > step;
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryColor : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildBasicInfoStep(bool isDesktop) {
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isDesktop) ...[
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
        ],

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
        const Text(
          'Course Thumbnail (optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
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
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: Color(0xFF94A3B8),
                  size: 40,
                ),
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
                onChanged: (v) => setState(
                  () => _thumbnailUrl = v.trim().isEmpty ? null : v.trim(),
                ),
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
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _pickAndUploadThumbnail,
                    icon: const Icon(Icons.upload_rounded, size: 16),
                    label: const Text('Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
          ],
        ),
      ],
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 20),
      child: isDesktop
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _stepIllustrationPanel(
                    icon: Icons.school_rounded,
                    title: 'Course Information',
                    description:
                        'Let\'s start with the basic information about your course.',
                    step: 0,
                  ),
                  const SizedBox(width: 32),
                  Expanded(child: form),
                ],
              ),
            )
          : form,
    );
  }

  Widget _buildDetailsStep(bool isDesktop) {
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isDesktop) ...[
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
          const SizedBox(height: 28),
        ],

        // ── CLASSIFICATION SECTION ──
        _sectionCard(
          icon: Icons.category_rounded,
          title: 'Classification',
          children: [
            DropdownButtonFormField<String>(
              value: _categories.any((c) => c['value'] == _category)
                  ? _category
                  : (_categories.isNotEmpty
                        ? _categories.first['value']?.toString()
                        : null),
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categories.isNotEmpty
                  ? _categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['value']?.toString() ?? '',
                            child: _categoryLabel(c['name']?.toString() ?? ''),
                          ),
                        )
                        .toList()
                  : [
                      const DropdownMenuItem(
                        value: 'HealthProgram',
                        child: Text('Health Program'),
                      ),
                      const DropdownMenuItem(
                        value: 'FCPSPart1',
                        child: Text('FCPS Part 1'),
                      ),
                      DropdownMenuItem(
                        value: 'Medical Training',
                        child: _categoryLabel('Medical Training'),
                      ),
                      const DropdownMenuItem(
                        value: 'Wellness',
                        child: Text('Wellness'),
                      ),
                      const DropdownMenuItem(
                        value: 'Nutrition',
                        child: Text('Nutrition'),
                      ),
                      const DropdownMenuItem(
                        value: 'Mental Health',
                        child: Text('Mental Health'),
                      ),
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
                DropdownMenuItem(
                  value: 'Doctor',
                  child: Text('Healthcare Professionals'),
                ),
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
                DropdownMenuItem(
                  value: 'Intermediate',
                  child: Text('Intermediate'),
                ),
                DropdownMenuItem(value: 'Advanced', child: Text('Advanced')),
              ],
              onChanged: (value) => setState(() => _difficulty = value!),
            ),
          ],
        ),

        const SizedBox(height: 20),
        // ── SCHEDULE & FORMAT SECTION ──
        _sectionCard(
          icon: Icons.schedule_rounded,
          title: 'Schedule & Format',
          children: [
            const Text(
              'Course Duration',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _durationDaysController,
                    decoration: const InputDecoration(
                      labelText: 'Days',
                      border: OutlineInputBorder(),
                      suffixText: 'd',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _durationWeeksController,
                    decoration: const InputDecoration(
                      labelText: 'Weeks',
                      border: OutlineInputBorder(),
                      suffixText: 'w',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _durationMonthsController,
                    decoration: const InputDecoration(
                      labelText: 'Months',
                      border: OutlineInputBorder(),
                      suffixText: 'm',
                    ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _startDate != null
                        ? AppColors.primaryColor
                        : const Color(0xFFCBD5E1),
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: _startDate != null
                      ? AppColors.primaryColor.withValues(alpha: 0.04)
                      : const Color(0xFFF8FAFC),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: _startDate != null
                          ? AppColors.primaryColor
                          : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _startDate != null
                            ? 'Start Date: ${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                            : 'Course Start Date (optional)',
                        style: TextStyle(
                          fontSize: 14,
                          color: _startDate != null
                              ? AppColors.primaryColor
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    if (_startDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _startDate = null),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Auto-calculated end date preview
            if (_startDate != null) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final totalDays =
                      (int.tryParse(_durationDaysController.text) ?? 0) +
                      (int.tryParse(_durationWeeksController.text) ?? 0) * 7 +
                      (int.tryParse(_durationMonthsController.text) ?? 0) * 30;
                  if (totalDays == 0) return const SizedBox.shrink();
                  final endDate = _startDate!.add(Duration(days: totalDays));
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timeline_rounded,
                          size: 16,
                          color: AppColors.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Timeline: ${_startDate!.day}/${_startDate!.month}/${_startDate!.year} → ${endDate.day}/${endDate.month}/${endDate.year} ($totalDays days)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 20),

            // Course type
            const Text(
              'Course Type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _courseType = 'self-paced'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _courseType == 'self-paced'
                            ? const Color(0xFF10B981).withValues(alpha: 0.08)
                            : const Color(0xFFF8FAFC),
                        border: Border.all(
                          color: _courseType == 'self-paced'
                              ? const Color(0xFF10B981)
                              : const Color(0xFFE2E8F0),
                          width: _courseType == 'self-paced' ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.self_improvement_rounded,
                            color: _courseType == 'self-paced'
                                ? const Color(0xFF10B981)
                                : const Color(0xFF94A3B8),
                            size: 24,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Self-paced',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _courseType == 'self-paced'
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Student unlocks next module on completion',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _courseType = 'pragmatic'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _courseType == 'pragmatic'
                            ? const Color(0xFF6366F1).withValues(alpha: 0.08)
                            : const Color(0xFFF8FAFC),
                        border: Border.all(
                          color: _courseType == 'pragmatic'
                              ? const Color(0xFF6366F1)
                              : const Color(0xFFE2E8F0),
                          width: _courseType == 'pragmatic' ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.timeline_rounded,
                            color: _courseType == 'pragmatic'
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF94A3B8),
                            size: 24,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pragmatic',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _courseType == 'pragmatic'
                                  ? const Color(0xFF6366F1)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Next module unlocks only on scheduled date',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Publish immediately',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Make this course visible to students',
                  style: TextStyle(fontSize: 12),
                ),
                value: _isPublished,
                onChanged: (value) => setState(() => _isPublished = value),
                activeThumbColor: AppColors.primaryColor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
        // ── PRICING SECTION ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.payments_rounded,
                    color: AppColors.primaryColor,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Course Pricing',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Mark as Free checkbox
              CheckboxListTile(
                value: _isFree,
                onChanged: (v) => setState(() {
                  _isFree = v!;
                }),
                title: const Text(
                  'Mark as Free',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Students can enroll at no cost'),
                activeColor: AppColors.primaryColor,
                contentPadding: EdgeInsets.zero,
              ),

              if (!_isFree) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
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
                          const DropdownMenuItem(
                            value: 0,
                            child: Text('No discount'),
                          ),
                          ...([10, 20, 30, 40, 50, 60, 70, 80, 90, 100].map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text('$p% off'),
                            ),
                          )),
                        ],
                        onChanged: (v) => setState(() => _discountPercent = v!),
                      ),
                    ),
                  ],
                ),
                if (_discountPercent > 0 &&
                    _priceController.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_offer_rounded,
                          color: Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Original: PKR ${_priceController.text}',
                              style: const TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              'After discount: PKR ${_discountedPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Early Bird Discount ──
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 20),
                const Text(
                  'Early Bird Discount (optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'A flat PKR amount off the price, active only until a deadline you pick.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () =>
                      setState(() => _earlyBirdEnabled = !_earlyBirdEnabled),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _earlyBirdEnabled
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                          : const Color(0xFFF8FAFC),
                      border: Border.all(
                        color: _earlyBirdEnabled
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFE2E8F0),
                        width: _earlyBirdEnabled ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          color: _earlyBirdEnabled
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Enable Early Bird discount',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Switch(
                          value: _earlyBirdEnabled,
                          onChanged: (v) =>
                              setState(() => _earlyBirdEnabled = v),
                          activeThumbColor: const Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_earlyBirdEnabled) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _earlyBirdAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Early Bird discount (flat PKR off)',
                      hintText: 'e.g. 2000',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.money_off_rounded),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _earlyBirdMode = 'days'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _earlyBirdMode == 'days'
                                  ? const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.08)
                                  : const Color(0xFFF8FAFC),
                              border: Border.all(
                                color: _earlyBirdMode == 'days'
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFFE2E8F0),
                                width: _earlyBirdMode == 'days' ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Days from creation',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _earlyBirdMode == 'days'
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _earlyBirdMode = 'date'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _earlyBirdMode == 'date'
                                  ? const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.08)
                                  : const Color(0xFFF8FAFC),
                              border: Border.all(
                                color: _earlyBirdMode == 'date'
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFFE2E8F0),
                                width: _earlyBirdMode == 'date' ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Pick a calendar date',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _earlyBirdMode == 'date'
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_earlyBirdMode == 'days')
                    TextFormField(
                      controller: _earlyBirdDaysController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Days from course creation',
                        hintText: 'e.g. 7',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timer_rounded),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              _earlyBirdDate ??
                              DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                        );
                        if (picked != null)
                          setState(() => _earlyBirdDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _earlyBirdDate != null
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFCBD5E1),
                          ),
                          borderRadius: BorderRadius.circular(4),
                          color: _earlyBirdDate != null
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.04)
                              : Colors.white,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 18,
                              color: _earlyBirdDate != null
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _earlyBirdDate != null
                                  ? 'Deadline: ${_earlyBirdDate!.day}/${_earlyBirdDate!.month}/${_earlyBirdDate!.year}'
                                  : 'Pick deadline date',
                              style: TextStyle(
                                fontSize: 14,
                                color: _earlyBirdDate != null
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],

                // ── Installment Plan ──
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 20),
                const Text(
                  'Installment Plan (optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Let students pay over several months instead of one lump sum. Payments are manual — the student pays each installment separately.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => setState(
                    () => _installmentPlanEnabled = !_installmentPlanEnabled,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _installmentPlanEnabled
                          ? const Color(0xFF6366F1).withValues(alpha: 0.08)
                          : const Color(0xFFF8FAFC),
                      border: Border.all(
                        color: _installmentPlanEnabled
                            ? const Color(0xFF6366F1)
                            : const Color(0xFFE2E8F0),
                        width: _installmentPlanEnabled ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_view_month_rounded,
                          color: _installmentPlanEnabled
                              ? const Color(0xFF6366F1)
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Enable installment plan',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Switch(
                          value: _installmentPlanEnabled,
                          onChanged: (v) =>
                              setState(() => _installmentPlanEnabled = v),
                          activeThumbColor: const Color(0xFF6366F1),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_installmentPlanEnabled) ...[
                  const SizedBox(height: 12),
                  ..._buildInstallmentRows(),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(
                          () => _installments.add(_InstallmentRow())),
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          size: 20, color: Color(0xFF6366F1)),
                      label: const Text('Add Installment',
                          style: TextStyle(
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Live total — neutral info only, no restriction.
                  Builder(
                    builder: (_) {
                      final total = _installmentsTotal;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 18, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Text(
                              'Total installments: PKR ${total.round()}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 20),
      child: isDesktop
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _stepIllustrationPanel(
                    icon: Icons.tune_rounded,
                    title: 'Course Details',
                    description:
                        'Configure course settings, audience and pricing.',
                    step: 1,
                  ),
                  const SizedBox(width: 32),
                  Expanded(child: form),
                ],
              ),
            )
          : form,
    );
  }

  double get _discountedPrice {
    final price = double.tryParse(_priceController.text) ?? 0;
    return price - (price * _discountPercent / 100);
  }

  // Shared white-card wrapper for each Details-step section — keeps every
  // group visually consistent (icon + title header, 12px radius, subtle
  // border/shadow) instead of fields floating loosely on the grey scaffold.
  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
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
    final moduleEnd = moduleStart != null && durationDays > 0
        ? moduleStart.add(Duration(days: durationDays))
        : null;
    final timelineText = moduleStart != null && moduleEnd != null
        ? '${moduleStart.day}/${moduleStart.month}/${moduleStart.year} → ${moduleEnd.day}/${moduleEnd.month}/${moduleEnd.year}'
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryColor,
          child: Text(
            '${index + 1}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          module['title'] ?? 'Module ${index + 1}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${lessons.length} lesson${lessons.length == 1 ? '' : 's'}${durationDays > 0 ? ' · $durationDays days' : ''}',
            ),
            if (timelineText != null)
              Text(
                timelineText,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryColor,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.primaryColor,
                size: 20,
              ),
              tooltip: 'Edit Module',
              onPressed: () => _editModule(index),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 20,
              ),
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
                      child: Text(
                        module['description'],
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  ...lessons.asMap().entries.map((e) {
                    final lesson = e.value as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primaryColor.withValues(
                          alpha: 0.1,
                        ),
                        child: Text(
                          '${e.key + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ),
                      title: Text(
                        lesson['title'] ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Row(
                        children: [
                          if ((lesson['duration'] ?? 0) > 0)
                            Text(
                              '${lesson['duration']} min',
                              style: const TextStyle(fontSize: 11),
                            ),
                          if (lesson['videoUrl'] != null &&
                              (lesson['videoUrl'] as String).isNotEmpty) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.videocam_rounded,
                              size: 14,
                              color: Color(0xFF3B82F6),
                            ),
                          ],
                          if (lesson['documentUrl'] != null &&
                              (lesson['documentUrl'] as String).isNotEmpty) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.description_outlined,
                              size: 14,
                              color: Color(0xFF10B981),
                            ),
                          ],
                          if (lesson['liveSessionDateTime'] != null) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.video_call_rounded,
                              size: 14,
                              color: Color(0xFF6366F1),
                            ),
                          ],
                        ],
                      ),
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
      MaterialPageRoute(
        builder: (_) => _ModuleEditorPage(existingModule: _modules[index]),
      ),
    );
    if (module != null) setState(() => _modules[index] = module);
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            onPressed: _isSubmitting
                ? null
                : (_currentStep > 0
                      ? _previousStep
                      : () => Navigator.pop(context)),
            icon: Icon(
              _currentStep > 0 ? Icons.arrow_back_rounded : Icons.close_rounded,
              size: 18,
            ),
            label: Text(_currentStep > 0 ? 'Back' : 'Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _nextStep,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _currentStep < 2
                        ? Icons.arrow_forward_rounded
                        : Icons.check_rounded,
                    size: 18,
                  ),
            label: Text(
              _isSubmitting
                  ? 'Creating...'
                  : (_currentStep < 2 ? 'Next Step' : 'Create Course'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// One row of the manual installment plan: an amount, and how many days after
// enrollment it's due (0 for the first, on-enrollment installment).
class _InstallmentRow {
  final TextEditingController amount = TextEditingController();
  final TextEditingController days = TextEditingController();
  void dispose() {
    amount.dispose();
    days.dispose();
  }
}

// ─── Full-page Module Editor with inline lesson forms ────────────────────────

class _LmsLessonForm {
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController contentCtrl = TextEditingController();
  final TextEditingController durationCtrl = TextEditingController();
  final TextEditingController liveNoteCtrl = TextEditingController();
  String? videoUrl;
  String? documentUrl;
  String? documentName;
  DateTime? liveSessionDateTime;

  _LmsLessonForm({Map<String, dynamic>? existing}) {
    if (existing != null) {
      titleCtrl.text = existing['title']?.toString() ?? '';
      contentCtrl.text = existing['content']?.toString() ?? '';
      durationCtrl.text = existing['duration']?.toString() ?? '';
      liveNoteCtrl.text = existing['liveSessionNote']?.toString() ?? '';
      videoUrl = existing['videoUrl']?.toString();
      documentUrl = existing['documentUrl']?.toString();
      documentName = existing['documentName']?.toString();
      final lsdt = existing['liveSessionDateTime'];
      if (lsdt != null) {
        liveSessionDateTime = DateTime.tryParse(lsdt.toString());
      }
    }
  }

  Map<String, dynamic> toMap(int order) => {
    'title': titleCtrl.text.trim(),
    'content': contentCtrl.text.trim(),
    'duration': int.tryParse(durationCtrl.text.trim()) ?? 0,
    'order': order,
    if (videoUrl != null && videoUrl!.isNotEmpty) 'videoUrl': videoUrl,
    if (documentUrl != null && documentUrl!.isNotEmpty)
      'documentUrl': documentUrl,
    if (documentName != null) 'documentName': documentName,
    // .toUtc() is required: liveSessionDateTime is built from local date/time
    // pickers, so a bare .toIso8601String() has no timezone marker and the
    // backend's `new Date(...)` would parse it in the SERVER's timezone
    // (UTC on Vercel) instead of the instructor's — silently shifting the
    // displayed time by several hours. Converting to UTC first makes the
    // string carry an explicit 'Z', so the same instant survives the round trip.
    if (liveSessionDateTime != null)
      'liveSessionDateTime': liveSessionDateTime!.toUtc().toIso8601String(),
    if (liveNoteCtrl.text.trim().isNotEmpty)
      'liveSessionNote': liveNoteCtrl.text.trim(),
  };

  void dispose() {
    titleCtrl.dispose();
    contentCtrl.dispose();
    durationCtrl.dispose();
    liveNoteCtrl.dispose();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter module title')));
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
    for (final f in _lessonForms) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => goBackOrHome(context),
        ),
        title: Text(
          widget.existingModule == null ? 'Add Module' : 'Edit Module',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Save Module',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
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
                  decoration: const InputDecoration(
                    labelText: 'Module Title *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Module Description (optional)',
                    border: OutlineInputBorder(),
                  ),
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
                Row(
                  children: [
                    const Icon(
                      Icons.play_lesson_rounded,
                      color: AppColors.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Lessons',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_lessonForms.length} added',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._lessonForms.asMap().entries.map((entry) {
                  final i = entry.key;
                  final form = entry.value;
                  return _LmsInlineLessonWidget(
                    key: ObjectKey(form),
                    form: form,
                    number: i + 1,
                    onRemove: _lessonForms.length > 1
                        ? () => setState(() {
                            form.dispose();
                            _lessonForms.removeAt(i);
                          })
                        : null,
                    onChanged: () => setState(() {}),
                  );
                }),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _lessonForms.add(_LmsLessonForm())),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Another Lesson'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryColor,
                      side: const BorderSide(color: AppColors.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Module',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      if (file.size > 100 * 1024 * 1024) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Max 100MB for videos'),
              backgroundColor: Colors.red,
            ),
          );
        return;
      }
      setState(() => _uploadingVideo = true);
      final url = await _signedCloudinaryUpload(
        bytes: file.bytes!,
        filename: file.name,
        folder: 'icare/lessons/videos',
      );
      if (url != null) {
        setState(() {
          widget.form.videoUrl = url;
          _uploadingVideo = false;
        });
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Video uploaded!'),
              backgroundColor: Colors.green,
            ),
          );
      }
    } catch (e) {
      setState(() => _uploadingVideo = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload failed: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'xls',
          'xlsx',
          'txt',
        ],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      if (file.size > 50 * 1024 * 1024) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Max 50MB for documents'),
              backgroundColor: Colors.red,
            ),
          );
        return;
      }
      setState(() => _uploadingDoc = true);
      final url = await _signedCloudinaryUpload(
        bytes: file.bytes!,
        filename: file.name,
        folder: 'icare/lessons/docs',
        resourceType: 'raw',
      );
      if (url != null) {
        setState(() {
          widget.form.documentUrl = url;
          widget.form.documentName = file.name;
          _uploadingDoc = false;
        });
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Document uploaded!'),
              backgroundColor: Colors.green,
            ),
          );
      }
    } catch (e) {
      setState(() => _uploadingDoc = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload failed: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: AppColors.primaryColor,
                  child: Text(
                    '${widget.number}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Lesson',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryColor,
                  ),
                ),
                const Spacer(),
                if (widget.onRemove != null)
                  GestureDetector(
                    onTap: widget.onRemove,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.red,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: f.titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lesson Title *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: f.contentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: f.durationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes)',
                    border: OutlineInputBorder(),
                    suffixText: 'min',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                _uploadTile(
                  icon: Icons.play_circle_outline_rounded,
                  color: const Color(0xFF3B82F6),
                  title: 'Video',
                  subtitle:
                      f.videoUrl ??
                      'Upload .mp4, .webm, or video file (max 100MB)',
                  has: f.videoUrl != null,
                  loading: _uploadingVideo,
                  onTap: _pickVideo,
                  onClear: () => setState(() {
                    f.videoUrl = null;
                  }),
                ),
                const SizedBox(height: 10),
                _uploadTile(
                  icon: Icons.description_outlined,
                  color: const Color(0xFF10B981),
                  title: 'Document',
                  subtitle:
                      f.documentName ??
                      (f.documentUrl != null
                          ? 'Attached'
                          : 'PDF, DOC, PPT, XLS (max 50MB)'),
                  has: f.documentUrl != null,
                  loading: _uploadingDoc,
                  onTap: _pickDocument,
                  onClear: () => setState(() {
                    f.documentUrl = null;
                    f.documentName = null;
                  }),
                ),
                const SizedBox(height: 14),
                // ── Feature 2: Live Session Date/Time ──────────────────────────
                const Text(
                  'Live Session (optional)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: f.liveSessionDateTime != null
                        ? const Color(0xFF6366F1).withValues(alpha: 0.06)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: f.liveSessionDateTime != null
                          ? const Color(0xFF6366F1).withValues(alpha: 0.4)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.video_call_rounded,
                        color: Color(0xFF6366F1),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.liveSessionDateTime != null
                                  ? '${f.liveSessionDateTime!.day}/${f.liveSessionDateTime!.month}/${f.liveSessionDateTime!.year}  ${f.liveSessionDateTime!.hour.toString().padLeft(2, '0')}:${f.liveSessionDateTime!.minute.toString().padLeft(2, '0')}'
                                  : 'Schedule live session for this lesson',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: f.liveSessionDateTime != null
                                    ? const Color(0xFF6366F1)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                            const Text(
                              'For reminders only — not auto-started',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (f.liveSessionDateTime != null)
                        GestureDetector(
                          onTap: () =>
                              setState(() => f.liveSessionDateTime = null),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.red,
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(
                                const Duration(days: 1),
                              ),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date == null || !mounted) return;
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(hour: 10, minute: 0),
                            );
                            if (time == null || !mounted) return;
                            setState(
                              () => f.liveSessionDateTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              ),
                            );
                          },
                          child: const Icon(
                            Icons.add_circle_outline_rounded,
                            color: Color(0xFF6366F1),
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
                if (f.liveSessionDateTime != null) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: f.liveNoteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Live session note (optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                      hintText: 'e.g. Join via Zoom link in announcements',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _uploadTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool has,
    required bool loading,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: has ? color.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: has ? color.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: has ? color : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (has)
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.red,
                ),
              )
            else
              Icon(Icons.add_circle_outline_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}
