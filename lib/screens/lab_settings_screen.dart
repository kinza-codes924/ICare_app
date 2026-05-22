import 'package:flutter/material.dart';
import '../services/laboratory_service.dart';
import '../widgets/back_button.dart';

class LabSettingsScreen extends StatefulWidget {
  const LabSettingsScreen({super.key});

  @override
  State<LabSettingsScreen> createState() => _LabSettingsScreenState();
}

class _LabSettingsScreenState extends State<LabSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final LaboratoryService _labService = LaboratoryService();

  bool _isLoading = true;
  bool _isSaving = false;

  // Lab info
  final _labNameController = TextEditingController();
  final _licenseController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // Operating hours
  final _openTimeController = TextEditingController();
  final _closeTimeController = TextEditingController();
  bool _openSaturday = true;
  bool _openSunday = false;
  bool _open24Hours = false;

  // DRAP compliance
  bool _drapCompliance = false;
  bool _homeSampleCollection = false;

  // Notifications
  bool _notifyNewBooking = true;
  bool _notifyUrgentTest = true;

  static const Color primaryColor = Color(0xFF0B2D6E);
  static const Color secondaryColor = Color(0xFF1565C0);
  static const Color backgroundColor = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _labNameController.dispose();
    _licenseController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _labService.getProfile();
      _labNameController.text = profile['labName'] ?? profile['name'] ?? '';
      _licenseController.text = profile['licenseNumber'] ?? '';
      _addressController.text = profile['address'] ?? '';
      _cityController.text = profile['city'] ?? '';
      _phoneController.text = profile['phone'] ?? profile['labPhone'] ?? '';
      _emailController.text = profile['email'] ?? profile['labEmail'] ?? '';
      _openTimeController.text = profile['workingHoursFrom'] ?? '08:00 AM';
      _closeTimeController.text = profile['workingHoursTo'] ?? '08:00 PM';
      _drapCompliance = profile['drapCompliance'] == true;
      _homeSampleCollection = profile['homeSampleAvailable'] == true;

      final prefs = profile['notificationPreferences'] as Map<String, dynamic>? ?? {};
      _notifyNewBooking = prefs['newBooking'] != false;
      _notifyUrgentTest = prefs['urgentTest'] != false;
    } catch (_) {
      // Use defaults on error
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _labService.updateProfile({
        'labName': _labNameController.text.trim(),
        'licenseNumber': _licenseController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'labPhone': _phoneController.text.trim(),
        'labEmail': _emailController.text.trim(),
        'workingHoursFrom': _openTimeController.text.trim(),
        'workingHoursTo': _closeTimeController.text.trim(),
        'openSaturday': _openSaturday,
        'openSunday': _openSunday,
        'open24Hours': _open24Hours,
        'drapCompliance': _drapCompliance,
        'homeSampleAvailable': _homeSampleCollection,
        'notificationPreferences': {
          'newBooking': _notifyNewBooking,
          'urgentTest': _notifyUrgentTest,
        },
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save settings. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          'Lab Settings',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Gilroy-Bold',
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _isSaving ? null : _saveSettings,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryColor,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      title: 'Lab Information',
                      icon: Icons.business_rounded,
                      iconColor: primaryColor,
                      children: [
                        _buildField(
                          controller: _labNameController,
                          label: 'Lab Name',
                          icon: Icons.local_hospital_rounded,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          controller: _licenseController,
                          label: 'License Number',
                          icon: Icons.verified_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          controller: _phoneController,
                          label: 'Contact Number',
                          icon: Icons.phone_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          controller: _emailController,
                          label: 'Email Address',
                          icon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      title: 'Branch Address',
                      icon: Icons.location_on_rounded,
                      iconColor: const Color(0xFF0EA5E9),
                      children: [
                        _buildField(
                          controller: _addressController,
                          label: 'Street Address',
                          icon: Icons.home_rounded,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          controller: _cityController,
                          label: 'City',
                          icon: Icons.location_city_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      title: 'Operating Hours',
                      icon: Icons.access_time_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      children: [
                        _buildSwitchTile(
                          title: 'Open 24 Hours',
                          subtitle: 'Lab operates around the clock',
                          value: _open24Hours,
                          onChanged: (v) => setState(() => _open24Hours = v),
                        ),
                        if (!_open24Hours) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildField(
                                  controller: _openTimeController,
                                  label: 'Opens At',
                                  icon: Icons.wb_sunny_rounded,
                                  hint: '08:00 AM',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildField(
                                  controller: _closeTimeController,
                                  label: 'Closes At',
                                  icon: Icons.nights_stay_rounded,
                                  hint: '08:00 PM',
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        _buildSwitchTile(
                          title: 'Open on Saturday',
                          subtitle: 'Accept bookings on Saturdays',
                          value: _openSaturday,
                          onChanged: (v) => setState(() => _openSaturday = v),
                        ),
                        const SizedBox(height: 8),
                        _buildSwitchTile(
                          title: 'Open on Sunday',
                          subtitle: 'Accept bookings on Sundays',
                          value: _openSunday,
                          onChanged: (v) => setState(() => _openSunday = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      title: 'Compliance & Services',
                      icon: Icons.shield_rounded,
                      iconColor: const Color(0xFF10B981),
                      children: [
                        _buildSwitchTile(
                          title: 'DRAP Compliant',
                          subtitle: 'Lab meets Drug Regulatory Authority of Pakistan standards',
                          value: _drapCompliance,
                          onChanged: (v) => setState(() => _drapCompliance = v),
                          activeColor: const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 8),
                        _buildSwitchTile(
                          title: 'Home Sample Collection',
                          subtitle: 'Offer at-home sample pickup service',
                          value: _homeSampleCollection,
                          onChanged: (v) => setState(() => _homeSampleCollection = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      title: 'Notification Preferences',
                      icon: Icons.notifications_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      children: [
                        _buildSwitchTile(
                          title: 'New Booking Alert',
                          subtitle: 'Get notified when a new test order is received',
                          value: _notifyNewBooking,
                          onChanged: (v) => setState(() => _notifyNewBooking = v),
                        ),
                        const SizedBox(height: 8),
                        _buildSwitchTile(
                          title: 'Urgent Test Alert',
                          subtitle: 'Get notified immediately for urgent/STAT test orders',
                          value: _notifyUrgentTest,
                          onChanged: (v) => setState(() => _notifyUrgentTest = v),
                          activeColor: Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveSettings,
                        icon: const Icon(Icons.save_rounded, color: Colors.white),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save Settings',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? activeColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: activeColor ?? primaryColor,
        ),
      ],
    );
  }
}
