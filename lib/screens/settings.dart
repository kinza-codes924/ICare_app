import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/models/user.dart' as app_user;
import 'package:icare/services/doctor_service.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/about_us.dart' show AboutUs;
import 'package:icare/screens/change_password.dart' show ChangePassword;
import 'package:icare/screens/certificates_screen.dart';
import 'package:icare/screens/courses.dart' show Courses;
import 'package:icare/screens/doctor_availability.dart' show DoctorAvailability;
import 'package:icare/screens/doctor_profile_setup.dart' show DoctorProfileSetup;
import 'package:icare/screens/help_and_support.dart' show HelpAndSupport;
import 'package:icare/screens/notification_settings.dart' show NotificationSettings;
import 'package:icare/screens/privacy_policy.dart' show PrivacyPolicy;
import 'package:icare/screens/terms_and_conditions.dart' show TermsAndConditions;
import 'package:icare/utils/theme.dart';
import 'package:icare/services/security_service.dart';
import 'package:icare/services/biometric_service.dart';
import 'package:icare/services/health_settings_service.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/shared_pref.dart';
import '../utils/js_stub.dart'
    if (dart.library.html) 'dart:js' as js;

// ═══════════════════════════════════════════════════════════════════════════
// SETTINGS SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final SecurityService _securityService = SecurityService();
  final HealthSettingsService _healthSettingsService = HealthSettingsService();
  final BiometricService _biometricService = BiometricService();

  bool _is2FAEnabled = false;
  bool _isBiometricEnabled = false;
  bool _biometricAvailable = false;
  String _medicalConditions = '';
  String _allergies = '';
  String _currentMedications = '';
  String _healthGoals = '';
  int _waterReminderMinutes = 60;
  String _selectedLanguage = 'English';
  String _selectedCountry = 'Pakistan';
  String _savedDeliveryAddress = '';

  final Map<String, bool> _trackerToggles = {
    'bloodPressure': true, 'bloodSugar': true, 'weight': false, 'water': true,
    'medication': true, 'steps': false, 'sleep': false, 'heartRate': true,
    'temperature': false, 'oxygenLevel': false,
  };

  bool _healthModeEnabled = false;
  List<String> _selectedConditions = [];
  final List<String> _savedPaymentMethods = [];
  final List<String> _billingHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHealthSettings();
    _loadUserData();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final available = await _biometricService.isAvailable();
    final enabled = await _biometricService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _isBiometricEnabled = enabled;
      });
    }
  }

  void _loadUserData() {
    ref.read(authProvider).user;
  }

  Future<void> _loadHealthSettings() async {
    final role = ref.read(authProvider).userRole ?? '';
    if (role != 'Patient') return;
    try {
      final result = await _healthSettingsService.getSettings();
      if (result['success'] && mounted) {
        final settings = result['settings'];
        setState(() {
          _healthModeEnabled = settings['healthModeEnabled'] ?? false;
          _selectedConditions = List<String>.from(settings['selectedConditions'] ?? []);
          final trackedVitals = settings['trackedVitals'] ?? {};
          trackedVitals.forEach((key, value) {
            if (_trackerToggles.containsKey(key)) _trackerToggles[key] = value;
          });
        });
      }
    } catch (_) {}
  }

  Future<void> _updateTrackerToggle(String key, bool value) async {
    setState(() => _trackerToggles[key] = value);
    try {
      await _healthSettingsService.updateTrackerToggles(_trackerToggles);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save tracker settings')),
        );
      }
    }
  }

  Future<void> _toggleHealthMode(String condition, bool enabled) async {
    setState(() {
      if (enabled) {
        if (!_selectedConditions.contains(condition)) _selectedConditions.add(condition);
        _healthModeEnabled = true;
      } else {
        _selectedConditions.remove(condition);
        if (_selectedConditions.isEmpty) _healthModeEnabled = false;
      }
    });
    try {
      await _healthSettingsService.toggleHealthMode(
        enabled: _healthModeEnabled,
        conditions: _selectedConditions,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save health mode settings')),
        );
      }
    }
  }

  Future<void> _toggle2FA(bool value) async {
    try {
      if (value) {
        final data = await _securityService.enable2FA();
        _show2FAConfirmationDialog(data['qrCodeUrl'] ?? '');
      } else {
        await _securityService.disable2FA();
        setState(() => _is2FAEnabled = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
    }
  }

  void _show2FAConfirmationDialog(String qrUrl) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enable 2FA', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Scan this QR code with your authenticator app.'),
          const SizedBox(height: 16),
          Container(width: 150, height: 150, color: Colors.grey[200], child: const Icon(Icons.qr_code_2_rounded, size: 100)),
          const SizedBox(height: 16),
          TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Verification Code', hintText: 'Enter 6-digit code'), keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final verified = await _securityService.verify2FA(codeController.text);
              if (verified) {
                setState(() => _is2FAEnabled = true);
                if (mounted) Navigator.pop(ctx);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('2FA Enabled Successfully!')));
              } else {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid code, try again.')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Verify & Enable'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      try {
        final result = await _biometricService.authenticate(
          reason: 'Confirm your identity to enable biometric sign-in',
        );
        if (result == BiometricResult.success) {
          final authState = ref.read(authProvider);
          final email = authState.user?.email ?? '';
          final token = authState.token ?? await SharedPref().getToken() ?? '';
          final user = authState.user;
          await _biometricService.enableBiometrics(
            email,
            token: token.isNotEmpty ? token : null,
            user: user,
          );
          setState(() => _isBiometricEnabled = true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Biometric sign-in enabled'), backgroundColor: Colors.green),
            );
          }
        } else if (result == BiometricResult.notAvailable) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Biometrics not available on this device')),
            );
          }
        }
        // cancelled/failed → do nothing, switch stays off
      } catch (e) {
        debugPrint('Toggle biometrics error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to enable biometric sign-in. Please try again.')),
          );
        }
      }
    } else {
      await _biometricService.disableBiometrics();
      setState(() => _isBiometricEnabled = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric sign-in disabled')),
        );
      }
    }
    // Also sync preference to backend
    try {
      await _securityService.updateBiometricPreference(value);
    } catch (_) {}
  }

  void _handleLogout() {
    ref.read(authProvider.notifier).setUserLogout();
    context.go('/login');
  }

  void _showReportIssueDialog(BuildContext ctx) {
    final titleC = TextEditingController();
    final descC = TextEditingController();
    final fk = GlobalKey<FormState>();
    showDialog(context: ctx, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.bug_report_outlined, color: Color(0xFFEF4444), size: 22), SizedBox(width: 10), Text('Report an Issue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: 400, child: Form(key: fk, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Describe the issue you encountered.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))), const SizedBox(height: 16),
        TextFormField(controller: titleC, decoration: InputDecoration(labelText: 'Issue Title', hintText: 'e.g. Login not working', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)), validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null), const SizedBox(height: 12),
        TextFormField(controller: descC, maxLines: 4, decoration: InputDecoration(labelText: 'Description', hintText: 'Tell us what happened...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), alignLabelWithHint: true), validator: (v) => (v == null || v.trim().isEmpty) ? 'Please describe the issue' : null),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
        ElevatedButton.icon(onPressed: () { if (fk.currentState!.validate()) { Navigator.pop(dc); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Issue reported. Thank you!'), duration: Duration(seconds: 3))); } }, icon: const Icon(Icons.send_rounded, size: 16), label: const Text('Submit'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
      ],
    ));
  }

  void _showDeleteAccountDialog(BuildContext ctx) {
    showDialog(context: ctx, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 24), SizedBox(width: 10), Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFFEF4444)))]),
      content: const Text('Are you sure? This action is permanent and cannot be undone.', style: TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
        ElevatedButton.icon(onPressed: () { Navigator.pop(dc); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Account deletion request submitted.'), backgroundColor: Color(0xFFEF4444))); }, icon: const Icon(Icons.delete_forever_rounded, size: 16), label: const Text('Delete My Account'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
      ],
    ));
  }

  void _comingSoon(BuildContext ctx, String feature) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [const Icon(Icons.access_time_rounded, color: Color(0xFFF59E0B), size: 22), const SizedBox(width: 10), Expanded(child: Text(feature, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)))]),
      content: const Text('This feature is coming soon. Stay tuned!'),
      actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('OK'))],
    ));
  }

  void _showMedicalConditionsDialog(BuildContext ctx) {
    final c = TextEditingController(text: _medicalConditions);
    showDialog(context: ctx, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.monitor_heart_outlined, color: Color(0xFFEF4444), size: 22), SizedBox(width: 10), Text('Medical Conditions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('List your medical conditions', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))), const SizedBox(height: 12),
        TextField(controller: c, maxLines: 3, decoration: InputDecoration(hintText: 'e.g. Diabetes Type 2, Hypertension', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.all(12))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))), ElevatedButton(onPressed: () { setState(() => _medicalConditions = c.text.trim()); Navigator.pop(dc); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Medical conditions saved'), backgroundColor: Colors.green)); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Save'))],
    ));
  }

  void _showAllergiesDialog(BuildContext ctx) {
    final c = TextEditingController(text: _allergies);
    showDialog(context: ctx, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 22), SizedBox(width: 10), Text('Allergies', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('List any allergies', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))), const SizedBox(height: 12),
        TextField(controller: c, maxLines: 3, decoration: InputDecoration(hintText: 'e.g. Apple, Peanuts', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.all(12))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))), ElevatedButton(onPressed: () { setState(() => _allergies = c.text.trim()); Navigator.pop(dc); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Allergies saved'), backgroundColor: Colors.green)); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Save'))],
    ));
  }

  void _showCurrentMedicationsDialog(BuildContext ctx) {
    final c = TextEditingController(text: _currentMedications);
    showDialog(context: ctx, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.medication_outlined, color: Color(0xFF8B5CF6), size: 22), SizedBox(width: 10), Text('Current Medications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('List your current medications', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))), const SizedBox(height: 12),
        TextField(controller: c, maxLines: 3, decoration: InputDecoration(hintText: 'e.g. Metformin 500mg', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.all(12))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))), ElevatedButton(onPressed: () { setState(() => _currentMedications = c.text.trim()); Navigator.pop(dc); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Medications saved'), backgroundColor: Colors.green)); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Save'))],
    ));
  }

  void _showHealthGoalsDialog(BuildContext ctx) {
    final c = TextEditingController(text: _healthGoals);
    showDialog(context: ctx, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.flag_outlined, color: Color(0xFF10B981), size: 22), SizedBox(width: 10), Text('Health Goals', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Set your health goals', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))), const SizedBox(height: 12),
        TextField(controller: c, maxLines: 3, decoration: InputDecoration(hintText: 'e.g. Lose 10 kg', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.all(12))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))), ElevatedButton(onPressed: () { setState(() => _healthGoals = c.text.trim()); Navigator.pop(dc); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Health goals saved'), backgroundColor: Colors.green)); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Save'))],
    ));
  }

  void _showWaterReminderDialog(BuildContext ctx) {
    final intervals = [30, 60, 120, 180];
    final labels = ['30 minutes', '1 hour', '2 hours', '3 hours'];
    int selected = _waterReminderMinutes;
    showDialog(context: ctx, builder: (dc) => StatefulBuilder(builder: (ctx2, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.water_drop_outlined, color: Color(0xFF3B82F6), size: 22), SizedBox(width: 10), Text('Water Reminder', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: 300, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('How often?', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))), const SizedBox(height: 16),
        ...List.generate(intervals.length, (i) {
          final isSel = selected == intervals[i];
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(onTap: () => setS(() => selected = intervals[i]), borderRadius: BorderRadius.circular(10), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(color: isSel ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: isSel ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0), width: isSel ? 1.5 : 1)), child: Row(children: [Icon(isSel ? Icons.radio_button_checked : Icons.radio_button_off, color: isSel ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1), size: 20), const SizedBox(width: 12), Text(labels[i], style: TextStyle(fontSize: 14, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? const Color(0xFF1E293B) : const Color(0xFF64748B)))]))));
        }),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))), ElevatedButton(onPressed: () { setState(() => _waterReminderMinutes = selected); Navigator.pop(dc); try { js.context.callMethod('setupWaterReminder', [selected]); } catch (_) {} ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Water reminder set to every ${labels[intervals.indexOf(selected)]}'), backgroundColor: Colors.green)); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Set Reminder'))],
    )));
  }

  void _showLanguageDialog(BuildContext ctx) {
    final languages = ['English', 'Urdu'];
    String selected = _selectedLanguage;
    showDialog(context: ctx, builder: (dc) => StatefulBuilder(builder: (ctx2, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.translate_rounded, color: Color(0xFF64748B), size: 22), SizedBox(width: 10), Text('Language', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: 300, child: Column(mainAxisSize: MainAxisSize.min, children: List.generate(languages.length, (i) {
        final lang = languages[i];
        final isSel = selected == lang;
        return Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(onTap: () => setS(() => selected = lang), borderRadius: BorderRadius.circular(10), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(color: isSel ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: isSel ? AppColors.primaryColor : const Color(0xFFE2E8F0), width: isSel ? 1.5 : 1)), child: Row(children: [Icon(isSel ? Icons.radio_button_checked : Icons.radio_button_off, color: isSel ? AppColors.primaryColor : const Color(0xFFCBD5E1), size: 20), const SizedBox(width: 12), Text(lang, style: TextStyle(fontSize: 14, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? const Color(0xFF1E293B) : const Color(0xFF64748B)))]))));
      }))),
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))), ElevatedButton(onPressed: () { setState(() => _selectedLanguage = selected); Navigator.pop(dc); ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Language set to $selected'), backgroundColor: Colors.green)); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Apply'))],
    )));
  }

  void _showCountryRegionDialog(BuildContext ctx) {
    final role = ref.read(authProvider).userRole ?? '';
    final isPatient = role == 'Patient';
    
    // For patients: only Pakistan, others coming soon
    // For doctors: all regions available
    final countries = isPatient 
      ? ['Pakistan']
      : ['Pakistan', 'India', 'Bangladesh', 'United States', 'United Kingdom', 'Canada', 'Australia'];
    
    String selected = _selectedCountry;
    showDialog(context: ctx, builder: (dc) => StatefulBuilder(builder: (ctx2, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.public_outlined, color: Color(0xFF64748B), size: 22), SizedBox(width: 10), Text('Country & Region', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: 300, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (isPatient) const Text('Currently available in Pakistan only. More countries coming soon!', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        if (!isPatient) const Text('Select your country/region', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(height: 16),
        ...List.generate(countries.length, (i) {
          final country = countries[i];
          final isSel = selected == country;
          final isComingSoon = !isPatient && country != 'Pakistan';
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(
            onTap: isComingSoon ? null : () => setS(() => selected = country), 
            borderRadius: BorderRadius.circular(10), 
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), 
              decoration: BoxDecoration(
                color: isSel ? const Color(0xFFEFF6FF) : (isComingSoon ? const Color(0xFFFAFAFA) : const Color(0xFFF8FAFC)), 
                borderRadius: BorderRadius.circular(10), 
                border: Border.all(color: isSel ? AppColors.primaryColor : const Color(0xFFE2E8F0), width: isSel ? 1.5 : 1)
              ), 
              child: Row(children: [
                Icon(isSel ? Icons.radio_button_checked : Icons.radio_button_off, color: isSel ? AppColors.primaryColor : (isComingSoon ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1)), size: 20), 
                const SizedBox(width: 12), 
                Expanded(child: Text(country, style: TextStyle(fontSize: 14, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? const Color(0xFF1E293B) : (isComingSoon ? const Color(0xFF94A3B8) : const Color(0xFF64748B))))),
                if (isComingSoon) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Coming Soon', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B))),
                ),
              ])
            )
          ));
        }),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))), ElevatedButton(onPressed: () { setState(() => _selectedCountry = selected); Navigator.pop(dc); ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Country set to $selected'), backgroundColor: Colors.green)); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Apply'))],
    )));
  }

  void _showDeliveryAddressDialog(BuildContext ctx) {
    final c = TextEditingController(text: _savedDeliveryAddress);
    showDialog(context: ctx, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.location_on_outlined, color: Color(0xFF10B981), size: 22), SizedBox(width: 10), Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Enter your delivery address', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))), const SizedBox(height: 12),
        TextField(controller: c, maxLines: 4, decoration: InputDecoration(hintText: 'House #, Street, City', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.all(12))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))), ElevatedButton(onPressed: () { setState(() => _savedDeliveryAddress = c.text.trim()); Navigator.pop(dc); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Delivery address saved'), backgroundColor: Colors.green)); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Save'))],
    ));
  }

  void _downloadHealthData(BuildContext ctx) {
    showDialog(context: ctx, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.download_outlined, color: Color(0xFF8B5CF6), size: 22), SizedBox(width: 10), Text('Download Health Data', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: const SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your health data will be downloaded.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        SizedBox(height: 12),
        Text('Includes: Consultations, Prescriptions, Lab Reports, Vitals', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))), ElevatedButton.icon(onPressed: () { Navigator.pop(dc); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Your health data is being prepared for download.'), backgroundColor: Colors.green, duration: Duration(seconds: 4))); }, icon: const Icon(Icons.download_rounded, size: 16), label: const Text('Download'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))],
    ));
  }

  void _showPaymentMethodsDialog(BuildContext ctx) {
    showDialog(context: ctx, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.credit_card_outlined, color: Color(0xFF10B981), size: 22), SizedBox(width: 10), Text('Payment Methods', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Your saved payment methods', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))), const SizedBox(height: 16),
        if (_savedPaymentMethods.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('No payment methods saved yet', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))))) else ...List.generate(_savedPaymentMethods.length, (i) => ListTile(leading: const Icon(Icons.credit_card_rounded, color: Color(0xFF10B981)), title: Text(_savedPaymentMethods[i]), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)), onPressed: () { setState(() => _savedPaymentMethods.removeAt(i)); Navigator.pop(dc); }))),
        const SizedBox(height: 12),
        ElevatedButton.icon(onPressed: () { Navigator.pop(dc); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Add payment method'), backgroundColor: Colors.green)); }, icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Add Payment Method'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))))],
    ));
  }

  void _showBillingHistoryDialog(BuildContext ctx) {
    showDialog(context: ctx, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.receipt_long_outlined, color: Color(0xFF10B981), size: 22), SizedBox(width: 10), Text('Billing History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('All your payment transactions', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))), const SizedBox(height: 16),
        if (_billingHistory.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Column(children: [Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFFCBD5E1)), SizedBox(height: 8), Text('No billing history yet', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)))]))) else ...List.generate(_billingHistory.length, (i) => ListTile(leading: const Icon(Icons.receipt_rounded, color: Color(0xFF10B981)), title: Text(_billingHistory[i]), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFCBD5E1)))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))))],
    ));
  }

  void _showFeeDialog(BuildContext ctx) {
    final ctrl = TextEditingController();
    bool saving = false;
    showDialog(context: ctx, builder: (dc) => StatefulBuilder(builder: (dc2, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.attach_money_rounded, color: Color(0xFF10B981), size: 24), SizedBox(width: 10), Text('Consultation Fee', style: TextStyle(fontWeight: FontWeight.w800))]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Set your consultation fee (Rs.)', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))), const SizedBox(height: 12),
        TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true, decoration: InputDecoration(hintText: 'e.g. 2000', prefixText: 'Rs. ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: const Color(0xFFF8FAFC))),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel')), ElevatedButton(onPressed: saving ? null : () async { final fee = double.tryParse(ctrl.text.trim()); if (fee == null || fee < 0) return; setS(() => saving = true); try { final svc = DoctorService(); await svc.updateConsultationFee(fee); if (dc2.mounted) Navigator.pop(dc2); if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Consultation fee set to Rs. ${fee.toInt()}'), backgroundColor: Colors.green)); } catch (e) { if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red)); } setS(() => saving = false); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'))],
    )));
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.read(authProvider).userRole ?? '';
    final user = ref.read(authProvider).user;
    final isPatient = role == 'Patient';
    final isPharmacy = role == 'Pharmacy';
    final isLaboratory = role == 'Laboratory';
    final isDoctor = role == 'Doctor';
    final isStudent = role == 'Student';
    final isInstructor = role == 'Instructor';
    final isWide = MediaQuery.of(context).size.width > 600;

    final params = _SettingsLayoutParams(
      role: role, user: user,
      isPatient: isPatient, isPharmacy: isPharmacy, isLaboratory: isLaboratory,
      isDoctor: isDoctor, isStudent: isStudent, isInstructor: isInstructor,
      is2FAEnabled: _is2FAEnabled, isBiometricEnabled: _isBiometricEnabled,
      biometricAvailable: _biometricAvailable,
      trackerToggles: _trackerToggles, healthModeEnabled: _healthModeEnabled,
      selectedConditions: _selectedConditions,
      medicalConditions: _medicalConditions, allergies: _allergies,
      currentMedications: _currentMedications, healthGoals: _healthGoals,
      waterReminderMinutes: _waterReminderMinutes, selectedLanguage: _selectedLanguage,
      selectedCountry: _selectedCountry,
      savedDeliveryAddress: _savedDeliveryAddress,
      savedPaymentMethods: _savedPaymentMethods, billingHistory: _billingHistory,
      onToggle2FA: _toggle2FA, onToggleBiometrics: _toggleBiometrics,
      onTrackerToggle: _updateTrackerToggle, onHealthModeToggle: _toggleHealthMode,
      onLogout: _handleLogout, onComingSoon: _comingSoon,
      onReportIssue: _showReportIssueDialog, onDeleteAccount: _showDeleteAccountDialog,
      onShowFeeDialog: _showFeeDialog,
      onShowMedicalConditions: _showMedicalConditionsDialog, onShowAllergies: _showAllergiesDialog,
      onShowCurrentMedications: _showCurrentMedicationsDialog, onShowHealthGoals: _showHealthGoalsDialog,
      onShowWaterReminder: _showWaterReminderDialog, onShowLanguage: _showLanguageDialog,
      onShowCountryRegion: _showCountryRegionDialog,
      onShowDeliveryAddress: _showDeliveryAddressDialog, onDownloadHealthData: _downloadHealthData,
      onShowPaymentMethods: _showPaymentMethodsDialog, onShowBillingHistory: _showBillingHistoryDialog,
    );

    if (isWide) return _WebSettingsLayout(p: params);
    return _MobileSettingsLayout(p: params);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED PARAMS
