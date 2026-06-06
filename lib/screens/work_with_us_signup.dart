import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/screens/terms_and_conditions.dart';
import 'package:icare/screens/privacy_policy.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/auth_left_panel.dart';
import 'package:icare/screens/verification_status_screen.dart';

class WorkWithUsSignup extends StatefulWidget {
  const WorkWithUsSignup({super.key});

  @override
  State<WorkWithUsSignup> createState() => _WorkWithUsSignupState();
}

class _WorkWithUsSignupState extends State<WorkWithUsSignup> {
  int _step = 0; // 0=Partner Type, 1=Basic Info, 2=Detailed Form

  // ── Step 1: Basic Info ───────────────────────────────────────────────────
  final _step1Key = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _obscurePassword = true;

  // ── Step 2: Partner Type ─────────────────────────────────────────────────
  String? _selectedRole;

  // ── Step 3: Doctor Fields ────────────────────────────────────────────────
  final _qualificationCtrl = TextEditingController();
  final _specializationCtrl = TextEditingController();
  final _pmdcCtrl = TextEditingController();
  final _docExpCtrl = TextEditingController();
  final _workplaceCtrl = TextEditingController();
  final Set<String> _docAvailDays = {};
  final _docTimingsCtrl = TextEditingController();
  String? _docCnic;
  String? _docPmdcCert;
  String? _docExpCert;
  final bool _docConfirmInfo = false;
  final bool _docAgreeOnboarding = false;
  final _docCommentsCtrl = TextEditingController();

  // ── Step 3: Pharmacy Fields ──────────────────────────────────────────────
  final _pharmNameCtrl = TextEditingController();
  final _drugLicenseCtrl = TextEditingController();
  final _pharmacistNameCtrl = TextEditingController();
  final _pharmYearsCtrl = TextEditingController();
  bool? _pharmDelivery;
  final Set<String> _pharmOpDays = {};
  final _pharmHoursCtrl = TextEditingController();
  bool? _pharmOnlineOrders;
  bool? _pharmHasPOS;
  final _pharmPOSDetailCtrl = TextEditingController();
  bool? _pharmWillingIntegrate;
  String? _pharmCnic;
  String? _pharmDrugLicense;
  String? _pharmRegCert;
  final bool _pharmConfirmInfo = false;
  final bool _pharmAgreeOnboarding = false;
  final _pharmCommentsCtrl = TextEditingController();

  // ── Step 3: Laboratory Fields ────────────────────────────────────────────
  final _labNameCtrl = TextEditingController();
  final _labLicenseCtrl = TextEditingController();
  final _labYearsCtrl = TextEditingController();
  String? _labTestsFile;
  bool? _labHomeSampling;
  final Set<String> _labOpDays = {};
  final _labHoursCtrl = TextEditingController();
  bool? _labOnlineReports;
  bool? _labHasLIS;
  final _labLISDetailCtrl = TextEditingController();
  bool? _labWillingIntegrate;
  String? _labCnic;
  String? _labLicense;
  String? _labAccredCert;
  final bool _labConfirmInfo = false;
  final bool _labAgreeOnboarding = false;
  final _labCommentsCtrl = TextEditingController();

  // ── Step 3: Student Fields ───────────────────────────────────────────────
  final _studentUniversityCtrl = TextEditingController();
  final _studentProgramCtrl = TextEditingController();
  final _studentYearCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  String? _studentIdFile;
  final bool _studentConfirmInfo = false;
  final _studentCommentsCtrl = TextEditingController();

  // ── Step 3: Instructor Fields ────────────────────────────────────────────
  final _instrQualificationCtrl = TextEditingController();
  final _instrSpecializationCtrl = TextEditingController();
  final _instrExpCtrl = TextEditingController();
  final _instrInstitutionCtrl = TextEditingController();
  final _instrCoursesCtrl = TextEditingController();
  String? _instrCnic;
  String? _instrCvFile;
  final bool _instructorConfirmInfo = false;
  final bool _instructorAgreeOnboarding = false;
  final _instrCommentsCtrl = TextEditingController();

