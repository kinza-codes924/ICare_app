import 'package:flutter/material.dart';
import 'package:icare/services/instructor_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text_input.dart';

class InstructorProfileSetupScreen extends StatefulWidget {
  const InstructorProfileSetupScreen({super.key});

  @override
  State<InstructorProfileSetupScreen> createState() =>
      _InstructorProfileSetupScreenState();
}

class _InstructorProfileSetupScreenState
    extends State<InstructorProfileSetupScreen> {
  final InstructorService _instructorService = InstructorService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _qualificationController =
      TextEditingController();
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
  bool _isLoading = false;

  final List<String> _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
          _availabilityDays = List<String>.from(
            profile['availabilityDays'] ?? [],
          );

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
        });
      }
    } catch (e) {
      // Profile doesn't exist yet, that's okay
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

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
          'start':
              '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
          'end':
              '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: const Text('Something went wrong. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addSpecialty() {
    if (_specialtyController.text.isNotEmpty) {
      setState(() {
        _specialties.add(_specialtyController.text);
        _specialtyController.clear();
      });
    }
  }

  void _addLanguage() {
    if (_languageController.text.isNotEmpty) {
      setState(() {
        _languages.add(_languageController.text);
        _languageController.clear();
      });
    }
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
          'Instructor Profile Setup',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection('Basic Information', [
                CustomInputField(
                  controller: _bioController,
                  hintText: 'Bio',
                  maxLines: 3,
                  validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                CustomInputField(
                  controller: _qualificationController,
                  hintText: 'Qualification (e.g., PhD in Psychology)',
                  validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CustomInputField(
                        controller: _ageController,
                        hintText: 'Age',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedGender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          border: OutlineInputBorder(),
                        ),
                        items: ['Male', 'Female', 'Other'].map((gender) {
                          return DropdownMenuItem(
                            value: gender,
                            child: Text(gender),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedGender = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CustomInputField(
                  controller: _addressController,
                  hintText: 'Address',
                ),
                const SizedBox(height: 16),
                CustomInputField(
                  controller: _experienceController,
                  hintText: 'Years of Experience',
                ),
              ]),

              const SizedBox(height: 24),

              _buildSection('Specialties', [
                Row(
                  children: [
                    Expanded(
                      child: CustomInputField(
                        controller: _specialtyController,
                        hintText: 'Add specialty',
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addSpecialty,
                      icon: const Icon(
                        Icons.add_circle,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _specialties
                      .map(
                        (s) => Chip(
                          label: Text(s),
                          onDeleted: () =>
                              setState(() => _specialties.remove(s)),
                        ),
                      )
                      .toList(),
                ),
              ]),

              const SizedBox(height: 24),

              _buildSection('Languages', [
                Row(
                  children: [
                    Expanded(
                      child: CustomInputField(
                        controller: _languageController,
                        hintText: 'Add language',
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addLanguage,
                      icon: const Icon(
                        Icons.add_circle,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _languages
                      .map(
                        (l) => Chip(
                          label: Text(l),
                          onDeleted: () => setState(() => _languages.remove(l)),
                        ),
                      )
                      .toList(),
                ),
              ]),

              const SizedBox(height: 32),

              CustomButton(
                label: _isLoading ? 'Saving...' : 'Save Profile',
                onPressed: _isLoading ? null : _saveProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  @override
  void dispose() {
    _bioController.dispose();
    _qualificationController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _experienceController.dispose();
    _specialtyController.dispose();
    _languageController.dispose();
    super.dispose();
  }
}
