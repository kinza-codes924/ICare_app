import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:icare/services/instructor_service.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/models/user.dart';
import 'package:icare/providers/auth_provider.dart';

class InstructorProfileSetupScreen extends ConsumerStatefulWidget {
  const InstructorProfileSetupScreen({super.key});

  @override
  ConsumerState<InstructorProfileSetupScreen> createState() =>
      _InstructorProfileSetupScreenState();
}

class _InstructorProfileSetupScreenState
    extends ConsumerState<InstructorProfileSetupScreen>
    with TickerProviderStateMixin {
  final InstructorService _instructorService = InstructorService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _qualificationController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _languageController = TextEditingController();

  String _selectedGender = 'Male';
  List<String> _specialties = [];
  List<String> _languages = [];
  List<String> _availabilityDays = [];
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  bool _isLoading = true;
  bool _isSaving = false;

  Uint8List? _imageBytes;
  String? _existingProfilePictureUrl;
  final ImagePicker _picker = ImagePicker();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  static const Color _primary = Color(0xFF3949AB);
  static const Color _primaryDark = Color(0xFF1A237E);
  static const Color _accent = Color(0xFF5C6BC0);
  static const Color _bg = Color(0xFFF0F2FF);

  final List<String> _weekDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadProfile();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _bioController.dispose();
    _qualificationController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _experienceController.dispose();
    _specialtyController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 600,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (mounted) setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _instructorService.getMyProfile();
      if (mounted) {
        setState(() {
          _bioController.text = profile['bio'] ?? '';
          _qualificationController.text = profile['qualification'] ?? '';
          _ageController.text = profile['age']?.toString() ?? '';
          _addressController.text = profile['address'] ?? '';
          _experienceController.text = profile['experience'] ?? '';
          _selectedGender = profile['gender'] ?? 'Male';
          _specialties = List<String>.from(profile['specialties'] ?? []);
          _languages = List<String>.from(profile['languages'] ?? []);
          _availabilityDays = List<String>.from(profile['availabilityDays'] ?? []);
          _existingProfilePictureUrl =
              (profile['profilePicture'] ?? profile['profile_image'])?.toString();
          if (profile['availabilityTime'] != null) {
            final start = profile['availabilityTime']['start']?.split(':');
            final end = profile['availabilityTime']['end']?.split(':');
            if (start != null && start.length == 2) {
              _startTime = TimeOfDay(
                hour: int.parse(start[0]),
                minute: int.parse(start[1]),
              );
            }
            if (end != null && end.length == 2) {
              _endTime = TimeOfDay(
                hour: int.parse(end[0]),
                minute: int.parse(end[1]),
              );
            }
          }
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _animationController.forward();
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _instructorService.updateProfile({
        'bio': _bioController.text,
        'qualification': _qualificationController.text,
        'age': int.tryParse(_ageController.text),
        'gender': _selectedGender,
        'address': _addressController.text,
        'specialties': _specialties,
        'languages': _languages,
        'experience': _experienceController.text,
        'availabilityDays': _availabilityDays,
        'availabilityTime': {
          'start': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
          'end': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        },
        if (_imageBytes != null)
          'profilePicture': 'data:image/jpeg;base64,${base64Encode(_imageBytes!)}',
      });

      if (_imageBytes != null) {
        final pic = 'data:image/jpeg;base64,${base64Encode(_imageBytes!)}';
        setState(() => _existingProfilePictureUrl = pic);
        // Patch auth state immediately so dashboard avatar updates right now
        ref.read(authProvider.notifier).patchPicture(pic);
      }

      // Also refresh other fields (name etc.) from backend
      try {
        final resp = await ApiService().get('/users/profile');
        if (resp.data != null && mounted) {
          final fetched = User.fromJson(resp.data);
          // If backend returned no picture but we have one locally, keep local
          final localPic = _existingProfilePictureUrl;
          if (fetched.profilePicture == null && localPic != null) {
            ref.read(authProvider.notifier).patchPicture(localPic);
          } else {
            await ref.read(authProvider.notifier).setUser(fetched);
          }
        }
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addSpecialty() {
    if (_specialtyController.text.trim().isNotEmpty) {
      setState(() {
        _specialties.add(_specialtyController.text.trim());
        _specialtyController.clear();
      });
    }
  }

  void _addLanguage() {
    if (_languageController.text.trim().isNotEmpty) {
      setState(() {
        _languages.add(_languageController.text.trim());
        _languageController.clear();
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(context: context, initialTime: _endTime);
    if (picked != null) setState(() => _endTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primaryDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Instructor Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: _primaryDark,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isDesktop ? 40 : 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isDesktop ? 900 : double.infinity),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildSection(
                            'Basic Information',
                            Icons.person_outline_rounded,
                            [
                              _buildTextField(
                                controller: _bioController,
                                label: 'Professional Bio',
                                icon: Icons.notes_rounded,
                                hint: 'Tell students about yourself...',
                                maxLines: 3,
                                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                controller: _qualificationController,
                                label: 'Qualification',
                                icon: Icons.history_edu_rounded,
                                hint: 'e.g. PhD in Psychology',
                                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                controller: _experienceController,
                                label: 'Years of Experience',
                                icon: Icons.workspace_premium_outlined,
                                hint: 'e.g. 5',
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _buildTextField(
                                      controller: _ageController,
                                      label: 'Age',
                                      icon: Icons.cake_outlined,
                                      hint: '30',
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedGender,
                                      decoration: InputDecoration(
                                        labelText: 'Gender',
                                        prefixIcon: const Icon(Icons.people_outline_rounded, color: _accent),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: _accent, width: 2),
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFF),
                                      ),
                                      items: ['Male', 'Female', 'Other']
                                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                          .toList(),
                                      onChanged: (v) => setState(() => _selectedGender = v!),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                controller: _addressController,
                                label: 'Address',
                                icon: Icons.map_outlined,
                                hint: 'City, Country',
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildSection(
                            'Specialties',
                            Icons.psychology_outlined,
                            [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _specialtyController,
                                      label: 'Add specialty',
                                      icon: Icons.add_circle_outline,
                                      hint: 'e.g. Mental Health',
                                      onSubmitted: (_) => _addSpecialty(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _addButton(_addSpecialty),
                                ],
                              ),
                              if (_specialties.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _specialties
                                      .map((s) => _chip(s, () => setState(() => _specialties.remove(s))))
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildSection(
                            'Languages',
                            Icons.language_outlined,
                            [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _languageController,
                                      label: 'Add language',
                                      icon: Icons.translate_outlined,
                                      hint: 'e.g. English',
                                      onSubmitted: (_) => _addLanguage(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _addButton(_addLanguage),
                                ],
                              ),
                              if (_languages.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _languages
                                      .map((l) => _chip(l, () => setState(() => _languages.remove(l))))
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildSection(
                            'Availability',
                            Icons.schedule_outlined,
                            [
                              const Text(
                                'Available Days',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _weekDays.map((day) {
                                  final selected = _availabilityDays.contains(day);
                                  return GestureDetector(
                                    onTap: () => setState(() {
                                      if (selected) _availabilityDays.remove(day);
                                      else _availabilityDays.add(day);
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: selected ? _primary : Colors.white,
                                        border: Border.all(
                                          color: selected ? _primary : const Color(0xFFE2E8F0),
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        day.substring(0, 3),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: selected ? Colors.white : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Available Hours',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: _timeButton('From', _startTime, _pickStartTime)),
                                  const SizedBox(width: 14),
                                  Expanded(child: _timeButton('To', _endTime, _pickEndTime)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          _buildSaveButton(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryDark, Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryDark.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickProfileImage,
            child: Stack(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _imageBytes != null
                        ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                        : _existingProfilePictureUrl != null
                            ? Image.network(
                                _existingProfilePictureUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.school_rounded,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.school_rounded, size: 40, color: Colors.white),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Color(0xFF5C6BC0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Instructor Profile',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Set up your profile so students can learn more about you',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Tap photo to change',
                    style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EAF6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _primary, size: 22),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _accent),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accent, width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
    );
  }

  Widget _addButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _primary,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 15, color: _accent),
          ),
        ],
      ),
    );
  }

  Widget _timeButton(String label, TimeOfDay time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded, color: _accent, size: 18),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                Text(
                  time.format(context),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_primaryDark, _primary]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _primaryDark.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 12),
                    Text(
                      'Save Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
