import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/services/doctor_service.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/models/user.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:image_picker/image_picker.dart';

class DoctorProfileSetup extends ConsumerStatefulWidget {
  const DoctorProfileSetup({super.key});

  @override
  ConsumerState<DoctorProfileSetup> createState() => _DoctorProfileSetupState();
}

class _DoctorProfileSetupState extends ConsumerState<DoctorProfileSetup> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  final TextEditingController specializationController =
      TextEditingController();
  final TextEditingController degreesController = TextEditingController();
  final TextEditingController experienceController = TextEditingController();
  final TextEditingController licenseController = TextEditingController();
  final TextEditingController clinicNameController = TextEditingController();
  final TextEditingController clinicAddressController = TextEditingController();
  final TextEditingController startTimeController = TextEditingController();
  final TextEditingController endTimeController = TextEditingController();

  // License expiry date
  DateTime? _licenseValidTill;

  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  // Specialties — doctor selects which specialties they practice
  final List<String> _selectedSpecialties = [];

  static const _commonSpecialties = [
    'Cardiologist', 'Dermatologist', 'Neurologist', 'Orthopedic Surgeon',
    'Gynecologist', 'Pediatrician', 'Psychiatrist', 'Ophthalmologist',
    'ENT Specialist', 'Urologist', 'Gastroenterologist', 'Endocrinologist',
    'Pulmonologist', 'Oncologist', 'Nephrologist', 'Rheumatologist',
    'Diabetologist', 'General Physician', 'Dentist', 'Nutritionist',
  ];

  // Specialty search + custom entry
  String _specialtySearch = '';
  final TextEditingController _specialtySearchCtrl = TextEditingController();
  final TextEditingController _specialtyCustomCtrl = TextEditingController();

  // Conditions treated — doctor selects what conditions they handle
  final List<String> _conditionsTreated = [];
  final TextEditingController _conditionInputCtrl = TextEditingController();

  // Spoken Languages — Pakistani languages
  final List<String> _spokenLanguages = [
    'Urdu',
    'Punjabi',
    'Pashto',
    'Sindhi',
    'Balochi',
    'English'
  ];
  final List<String> _selectedLanguages = [];

  static const _commonConditions = [
    'Hypertension', 'Diabetes', 'Heart Disease', 'Asthma', 'Back Pain',
    'Headache / Migraine', 'Fever', 'Allergy', 'Anxiety', 'Depression',
    'Obesity', 'Arthritis', 'Kidney Disease', 'Thyroid Disorders',
    'Skin Conditions', 'Eye Problems', 'Dental Issues', 'Pregnancy Care',
    'Child Health', 'Bone & Joint Pain',
  ];

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 600);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  // Available days selection
  final Map<String, bool> selectedDays = {
    'Monday': false,
    'Tuesday': false,
    'Wednesday': false,
    'Thursday': false,
    'Friday': false,
    'Saturday': false,
    'Sunday': false,
  };

  @override
  void dispose() {
    specializationController.dispose();
    degreesController.dispose();
    experienceController.dispose();
    licenseController.dispose();
    clinicNameController.dispose();
    clinicAddressController.dispose();
    startTimeController.dispose();
    endTimeController.dispose();
    _specialtySearchCtrl.dispose();
    _specialtyCustomCtrl.dispose();
    _conditionInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.format(context);
      });
    }
  }

  /// Opens a date picker for license expiry and schedules a 30-day admin reminder.
  Future<void> _pickLicenseExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _licenseValidTill ?? now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: DateTime(now.year + 20),
      helpText: 'Select License Expiry Date',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primaryColor,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _licenseValidTill = picked);
      // Schedule 30-day admin notification (saved to backend)
      await _saveLicenseExpiry(picked);
    }
  }

  /// Saves license expiry to backend. Backend will send admin notification 30 days before.
  Future<void> _saveLicenseExpiry(DateTime expiryDate) async {
    try {
      await DoctorService().updateLicenseExpiry(expiryDate);
    } catch (e) {
      debugPrint('⚠️ Could not save license expiry: $e');
    }
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final availableDays = selectedDays.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (availableDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one available day'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final degrees = degreesController.text
        .split(',')
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toList();

    final result = await DoctorService().updateDoctorProfile(
      specialization: specializationController.text,
      degrees: degrees,
      experience: experienceController.text,
      licenseNumber: licenseController.text,
      clinicName: clinicNameController.text,
      clinicAddress: clinicAddressController.text,
      availableDays: availableDays,
      startTime: startTimeController.text,
      endTime: endTimeController.text,
      profileImage: _imageBytes,
    );

    // Save specialties separately
    if (_selectedSpecialties.isNotEmpty) {
      try {
        await ApiService().post('/doctors/add_doctor_details', {
          'specialties': _selectedSpecialties,
        });
      } catch (_) {}
    }

    // Save conditions treated separately
    if (_conditionsTreated.isNotEmpty) {
      try {
        await ApiService().post('/doctors/add_doctor_details', {
          'conditionsTreated': _conditionsTreated,
        });
      } catch (_) {}
    }

    // Save spoken languages separately
    if (_selectedLanguages.isNotEmpty) {
      try {
        await ApiService().post('/doctors/add_doctor_details', {
          'spokenLanguages': _selectedLanguages,
        });
      } catch (_) {}
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      // Re-fetch user profile to update auth provider with new photo
      try {
        final apiService = ApiService();
        final response = await apiService.get('/users/profile');
        if (response.data != null && mounted) {
          final updatedUser = User.fromJson(response.data);
          await ref.read(authProvider.notifier).setUser(updatedUser);
        }
      } catch (e) {
        debugPrint('Could not refresh user profile: $e');
      }
      _showSuccessModal();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to update profile'),
        ),
      );
    }
  }

  void _showSuccessModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 70,
                  width: 70,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Profile Updated",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Your professional profile has been updated successfully.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Done",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 900) {
      return _buildWebView();
    }
    return _buildMobileView();
  }

  Widget _buildMobileView() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgColor,
        leading: const CustomBackButton(color: AppColors.primaryColor),
        automaticallyImplyLeading: false,
        title: const Text(
          "Professional Profile",
          style: TextStyle(
            fontSize: 16.78,
            fontFamily: "Gilroy-Bold",
            fontWeight: FontWeight.w400,
            color: AppColors.primary500,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Photo
                Center(
                  child: GestureDetector(
                    onTap: _pickProfileImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.3), width: 3),
                          ),
                          child: ClipOval(
                            child: _imageBytes != null
                                ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                                : Icon(Icons.person_rounded, size: 44, color: AppColors.primaryColor),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text('Tap to upload profile photo', style: TextStyle(fontSize: 12, color: AppColors.primaryColor)),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle("Basic Information"),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: specializationController,
                  label: "Specialization",
                  icon: Icons.medical_services_outlined,
                  hint: "e.g., Cardiologist, Dermatologist",
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: degreesController,
                  label: "Degrees (comma separated)",
                  icon: Icons.school_outlined,
                  hint: "e.g., MBBS, MD, PhD",
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: experienceController,
                  label: "Years of Experience",
                  icon: Icons.work_outline,
                  hint: "e.g., 5 years",
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                // License Number + Valid Till side by side
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: licenseController,
                        label: "License Number",
                        icon: Icons.badge_outlined,
                        hint: "Medical license number",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildValidTillField(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionTitle("Your Specialties"),
                const SizedBox(height: 8),
                Text(
                  'Select all specialties you practice. Patients will find you based on these.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                _buildSpecialtiesSelector(),
                const SizedBox(height: 24),
                _buildSectionTitle("Conditions You Treat"),
                const SizedBox(height: 8),
                Text(
                  'Select or add conditions you commonly treat. Patients will find you when searching these conditions.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                _buildConditionsTreated(),
                const SizedBox(height: 32),
                _buildSectionTitle("Languages You Speak"),
                const SizedBox(height: 8),
                Text(
                  'Select all languages you speak to help patients find you.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                _buildLanguagesSelector(),
                const SizedBox(height: 32),
                _buildSectionTitle("Availability"),
                const SizedBox(height: 16),
                _buildDaysSelector(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeField(
                        controller: startTimeController,
                        label: "Start Time",
                        hint: "09:00 AM",
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTimeField(
                        controller: endTimeController,
                        label: "End Time",
                        hint: "05:00 PM",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: _isLoading ? null : _submitProfile,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Save Profile",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Row(
        children: [
          // Left Panel
          Container(
            width: 450,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryColor, Color(0xFF6366F1)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CustomBackButton(color: Colors.white),
                  const Spacer(),
                  const Text(
                    "Complete Your\nProfessional Profile",
                    style: TextStyle(
                      fontSize: 38,
                      fontFamily: "Gilroy-Bold",
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Set up your professional details, clinic information, and availability to start accepting appointments from patients.",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 18,
                      height: 1.6,
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
          // Right Panel
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(80),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "DOCTOR PROFILE",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryColor,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Professional Details",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                            fontFamily: "Gilroy-Bold",
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Profile Photo Upload
                        Center(
                          child: GestureDetector(
                            onTap: _pickProfileImage,
                            child: Stack(
                              children: [
                                Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.3), width: 3),
                                  ),
                                  child: ClipOval(
                                    child: _imageBytes != null
                                        ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                                        : Icon(Icons.person_rounded, size: 50, color: AppColors.primaryColor),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text('Tap to upload profile photo', style: TextStyle(fontSize: 13, color: AppColors.primaryColor)),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: specializationController,
                                label: "Specialization",
                                icon: Icons.medical_services_outlined,
                                hint: "e.g., Cardiologist",
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildTextField(
                                controller: experienceController,
                                label: "Years of Experience",
                                icon: Icons.work_outline,
                                hint: "e.g., 5 years",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: degreesController,
                                label: "Degrees (comma separated)",
                                icon: Icons.school_outlined,
                                hint: "e.g., MBBS, MD, PhD",
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildTextField(
                                controller: licenseController,
                                label: "License Number",
                                icon: Icons.badge_outlined,
                                hint: "Medical license number",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Valid Till — full width row below license
                        _buildValidTillField(),
                        const SizedBox(height: 40),
                        const Text(
                          "Your Specialties",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select all specialties you practice. Patients will find you based on these.',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 12),
                        _buildSpecialtiesSelector(),
                        const SizedBox(height: 40),
                        const Text(
                          "Conditions You Treat",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select or add conditions you commonly treat.',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 12),
                        _buildConditionsTreated(),
                        const SizedBox(height: 40),
                        const Text(
                          "Languages You Speak",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select all languages you speak to help patients find you.',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 12),
                        _buildLanguagesSelector(),
                        const SizedBox(height: 40),
                        const Text(
                          "Availability Schedule",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildDaysSelector(),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTimeField(
                                controller: startTimeController,
                                label: "Start Time",
                                hint: "09:00 AM",
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildTimeField(
                                controller: endTimeController,
                                label: "End Time",
                                hint: "05:00 PM",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 60),
                        SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _isLoading ? null : _submitProfile,
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    "Save Professional Profile",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                      fontFamily: "Gilroy-Bold",
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildSpecialtiesSelector() {
    final filtered = _specialtySearch.isEmpty
        ? _commonSpecialties
        : _commonSpecialties
            .where((s) => s.toLowerCase().contains(_specialtySearch.toLowerCase()))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar to filter chips
        TextField(
          controller: _specialtySearchCtrl,
          decoration: InputDecoration(
            hintText: 'Search specialties...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true, fillColor: const Color(0xFFF8FAFC),
          ),
          onChanged: (v) => setState(() => _specialtySearch = v),
        ),
        const SizedBox(height: 12),
        // Filtered specialty chips
        if (filtered.isEmpty)
          Text('No matching specialties. Add a custom one below.', style: TextStyle(fontSize: 12, color: Colors.grey[500]))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filtered.map((s) {
              final isSelected = _selectedSpecialties.contains(s);
              return FilterChip(
                label: Text(s, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF475569))),
                selected: isSelected,
                onSelected: (v) => setState(() {
                  if (v) { _selectedSpecialties.add(s); } else { _selectedSpecialties.remove(s); }
                }),
                selectedColor: AppColors.primaryColor,
                backgroundColor: const Color(0xFFF1F5F9),
                checkmarkColor: Colors.white,
                side: BorderSide(color: isSelected ? AppColors.primaryColor : const Color(0xFFE2E8F0)),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              );
            }).toList(),
          ),
        const SizedBox(height: 12),
        // Add custom specialty
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _specialtyCustomCtrl,
                decoration: InputDecoration(
                  hintText: 'Add custom specialty...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true, fillColor: const Color(0xFFF8FAFC),
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty && !_selectedSpecialties.contains(v.trim())) {
                    setState(() { _selectedSpecialties.add(v.trim()); _specialtyCustomCtrl.clear(); });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_rounded, color: AppColors.primaryColor),
              onPressed: () {
                final v = _specialtyCustomCtrl.text.trim();
                if (v.isNotEmpty && !_selectedSpecialties.contains(v)) {
                  setState(() { _selectedSpecialties.add(v); _specialtyCustomCtrl.clear(); });
                }
              },
            ),
          ],
        ),
        if (_selectedSpecialties.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('${_selectedSpecialties.length} specialty(ies) selected', style: const TextStyle(fontSize: 12, color: AppColors.primaryColor, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }

  Widget _buildConditionsTreated() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Common conditions chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _commonConditions.map((c) {
            final isSelected = _conditionsTreated.contains(c);
            return FilterChip(
              label: Text(c, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF475569))),
              selected: isSelected,
              onSelected: (v) => setState(() {
                if (v) {
                  _conditionsTreated.add(c);
                } else {
                  _conditionsTreated.remove(c);
                }
              }),
              selectedColor: AppColors.primaryColor,
              backgroundColor: const Color(0xFFF1F5F9),
              checkmarkColor: Colors.white,
              side: BorderSide(color: isSelected ? AppColors.primaryColor : const Color(0xFFE2E8F0)),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Custom condition input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _conditionInputCtrl,
                decoration: InputDecoration(
                  hintText: 'Add custom condition...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true, fillColor: const Color(0xFFF8FAFC),
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty && !_conditionsTreated.contains(v.trim())) {
                    setState(() { _conditionsTreated.add(v.trim()); _conditionInputCtrl.clear(); });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_rounded, color: AppColors.primaryColor),
              onPressed: () {
                final v = _conditionInputCtrl.text.trim();
                if (v.isNotEmpty && !_conditionsTreated.contains(v)) {
                  setState(() { _conditionsTreated.add(v); _conditionInputCtrl.clear(); });
                }
              },
            ),
          ],
        ),
        if (_conditionsTreated.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('${_conditionsTreated.length} condition(s) selected', style: const TextStyle(fontSize: 12, color: AppColors.primaryColor, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }

  Widget _buildLanguagesSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _spokenLanguages.map((lang) {
        final isSelected = _selectedLanguages.contains(lang);
        return FilterChip(
          label: Text(lang, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF475569))),
          selected: isSelected,
          onSelected: (v) => setState(() {
            if (v) {
              _selectedLanguages.add(lang);
            } else {
              _selectedLanguages.remove(lang);
            }
          }),
          selectedColor: AppColors.primaryColor,
          backgroundColor: const Color(0xFFF1F5F9),
          checkmarkColor: Colors.white,
          side: BorderSide(color: isSelected ? AppColors.primaryColor : const Color(0xFFE2E8F0)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        );
      }).toList(),
    );
  }

  /// "Valid Till" date picker field for license expiry
  Widget _buildValidTillField() {
    final hasDate = _licenseValidTill != null;
    final dateStr = hasDate
        ? '${_licenseValidTill!.day.toString().padLeft(2, '0')}/'
          '${_licenseValidTill!.month.toString().padLeft(2, '0')}/'
          '${_licenseValidTill!.year}'
        : '';

    // Warn if expiry is within 30 days
    final isExpiringSoon = hasDate &&
        _licenseValidTill!.difference(DateTime.now()).inDays <= 30;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Valid Till',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickLicenseExpiry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isExpiringSoon
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFE2E8F0),
                width: isExpiringSoon ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: isExpiringSoon
                      ? const Color(0xFFF59E0B)
                      : AppColors.primaryColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasDate ? dateStr : 'Select expiry date',
                    style: TextStyle(
                      fontSize: 14,
                      color: hasDate
                          ? (isExpiringSoon
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF0F172A))
                          : const Color(0xFF94A3B8),
                      fontWeight: hasDate ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (isExpiringSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Expiring Soon',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hasDate)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Admin will be notified 30 days before expiry',
              style: TextStyle(
                fontSize: 11,
                color: isExpiringSoon
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            prefixIcon: Icon(icon, color: AppColors.primaryColor, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
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
              borderSide: const BorderSide(
                color: AppColors.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: () => _selectTime(controller),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Required';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            prefixIcon: const Icon(
              Icons.access_time,
              color: AppColors.primaryColor,
              size: 20,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
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
              borderSide: const BorderSide(
                color: AppColors.primaryColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaysSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: selectedDays.keys.map((day) {
        final isSelected = selectedDays[day]!;
        return FilterChip(
          label: Text(day.substring(0, 3)),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              selectedDays[day] = selected;
            });
          },
          selectedColor: AppColors.primaryColor,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected
                  ? AppColors.primaryColor
                  : const Color(0xFFE2E8F0),
            ),
          ),
        );
      }).toList(),
    );
  }
}
