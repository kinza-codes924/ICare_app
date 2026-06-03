import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/models/user.dart' as app_user;
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/services/user_service.dart';
import 'package:icare/services/doctor_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart' show buildProfileImageProvider;
import 'package:icare/widgets/custom_text_input.dart';
import 'package:image_picker/image_picker.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController cnicController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController bloodGroupController = TextEditingController();

  // Height state
  String _heightUnit = 'cm';
  String? _heightCm;
  String? _heightM;
  int _heightFt = 5;
  int _heightIn = 7;

  // Weight state
  String _weightUnit = 'kg';
  String? _weightKg;
  String? _weightLbs;

  // Doctor-specific fields
  String? _selectedSpecialization;
  final Set<String> _selectedDoctorConditions = {};

  static const _specializations = [
    'Cardiologist','Dermatologist','Neurologist','Orthopedic','Gynecologist',
    'Pediatrician','Psychiatrist','Ophthalmologist','ENT Specialist','Urologist',
    'Gastroenterologist','Endocrinologist','Pulmonologist','Oncologist','Nephrologist',
    'Rheumatologist','Diabetologist','General Physician','Dentist','Nutritionist',
  ];

  static const _doctorConditions = [
    'Diabetes','Hypertension','Fever','Heart Disease','Asthma','Back Pain',
    'Arthritis','Anxiety','Depression','Migraine','Obesity','Thyroid',
    'Kidney Disease','Liver Disease','Cancer','Skin Problem','Eye Problem',
    'Ear Infection','Stomach Pain','Chest Pain','Shortness of Breath',
    'Joint Pain','Allergies','Insomnia','PCOS','Hepatitis','Dengue',
    'Typhoid','Anemia','Vitamin Deficiency',
  ];

  // Patient Conditions & Goals
  final Set<String> _selectedConditions = {};
  final Set<String> _selectedGoals = {};

  static const _conditions = [
    'Hypertension / BP',
    'Diabetes',
    'Heart Disease (IHD)',
    'Asthma',
    'Thyroid Disease',
    'Kidney Disease',
    'Arthritis',
    'Obesity',
  ];
  static const _goals = [
    'Weight Loss',
    'BP Control',
    'Blood Sugar Control',
    'Improve Fitness',
    'Quit Smoking',
    'Mental Wellness',
    'Healthy Diet',
    'Better Sleep',
  ];

  // Emergency contacts — minimum 2, can add more
  final List<Map<String, TextEditingController>> _emergencyContacts = [
    {'name': TextEditingController(), 'relation': TextEditingController(), 'phone': TextEditingController()},
    {'name': TextEditingController(), 'relation': TextEditingController(), 'phone': TextEditingController()},
  ];
  final UserService _userService = UserService();
  final DoctorService _doctorService = DoctorService();
  bool isLoading = false;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  String? _selectedGender; // 'Male', 'Female', 'Other'

  Future<void> _pickImage() async {
    // On web, camera is not supported — go straight to gallery
    if (kIsWeb) {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 600,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() => _imageBytes = bytes);
      }
      return;
    }

    // Mobile: offer gallery or camera
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('Gallery'.tr()),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                  maxWidth: 600,
                );
                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  setState(() => _imageBytes = bytes);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text('Camera'.tr()),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                  maxWidth: 600,
                );
                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  setState(() => _imageBytes = bytes);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      nameController.text = user.name;
      phoneController.text = user.phoneNumber;
      ageController.text = user.age ?? '';
      cnicController.text = user.cnic ?? '';
      final g = user.gender?.trim() ?? '';
      if (g.toLowerCase() == 'male') {
        _selectedGender = 'Male';
      } else if (g.toLowerCase() == 'female') {
        _selectedGender = 'Female';
      } else if (g.isNotEmpty) {
        _selectedGender = 'Other';
      }
    }
    final role = ref.read(authProvider).userRole ?? '';
    if (role != 'Patient') _loadDoctorProfile();
  }

  Future<void> _loadDoctorProfile() async {
    final result = await _doctorService.getMyDoctorProfile();
    if (!mounted) return;
    if (result['success'] == true && result['doctor'] != null) {
      final doc = result['doctor'] as Map<String, dynamic>;
      setState(() {
        final spec = doc['specialization']?.toString();
        if (spec != null && spec.isNotEmpty) _selectedSpecialization = spec;
        final conds = doc['conditionsTreated'];
        if (conds is List) {
          _selectedDoctorConditions.addAll(conds.map((c) => c.toString()));
        }
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    cnicController.dispose();
    ageController.dispose();
    addressController.dispose();
    bloodGroupController.dispose();
    for (final c in _emergencyContacts) {
      c['name']!.dispose();
      c['relation']!.dispose();
      c['phone']!.dispose();
    }
    super.dispose();
  }

  void _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final role = ref.read(authProvider).userRole ?? '';
      final isDoctor = role != 'Patient';

      // For doctors: save specialization + conditions to doctor profile
      if (isDoctor && _selectedSpecialization != null && _selectedSpecialization!.isNotEmpty) {
        await _doctorService.updateDoctorSpecialization(
          specialization: _selectedSpecialization!,
          conditionsTreated: _selectedDoctorConditions.toList(),
        );
      }

      // Build height string
      String? heightStr;
      if (_heightUnit == 'cm' && _heightCm != null) {
        heightStr = '$_heightCm cm';
      } else if (_heightUnit == 'm' && _heightM != null) {
        heightStr = '$_heightM m';
      } else if (_heightUnit == 'ft') {
        heightStr = "$_heightFt'$_heightIn\"";
      }

      // Build weight string
      String? weightStr;
      if (_weightUnit == 'kg' && _weightKg != null) {
        weightStr = '$_weightKg kg';
      } else if (_weightUnit == 'lbs' && _weightLbs != null) {
        weightStr = '$_weightLbs lbs';
      }

      final ecList = _emergencyContacts
          .where((c) => c['name']!.text.trim().isNotEmpty || c['phone']!.text.trim().isNotEmpty)
          .map((c) => {
                'name': c['name']!.text.trim(),
                'relationship': c['relation']!.text.trim(),
                'phone': c['phone']!.text.trim(),
              })
          .toList();

      final result = await _userService.updateProfile(
        name: nameController.text.trim(),
        phoneNumber: phoneController.text.trim(),
        cnic: cnicController.text.trim().isEmpty ? null : cnicController.text.trim(),
        age: ageController.text.trim().isEmpty ? null : ageController.text.trim(),
        gender: _selectedGender,
        height: heightStr,
        weight: weightStr,
        address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
        profileImage: _imageBytes,
        existingConditions: _selectedConditions.isEmpty ? null : _selectedConditions.join(', '),
        healthGoals: _selectedGoals.isEmpty ? null : _selectedGoals.join(', '),
        emergencyContacts: ecList.isEmpty ? null : ecList,
      );

      if (result['success']) {
        final userData = result['user'];
        final user = app_user.User.fromJson(userData);
        ref.read(authProvider.notifier).setUser(user);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        _showError(result['message']);
      }
    } catch (e) {
      _showError('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final role = ref.read(authProvider).userRole ?? '';
    final isPatient = role == 'Patient';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile'.tr(),
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // Profile Picture with upload
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryColor.withValues(alpha: 0.1),
                          border: Border.all(
                            color: AppColors.primaryColor.withValues(alpha: 0.2),
                            width: 3,
                          ),
                        ),
                        child: ClipOval(
                          child: _imageBytes != null
                              ? Image.memory(
                                  _imageBytes!,
                                  fit: BoxFit.cover,
                                  width: 120,
                                  height: 120,
                                )
                              : buildProfileImageProvider(user?.profilePicture) != null
                              ? Image(
                                  image: buildProfileImageProvider(user!.profilePicture!)!,
                                  fit: BoxFit.cover,
                                  width: 120,
                                  height: 120,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text(
                                        user.name.substring(0, 1).toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primaryColor,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Center(
                                  child: Text(
                                    user?.name.substring(0, 1).toUpperCase() ?? 'U',
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryColor,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to upload photo',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),

                // Form
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 20),
                        CustomInputField(
                          hintText: 'Full Name'.tr(),
                          leadingIcon: const Icon(
                            Icons.person_outline,
                            color: Color(0xFF94A3B8),
                          ),
                          controller: nameController,
                          bgColor: const Color(0xFFF8FAFC),
                          borderRadius: 14,
                          borderColor: const Color(0xFFE2E8F0),
                          borderWidth: 1.5,
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomInputField(
                          hintText: 'Phone Number'.tr(),
                          leadingIcon: const Icon(
                            Icons.phone_outlined,
                            color: Color(0xFF94A3B8),
                          ),
                          controller: phoneController,
                          bgColor: const Color(0xFFF8FAFC),
                          borderRadius: 14,
                          borderColor: const Color(0xFFE2E8F0),
                          borderWidth: 1.5,
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please enter your phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Email (read-only)
                        CustomInputField(
                          hintText: user?.email ?? '',
                          leadingIcon: const Icon(
                            Icons.email_outlined,
                            color: Color(0xFF94A3B8),
                          ),
                          controller: TextEditingController(text: user?.email),
                          bgColor: const Color(0xFFF1F5F9),
                          borderRadius: 14,
                          borderColor: const Color(0xFFE2E8F0),
                          borderWidth: 1.5,
                          enabled: false,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Email cannot be changed',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        if (!isPatient) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Doctor Profile',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 16),
                          _buildSectionLabel('Specialization', Icons.medical_services_outlined),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedSpecialization,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: 'Select your specialization'.tr(),
                              prefixIcon: const Icon(Icons.local_hospital_outlined, color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            ),
                            items: _specializations.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setState(() => _selectedSpecialization = v),
                          ),
                          const SizedBox(height: 16),
                          _buildSectionLabel('Conditions Treated', Icons.healing_outlined),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _doctorConditions.map((c) {
                              final sel = _selectedDoctorConditions.contains(c);
                              return GestureDetector(
                                onTap: () => setState(() {
                                  if (sel) _selectedDoctorConditions.remove(c);
                                  else _selectedDoctorConditions.add(c);
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: sel ? AppColors.primaryColor : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: sel ? AppColors.primaryColor : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(c, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : const Color(0xFF475569))),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        if (isPatient) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: cnicController,
                            maxLength: 13,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'ID Card Number (13 digits)',
                              prefixIcon: const Icon(Icons.credit_card_outlined, color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Health Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Gender selector
                          const Text(
                            'Gender',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: ['Male', 'Female', 'Other'].map((g) {
                              final isSelected = _selectedGender == g;
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedGender = g),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primaryColor
                                          : const Color(0xFFF1F5F9),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primaryColor
                                            : const Color(0xFFE2E8F0),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          g == 'Male'
                                              ? Icons.male_rounded
                                              : g == 'Female'
                                                  ? Icons.female_rounded
                                                  : Icons.transgender_rounded,
                                          size: 16,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          g,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          // Age
                          CustomInputField(
                            hintText: 'Age'.tr(),
                            leadingIcon: const Icon(Icons.cake_outlined, color: Color(0xFF94A3B8)),
                            controller: ageController,
                            bgColor: const Color(0xFFF8FAFC),
                            borderRadius: 14,
                            borderColor: const Color(0xFFE2E8F0),
                            borderWidth: 1.5,
                          ),
                          const SizedBox(height: 16),
                          // Height unit selector + dropdown
                          _buildSectionLabel('Height', Icons.height_rounded),
                          const SizedBox(height: 8),
                          _buildUnitSelector(
                            options: const ['cm', 'm', 'ft'],
                            selected: _heightUnit,
                            onChanged: (u) => setState(() => _heightUnit = u),
                          ),
                          const SizedBox(height: 8),
                          if (_heightUnit == 'cm')
                            _buildDropdown<String>(
                              value: _heightCm,
                              hint: 'Select cm',
                              items: List.generate(71, (i) => '${140 + i}'),
                              onChanged: (v) => setState(() => _heightCm = v),
                              label: (v) => '$v cm',
                            )
                          else if (_heightUnit == 'm')
                            _buildDropdown<String>(
                              value: _heightM,
                              hint: 'Select meters',
                              items: List.generate(71, (i) => (1.40 + i * 0.01).toStringAsFixed(2)),
                              onChanged: (v) => setState(() => _heightM = v),
                              label: (v) => '$v m',
                            )
                          else
                            Row(children: [
                              Expanded(child: _buildDropdown<int>(
                                value: _heightFt,
                                hint: 'ft',
                                items: List.generate(5, (i) => 4 + i),
                                onChanged: (v) => setState(() => _heightFt = v!),
                                label: (v) => "$v ft",
                              )),
                              const SizedBox(width: 8),
                              Expanded(child: _buildDropdown<int>(
                                value: _heightIn,
                                hint: 'in',
                                items: List.generate(12, (i) => i),
                                onChanged: (v) => setState(() => _heightIn = v!),
                                label: (v) => "$v in",
                              )),
                            ]),
                          const SizedBox(height: 16),
                          // Weight unit selector + dropdown
                          _buildSectionLabel('Weight', Icons.monitor_weight_outlined),
                          const SizedBox(height: 8),
                          _buildUnitSelector(
                            options: const ['kg', 'lbs'],
                            selected: _weightUnit,
                            onChanged: (u) => setState(() => _weightUnit = u),
                          ),
                          const SizedBox(height: 8),
                          if (_weightUnit == 'kg')
                            _buildDropdown<String>(
                              value: _weightKg,
                              hint: 'Select kg',
                              items: List.generate(171, (i) => '${30 + i}'),
                              onChanged: (v) => setState(() => _weightKg = v),
                              label: (v) => '$v kg',
                            )
                          else
                            _buildDropdown<String>(
                              value: _weightLbs,
                              hint: 'Select lbs',
                              items: List.generate(186, (i) => '${66 + i * 2}'),
                              onChanged: (v) => setState(() => _weightLbs = v),
                              label: (v) => '$v lbs',
                            ),
                          const SizedBox(height: 16),
                          CustomInputField(
                            hintText: 'Address',
                            leadingIcon: const Icon(
                              Icons.location_on_outlined,
                              color: Color(0xFF94A3B8),
                            ),
                            controller: addressController,
                            bgColor: const Color(0xFFF8FAFC),
                            borderRadius: 14,
                            borderColor: const Color(0xFFE2E8F0),
                            borderWidth: 1.5,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Health Profile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Blood Group
                          DropdownButtonFormField<String>(
                            initialValue: bloodGroupController.text.isEmpty ? null : bloodGroupController.text,
                            decoration: InputDecoration(
                              labelText: 'Blood Group',
                              prefixIcon: const Icon(Icons.bloodtype_outlined, color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                              ),
                            ),
                            items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                .toList(),
                            onChanged: (v) => bloodGroupController.text = v ?? '',
                          ),
                          const SizedBox(height: 16),
                          // Emergency Contacts
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Emergency Contacts',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _emergencyContacts.add({
                                      'name': TextEditingController(),
                                      'relation': TextEditingController(),
                                      'phone': TextEditingController(),
                                    });
                                  });
                                },
                                icon: const Icon(Icons.add_circle_outline_rounded,
                                    size: 18, color: AppColors.primaryColor),
                                label: const Text('Add',
                                    style: TextStyle(
                                        color: AppColors.primaryColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(_emergencyContacts.length, (i) {
                            final contact = _emergencyContacts[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7F7),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFFFFE4E4), width: 1.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Emergency Contact ${i + 1}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFEF4444),
                                          ),
                                        ),
                                        if (i >= 2)
                                          GestureDetector(
                                            onTap: () => setState(
                                                () => _emergencyContacts.removeAt(i)),
                                            child: const Icon(
                                                Icons.remove_circle_outline_rounded,
                                                size: 18,
                                                color: Color(0xFFEF4444)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    CustomInputField(
                                      hintText: 'Contact Name',
                                      leadingIcon: const Icon(
                                          Icons.person_outline,
                                          color: Color(0xFF94A3B8)),
                                      controller: contact['name']!,
                                      bgColor: Colors.white,
                                      borderRadius: 10,
                                      borderColor: const Color(0xFFE2E8F0),
                                      borderWidth: 1.5,
                                    ),
                                    const SizedBox(height: 10),
                                    CustomInputField(
                                      hintText: 'Relationship (e.g. Father, Spouse)',
                                      leadingIcon: const Icon(
                                          Icons.family_restroom_rounded,
                                          color: Color(0xFF94A3B8)),
                                      controller: contact['relation']!,
                                      bgColor: Colors.white,
                                      borderRadius: 10,
                                      borderColor: const Color(0xFFE2E8F0),
                                      borderWidth: 1.5,
                                    ),
                                    const SizedBox(height: 10),
                                    CustomInputField(
                                      hintText: 'Phone Number'.tr(),
                                      leadingIcon: const Icon(
                                          Icons.phone_outlined,
                                          color: Color(0xFF94A3B8)),
                                      controller: contact['phone']!,
                                      bgColor: Colors.white,
                                      borderRadius: 10,
                                      borderColor: const Color(0xFFE2E8F0),
                                      borderWidth: 1.5,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                          _buildSectionLabel('Existing Conditions', Icons.medical_information_outlined),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _conditions.map((c) {
                              final sel = _selectedConditions.contains(c);
                              return GestureDetector(
                                onTap: () => setState(() {
                                  if (sel) {
                                    _selectedConditions.remove(c);
                                  } else {
                                    _selectedConditions.add(c);
                                  }
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: sel ? AppColors.primaryColor : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: sel ? AppColors.primaryColor : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(c, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : const Color(0xFF475569))),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          _buildSectionLabel('Health Goals', Icons.flag_outlined),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _goals.map((g) {
                              final sel = _selectedGoals.contains(g);
                              return GestureDetector(
                                onTap: () => setState(() {
                                  if (sel) {
                                    _selectedGoals.remove(g);
                                  } else {
                                    _selectedGoals.add(g);
                                  }
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: sel ? AppColors.primaryColor : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: sel ? AppColors.primaryColor : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(g, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : const Color(0xFF475569))),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 32),
                        // Update Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: isLoading ? null : _handleUpdate,
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Update Profile'.tr(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
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

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildUnitSelector({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      children: options.map((o) {
        final isSel = o == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onChanged(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? AppColors.primaryColor : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSel ? AppColors.primaryColor : const Color(0xFFE2E8F0)),
              ),
              child: Text(o, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isSel ? Colors.white : const Color(0xFF475569))),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String Function(T) label,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: items.map((i) => DropdownMenuItem<T>(value: i, child: Text(label(i)))).toList(),
      onChanged: onChanged,
    );
  }
}
