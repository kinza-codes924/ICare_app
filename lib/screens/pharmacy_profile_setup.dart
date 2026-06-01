import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
// ignore: avoid_web_libraries_in_flutter
import '../utils/html_stub.dart' as html
    if (dart.library.html) 'dart:html';
import '../services/pharmacy_service.dart';
import 'tabs.dart';

class PharmacyProfileSetup extends StatefulWidget {
  const PharmacyProfileSetup({super.key});

  @override
  State<PharmacyProfileSetup> createState() => _PharmacyProfileSetupState();
}

class _PharmacyProfileSetupState extends State<PharmacyProfileSetup> {
  final _formKey = GlobalKey<FormState>();
  final PharmacyService _pharmacyService = PharmacyService();

  bool _isLoading = true;
  bool _isSaving = false;

  final _ownerNameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _openHoursFromController = TextEditingController();
  final _openHoursToController = TextEditingController();

  bool _deliveryAvailable = false;
  bool _drapCompliance = false;
  final _deliveryFeeController = TextEditingController();
  double? _latitude;
  double? _longitude;
  bool _gettingLocation = false;

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 600);
    if (picked != null) setState(() => _profileImage = File(picked.path));
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _cnicController.dispose();
    _licenseNumberController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _openHoursFromController.dispose();
    _openHoursToController.dispose();
    _deliveryFeeController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _pharmacyService.getPharmacyProfile();
      setState(() {
        // Filter out default role names stored by backend during registration
        const defaultRoles = {'patient', 'doctor', 'pharmacy', 'admin', 'lab', 'pharmacist'};
        String rawName = profile['pharmacyName']?.toString()
            ?? profile['ownerName']?.toString()
            ?? '';
        _ownerNameController.text = defaultRoles.contains(rawName.toLowerCase().trim()) ? '' : rawName;
        _cnicController.text = profile['cnic'] ?? '';
        _licenseNumberController.text = profile['licenseNumber'] ?? profile['drugSaleLicense'] ?? '';
        _addressController.text = profile['address'] ?? '';
        _cityController.text = profile['city'] ?? '';
        _openHoursFromController.text = profile['openHours']?['from'] ?? '';
        _openHoursToController.text = profile['openHours']?['to'] ?? '';
        _deliveryAvailable = profile['deliveryAvailable'] ?? false;
        _deliveryFeeController.text = (profile['deliveryFee'] ?? '').toString() == '0' ? '' : (profile['deliveryFee'] ?? '').toString();
        _latitude = (profile['latitude'] as num?)?.toDouble();
        _longitude = (profile['longitude'] as num?)?.toDouble();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: const Text('Unable to load data. Please try again.')));
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
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _gettingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get location. Please allow location access.')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await _pharmacyService.updatePharmacyProfile({
        'ownerName': _ownerNameController.text,
        'cnic': _cnicController.text,
        'licenseNumber': _licenseNumberController.text,
        'address': _addressController.text,
        'city': _cityController.text,
        'openHours': {
          'from': _openHoursFromController.text,
          'to': _openHoursToController.text,
        },
        'deliveryAvailable': _deliveryAvailable,
        'deliveryFee': double.tryParse(_deliveryFeeController.text.trim()) ?? 0,
        if (_latitude != null) 'latitude': _latitude,
        if (_longitude != null) 'longitude': _longitude,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        // Navigate to dashboard after profile setup
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (ctx) => const TabsScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: const Text('Something went wrong. Please try again.')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Pharmacy Profile Setup'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Photo Upload
                    Center(
                      child: GestureDetector(
                        onTap: _pickProfileImage,
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00897B).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF00897B).withValues(alpha: 0.3), width: 3),
                              ),
                              child: ClipOval(
                                child: _profileImage != null
                                    ? Image.file(_profileImage!, fit: BoxFit.cover)
                                    : const Icon(Icons.local_pharmacy_rounded, size: 44, color: Color(0xFF00897B)),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00897B),
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
                    const Center(
                      child: Text('Tap to upload pharmacy logo', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ),
                    const SizedBox(height: 24),
                    _buildSection('Basic Information', Icons.info_outline, [
                      _buildTextField(
                        controller: _ownerNameController,
                        label: 'Pharmacy Name',
                        icon: Icons.local_pharmacy,
                        validator: (v) =>
                            v?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _cnicController,
                        label: 'CNIC',
                        icon: Icons.badge,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _licenseNumberController,
                        label: 'Drug Sale License',
                        icon: Icons.verified_user,
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSection('Location', Icons.location_on, [
                      _buildTextField(
                        controller: _addressController,
                        label: 'Address',
                        icon: Icons.home,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _cityController,
                        label: 'City',
                        icon: Icons.location_city,
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
                                  _latitude != null ? Icons.my_location : Icons.location_searching,
                                  color: _latitude != null ? const Color(0xFF10B981) : const Color(0xFF00897B),
                                ),
                          label: Text(
                            _latitude != null
                                ? '✓ Location saved (${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)})'
                                : 'Use My Current Location',
                            style: TextStyle(
                              color: _latitude != null ? const Color(0xFF10B981) : const Color(0xFF00897B),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: _latitude != null ? const Color(0xFF10B981) : const Color(0xFF00897B),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSection('Operating Hours', Icons.access_time, [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _openHoursFromController,
                              label: 'From (e.g., 09:00 AM)',
                              icon: Icons.schedule,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _openHoursToController,
                              label: 'To (e.g., 09:00 PM)',
                              icon: Icons.schedule,
                            ),
                          ),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSection('Services', Icons.local_shipping, [
                      SwitchListTile(
                        title: const Text('Delivery Available'),
                        subtitle: const Text('Offer home delivery service'),
                        value: _deliveryAvailable,
                        onChanged: (value) {
                          setState(() => _deliveryAvailable = value);
                        },
                        activeThumbColor: const Color(0xFF00897B),
                      ),
                      if (_deliveryAvailable) ...[
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _deliveryFeeController,
                          label: 'Delivery Fee (PKR)',
                          icon: Icons.local_shipping_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Compliance', Icons.verified_user_outlined, [
                      CheckboxListTile(
                        title: const Text(
                          'DRAP Compliance Agreement',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: const Text(
                          'I confirm this pharmacy operates in accordance with DRAP (Drug Regulatory Authority of Pakistan) regulations and drug sale policies.',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _drapCompliance,
                        onChanged: (value) {
                          setState(() => _drapCompliance = value ?? false);
                        },
                        activeColor: const Color(0xFF00897B),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ]),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Profile',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF00897B), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF00897B)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00897B), width: 2),
        ),
      ),
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }
}