// ═══════════════════════════════════════════════════════════════════════════

class _SettingsLayoutParams {
  final String role;
  final app_user.User? user;
  final bool isPatient, isPharmacy, isLaboratory, isDoctor, isStudent, isInstructor;
  final bool is2FAEnabled, isBiometricEnabled, biometricAvailable, healthModeEnabled;
  final List<String> selectedConditions;
  final String medicalConditions, allergies, currentMedications, healthGoals;
  final int waterReminderMinutes;
  final String selectedLanguage, selectedCountry, savedDeliveryAddress;
  final List<String> savedPaymentMethods, billingHistory;
  final Map<String, bool> trackerToggles;
  final void Function(bool) onToggle2FA, onToggleBiometrics;
  final void Function(String, bool) onTrackerToggle, onHealthModeToggle;
  final VoidCallback onLogout;
  final void Function(BuildContext, String) onComingSoon;
  final void Function(BuildContext) onReportIssue, onDeleteAccount, onShowFeeDialog;
  final void Function(BuildContext) onShowMedicalConditions, onShowAllergies, onShowCurrentMedications;
  final void Function(BuildContext) onShowHealthGoals, onShowWaterReminder, onShowLanguage;
  final void Function(BuildContext) onShowCountryRegion;
  final void Function(BuildContext) onShowDeliveryAddress, onDownloadHealthData;
  final void Function(BuildContext) onShowPaymentMethods, onShowBillingHistory;

