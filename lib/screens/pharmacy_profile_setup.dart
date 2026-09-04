import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
// ignore: avoid_web_libraries_in_flutter
import '../utils/html_stub.dart' as html
    if (dart.library.html) 'dart:html';
import '../utils/geo_locator_stub.dart'
    if (dart.library.html) '../utils/geo_locator_web.dart';
import '../services/pharmacy_service.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import 'tabs.dart';
import 'package:icare/widgets/back_button.dart';

class PharmacyProfileSetup extends ConsumerStatefulWidget {
  const PharmacyProfileSetup({super.key});

  @override
  ConsumerState<PharmacyProfileSetup> createState() => _PharmacyProfileSetupState();
}

class _PharmacyProfileSetupState extends ConsumerState<PharmacyProfileSetup> {
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

  Uint8List? _imageBytes;
  String? _existingProfilePictureUrl;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 600);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
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
        _existingProfilePictureUrl = profile['profilePicture']?.toString();
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
    if (!kIsWeb) {
      _showManualCoordinatesDialog(
          reason: 'Auto-location is only available on web. Enter coordinates manually.');
      return;
    }

    // HTTPS / secure-context check
    try {
      final protocol = html.window.location.protocol;
      final hostname = html.window.location.hostname;
      if (protocol != 'https:' && hostname != 'localhost' && hostname != '127.0.0.1') {
        _showManualCoordinatesDialog(
            reason: 'Location detection requires a secure HTTPS connection. '
                'Enter your pharmacy coordinates manually.');
        return;
      }
    } catch (_) {}

    setState(() => _gettingLocation = true);

    int? errorCode;
    final coords = await getGpsCoords((code) => errorCode = code);

    if (!mounted) return;
    setState(() => _gettingLocation = false);

    if (coords != null) {
      setState(() {
        _latitude = coords[0];
        _longitude = coords[1];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location captured successfully!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Location failed — show manual dialog with helpful message
    final String reason;
    switch (errorCode ?? 0) {
      case 1:
        reason = 'Location access is blocked by the browser.\n\n'
            'To fix: click the 🔒 lock icon in your browser address bar → '
            'click "Location" → select "Allow" → then tap the location button again.';
        break;
      case 2:
        reason = 'Your device could not determine the location '
            '(GPS or network unavailable).\n\n'
            'Please enter your pharmacy coordinates manually below.';
        break;
      case 3:
      default:
        reason = 'Could not detect location automatically.\n\n'
            'Tip: Open Google Maps, long-press your pharmacy location, '
            'and copy the coordinates shown at the top.';
    }
    _showManualCoordinatesDialog(reason: reason);
  }

  void _showManualCoordinatesDialog({String? reason}) {
    if (!mounted) return;
    final latCtrl =
        TextEditingController(text: _latitude?.toStringAsFixed(6) ?? '');
    final lngCtrl =
        TextEditingController(text: _longitude?.toStringAsFixed(6) ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.pin_drop_rounded, color: Color(0xFF00897B)),
            SizedBox(width: 10),
            Expanded(
              child: Text('Enter Pharmacy Coordinates',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (reason != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(reason,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF92400E))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: latCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration: InputDecoration(
                  labelText: 'Latitude',
                  hintText: 'e.g. 31.5204',
                  prefixIcon: const Icon(Icons.swap_vert_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lngCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration: InputDecoration(
                  labelText: 'Longitude',
                  hintText: 'e.g. 74.3587',
                  prefixIcon: const Icon(Icons.swap_horiz_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '💡 Tip: Open Google Maps, right-click your pharmacy\'s location, '
                'and the coordinates appear at the top of the menu.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              final lat = double.tryParse(latCtrl.text.trim());
              final lng = double.tryParse(lngCtrl.text.trim());
              if (lat == null || lng == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Enter valid decimal numbers.'),
                  backgroundColor: Colors.red,
                ));
                return;
              }
              if (lat < -90 || lat > 90) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Latitude must be between -90 and 90.'),
                  backgroundColor: Colors.red,
                ));
                return;
              }
              if (lng < -180 || lng > 180) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Longitude must be between -180 and 180.'),
                  backgroundColor: Colors.red,
                ));
                return;
              }
              if (mounted) setState(() { _latitude = lat; _longitude = lng; });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Location saved successfully!'),
                  backgroundColor: Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Save Location'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await _pharmacyService.updatePharmacyProfile({
        'pharmacyName': _ownerNameController.text,
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
        if (_imageBytes != null)
          'profilePicture': 'data:image/jpeg;base64,${base64Encode(_imageBytes!)}',
      });
      if (_imageBytes != null) {
        final pic = 'data:image/jpeg;base64,${base64Encode(_imageBytes!)}';
        setState(() => _existingProfilePictureUrl = pic);
        ref.read(authProvider.notifier).patchPicture(pic);
      }
      try {
        final resp = await ApiService().get('/users/profile');
        if (resp.data != null && mounted) {
          final fetched = User.fromJson(resp.data);
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
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        // Navigate to dashboard after profile setup
        context.go('/dashboard');
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
        leading: const CustomBackButton(),
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
                                child: _imageBytes != null
                                    ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                                    : _existingProfilePictureUrl != null
                                        ? Image.network(_existingProfilePictureUrl!, fit: BoxFit.cover)
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
