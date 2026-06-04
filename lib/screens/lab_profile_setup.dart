import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
// ignore: avoid_web_libraries_in_flutter
import '../utils/html_stub.dart' as html
    if (dart.library.html) 'dart:html';
import '../services/laboratory_service.dart';
import 'tabs.dart';
import '../widgets/back_button.dart';

class LabProfileSetup extends StatefulWidget {
  const LabProfileSetup({super.key});

  @override
  State<LabProfileSetup> createState() => _LabProfileSetupState();
}

class _LabProfileSetupState extends State<LabProfileSetup>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final LaboratoryService _labService = LaboratoryService();

  bool _isLoading = true;
  bool _isSaving = false;

  final _labNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _accreditationController = TextEditingController();
  final _labEmailController = TextEditingController();
  final _labPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _workingHoursFromController = TextEditingController();
  final _workingHoursToController = TextEditingController();

  bool _homeSampleAvailable = false;
  bool _drapCompliance = false;
  double? _latitude;
  double? _longitude;
  bool _gettingLocation = false;

  // Profile Image
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  // Doctors Panel
  final List<Map<String, TextEditingController>> _doctors = [];
  // Sample Collectors Panel
  final List<Map<String, TextEditingController>> _collectors = [];
  // Compliance Documents
  final List<Map<String, String>> _documents = []; // [{type, name}]
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Premium Theme Colors
  static const Color primaryColor = Color(0xFF0B2D6E);
  static const Color secondaryColor = Color(0xFF1565C0);
  static const Color accentColor = Color(0xFF0EA5E9);
  static const Color backgroundColor = Color(0xFFF8FAFC);

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
    _labNameController.dispose();
    _ownerNameController.dispose();
    _licenseNumberController.dispose();
    _accreditationController.dispose();
    _labEmailController.dispose();
    _labPhoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _workingHoursFromController.dispose();
    _workingHoursToController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _labService.getProfile();
      // Load doctors
      final doctorsList = (profile['doctors'] as List<dynamic>? ?? []);
      final loadedDoctors = doctorsList.map((d) => {
        'name': TextEditingController(text: d['name']?.toString() ?? ''),
        'education': TextEditingController(text: d['education']?.toString() ?? ''),
        'designation': TextEditingController(text: d['designation']?.toString() ?? ''),
      }).toList();
      // Load collectors
      final collectorsList = (profile['collectors'] as List<dynamic>? ?? []);
      final loadedCollectors = collectorsList.map((c) => {
        'name': TextEditingController(text: c['name']?.toString() ?? ''),
        'designation': TextEditingController(text: c['designation']?.toString() ?? ''),
      }).toList();
      setState(() {
        _labNameController.text = profile['labName'] ?? profile['lab_name'] ?? '';
        _ownerNameController.text = profile['ownerName'] ?? '';
        _licenseNumberController.text = profile['licenseNumber'] ?? profile['license_number'] ?? '';
        _accreditationController.text = profile['accreditation'] ?? '';
        _labEmailController.text = profile['labEmail'] ?? '';
        _labPhoneController.text = profile['labPhoneNumber'] ?? '';
        _addressController.text = profile['address'] ?? '';
        _cityController.text = profile['city'] ?? '';
        _titleController.text = profile['title'] ?? '';
        _descriptionController.text = profile['description'] ?? '';
        _workingHoursFromController.text =
            profile['workingHours']?['from'] ?? '';
        _workingHoursToController.text = profile['workingHours']?['to'] ?? '';
        _homeSampleAvailable = profile['homeSampleAvailable'] ?? false;
        _latitude = (profile['latitude'] as num?)?.toDouble();
        _longitude = (profile['longitude'] as num?)?.toDouble();
        _doctors.clear();
        _doctors.addAll(loadedDoctors);
        _collectors.clear();
        _collectors.addAll(loadedCollectors);
        _documents.clear();
        final docsList = (profile['documents'] as List<dynamic>? ?? []);
        _documents.addAll(docsList.map((d) => {
          'type': d['type']?.toString() ?? '',
          'name': d['name']?.toString() ?? '',
        }));
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to load data. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _getGpsLocation() async {
    if (!kIsWeb) return;
    setState(() => _gettingLocation = true);
    try {
      final pos = await html.window.navigator.geolocation
          .getCurrentPosition()
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        setState(() {
          _latitude = pos.coords?.latitude?.toDouble();
          _longitude = pos.coords?.longitude?.toDouble();
          _gettingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location captured successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _gettingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get location. Please allow location access.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await _labService.updateProfile({
        'labName': _labNameController.text,
        'ownerName': _ownerNameController.text,
        'licenseNumber': _licenseNumberController.text,
        'accreditation': _accreditationController.text,
        'labEmail': _labEmailController.text,
        'labPhoneNumber': _labPhoneController.text,
        'address': _addressController.text,
        'city': _cityController.text,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'workingHours': {
          'from': _workingHoursFromController.text,
          'to': _workingHoursToController.text,
        },
        'homeSampleAvailable': _homeSampleAvailable,
        if (_latitude != null) 'latitude': _latitude,
        if (_longitude != null) 'longitude': _longitude,
        'doctors': _doctors.map((d) => {
          'name': d['name']!.text.trim(),
          'education': d['education']!.text.trim(),
          'designation': d['designation']!.text.trim(),
        }).toList(),
        'collectors': _collectors.map((c) => {
          'name': c['name']!.text.trim(),
          'designation': c['designation']!.text.trim(),
        }).toList(),
        'documents': _documents,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (ctx) => const TabsScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Something went wrong. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 600);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          'Laboratory Profile',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Gilroy-Bold',
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 40 : 20),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 1000 : double.infinity,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 24),
                          _buildSection(
                            'Basic Information',
                            Icons.business_rounded,
                            [
                              _buildTextField(
                                controller: _labNameController,
                                label: 'Laboratory Name',
                                icon: Icons.business_rounded,
                                hint: 'e.g., City Medical Laboratory',
                                validator: (v) => v?.isEmpty ?? true
                                    ? 'Laboratory name is required'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _ownerNameController,
                                label: 'Owner Name',
                                icon: Icons.person_rounded,
                                hint: 'e.g., Dr. Ahmed Khan',
                                validator: (v) => v?.isEmpty ?? true
                                    ? 'Owner name is required'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _licenseNumberController,
                                label: 'License Number',
                                icon: Icons.badge_rounded,
                                hint: 'e.g., LAB-2024-PKR-12345',
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _accreditationController,
                                label: 'Accreditation',
                                icon: Icons.verified_rounded,
                                hint: 'e.g., ISO 15189, DRAP Approved',
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildSection(
                            'Contact Information',
                            Icons.contact_phone_rounded,
                            [
                              _buildTextField(
                                controller: _labEmailController,
                                label: 'Laboratory Email',
                                icon: Icons.email_rounded,
                                hint: 'info@yourlab.com',
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _labPhoneController,
                                label: 'Laboratory Phone',
                                icon: Icons.phone_rounded,
                                hint: '+92-300-1234567',
                                keyboardType: TextInputType.phone,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildSection(
                            'Location Details',
                            Icons.location_on_rounded,
                            [
                              _buildTextField(
                                controller: _addressController,
                                label: 'Address',
                                icon: Icons.home_rounded,
                                hint: '123 Medical Plaza, Main Boulevard',
                                maxLines: 2,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _cityController,
                                label: 'City',
                                icon: Icons.location_city_rounded,
                                hint: 'Lahore',
                              ),
                              const SizedBox(height: 16),
                              // GPS Location Button
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _gettingLocation ? null : _getGpsLocation,
                                  icon: _gettingLocation
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Icon(
                                          _latitude != null ? Icons.my_location_rounded : Icons.location_searching_rounded,
                                          color: _latitude != null ? const Color(0xFF10B981) : const Color(0xFF1565C0),
                                        ),
                                  label: Text(
                                    _latitude != null
                                        ? '✓ Location saved (${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)})'
                                        : 'Use My Current Location',
                                    style: TextStyle(
                                      color: _latitude != null ? const Color(0xFF10B981) : const Color(0xFF1565C0),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: _latitude != null ? const Color(0xFF10B981) : const Color(0xFF1565C0),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildSection(
                            'About Laboratory',
                            Icons.description_rounded,
                            [
                              _buildTextField(
                                controller: _titleController,
                                label: 'Title/Tagline',
                                icon: Icons.title_rounded,
                                hint: 'Your Trusted Healthcare Partner',
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _descriptionController,
                                label: 'Description',
                                icon: Icons.notes_rounded,
                                hint:
                                    'Tell patients about your laboratory, services, and expertise...',
                                maxLines: 4,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildDoctorsPanel(),
                          const SizedBox(height: 20),
                          _buildCollectorsPanel(),
                          const SizedBox(height: 20),
                          _buildDocumentsPanel(),
                          const SizedBox(height: 20),
                          _buildSection(
                            'Working Hours',
                            Icons.access_time_rounded,
                            [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _workingHoursFromController,
                                      label: 'Opening Time',
                                      icon: Icons.wb_sunny_rounded,
                                      hint: '08:00 AM',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _workingHoursToController,
                                      label: 'Closing Time',
                                      icon: Icons.nightlight_round,
                                      hint: '10:00 PM',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildWorkingDaysSelector(),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildServicesSection(),
                          const SizedBox(height: 20),
                          _buildDrapSection(),
                          const SizedBox(height: 32),
                          _buildSaveButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor),
          SizedBox(height: 16),
          Text(
            'Loading profile...',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
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
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _imageBytes != null
                        ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                        : const Icon(Icons.science_rounded, size: 40, color: Colors.white),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor, width: 1.5),
                    ),
                    child: Icon(Icons.camera_alt, size: 14, color: primaryColor),
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
                  'Laboratory Profile Setup',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the logo to upload your lab photo',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
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
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryColor),
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
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
    );
  }

  Widget _buildServicesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryColor, secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Services Offered',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () {
              setState(() => _homeSampleAvailable = !_homeSampleAvailable);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _homeSampleAvailable
                    ? primaryColor.withValues(alpha: 0.1)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _homeSampleAvailable
                      ? primaryColor
                      : const Color(0xFFE2E8F0),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _homeSampleAvailable
                          ? primaryColor
                          : const Color(0xFF64748B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.home_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Home Sample Collection',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Offer sample collection at patient\'s home',
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(
                              0xFF64748B,
                            ).withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _homeSampleAvailable
                          ? primaryColor
                          : Colors.transparent,
                      border: Border.all(
                        color: _homeSampleAvailable
                            ? primaryColor
                            : const Color(0xFF64748B),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: _homeSampleAvailable
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  final List<String> _workingDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  Widget _buildWorkingDaysSelector() {
    final allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: allDays.map((day) {
        final isSelected = _workingDays.contains(day);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _workingDays.remove(day);
              } else {
                _workingDays.add(day);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? primaryColor : const Color(0xFFE2E8F0)),
            ),
            child: Text(day, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : const Color(0xFF64748B))),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDoctorsPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.people_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Doctors Panel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              const Spacer(),
              if (_doctors.length < 6)
                TextButton.icon(
                  onPressed: () => setState(() => _doctors.add({
                    'name': TextEditingController(),
                    'education': TextEditingController(),
                    'designation': TextEditingController(),
                  })),
                  icon: const Icon(Icons.add_circle_rounded, size: 18),
                  label: const Text('Add Doctor'),
                  style: TextButton.styleFrom(foregroundColor: primaryColor),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('These doctors appear on every lab report as "Verified by". Max 6 doctors.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(height: 16),
          if (_doctors.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_rounded, color: Color(0xFFCBD5E1), size: 24),
                  SizedBox(width: 8),
                  Text('No doctors added yet. Tap "Add Doctor" to begin.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                ],
              ),
            )
          else
            ...List.generate(_doctors.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('Doctor ${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20), onPressed: () => setState(() => _doctors.removeAt(i)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: _doctors[i]['name'], decoration: _inputDec('Full Name', Icons.person_rounded)),
                    const SizedBox(height: 8),
                    TextField(controller: _doctors[i]['education'], decoration: _inputDec('Education (e.g. MBBS, FCPS)', Icons.school_rounded)),
                    const SizedBox(height: 8),
                    TextField(controller: _doctors[i]['designation'], decoration: _inputDec('Designation (e.g. Associate Professor)', Icons.work_rounded)),
                  ],
                ),
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildCollectorsPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.science_rounded, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Sample Collectors Panel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _collectors.add({
                  'name': TextEditingController(),
                  'designation': TextEditingController(),
                })),
                icon: const Icon(Icons.add_circle_rounded, size: 18),
                label: const Text('Add Collector'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF10B981)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('These staff members appear as "Sample Collected By" on lab reports.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(height: 16),
          if (_collectors.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_rounded, color: Color(0xFFCBD5E1), size: 24),
                  SizedBox(width: 8),
                  Text('No collectors added yet.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                ],
              ),
            )
          else
            ...List.generate(_collectors.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('Collector ${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20), onPressed: () => setState(() => _collectors.removeAt(i)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: _collectors[i]['name'], decoration: _inputDec('Full Name', Icons.person_rounded)),
                    const SizedBox(height: 8),
                    TextField(controller: _collectors[i]['designation'], decoration: _inputDec('Designation (e.g. Lab Technician)', Icons.work_rounded)),
                  ],
                ),
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildDocumentsPanel() {
    const docTypes = ['Registration Certificate', 'License Document', 'Compliance Certificate', 'DRAP Certificate', 'Other'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.folder_special_rounded, color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Compliance Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                    allowMultiple: true,
                  );
                  if (result != null) {
                    setState(() {
                      for (final f in result.files) {
                        _documents.add({'type': 'Other', 'name': f.name});
                      }
                    });
                  }
                },
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Upload'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFF59E0B)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Upload Registration Certificate, License, and Compliance Documents.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(height: 16),
          if (_documents.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload_file_rounded, color: Color(0xFFCBD5E1), size: 24),
                  SizedBox(width: 8),
                  Text('No documents uploaded yet.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                ],
              ),
            )
          else
            ...List.generate(_documents.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_rounded, color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: docTypes.contains(_documents[i]['type']) ? _documents[i]['type'] : 'Other',
                              isDense: true,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                              items: docTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (v) => setState(() => _documents[i] = {..._documents[i], 'type': v!}),
                            ),
                          ),
                          Text(_documents[i]['name'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                      onPressed: () => setState(() => _documents.removeAt(i)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            )),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: primaryColor),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
    );
  }

  Widget _buildDrapSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _drapCompliance ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
      ),
      child: CheckboxListTile(
        title: const Text(
          'DRAP Compliance Agreement',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: const Text(
          'I confirm this laboratory operates in accordance with DRAP (Drug Regulatory Authority of Pakistan) regulations and diagnostic testing standards.',
          style: TextStyle(fontSize: 12, height: 1.4),
        ),
        value: _drapCompliance,
        onChanged: (value) {
          setState(() => _drapCompliance = value ?? false);
        },
        activeColor: const Color(0xFF10B981),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [primaryColor, secondaryColor]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_rounded, color: Colors.white, size: 22),
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
    );
  }
}