  const _SettingsLayoutParams({
    required this.role, required this.user,
    required this.isPatient, required this.isPharmacy, required this.isLaboratory,
    required this.isDoctor, required this.isStudent, required this.isInstructor,
    required this.is2FAEnabled, required this.isBiometricEnabled,
    required this.biometricAvailable,
    required this.healthModeEnabled, required this.selectedConditions,
    required this.medicalConditions, required this.allergies,
    required this.currentMedications, required this.healthGoals,
    required this.waterReminderMinutes, required this.selectedLanguage,
    required this.selectedCountry,
    required this.savedDeliveryAddress, required this.savedPaymentMethods,
    required this.billingHistory, required this.trackerToggles,
    required this.onToggle2FA, required this.onToggleBiometrics,
    required this.onTrackerToggle, required this.onHealthModeToggle,
    required this.onLogout, required this.onComingSoon,
    required this.onReportIssue, required this.onDeleteAccount,
    required this.onShowFeeDialog, required this.onShowMedicalConditions,
    required this.onShowAllergies, required this.onShowCurrentMedications,
    required this.onShowHealthGoals, required this.onShowWaterReminder,
    required this.onShowLanguage, required this.onShowCountryRegion,
    required this.onShowDeliveryAddress,
    required this.onDownloadHealthData, required this.onShowPaymentMethods,
    required this.onShowBillingHistory,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// WEB LAYOUT
// ═══════════════════════════════════════════════════════════════════════════

class _WebSettingsLayout extends StatelessWidget {
  final _SettingsLayoutParams p;
  const _WebSettingsLayout({required this.p});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.w700)), centerTitle: true, backgroundColor: Colors.white, foregroundColor: AppColors.primaryColor, elevation: 0, surfaceTintColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Center(child: Container(constraints: const BoxConstraints(maxWidth: 800), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Remove any blue background header - using clean white layout
        _ProfileEditCard(p: p), const SizedBox(height: 24),
        if (p.isDoctor) ...[_doctorProfessionalCard(context), const SizedBox(height: 24)],
        if (p.isPatient) ...[_healthProfile(context), const SizedBox(height: 24)],
        _notificationsCard(context), const SizedBox(height: 24),
        if (p.isPatient) ...[_waterReminderCard(context), const SizedBox(height: 24)],
        if (p.isPatient) ...[_rewardsCard(context), const SizedBox(height: 24)],
        if (p.isPatient) ...[_privacyCard(context), const SizedBox(height: 24)],
        if (p.isPatient) ...[_paymentCard(context), const SizedBox(height: 24)],
        _contactCard(context), const SizedBox(height: 24),
        if (p.isPatient) ...[_pharmacyCard(context), const SizedBox(height: 24)],
        if (p.isStudent || p.isInstructor) ...[_learningCard(context), const SizedBox(height: 24)],
        _securityCard(context), const SizedBox(height: 24),
        if (p.isDoctor) ...[_notificationSettingsCard(context), const SizedBox(height: 24)],
        _languageCard(context), const SizedBox(height: 24),
        if (p.isPatient) ...[_trackerCard(context), const SizedBox(height: 24)],
        if (p.isPatient) ...[_healthModeCard(context), const SizedBox(height: 24)],
        _aboutCard(context), const SizedBox(height: 32),
        _logoutButton(context), const SizedBox(height: 24),
      ])))));
  }

  // ── PROFILE CARD ──
  Widget _profileCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 32, backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
            backgroundImage: p.user?.profilePicture != null ? NetworkImage(p.user!.profilePicture!) : null,
            child: p.user?.profilePicture == null ? Text((p.user?.name ?? 'U').substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryColor)) : null),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.user?.name ?? 'User', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(p.user?.email ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
          ])),
        ]),
        const SizedBox(height: 16), const Divider(), const SizedBox(height: 12),
        _profileRow(Icons.person_outline, 'Gender', p.user?.gender ?? 'Not set'),
        const SizedBox(height: 8), _profileRow(Icons.calendar_today_outlined, 'Age', p.user?.age ?? 'Not set'),
        const SizedBox(height: 8), _profileRow(Icons.phone_outlined, 'Phone', p.user?.phoneNumber ?? 'Not set'),
        const SizedBox(height: 8), _profileRow(Icons.email_outlined, 'Email', p.user?.email ?? 'Not set'),
        if (p.isPatient) ...[const SizedBox(height: 8), _profileRow(Icons.badge_outlined, 'MR Number', p.user?.mrNumber ?? 'N/A')],
      ])));
  }

  Widget _profileRow(IconData icon, String label, String value) {
    return Row(children: [Icon(icon, size: 18, color: const Color(0xFF64748B)), const SizedBox(width: 10), Text('$label: ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569))), Expanded(child: Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))))]);
  }

  // ── HEALTH PROFILE ──
  Widget _healthProfile(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Health Profile'), const SizedBox(height: 16),
        _settingsTile(icon: Icons.monitor_heart_outlined, iconColor: const Color(0xFFEF4444), title: 'Medical Conditions', subtitle: p.medicalConditions.isEmpty ? 'Tap to add' : p.medicalConditions, onTap: () => p.onShowMedicalConditions(context)),
        const Divider(height: 1),
        _settingsTile(icon: Icons.warning_amber_rounded, iconColor: const Color(0xFFF59E0B), title: 'Allergies', subtitle: p.allergies.isEmpty ? 'Tap to add' : p.allergies, onTap: () => p.onShowAllergies(context)),
        const Divider(height: 1),
        _settingsTile(icon: Icons.medication_outlined, iconColor: const Color(0xFF8B5CF6), title: 'Current Medications', subtitle: p.currentMedications.isEmpty ? 'Tap to add' : p.currentMedications, onTap: () => p.onShowCurrentMedications(context)),
        const Divider(height: 1),
        _settingsTile(icon: Icons.flag_outlined, iconColor: const Color(0xFF10B981), title: 'Health Goals', subtitle: p.healthGoals.isEmpty ? 'Tap to set goals' : p.healthGoals, onTap: () => p.onShowHealthGoals(context)),
      ])));
  }

  // ── NOTIFICATIONS ──
  Widget _notificationsCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Notifications'), const SizedBox(height: 16),
        _switchTile(icon: Icons.calendar_today_outlined, title: 'Booking Updates', subtitle: 'Appointment confirmations & changes', value: true, onChanged: (_) {}),
        const Divider(height: 1),
        _switchTile(icon: Icons.message_outlined, title: 'Doctor Messages', subtitle: 'Messages from providers', value: true, onChanged: (_) {}),
        const Divider(height: 1),
        _switchTile(icon: Icons.local_offer_outlined, title: 'Promotions & Offers', subtitle: 'Special deals & health tips', value: false, onChanged: (_) {}),
        const Divider(height: 1),
        _switchTile(icon: Icons.volume_up_outlined, title: 'Sound Notifications', subtitle: 'Play sound for notifications', value: true, onChanged: (_) {}),
        const Divider(height: 1),
        _switchTile(icon: Icons.email_outlined, title: 'Send Prescription to Email', subtitle: 'Automatically email prescriptions', value: true, onChanged: (_) {}),
      ])));
  }

  // ── WATER REMINDER ──
  Widget _waterReminderCard(BuildContext context) {
    final labels = {'30': '30 min', '60': '1 hr', '120': '2 hrs', '180': '3 hrs'};
    final label = labels[p.waterReminderMinutes.toString()] ?? '1 hr';
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Water Reminders'), const SizedBox(height: 16),
        _settingsTile(icon: Icons.water_drop_outlined, iconColor: const Color(0xFF3B82F6), title: 'Remind me every', subtitle: label, onTap: () => p.onShowWaterReminder(context)),
      ])));
  }

  // ── REWARDS ──
  Widget _rewardsCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Rewards & Points'), const SizedBox(height: 16),
        _settingsTile(icon: Icons.stars_outlined, iconColor: const Color(0xFFF59E0B), title: 'Reward Points', subtitle: 'Coming soon', onTap: () => p.onComingSoon(context, 'Reward Points')),
        const Divider(height: 1),
        _settingsTile(icon: Icons.history_outlined, iconColor: const Color(0xFFF59E0B), title: 'Reward History', subtitle: 'Coming soon', onTap: () => p.onComingSoon(context, 'Reward History')),
        const Divider(height: 1),
        _settingsTile(icon: Icons.swap_horiz_outlined, iconColor: const Color(0xFFF59E0B), title: 'Redemption History', subtitle: 'Coming soon', onTap: () => p.onComingSoon(context, 'Redemption History')),
      ])));
  }

  // ── PRIVACY ──
  Widget _privacyCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Privacy & Data'), const SizedBox(height: 16),
        _settingsTile(icon: Icons.download_outlined, iconColor: const Color(0xFF8B5CF6), title: 'Download Health Data', subtitle: 'Export all consultations & records', onTap: () => p.onDownloadHealthData(context)),
      ])));
  }

  // ── PAYMENTS ──
  Widget _paymentCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Payment & Subscription'), const SizedBox(height: 16),
        _settingsTile(icon: Icons.credit_card_outlined, iconColor: const Color(0xFF10B981), title: 'Saved Payment Methods', subtitle: p.savedPaymentMethods.isEmpty ? 'No methods saved' : '${p.savedPaymentMethods.length} method(s)', onTap: () => p.onShowPaymentMethods(context)),
        const Divider(height: 1),
        _settingsTile(icon: Icons.receipt_long_outlined, iconColor: const Color(0xFF10B981), title: 'Billing History', subtitle: p.billingHistory.isEmpty ? 'View transactions' : '${p.billingHistory.length} transaction(s)', onTap: () => p.onShowBillingHistory(context)),
      ])));
  }

  // ── CONTACT ──
  Widget _contactCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Contact & Legal'), const SizedBox(height: 16),
        _settingsTile(icon: Icons.headset_mic_outlined, iconColor: const Color(0xFF6366F1), title: 'Contact Support', subtitle: 'Get help from our team', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpAndSupport()))),
        const Divider(height: 1),
        _settingsTile(icon: Icons.help_outline, iconColor: const Color(0xFF6366F1), title: 'FAQ', subtitle: 'Frequently asked questions', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpAndSupport()))),
        const Divider(height: 1),
        _settingsTile(icon: Icons.bug_report_outlined, iconColor: const Color(0xFFEF4444), title: 'Report an Issue', subtitle: 'Report bugs & problems', onTap: () => p.onReportIssue(context)),
        const Divider(height: 1),
        _settingsTile(icon: Icons.description_outlined, iconColor: const Color(0xFF64748B), title: 'Terms & Conditions', subtitle: 'Review terms of service', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsAndConditions()))),
        const Divider(height: 1),
        _settingsTile(icon: Icons.privacy_tip_outlined, iconColor: const Color(0xFF64748B), title: 'Privacy Policy', subtitle: 'How we handle your data', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicy()))),
      ])));
  }

  // ── PHARMACY ──
  Widget _pharmacyCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Pharmacy Settings'), const SizedBox(height: 16),
        _settingsTile(icon: Icons.location_on_outlined, iconColor: const Color(0xFF10B981), title: 'Save Delivery Address', subtitle: p.savedDeliveryAddress.isEmpty ? 'Tap to add' : p.savedDeliveryAddress, onTap: () => p.onShowDeliveryAddress(context)),
        const Divider(height: 1),
        _settingsTile(icon: Icons.shopping_bag_outlined, iconColor: const Color(0xFF3B82F6), title: 'Order History', subtitle: 'View all pharmacy orders', onTap: () => p.onComingSoon(context, 'Order History')),
        const Divider(height: 1),
        _settingsTile(icon: Icons.local_shipping_outlined, iconColor: const Color(0xFF8B5CF6), title: 'Delivery Preferences', subtitle: 'Set delivery instructions', onTap: () => p.onShowDeliveryAddress(context)),
      ])));
  }

  // ── LEARNING ──
  Widget _learningCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Learning'), const SizedBox(height: 16),
        _settingsTile(icon: Icons.book_outlined, iconColor: const Color(0xFF6366F1), title: 'Enrolled Courses', subtitle: 'View your enrolled courses', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Courses()))),
        const Divider(height: 1),
        _settingsTile(icon: Icons.verified_outlined, iconColor: const Color(0xFF10B981), title: 'Certificates', subtitle: 'View your earned certificates', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CertificatesScreen()))),
        const Divider(height: 1),
        _settingsTile(icon: Icons.trending_up_outlined, iconColor: const Color(0xFF8B5CF6), title: 'Progress Tracking', subtitle: 'Track course progress', onTap: () => p.onComingSoon(context, 'Progress Tracking')),
        const Divider(height: 1),
        _switchTile(icon: Icons.notifications_active_outlined, title: 'Notifications for New Courses', subtitle: 'Get notified about new offerings', value: false, onChanged: (_) {}),
      ])));
  }

  // ── SECURITY ──
  Widget _securityCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Security'), const SizedBox(height: 16),
        _settingsTile(icon: Icons.lock_outline, iconColor: const Color(0xFF64748B), title: 'Change Password', subtitle: 'Update your password', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePassword()))),
        const Divider(height: 1),
        _settingsTile(icon: Icons.history_outlined, iconColor: const Color(0xFF64748B), title: 'Login Activity', subtitle: 'Review recent login sessions', onTap: () => p.onComingSoon(context, 'Login Activity')),
        // Biometric — shown for all roles if device supports it
        if (p.biometricAvailable) ...[
          const Divider(height: 1),
          _switchTile(icon: Icons.fingerprint, title: 'Biometric Sign-In', subtitle: p.isBiometricEnabled ? 'Tap to disable fingerprint / Face ID' : 'Enable fingerprint or Face ID sign-in', value: p.isBiometricEnabled, onChanged: p.onToggleBiometrics),
        ],
        if (p.isPatient) ...[
          const Divider(height: 1),
          _switchTile(icon: Icons.verified_user_outlined, title: 'Two-Factor Authentication (2FA)', subtitle: p.is2FAEnabled ? 'Enabled' : 'Extra layer of security', value: p.is2FAEnabled, onChanged: p.onToggle2FA),
        ],
      ])));
  }

  // ── NOTIFICATION SETTINGS (Doctor only) ──
  Widget _notificationSettingsCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Notifications'), const SizedBox(height: 16),
        _settingsTile(icon: Icons.notifications_active_outlined, iconColor: const Color(0xFF3B82F6), title: 'Notification Settings', subtitle: 'Manage notification preferences', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettings()))),
      ])));
  }

  // ── DOCTOR PROFESSIONAL SETTINGS ──
  Widget _doctorProfessionalCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel('Professional Settings'),
          const SizedBox(height: 16),
          // Consultation Fee
          _settingsTile(
            icon: Icons.attach_money_rounded,
            iconColor: const Color(0xFF10B981),
            title: 'Consultation Fee',
            subtitle: 'Set your consultation fee (Rs.)',
            onTap: () => p.onShowFeeDialog(context),
          ),
          const Divider(height: 1),
          // Availability & Schedule
          _settingsTile(
            icon: Icons.calendar_month_outlined,
            iconColor: const Color(0xFF6366F1),
            title: 'Availability & Schedule',
            subtitle: 'Manage your working hours & days',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorAvailability())),
          ),
          const Divider(height: 1),
          // Medical License
          _settingsTile(
            icon: Icons.badge_outlined,
            iconColor: const Color(0xFF0EA5E9),
            title: 'Medical License',
            subtitle: 'View & update license details',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorProfileSetup())),
          ),
        ]),
      ),
    );
  }

  // ── LANGUAGE ──
  Widget _languageCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Language & Region'), const SizedBox(height: 16),
        _settingsTile(icon: Icons.translate_rounded, iconColor: const Color(0xFF64748B), title: 'Language', subtitle: p.selectedLanguage, onTap: () => p.onShowLanguage(context)),
        const Divider(height: 1),
        _settingsTile(icon: Icons.public_outlined, iconColor: const Color(0xFF64748B), title: 'Country & Region', subtitle: p.selectedCountry, onTap: () => p.onShowCountryRegion(context)),
      ])));
  }

  // ── HEALTH MODE ──
  Widget _trackerCard(BuildContext context) {
    final items = [
      ('bloodPressure', Icons.favorite_border_rounded, 'Blood Pressure', const Color(0xFFEF4444)),
      ('bloodSugar', Icons.water_drop_outlined, 'Blood Sugar', const Color(0xFFF59E0B)),
      ('weight', Icons.monitor_weight_outlined, 'Weight', const Color(0xFF8B5CF6)),
      ('water', Icons.local_drink_outlined, 'Water Intake', const Color(0xFF14B8A6)),
      ('medication', Icons.medication_outlined, 'Medication', const Color(0xFF3B82F6)),
    ];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel('What to Track'), const SizedBox(height: 16),
          ...items.asMap().entries.map((e) {
            final i = e.key;
            final (key, icon, label, color) = e.value;
            final isOn = p.trackerToggles[key] ?? false;
            return Column(children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
                title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(isOn ? 'Currently tracking' : 'Not tracking', style: TextStyle(fontSize: 12, color: isOn ? const Color(0xFF10B981) : const Color(0xFF94A3B8))),
                trailing: Switch(value: isOn, onChanged: (v) => p.onTrackerToggle(key, v), activeThumbColor: AppColors.primaryColor),
              ),
              if (i < items.length - 1) const Divider(height: 1),
            ]);
          }),
        ]),
      ),
    );
  }

  Widget _healthModeCard(BuildContext context) {
    final conditions = ['Diabetes', 'Hypertension', 'Heart Disease', 'Asthma', 'Thyroid'];
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Health Mode'), const SizedBox(height: 16),
        ...conditions.map((c) { final sel = p.selectedConditions.contains(c); return Padding(padding: const EdgeInsets.only(bottom: 0), child: Column(children: [_switchTile(icon: Icons.monitor_heart_outlined, title: c, subtitle: sel ? 'Active' : 'Tap to enable', value: sel, onChanged: (v) => p.onHealthModeToggle(c, v)), if (c != conditions.last) const Divider(height: 1)])); }),
      ])));
  }

  // ── ABOUT ──
  Widget _aboutCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('About & Legal'), const SizedBox(height: 16),
        _settingsTile(icon: Icons.info_outline, iconColor: const Color(0xFF64748B), title: 'About Us', subtitle: 'Learn more about iCare', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutUs()))),
      ])));
  }

  // ── LOGOUT ──
  Widget _logoutButton(BuildContext context) {
    return Center(
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: p.onLogout,
          icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
          label: const Text('Logout', style: TextStyle(color: Color(0xFFEF4444), fontSize: 16, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFCA5A5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: const Color(0xFFFEF2F2),
          ),
        ),
      ),
    );
  }

  // ── REUSABLE ──
  Widget _sectionLabel(String title) {
    return Row(children: [const Icon(Icons.circle, size: 8, color: AppColors.primaryColor), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))]);
  }

  Widget _settingsTile({required IconData icon, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(contentPadding: EdgeInsets.zero, leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFCBD5E1)), onTap: onTap);
  }

  Widget _switchTile({required IconData icon, required String title, required String subtitle, required bool value, required void Function(bool) onChanged}) {
    return ListTile(contentPadding: EdgeInsets.zero, leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppColors.primaryColor, size: 20)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))), trailing: Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primaryColor));
  }

  Widget _comingSoonBanner(String feature) {
    return Container(width: double.infinity, margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: const Color(0xFFFEFCE8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFEF08A))), child: Row(children: [const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFFCA8A04)), const SizedBox(width: 10), Expanded(child: Text('$feature — Coming soon', style: const TextStyle(fontSize: 13, color: Color(0xFF854D0E))))]));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MOBILE LAYOUT