  bool _submitting = false;

  static const _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static const _roles = [
    {
      'role': 'Doctor',
      'title': 'Doctor',
      'subtitle': 'Manage Patients & Prescriptions',
      'icon': Icons.medical_services_rounded,
      'color': Color(0xFF0036BC),
    },
    {
      'role': 'Pharmacy',
      'title': 'Pharmacy',
      'subtitle': 'Prescription Fulfillment',
      'icon': Icons.local_pharmacy_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'role': 'Laboratory',
      'title': 'Laboratory',
      'subtitle': 'Diagnostics & Reports',
      'icon': Icons.biotech_rounded,
      'color': Color(0xFF8B5CF6),
    },
    {
      'role': 'Student',
      'title': 'Student',
      'subtitle': 'Access Medical Courses & Learning',
      'icon': Icons.school_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'role': 'Instructor',
      'title': 'Instructor',
      'subtitle': 'Teach & Create Medical Courses',
      'icon': Icons.cast_for_education_rounded,
      'color': Color(0xFFEF4444),
    },
  ];

  @override
  void dispose() {
    _nameCtrl.dispose(); _contactPersonCtrl.dispose(); _phoneCtrl.dispose();
    _emailCtrl.dispose(); _cityCtrl.dispose(); _addressCtrl.dispose();
    _qualificationCtrl.dispose(); _specializationCtrl.dispose();
    _pmdcCtrl.dispose(); _docExpCtrl.dispose(); _workplaceCtrl.dispose();
    _docTimingsCtrl.dispose(); _docCommentsCtrl.dispose();
    _pharmNameCtrl.dispose(); _drugLicenseCtrl.dispose();
    _pharmacistNameCtrl.dispose(); _pharmYearsCtrl.dispose();
    _pharmHoursCtrl.dispose(); _pharmPOSDetailCtrl.dispose();
    _pharmCommentsCtrl.dispose();
    _labNameCtrl.dispose(); _labLicenseCtrl.dispose();
    _labYearsCtrl.dispose(); _labHoursCtrl.dispose();
    _labLISDetailCtrl.dispose(); _labCommentsCtrl.dispose();
    _studentUniversityCtrl.dispose(); _studentProgramCtrl.dispose();
    _studentYearCtrl.dispose(); _studentIdCtrl.dispose(); _studentCommentsCtrl.dispose();
    _instrQualificationCtrl.dispose(); _instrSpecializationCtrl.dispose();
    _instrExpCtrl.dispose(); _instrInstitutionCtrl.dispose();
    _instrCoursesCtrl.dispose(); _instrCommentsCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 0) {
      // Step 0: Partner Type — must select a role first
      if (_selectedRole == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a partner type to continue')),
        );
        return;
      }
      setState(() => _step = 1);
    } else if (_step == 1) {
      // Step 1: Basic Info — validate form
      if (!_step1Key.currentState!.validate()) return;
      setState(() => _step = 2);
    }
  }

  void _prevStep() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _submit() async {
    // Agreement is implicit by submitting — no checkbox validation needed
    setState(() => _submitting = true);

    try {
      // Map display roles to backend enum values in User model
      final roleMap = {
        'Doctor': 'doctor',
        'Pharmacy': 'pharmacy',
        'Laboratory': 'lab',       // enum is 'lab' not 'laboratory'
        'Student': 'student',
        'Instructor': 'instructor',
      };
      final backendRole = roleMap[_selectedRole] ?? _selectedRole!.toLowerCase();
      final capturedName = _nameCtrl.text.trim();

      final api = ApiService();
      final response = await api.post('/auth/register', {
        'username': capturedName,
        'name': capturedName,
        'email': _emailCtrl.text.trim().toLowerCase(),
        'password': _passwordCtrl.text,
        'phone': _phoneCtrl.text.trim(),
        'role': backendRole,
        'city': _cityCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
      });

      final resData = response.data;
      final isSuccess = response.statusCode == 201 || response.statusCode == 200 ||
          (resData is Map && resData['success'] == true);

      if (isSuccess) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => VerificationStatusScreen(
                role: _selectedRole!,
                applicantName: capturedName,
              ),
            ),
          );
        }
      } else {
        final msg = (resData is Map ? resData['message']?.toString() : null) ?? 'Registration failed. Please try again.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errMsg;
        if (e is DioException && e.response != null) {
          final data = e.response!.data;
          if (data is Map) {
            errMsg = data['message']?.toString() ?? data['error']?.toString() ?? 'Registration failed (${e.response!.statusCode}).';
          } else {
            errMsg = 'Registration failed. Status: ${e.response!.statusCode}';
          }
        } else if (e.toString().contains('already exists') || e.toString().contains('duplicate')) {
          errMsg = 'An account with this email already exists.';
        } else if (e.toString().contains('SocketException') || e.toString().contains('connection')) {
          errMsg = 'Network error. Please check your internet connection.';
        } else {
          errMsg = 'Registration failed. Please try again.';
          debugPrint('WorkWithUs submit error: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errMsg), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: isDesktop ? _buildDesktop() : _buildMobile(),
    );
  }

  Widget _buildDesktop() {
    return Row(
      children: [
        const Expanded(flex: 5, child: AuthLeftPanel()),
        Expanded(flex: 5, child: _buildRightPanel()),
      ],
    );
  }

  Widget _buildRightPanel() {
    return Container(
      color: const Color(0xFFF8FAFD),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Container(
            width: 520,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 44),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0036BC).withValues(alpha: 0.06),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobile() {
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    if (_step > 0) {
                      _prevStep();
                    } else if (Navigator.canPop(context)) Navigator.pop(context);
                    else context.go('/home');
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: Color(0xFF0B2D6E)),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Work With Us',
                    style: TextStyle(
                        color: Color(0xFF0036BC),
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        fontFamily: 'Gilroy-Bold')),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ResponsiveHelper.isDesktop(context)) ...[
          InkWell(
            onTap: () {
              if (_step > 0) {
                _prevStep();
              } else if (Navigator.canPop(context)) Navigator.pop(context);
              else context.go('/home');
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Color(0xFF0B2D6E)),
            ),
          ),
          const SizedBox(height: 28),
        ],
        _StepIndicator(currentStep: _step),
        const SizedBox(height: 28),
        if (_step == 0) _buildStep1(),  // Partner Type
        if (_step == 1) _buildStep2(),  // Basic Info
        if (_step == 2) _buildStep3(),  // Detailed Form
        if (_step == 0) ...[
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: () => context.go('/login'),
              child: RichText(
                text: TextSpan(
                  text: 'Already have an account? ',
                  style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      fontFamily: 'Gilroy-Medium'),
                  children: [
                    TextSpan(
                      text: 'Sign In',
                      style: TextStyle(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Gilroy-Bold'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STEP 1 — Select Partner Type (shown FIRST)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Select Partner Type', 'Choose how you want to work with iCare'),
        const SizedBox(height: 24),
        ..._roles.map((r) => _roleCard(r)),
        const SizedBox(height: 28),
        _primaryButton('Continue', Icons.arrow_forward_rounded, _nextStep),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STEP 2 — Basic Information (shown SECOND)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildStep2() {
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle('Basic Information', 'Tell us about yourself or your organization'),
          const SizedBox(height: 24),
          _inputField(_nameCtrl, 'Full Name / Organization Name', Icons.person_outline_rounded,
              validator: (v) => v == null || v.isEmpty ? 'Name is required' : null),
          const SizedBox(height: 14),
          _inputField(_contactPersonCtrl, 'Contact Person Name (if organization)',
              Icons.badge_outlined),
          const SizedBox(height: 14),
          _inputField(_phoneCtrl, 'Phone Number', Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.isEmpty ? 'Phone is required' : null),
          const SizedBox(height: 14),
          _inputField(_emailCtrl, 'Email Address', Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || v.isEmpty ? 'Email is required' : null),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Create Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _inputField(_cityCtrl, 'City', Icons.location_city_outlined,
              validator: (v) => v == null || v.isEmpty ? 'City is required' : null),
          const SizedBox(height: 14),
          _inputField(_addressCtrl, 'Complete Address', Icons.home_outlined,
              validator: (v) => v == null || v.isEmpty ? 'Address is required' : null),
          const SizedBox(height: 28),
          _primaryButton('Continue', Icons.arrow_forward_rounded, _nextStep),
        ],
      ),
    );
  }

  Widget _roleCard(Map<String, dynamic> r) {
    final color = r['color'] as Color;
    final isSelected = _selectedRole == r['role'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = r['role'] as String),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isSelected ? color : const Color(0xFFE2E8F0),
                width: isSelected ? 2 : 1.5),
            boxShadow: isSelected
                ? [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))]
                : [],
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isSelected ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(r['icon'] as IconData, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['title'] as String,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? color : const Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text(r['subtitle'] as String,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                )
              else
                Icon(Icons.radio_button_unchecked_rounded,
                    color: Colors.grey[300], size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STEP 3 — Role-specific Detailed Form
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildStep3() {
    if (_selectedRole == 'Doctor') return _buildDoctorForm();
    if (_selectedRole == 'Pharmacy') return _buildPharmacyForm();
    if (_selectedRole == 'Laboratory') return _buildLabForm();
    if (_selectedRole == 'Student') return _buildStudentForm();
    if (_selectedRole == 'Instructor') return _buildInstructorForm();
    return const SizedBox.shrink();
  }

  // ── Doctor Form ─────────────────────────────────────────────────────────────
  Widget _buildDoctorForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Doctor Registration', 'Complete your professional profile'),
        const SizedBox(height: 24),

        // 1. Professional Details
        _sectionHeader('1. Professional Details', Icons.medical_services_rounded,
            const Color(0xFF0036BC)),
        const SizedBox(height: 12),
        _inputField(_qualificationCtrl, 'Qualification', Icons.school_outlined,
            hint: 'e.g., MBBS, MD'),
        const SizedBox(height: 12),
        _inputField(_specializationCtrl, 'Specialization', Icons.psychology_outlined,
            hint: 'e.g., Cardiologist, General Practitioner'),
        const SizedBox(height: 12),
        _inputField(_pmdcCtrl, 'PMDC Registration Number', Icons.numbers_rounded),
        const SizedBox(height: 12),
        _inputField(_docExpCtrl, 'Years of Experience', Icons.timeline_rounded,
            keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        _inputField(_workplaceCtrl, 'Current Workplace / Clinic Name',
            Icons.local_hospital_outlined),
        const SizedBox(height: 24),

        // 2. Availability
        _sectionHeader('2. Availability', Icons.schedule_rounded, const Color(0xFF0036BC)),
        const SizedBox(height: 12),
        _label('Available Days'),
        const SizedBox(height: 8),
        _daySelector(_docAvailDays),
        const SizedBox(height: 12),
        _inputField(_docTimingsCtrl, 'Available Timings', Icons.access_time_rounded,
            hint: 'e.g., 9:00 AM – 5:00 PM'),
        const SizedBox(height: 24),

        // 3. Documents Upload
        _sectionHeader('3. Documents Upload', Icons.upload_file_rounded,
            const Color(0xFF0036BC)),
        const SizedBox(height: 12),
        _fileUploadRow('CNIC / ID', _docCnic, (v) => setState(() => _docCnic = v),
            required: true),
        const SizedBox(height: 10),
        _fileUploadRow('PMDC Certificate', _docPmdcCert,
            (v) => setState(() => _docPmdcCert = v), required: true),
        const SizedBox(height: 10),
        _fileUploadRow('Experience Certificates', _docExpCert,
            (v) => setState(() => _docExpCert = v), required: false),
        const SizedBox(height: 24),

        _sectionHeader('3. Additional Comments', Icons.comment_outlined,
            const Color(0xFF0036BC)),
        const SizedBox(height: 12),
        _multilineField(_docCommentsCtrl, 'Any additional information (optional)'),
        const SizedBox(height: 24),

        _submitButton(),
      ],
    );
  }

  // ── Pharmacy Form ────────────────────────────────────────────────────────────
  Widget _buildPharmacyForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Pharmacy Registration', 'Complete your pharmacy profile'),
        const SizedBox(height: 24),

        // 1. Pharmacy Details
        _sectionHeader('1. Pharmacy Details', Icons.local_pharmacy_rounded,
            const Color(0xFF10B981)),
        const SizedBox(height: 12),
        _inputField(_pharmNameCtrl, 'Pharmacy Name', Icons.storefront_outlined),
        const SizedBox(height: 12),
        _inputField(_drugLicenseCtrl, 'Drug License Number', Icons.numbers_rounded),
        const SizedBox(height: 12),
        _inputField(_pharmacistNameCtrl, 'Pharmacist Name', Icons.person_outline_rounded),
        const SizedBox(height: 12),
        _inputField(_pharmYearsCtrl, 'Years of Operation', Icons.timeline_rounded,
            keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        _label('Delivery Available'),
        const SizedBox(height: 8),
        _yesNoRow(_pharmDelivery, (v) => setState(() => _pharmDelivery = v)),
        const SizedBox(height: 24),

        // 2. Services & Availability
        _sectionHeader('2. Services & Availability', Icons.schedule_rounded,
            const Color(0xFF10B981)),
        const SizedBox(height: 12),
        _label('Operating Days'),
        const SizedBox(height: 8),
        _daySelector(_pharmOpDays),
        const SizedBox(height: 12),
        _inputField(_pharmHoursCtrl, 'Operating Hours', Icons.access_time_rounded,
            hint: 'e.g., 9:00 AM – 10:00 PM'),
        const SizedBox(height: 12),
        _label('Online Orders Available'),
        const SizedBox(height: 8),
        _yesNoRow(_pharmOnlineOrders, (v) => setState(() => _pharmOnlineOrders = v)),
        const SizedBox(height: 24),

        // 3. Technology & Integration
        _sectionHeader('3. Technology & Integration', Icons.integration_instructions_rounded,
            const Color(0xFF10B981)),
        const SizedBox(height: 12),
        _label('Do you use POS / inventory system?'),
        const SizedBox(height: 8),
        _yesNoRow(_pharmHasPOS, (v) => setState(() => _pharmHasPOS = v)),
        if (_pharmHasPOS == true) ...[
          const SizedBox(height: 10),
          _inputField(_pharmPOSDetailCtrl, 'If yes, specify system name',
              Icons.point_of_sale_rounded),
        ],
        const SizedBox(height: 12),
        _label('Willing to integrate with platform?'),
        const SizedBox(height: 8),
        _yesNoRow(
            _pharmWillingIntegrate, (v) => setState(() => _pharmWillingIntegrate = v)),
        const SizedBox(height: 24),

        // 4. Documents Upload
        _sectionHeader('4. Documents Upload', Icons.upload_file_rounded,
            const Color(0xFF10B981)),
        const SizedBox(height: 12),
        _fileUploadRow('CNIC / ID', _pharmCnic, (v) => setState(() => _pharmCnic = v),
            required: true),
        const SizedBox(height: 10),
        _fileUploadRow('Drug License', _pharmDrugLicense,
            (v) => setState(() => _pharmDrugLicense = v), required: true),
        const SizedBox(height: 10),
        _fileUploadRow('Pharmacy Registration Certificate', _pharmRegCert,
            (v) => setState(() => _pharmRegCert = v), required: true),
        const SizedBox(height: 24),

        _sectionHeader('5. Additional Comments', Icons.comment_outlined,
            const Color(0xFF10B981)),
        const SizedBox(height: 12),
        _multilineField(_pharmCommentsCtrl, 'Any additional information (optional)'),
        const SizedBox(height: 24),

        _submitButton(),
      ],
    );
  }

  // ── Laboratory Form ──────────────────────────────────────────────────────────
  Widget _buildLabForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Laboratory Registration', 'Complete your laboratory profile'),
        const SizedBox(height: 24),

        // 1. Lab Details
        _sectionHeader('1. Lab Details', Icons.biotech_rounded, const Color(0xFF8B5CF6)),
        const SizedBox(height: 12),
        _inputField(_labNameCtrl, 'Lab Name', Icons.science_outlined),
        const SizedBox(height: 12),
        _inputField(_labLicenseCtrl, 'Registration / License Number',
            Icons.numbers_rounded),
        const SizedBox(height: 12),
        _inputField(_labYearsCtrl, 'Years of Operation', Icons.timeline_rounded,
            keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        _fileUploadRow('Available Tests List (Upload)', _labTestsFile,
            (v) => setState(() => _labTestsFile = v), required: false,
            color: const Color(0xFF8B5CF6)),
        const SizedBox(height: 12),
        _label('Home Sampling Available'),
        const SizedBox(height: 8),
        _yesNoRow(_labHomeSampling, (v) => setState(() => _labHomeSampling = v),
            color: const Color(0xFF8B5CF6)),
        const SizedBox(height: 24),

        // 2. Services & Availability
        _sectionHeader('2. Services & Availability', Icons.schedule_rounded,
            const Color(0xFF8B5CF6)),
        const SizedBox(height: 12),
        _label('Operating Days'),
        const SizedBox(height: 8),
        _daySelector(_labOpDays),
        const SizedBox(height: 12),
        _inputField(_labHoursCtrl, 'Operating Hours', Icons.access_time_rounded,
            hint: 'e.g., 7:00 AM – 9:00 PM'),
        const SizedBox(height: 12),
        _label('Online Reports Available'),
        const SizedBox(height: 8),
        _yesNoRow(_labOnlineReports, (v) => setState(() => _labOnlineReports = v),
            color: const Color(0xFF8B5CF6)),
        const SizedBox(height: 24),

        // 3. Technology & Integration
        _sectionHeader('3. Technology & Integration', Icons.integration_instructions_rounded,
            const Color(0xFF8B5CF6)),
        const SizedBox(height: 12),
        _label('Do you use lab software / LIS?'),
        const SizedBox(height: 8),
        _yesNoRow(_labHasLIS, (v) => setState(() => _labHasLIS = v),
            color: const Color(0xFF8B5CF6)),
        if (_labHasLIS == true) ...[
          const SizedBox(height: 10),
          _inputField(_labLISDetailCtrl, 'If yes, specify system name',
              Icons.computer_rounded),
        ],
        const SizedBox(height: 12),
        _label('Willing to integrate with platform?'),
        const SizedBox(height: 8),
        _yesNoRow(
            _labWillingIntegrate, (v) => setState(() => _labWillingIntegrate = v),
            color: const Color(0xFF8B5CF6)),
        const SizedBox(height: 24),

        // 4. Documents Upload
        _sectionHeader('4. Documents Upload', Icons.upload_file_rounded,
            const Color(0xFF8B5CF6)),
        const SizedBox(height: 12),
        _fileUploadRow('CNIC / ID', _labCnic, (v) => setState(() => _labCnic = v),
            required: true, color: const Color(0xFF8B5CF6)),
        const SizedBox(height: 10),
        _fileUploadRow('Lab License', _labLicense,
            (v) => setState(() => _labLicense = v), required: true,
            color: const Color(0xFF8B5CF6)),
        const SizedBox(height: 10),
        _fileUploadRow('Accreditation Certificates', _labAccredCert,
            (v) => setState(() => _labAccredCert = v), required: false,
            color: const Color(0xFF8B5CF6)),
        const SizedBox(height: 24),

        _sectionHeader('5. Additional Comments', Icons.comment_outlined,
            const Color(0xFF8B5CF6)),
        const SizedBox(height: 12),
        _multilineField(_labCommentsCtrl, 'Any additional information (optional)'),
        const SizedBox(height: 24),

        _submitButton(color: const Color(0xFF8B5CF6)),
      ],
    );
  }

  // ── Student Form ─────────────────────────────────────────────────────────────
  Widget _buildStudentForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Student Registration', 'Complete your student profile'),
        const SizedBox(height: 24),

        _sectionHeader('1. Academic Details', Icons.school_rounded, const Color(0xFFF59E0B)),
        const SizedBox(height: 12),
        _inputField(_studentUniversityCtrl, 'University / Institution Name',
            Icons.account_balance_outlined),
        const SizedBox(height: 12),
        _inputField(_studentProgramCtrl, 'Program / Degree',
            Icons.menu_book_outlined, hint: 'e.g., MBBS, BDS, Pharm-D'),
        const SizedBox(height: 12),
        _inputField(_studentYearCtrl, 'Current Year / Semester',
            Icons.timeline_rounded, hint: 'e.g., 3rd Year, Semester 5'),
        const SizedBox(height: 12),
        _inputField(_studentIdCtrl, 'Student ID / Roll Number',
            Icons.badge_outlined),
        const SizedBox(height: 24),

        _sectionHeader('2. Documents', Icons.upload_file_rounded, const Color(0xFFF59E0B)),
        const SizedBox(height: 12),
        _fileUploadRow('Student ID Card', _studentIdFile,
            (v) => setState(() => _studentIdFile = v),
            required: true, color: const Color(0xFFF59E0B)),
        const SizedBox(height: 24),

        _sectionHeader('3. Additional Comments', Icons.comment_outlined,
            const Color(0xFFF59E0B)),
        const SizedBox(height: 12),
        _multilineField(_studentCommentsCtrl, 'Any additional information (optional)'),
        const SizedBox(height: 24),

        _submitButton(color: const Color(0xFFF59E0B)),
      ],
    );
  }

  // ── Instructor Form ───────────────────────────────────────────────────────────
  Widget _buildInstructorForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Instructor Registration', 'Complete your instructor profile'),
        const SizedBox(height: 24),

        _sectionHeader('1. Professional Details', Icons.cast_for_education_rounded,
            const Color(0xFFEF4444)),
        const SizedBox(height: 12),
        _inputField(_instrQualificationCtrl, 'Highest Qualification',
            Icons.school_outlined, hint: 'e.g., MBBS, MD, PhD'),
        const SizedBox(height: 12),
        _inputField(_instrSpecializationCtrl, 'Area of Expertise / Specialization',
            Icons.psychology_outlined),
        const SizedBox(height: 12),
        _inputField(_instrExpCtrl, 'Years of Teaching Experience',
            Icons.timeline_rounded, keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        _inputField(_instrInstitutionCtrl, 'Current Institution / Organization',
            Icons.account_balance_outlined),
        const SizedBox(height: 12),
        _inputField(_instrCoursesCtrl, 'Courses You Want to Teach',
            Icons.menu_book_outlined,
            hint: 'e.g., Anatomy, Pharmacology, Clinical Skills'),
        const SizedBox(height: 24),

        _sectionHeader('2. Documents', Icons.upload_file_rounded, const Color(0xFFEF4444)),
        const SizedBox(height: 12),
        _fileUploadRow('CNIC / ID', _instrCnic,
            (v) => setState(() => _instrCnic = v),
            required: true, color: const Color(0xFFEF4444)),
        const SizedBox(height: 10),
        _fileUploadRow('CV / Resume', _instrCvFile,
            (v) => setState(() => _instrCvFile = v),
            required: true, color: const Color(0xFFEF4444)),
        const SizedBox(height: 24),

        _sectionHeader('3. Additional Comments', Icons.comment_outlined,
            const Color(0xFFEF4444)),
        const SizedBox(height: 12),
        _multilineField(_instrCommentsCtrl, 'Any additional information (optional)'),
        const SizedBox(height: 24),

        _submitButton(color: const Color(0xFFEF4444)),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _stepTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0B2D6E),
                fontFamily: 'Gilroy-Bold')),
        const SizedBox(height: 4),
        Text(subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFamily: 'Gilroy-Bold')),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151)));
  }

  Widget _daySelector(Set<String> selected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _weekDays.map((day) {
        final isSelected = selected.contains(day);
        return GestureDetector(
          onTap: () => setState(() {
            isSelected ? selected.remove(day) : selected.add(day);
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryColor : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isSelected
                      ? AppColors.primaryColor
                      : const Color(0xFFE2E8F0)),
            ),
            child: Text(day,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF64748B))),
          ),
        );
      }).toList(),
    );
  }

  Widget _yesNoRow(bool? value, ValueChanged<bool?> onChanged,
      {Color color = AppColors.primaryColor}) {
    return Row(
      children: [
        _yesNoOption('Yes', true, value, onChanged, color),
        const SizedBox(width: 12),
        _yesNoOption('No', false, value, onChanged, color),
      ],
    );
  }

  Widget _yesNoOption(String label, bool optValue, bool? groupValue,
      ValueChanged<bool?> onChanged, Color color) {
    final isSelected = groupValue == optValue;
    return GestureDetector(
      onTap: () => onChanged(optValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 16,
              color: isSelected ? color : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? color : const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _fileUploadRow(
      String label, String? fileName, ValueChanged<String?> onPicked,
      {required bool required,
      Color color = AppColors.primaryColor}) {
    final hasFile = fileName != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasFile ? color.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: hasFile ? color.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(
              hasFile ? Icons.check_circle_rounded : Icons.upload_file_rounded,
              color: hasFile ? color : const Color(0xFF94A3B8),
              size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A))),
                    if (!required)
                      const Text(' (optional)',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                    hasFile ? fileName : 'No file selected',
                    style: TextStyle(
                        fontSize: 11,
                        color: hasFile ? color : const Color(0xFF94A3B8))),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                  allowMultiple: false,
                );
                if (result != null && result.files.isNotEmpty) {
                  onPicked(result.files.first.name);
                }
              } catch (e) {
                // Fallback if file picker fails
                onPicked('${label.replaceAll(' ', '_')}.pdf');
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: Text(hasFile ? 'Change' : 'Browse',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _checkboxRow({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
    Color color = AppColors.primaryColor,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: value ? color.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: value ? color.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24, height: 24,
              child: Checkbox(
                value: value,
                activeColor: color,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                      height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _multilineField(TextEditingController ctrl, String hint) {
    return TextFormField(
      controller: ctrl,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryColor, width: 2)),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _inputField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint ?? label,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryColor, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Gilroy-Bold')),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _submitButton({Color color = AppColors.primaryColor}) {
    return Column(
      children: [
        // "By clicking submit, you agree to our Terms and Conditions"
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              const Text(
                'By clicking submit, you agree to our ',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TermsAndConditions()),
                ),
                child: Text(
                  'Terms and Conditions',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: color,
                  ),
                ),
              ),
              const Text(
                ' and ',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicy()),
                ),
                child: Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: color,
                  ),
                ),
              ),
              const Text(
                '.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Submit Application',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Gilroy-Bold')),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// STEP INDICATOR
// ════════════════════════════════════════════════════════════════════════════
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  static const _steps = ['Partner Type', 'Basic Info', 'Details & Submit'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIndex = i ~/ 2;
          return Expanded(
            child: Container(
              height: 2,
              color: currentStep > stepIndex
                  ? AppColors.primaryColor
                  : const Color(0xFFE2E8F0),
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final isDone = currentStep > stepIndex;
        final isCurrent = currentStep == stepIndex;
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone || isCurrent
                    ? AppColors.primaryColor
                    : const Color(0xFFE2E8F0),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isCurrent
                              ? Colors.white
                              : const Color(0xFF94A3B8),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _steps[stepIndex],
              style: TextStyle(
                fontSize: 10,
                fontWeight: isCurrent || isDone
                    ? FontWeight.w700
                    : FontWeight.w400,
                color: isCurrent || isDone
                    ? AppColors.primaryColor
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        );
      }),
    );
  }
}