// ═══════════════════════════════════════════════════════════════════════════

class _MobileSettingsLayout extends StatelessWidget {
  final _SettingsLayoutParams p;
  const _MobileSettingsLayout({required this.p});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.w700)), centerTitle: true, backgroundColor: Colors.white, foregroundColor: AppColors.primaryColor, elevation: 0, surfaceTintColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ProfileEditCard(p: p), const SizedBox(height: 16),
        if (p.isDoctor) ...[_doctorProfessionalCard(context), const SizedBox(height: 16)],
        if (p.isPatient) ...[_healthProfile(context), const SizedBox(height: 16)],
        _notificationsCard(context), const SizedBox(height: 16),
        if (p.isPatient) ...[_waterReminderCard(context), const SizedBox(height: 16)],
        if (p.isPatient) ...[_rewardsCard(context), const SizedBox(height: 16)],
        if (p.isPatient) ...[_privacyCard(context), const SizedBox(height: 16)],
        if (p.isPatient) ...[_paymentCard(context), const SizedBox(height: 16)],
        _contactCard(context), const SizedBox(height: 16),
        if (p.isPatient) ...[_pharmacyCard(context), const SizedBox(height: 16)],
        if (p.isStudent || p.isInstructor) ...[_learningCard(context), const SizedBox(height: 16)],
        _securityCard(context), const SizedBox(height: 16),
        if (p.isDoctor) ...[_notificationSettingsCard(context), const SizedBox(height: 16)],
        _languageCard(context), const SizedBox(height: 16),
        if (p.isPatient) ...[_trackerCard(context), const SizedBox(height: 16)],
        if (p.isPatient) ...[_healthModeCard(context), const SizedBox(height: 16)],
        _aboutCard(context), const SizedBox(height: 24),
        _logoutButton(context), const SizedBox(height: 24),
      ])),
    );
  }

  Widget _trackerCard(BuildContext context) {
    final items = [
      ('bloodPressure', Icons.favorite_border_rounded, 'Blood Pressure', const Color(0xFFEF4444)),
      ('bloodSugar', Icons.water_drop_outlined, 'Blood Sugar', const Color(0xFFF59E0B)),
      ('weight', Icons.monitor_weight_outlined, 'Weight', const Color(0xFF8B5CF6)),
      ('water', Icons.local_drink_outlined, 'Water Intake', const Color(0xFF14B8A6)),
      ('medication', Icons.medication_outlined, 'Medication', const Color(0xFF3B82F6)),
    ];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel('What to Track'), const SizedBox(height: 12),
          ...items.asMap().entries.map((e) {
            final i = e.key;
            final (key, icon, label, color) = e.value;
            final isOn = p.trackerToggles[key] ?? false;
            return Column(children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
                title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(isOn ? 'Tracking' : 'Not tracking', style: TextStyle(fontSize: 11, color: isOn ? const Color(0xFF10B981) : const Color(0xFF94A3B8))),
                trailing: Switch(value: isOn, onChanged: (v) => p.onTrackerToggle(key, v), activeThumbColor: AppColors.primaryColor, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                dense: true,
              ),
              if (i < items.length - 1) const Divider(height: 1),
            ]);
          }),
        ]),
      ),
    );
  }

  Widget _profileCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 28, backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
            backgroundImage: p.user?.profilePicture != null ? NetworkImage(p.user!.profilePicture!) : null,
            child: p.user?.profilePicture == null ? Text((p.user?.name ?? 'U').substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryColor)) : null),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.user?.name ?? 'User', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2), Text(p.user?.email ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ])),
        ]),
        const SizedBox(height: 14), const Divider(), const SizedBox(height: 10),
        _profileRow(Icons.person_outline, 'Gender', p.user?.gender ?? 'Not set'), const SizedBox(height: 6),
        _profileRow(Icons.calendar_today_outlined, 'Age', p.user?.age ?? 'Not set'), const SizedBox(height: 6),
        _profileRow(Icons.phone_outlined, 'Phone', p.user?.phoneNumber ?? 'Not set'), const SizedBox(height: 6),
        _profileRow(Icons.email_outlined, 'Email', p.user?.email ?? 'Not set'), const SizedBox(height: 6),
        if (p.isPatient) _profileRow(Icons.badge_outlined, 'MR Number', p.user?.mrNumber ?? 'N/A'),
      ])));
  }

  Widget _profileRow(IconData icon, String label, String value) {
    return Row(children: [Icon(icon, size: 16, color: const Color(0xFF64748B)), const SizedBox(width: 8), Text('$label: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))), Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))))]);
  }

  Widget _healthProfile(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Health Profile'), const SizedBox(height: 12),
        _settingsTile(icon: Icons.monitor_heart_outlined, iconColor: const Color(0xFFEF4444), title: 'Medical Conditions', subtitle: p.medicalConditions.isEmpty ? 'Tap to add' : p.medicalConditions, onTap: () => p.onShowMedicalConditions(context)),
        const Divider(height: 1),
        _settingsTile(icon: Icons.warning_amber_rounded, iconColor: const Color(0xFFF59E0B), title: 'Allergies', subtitle: p.allergies.isEmpty ? 'Tap to add' : p.allergies, onTap: () => p.onShowAllergies(context)),
        const Divider(height: 1),
        _settingsTile(icon: Icons.medication_outlined, iconColor: const Color(0xFF8B5CF6), title: 'Current Medications', subtitle: p.currentMedications.isEmpty ? 'Tap to add' : p.currentMedications, onTap: () => p.onShowCurrentMedications(context)),
        const Divider(height: 1),
        _settingsTile(icon: Icons.flag_outlined, iconColor: const Color(0xFF10B981), title: 'Health Goals', subtitle: p.healthGoals.isEmpty ? 'Tap to set goals' : p.healthGoals, onTap: () => p.onShowHealthGoals(context)),
      ])));
  }

  Widget _notificationsCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Notifications'), const SizedBox(height: 12),
        _switchTile(icon: Icons.calendar_today_outlined, title: 'Booking Updates', subtitle: 'Appointment confirmations & changes', value: true, onChanged: (_) {}),
        const Divider(height: 1), _switchTile(icon: Icons.message_outlined, title: 'Doctor Messages', subtitle: 'Messages from providers', value: true, onChanged: (_) {}),
        const Divider(height: 1), _switchTile(icon: Icons.local_offer_outlined, title: 'Promotions & Offers', subtitle: 'Special deals', value: false, onChanged: (_) {}),
        const Divider(height: 1), _switchTile(icon: Icons.volume_up_outlined, title: 'Sound Notifications', subtitle: 'Play sound', value: true, onChanged: (_) {}),
        const Divider(height: 1), _switchTile(icon: Icons.email_outlined, title: 'Send Prescription to Email', subtitle: 'Auto email prescriptions', value: true, onChanged: (_) {}),
      ])));
  }

  Widget _waterReminderCard(BuildContext context) {
    final labels = {'30': '30 min', '60': '1 hr', '120': '2 hrs', '180': '3 hrs'};
    final label = labels[p.waterReminderMinutes.toString()] ?? '1 hr';
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Water Reminders'), const SizedBox(height: 12),
        _settingsTile(icon: Icons.water_drop_outlined, iconColor: const Color(0xFF3B82F6), title: 'Remind me every', subtitle: label, onTap: () => p.onShowWaterReminder(context)),
      ])));
  }

  Widget _rewardsCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Rewards & Points'), const SizedBox(height: 12),
        _settingsTile(icon: Icons.stars_outlined, iconColor: const Color(0xFFF59E0B), title: 'Reward Points', subtitle: 'Coming soon', onTap: () => p.onComingSoon(context, 'Reward Points')),
        const Divider(height: 1), _settingsTile(icon: Icons.history_outlined, iconColor: const Color(0xFFF59E0B), title: 'Reward History', subtitle: 'Coming soon', onTap: () => p.onComingSoon(context, 'Reward History')),
        const Divider(height: 1), _settingsTile(icon: Icons.swap_horiz_outlined, iconColor: const Color(0xFFF59E0B), title: 'Redemption History', subtitle: 'Coming soon', onTap: () => p.onComingSoon(context, 'Redemption History')),
      ])));
  }

  Widget _privacyCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Privacy & Data'), const SizedBox(height: 12),
        _settingsTile(icon: Icons.download_outlined, iconColor: const Color(0xFF8B5CF6), title: 'Download Health Data', subtitle: 'Export all records', onTap: () => p.onDownloadHealthData(context)),
      ])));
  }

  Widget _paymentCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Payment & Subscription'), const SizedBox(height: 12),
        _settingsTile(icon: Icons.credit_card_outlined, iconColor: const Color(0xFF10B981), title: 'Saved Payment Methods', subtitle: p.savedPaymentMethods.isEmpty ? 'No methods saved' : '${p.savedPaymentMethods.length} method(s)', onTap: () => p.onShowPaymentMethods(context)),
        const Divider(height: 1), _settingsTile(icon: Icons.receipt_long_outlined, iconColor: const Color(0xFF10B981), title: 'Billing History', subtitle: p.billingHistory.isEmpty ? 'View transactions' : '${p.billingHistory.length} transaction(s)', onTap: () => p.onShowBillingHistory(context)),
      ])));
  }

  Widget _contactCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Contact & Legal'), const SizedBox(height: 12),
        _settingsTile(icon: Icons.headset_mic_outlined, iconColor: const Color(0xFF6366F1), title: 'Contact Support', subtitle: 'Get help', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpAndSupport()))),
        const Divider(height: 1), _settingsTile(icon: Icons.help_outline, iconColor: const Color(0xFF6366F1), title: 'FAQ', subtitle: 'Frequently asked questions', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpAndSupport()))),
        const Divider(height: 1), _settingsTile(icon: Icons.bug_report_outlined, iconColor: const Color(0xFFEF4444), title: 'Report an Issue', subtitle: 'Report bugs', onTap: () => p.onReportIssue(context)),
        const Divider(height: 1), _settingsTile(icon: Icons.description_outlined, iconColor: const Color(0xFF64748B), title: 'Terms & Conditions', subtitle: 'Review terms', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsAndConditions()))),
        const Divider(height: 1), _settingsTile(icon: Icons.privacy_tip_outlined, iconColor: const Color(0xFF64748B), title: 'Privacy Policy', subtitle: 'Data handling', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicy()))),
      ])));
  }

  Widget _pharmacyCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Pharmacy Settings'), const SizedBox(height: 12),
        _settingsTile(icon: Icons.location_on_outlined, iconColor: const Color(0xFF10B981), title: 'Save Delivery Address', subtitle: p.savedDeliveryAddress.isEmpty ? 'Tap to add' : p.savedDeliveryAddress, onTap: () => p.onShowDeliveryAddress(context)),
        const Divider(height: 1), _settingsTile(icon: Icons.shopping_bag_outlined, iconColor: const Color(0xFF3B82F6), title: 'Order History', subtitle: 'View orders', onTap: () => p.onComingSoon(context, 'Order History')),
        const Divider(height: 1), _settingsTile(icon: Icons.local_shipping_outlined, iconColor: const Color(0xFF8B5CF6), title: 'Delivery Preferences', subtitle: 'Set instructions', onTap: () => p.onShowDeliveryAddress(context)),
      ])));
  }

  Widget _learningCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Learning'), const SizedBox(height: 12),
        _settingsTile(icon: Icons.book_outlined, iconColor: const Color(0xFF6366F1), title: 'Enrolled Courses', subtitle: 'View courses', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Courses()))),
        const Divider(height: 1), _settingsTile(icon: Icons.verified_outlined, iconColor: const Color(0xFF10B981), title: 'Certificates', subtitle: 'Earned certificates', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CertificatesScreen()))),
        const Divider(height: 1), _settingsTile(icon: Icons.trending_up_outlined, iconColor: const Color(0xFF8B5CF6), title: 'Progress Tracking', subtitle: 'Track progress', onTap: () => p.onComingSoon(context, 'Progress Tracking')),
        const Divider(height: 1), _switchTile(icon: Icons.notifications_active_outlined, title: 'Notifications for New Courses', subtitle: 'Get notified', value: false, onChanged: (_) {}),
      ])));
  }

  Widget _securityCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Security'), const SizedBox(height: 12),
        _settingsTile(icon: Icons.lock_outline, iconColor: const Color(0xFF64748B), title: 'Change Password', subtitle: 'Update password', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePassword()))),
        const Divider(height: 1), _settingsTile(icon: Icons.history_outlined, iconColor: const Color(0xFF64748B), title: 'Login Activity', subtitle: 'Review sessions', onTap: () => p.onComingSoon(context, 'Login Activity')),
        // Biometric — shown for all roles if device supports it
        if (p.biometricAvailable) ...[
          const Divider(height: 1), _switchTile(icon: Icons.fingerprint, title: 'Biometric Sign-In', subtitle: p.isBiometricEnabled ? 'Tap to disable' : 'Enable fingerprint / Face ID', value: p.isBiometricEnabled, onChanged: p.onToggleBiometrics),
        ],
        if (p.isPatient) ...[
          const Divider(height: 1), _switchTile(icon: Icons.verified_user_outlined, title: '2FA', subtitle: p.is2FAEnabled ? 'Enabled' : 'Extra security', value: p.is2FAEnabled, onChanged: p.onToggle2FA),
        ],
      ])));
  }

  Widget _notificationSettingsCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Notifications'), const SizedBox(height: 12),
        _settingsTile(icon: Icons.notifications_active_outlined, iconColor: const Color(0xFF3B82F6), title: 'Notification Settings', subtitle: 'Manage preferences', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettings()))),
      ])));
  }

  // ── DOCTOR PROFESSIONAL SETTINGS ──
  Widget _doctorProfessionalCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel('Professional Settings'),
          const SizedBox(height: 12),
          _settingsTile(
            icon: Icons.attach_money_rounded,
            iconColor: const Color(0xFF10B981),
            title: 'Consultation Fee',
            subtitle: 'Set your consultation fee (Rs.)',
            onTap: () => p.onShowFeeDialog(context),
          ),
          const Divider(height: 1),
          _settingsTile(
            icon: Icons.calendar_month_outlined,
            iconColor: const Color(0xFF6366F1),
            title: 'Availability & Schedule',
            subtitle: 'Manage working hours & days',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorAvailability())),
          ),
          const Divider(height: 1),
          _settingsTile(
            icon: Icons.badge_outlined,
            iconColor: const Color(0xFF0EA5E9),
            title: 'Medical License',
            subtitle: 'View & update license details',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorProfileSetup())),
          ),
        ]),
      ),
    );
  }

  Widget _languageCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Language & Region'), const SizedBox(height: 12),
        _settingsTile(icon: Icons.translate_rounded, iconColor: const Color(0xFF64748B), title: 'Language', subtitle: p.selectedLanguage, onTap: () => p.onShowLanguage(context)),
        const Divider(height: 1), _settingsTile(icon: Icons.public_outlined, iconColor: const Color(0xFF64748B), title: 'Country & Region', subtitle: p.selectedCountry, onTap: () => p.onShowCountryRegion(context)),
      ])));
  }

  Widget _healthModeCard(BuildContext context) {
    final conditions = ['Diabetes', 'Hypertension', 'Heart Disease', 'Asthma', 'Thyroid'];
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Health Mode'), const SizedBox(height: 12),
        ...conditions.map((c) { final sel = p.selectedConditions.contains(c); return Padding(padding: const EdgeInsets.only(bottom: 0), child: Column(children: [_switchTile(icon: Icons.monitor_heart_outlined, title: c, subtitle: sel ? 'Active' : 'Tap to enable', value: sel, onChanged: (v) => p.onHealthModeToggle(c, v)), if (c != conditions.last) const Divider(height: 1)])); }),
      ])));
  }

  Widget _aboutCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('About & Legal'), const SizedBox(height: 12),
        _settingsTile(icon: Icons.info_outline, iconColor: const Color(0xFF64748B), title: 'About Us', subtitle: 'Learn about iCare', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutUs()))),
      ])));
  }

  Widget _logoutButton(BuildContext context) {
    return Center(
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: p.onLogout,
          icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
          label: const Text('Logout', style: TextStyle(color: Color(0xFFEF4444), fontSize: 16, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFCA5A5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: const Color(0xFFFEF2F2),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Row(children: [const Icon(Icons.circle, size: 7, color: AppColors.primaryColor), const SizedBox(width: 7), Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primaryColor))]);
  }

  Widget _settingsTile({required IconData icon, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(contentPadding: EdgeInsets.zero, leading: Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: iconColor, size: 18)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFCBD5E1)), onTap: onTap, dense: true);
  }

  Widget _switchTile({required IconData icon, required String title, required String subtitle, required bool value, required void Function(bool) onChanged}) {
    return ListTile(contentPadding: EdgeInsets.zero, leading: Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: AppColors.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: AppColors.primaryColor, size: 18)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))), trailing: Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primaryColor, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap), dense: true);
  }

  Widget _mobileComingSoon(String feature, IconData icon) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFFEFCE8), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFEF08A))), child: Row(children: [Icon(icon, size: 20, color: const Color(0xFFCA8A04)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(feature, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF854D0E))), const SizedBox(height: 2), const Text('Coming soon', style: TextStyle(fontSize: 12, color: Color(0xFFA16207)))])), const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFFCA8A04))]));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROFILE EDIT CARD — Approach 2: Global Toggle (View ↔ Edit)
// ═══════════════════════════════════════════════════════════════════════════

class _ProfileEditCard extends StatefulWidget {
  final _SettingsLayoutParams p;
  const _ProfileEditCard({required this.p});
  @override
  State<_ProfileEditCard> createState() => _ProfileEditCardState();
}

class _ProfileEditCardState extends State<_ProfileEditCard> {
  bool _editMode = false;
  bool _saving = false;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _ageCtrl;
  String? _gender;

  @override
  void initState() {
    super.initState();
    final u = widget.p.user;
    _nameCtrl  = TextEditingController(text: u?.name ?? '');
    _phoneCtrl = TextEditingController(text: u?.phoneNumber ?? '');
    _ageCtrl   = TextEditingController(text: u?.age ?? '');
    _gender    = (u?.gender?.isNotEmpty == true) ? u!.gender : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  void _cancelEdit() {
    final u = widget.p.user;
    setState(() {
      _editMode      = false;
      _nameCtrl.text  = u?.name ?? '';
      _phoneCtrl.text = u?.phoneNumber ?? '';
      _ageCtrl.text   = u?.age ?? '';
      _gender         = (u?.gender?.isNotEmpty == true) ? u!.gender : null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ApiService().put('/users/profile', {
        'name': _nameCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'age': _ageCtrl.text.trim(),
        if (_gender != null) 'gender': _gender,
      });
      setState(() { _editMode = false; _saving = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Update failed. Please try again.'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.p.user;
    final name   = _nameCtrl.text.isNotEmpty  ? _nameCtrl.text  : (u?.name ?? 'Not set');
    final phone  = _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text : (u?.phoneNumber ?? 'Not set');
    final age    = _ageCtrl.text.isNotEmpty   ? _ageCtrl.text   : (u?.age ?? 'Not set');
    final gender = _gender ?? u?.gender ?? 'Not set';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar + name + email ───────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                    backgroundImage: u?.profilePicture != null ? NetworkImage(u!.profilePicture!) : null,
                    child: u?.profilePicture == null
                        ? Text((u?.name ?? 'U').substring(0, 1).toUpperCase(),
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primaryColor))
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        const SizedBox(height: 3),
                        Text(u?.email ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  // Edit toggle button (only visible in view mode)
                  // Doctors → open DoctorProfileSetup. Others → inline edit mode.
                  if (!_editMode)
                    TextButton.icon(
                      onPressed: () {
                        if (widget.p.isDoctor) {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const DoctorProfileSetup(),
                          ));
                        } else {
                          setState(() => _editMode = true);
                        }
                      },
                      icon: const Icon(Icons.edit_rounded, size: 15),
                      label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryColor,
                        backgroundColor: AppColors.primaryColor.withValues(alpha: 0.07),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 18),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              // ── VIEW MODE ────────────────────────────────────────────────
              if (!_editMode) ...[
                _viewRow(Icons.person_outline_rounded,       'Full Name',    name),
                _viewRow(Icons.phone_outlined,               'Phone',        phone),
                _viewRow(Icons.cake_rounded,                 'Age',          age),
                _viewRow(Icons.wc_rounded,                   'Gender',       gender),
                _viewRow(Icons.email_outlined,               'Email',        u?.email ?? 'Not set'),
              ],

              // ── EDIT MODE ────────────────────────────────────────────────
              if (_editMode) ...[
                _editField('Full Name',    _nameCtrl,  Icons.person_outline_rounded, hint: 'Your full name'),
                const SizedBox(height: 14),
                _editField('Phone Number', _phoneCtrl, Icons.phone_outlined,         hint: '+92 300 0000000', type: TextInputType.phone),
                const SizedBox(height: 14),
                _editField('Age',          _ageCtrl,   Icons.cake_rounded,           hint: 'e.g. 30',         type: TextInputType.number),
                const SizedBox(height: 14),

                // Gender dropdown
                _fieldLabel('Gender'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  hint: const Text('Select gender', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                  decoration: _inputDeco(Icons.wc_rounded),
                  items: ['Male', 'Female', 'Other']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setState(() => _gender = v),
                ),

                const SizedBox(height: 24),

                // ── Action buttons ─────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _cancelEdit,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Update Profile', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _viewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: const Color(0xFF64748B)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl, IconData icon, {String? hint, TextInputType? type}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: type,
          decoration: _inputDeco(icon, hint: hint),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label) {
    return Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)));
  }

  InputDecoration _inputDeco(IconData icon, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}