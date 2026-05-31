import 'package:easy_localization/easy_localization.dart';
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
import 'package:icare/screens/current_medications_page.dart';
import 'package:icare/screens/notification_settings.dart' show NotificationSettings;
import 'package:icare/screens/privacy_policy.dart' show PrivacyPolicy;
import 'package:icare/screens/terms_and_conditions.dart' show TermsAndConditions;
import 'package:icare/utils/theme.dart';
import 'package:icare/services/security_service.dart';
import 'package:icare/services/biometric_service.dart';
import 'package:icare/services/health_settings_service.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/water_notif_stub.dart'
    if (dart.library.html) '../utils/water_notif_web.dart';

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
  List<Map<String, String>> _savedAddresses = [];
  String _savedDeliveryInstructions = '';

  final Map<String, bool> _trackerToggles = {
    'bloodPressure': true, 'bloodSugar': true, 'weight': false, 'water': true,
    'medication': true, 'steps': false, 'sleep': false, 'heartRate': true,
    'temperature': false, 'oxygenLevel': false,
  };

  bool _healthModeEnabled = false;
  List<String> _selectedConditions = [];
  final List<String> _savedPaymentMethods = [];
  final List<String> _billingHistory = [];

  // Billing & payment
  List<Map<String, dynamic>> _billingItems = [];
  bool _billingLoading = false;
  final List<Map<String, String>> _savedCards = [];

  @override
  void initState() {
    super.initState();
    _loadHealthSettings();
    _loadUserData();
    _loadBiometricState();
    _loadBillingItems();
    _loadSavedAddresses();
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
    final phoneC = TextEditingController();
    final fk = GlobalKey<FormState>();
    final authState = ref.read(authProvider);
    final user = authState.user;
    final userRole = authState.userRole ?? 'Patient';
    final userName = user?.name ?? '';
    final userEmail = user?.email ?? '';

    showDialog(context: ctx, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.bug_report_outlined, color: Color(0xFFEF4444), size: 22), SizedBox(width: 10), Text('Report an Issue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: 400, child: Form(key: fk, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Describe the issue you encountered and we\'ll investigate.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))), const SizedBox(height: 16),
        TextFormField(controller: TextEditingController(text: userRole)..selection = TextSelection.collapsed(offset: userRole.length), enabled: false, decoration: InputDecoration(labelText: 'Account Type', prefixIcon: const Icon(Icons.badge_outlined, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))), const SizedBox(height: 12),
        TextFormField(controller: TextEditingController(text: userName)..selection = TextSelection.collapsed(offset: userName.length), enabled: false, decoration: InputDecoration(labelText: 'Name', prefixIcon: const Icon(Icons.person_outline, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))), const SizedBox(height: 12),
        TextFormField(controller: TextEditingController(text: userEmail)..selection = TextSelection.collapsed(offset: userEmail.length), enabled: false, decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email_outlined, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))), const SizedBox(height: 12),
        TextFormField(controller: phoneC, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Phone Number', hintText: 'e.g. +923001234567', prefixIcon: const Icon(Icons.phone_outlined, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))), const SizedBox(height: 12),
        TextFormField(controller: titleC, decoration: InputDecoration(labelText: 'Issue Title', hintText: 'e.g. Login not working', prefixIcon: const Icon(Icons.title_outlined, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)), validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null), const SizedBox(height: 12),
        TextFormField(controller: descC, maxLines: 4, decoration: InputDecoration(labelText: 'Description', hintText: 'Tell us what happened in detail...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), alignLabelWithHint: true), validator: (v) => (v == null || v.trim().isEmpty) ? 'Please describe the issue' : null),
      ])))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
        ElevatedButton.icon(
          onPressed: () async {
            if (!fk.currentState!.validate()) return;
            Navigator.pop(dc);
            final subject = Uri.encodeComponent('[ICare Issue] ${titleC.text.trim()}');
            final body = Uri.encodeComponent(
              'Account Type: $userRole\n'
              'Name: $userName\n'
              'Email: $userEmail\n'
              'Phone: ${phoneC.text.trim()}\n\n'
              'Issue Title: ${titleC.text.trim()}\n\n'
              'Description:\n${descC.text.trim()}',
            );
            final mailUri = Uri.parse('mailto:icareofficialapp@gmail.com?subject=$subject&body=$body');
            if (await canLaunchUrl(mailUri)) {
              await launchUrl(mailUri);
            } else {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Could not open email app. Please email icareofficialapp@gmail.com directly.'), duration: Duration(seconds: 4)));
              }
            }
          },
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('Send via Email'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
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
    Navigator.of(ctx).push(
      MaterialPageRoute(builder: (_) => const CurrentMedicationsPage()),
    );
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
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))), ElevatedButton(onPressed: () { setState(() => _waterReminderMinutes = selected); Navigator.pop(dc); _setupWaterReminder(selected); ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Water reminder set to every ${labels[intervals.indexOf(selected)]}'), backgroundColor: Colors.green)); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Set Reminder'))],
    )));
  }

  Future<void> _setupWaterReminder(int minutes) async {
    try {
      final permission = await requestWaterNotifPermission();
      if (permission == 'granted') {
        scheduleWaterReminderInterval(minutes);
      } else if (permission == 'denied') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Notifications blocked. Please enable in browser site settings.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ));
        }
      }
    } catch (_) {}
  }

  Future<void> _loadBillingItems() async {
    if (!mounted) return;
    setState(() => _billingLoading = true);
    final items = <Map<String, dynamic>>[];
    final api = ApiService();

    // Consultations (raw JSON to access consultation_fee)
    try {
      final res = await api.get('/appointments/getAppointments');
      final appts = (res.data['appointments'] as List? ?? []);
      for (final a in appts) {
        final fee = a['consultation_fee'];
        final doctor = a['doctor_name'] ?? a['doctorName'] ?? 'Doctor';
        items.add({
          'id': a['_id'] ?? a['id'] ?? '',
          'type': 'consultation',
          'title': 'Consultation with Dr. $doctor',
          'amount': fee != null && fee != 0 ? 'PKR $fee' : '',
          'amountNum': fee ?? 0,
          'date': a['date'] ?? a['created_at'] ?? a['createdAt'] ?? '',
          'icon': Icons.medical_services_outlined,
          'color': const Color(0xFF3B82F6),
        });
      }
    } catch (_) {}

    // Lab bookings
    try {
      final res = await api.get('/laboratories/bookings/my');
      final bookings = (res.data['bookings'] as List? ?? []);
      for (final b in bookings) {
        final testName = b['testType'] ?? b['test_type'] ?? 'Lab Test';
        final lab = (b['laboratory'] is Map ? b['laboratory']['labName'] : null) ?? b['labName'] ?? 'Laboratory';
        final price = b['price'] ?? 0;
        items.add({
          'id': b['_id'] ?? '',
          'type': 'lab_test',
          'title': '$testName — $lab',
          'amount': price != 0 ? 'PKR $price' : '',
          'amountNum': price,
          'date': b['createdAt'] ?? b['test_date'] ?? b['date'] ?? '',
          'icon': Icons.science_outlined,
          'color': const Color(0xFF10B981),
        });
      }
    } catch (_) {}

    // Medicine orders
    try {
      final res = await api.get('/pharmacy/orders');
      final orders = (res.data['orders'] as List? ?? []);
      for (final o in orders) {
        final amount = o['total_amount'] ?? o['totalAmount'] ?? 0;
        final itemNames = (o['items'] as List? ?? []).take(3).map((i) => i is Map ? (i['name'] ?? i['product_name'] ?? '') : '').where((s) => s.toString().isNotEmpty).join(', ');
        items.add({
          'id': o['_id'] ?? '',
          'type': 'medicine',
          'title': itemNames.isNotEmpty ? 'Medicine: $itemNames' : 'Medicine Order #${(o['order_number'] ?? '').toString().split('-').last}',
          'amount': amount != 0 ? 'PKR $amount' : '',
          'amountNum': amount,
          'date': o['createdAt'] ?? o['created_at'] ?? '',
          'icon': Icons.medication_outlined,
          'color': const Color(0xFF8B5CF6),
        });
      }
    } catch (_) {}

    items.sort((a, b) {
      try { return DateTime.parse(b['date'].toString()).compareTo(DateTime.parse(a['date'].toString())); }
      catch (_) { return 0; }
    });

    if (mounted) setState(() { _billingItems = items; _billingLoading = false; });
  }

  void _showLanguageDialog(BuildContext ctx) {
    final currentLang = ctx.locale.languageCode == 'ur' ? 'ur' : 'en';
    String selected = currentLang;
    final langs = [
      {'code': 'en', 'label': 'English', 'native': 'English'},
      {'code': 'ur', 'label': 'اردو', 'native': 'Urdu'},
    ];
    showDialog(context: ctx, builder: (dc) => StatefulBuilder(builder: (_, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.translate_rounded, color: Color(0xFF64748B), size: 22), SizedBox(width: 10), Text('Language / زبان', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: 340, child: Column(mainAxisSize: MainAxisSize.min, children: [
        ...langs.map((lang) {
          final isSel = selected == lang['code'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => setS(() => selected = lang['code']!),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSel ? AppColors.primaryColor : const Color(0xFFE2E8F0), width: isSel ? 2 : 1),
                ),
                child: Row(children: [
                  Icon(isSel ? Icons.radio_button_checked : Icons.radio_button_off, color: isSel ? AppColors.primaryColor : const Color(0xFFCBD5E1), size: 20),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(lang['label']!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isSel ? const Color(0xFF1E293B) : const Color(0xFF475569))),
                    if (lang['code'] == 'ur') const Text('All app text will switch to Urdu', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ])),
                  if (isSel) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.primaryColor, borderRadius: BorderRadius.circular(20)), child: const Text('Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
                ]),
              ),
            ),
          );
        }),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(dc);
            final locale = selected == 'ur' ? const Locale('ur') : const Locale('en');
            await ctx.setLocale(locale);
            setState(() => _selectedLanguage = selected == 'ur' ? 'اردو' : 'English');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(selected == 'ur' ? 'زبان اردو میں تبدیل ہو گئی' : 'Language set to English'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Apply'),
        ),
      ],
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

  Future<void> _loadSavedAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('saved_delivery_addresses') ?? '[]';
      final decoded = jsonDecode(raw) as List? ?? [];
      if (mounted) setState(() => _savedAddresses = decoded.map((e) => Map<String, String>.from(e as Map)).toList());
      final instr = prefs.getString('delivery_instructions') ?? '';
      if (mounted) setState(() => _savedDeliveryInstructions = instr);
    } catch (_) {}
  }

  Future<void> _saveSavedAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_delivery_addresses', jsonEncode(_savedAddresses));
    } catch (_) {}
  }

  void _showDeliveryAddressesDialog(BuildContext ctx) {
    showDialog(context: ctx, builder: (dc) => StatefulBuilder(builder: (dc2, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.location_on_outlined, color: Color(0xFF10B981), size: 22), SizedBox(width: 10), Expanded(child: Text('Saved Addresses', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)))]),
      content: SizedBox(width: 440, height: 340, child: _savedAddresses.isEmpty
        ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.location_off_outlined, size: 48, color: Color(0xFFCBD5E1)),
            SizedBox(height: 12),
            Text('No saved addresses yet', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
            SizedBox(height: 6),
            Text('Tap "+ Add New" to add an address', style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
          ]))
        : ListView.separated(
            itemCount: _savedAddresses.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final addr = _savedAddresses[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.location_on_outlined, color: Color(0xFF10B981), size: 18)),
                title: Text(addr['label'] ?? 'Address ${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text('${addr['street'] ?? ''}${(addr['city'] ?? '').isNotEmpty ? ', ${addr['city']}' : ''}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)), onPressed: () {
                  setState(() => _savedAddresses.removeAt(i));
                  setS(() {});
                  _saveSavedAddresses();
                }),
              );
            },
          )),
      actions: [
        TextButton(onPressed: () { Navigator.pop(dc); _showAddAddressDialog(ctx); }, child: const Text('+ Add New', style: TextStyle(color: Color(0xFF0036BC), fontWeight: FontWeight.w600))),
        TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Close', style: TextStyle(color: Color(0xFF64748B)))),
      ],
    )));
  }

  void _showAddAddressDialog(BuildContext ctx) {
    final labelCtrl = TextEditingController();
    final streetCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    showDialog(context: ctx, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.add_location_alt_outlined, color: Color(0xFF10B981), size: 22), SizedBox(width: 10), Text('Add New Address', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: labelCtrl, decoration: InputDecoration(labelText: 'Label (e.g. Home, Office)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
        const SizedBox(height: 12),
        TextField(controller: streetCtrl, maxLines: 2, decoration: InputDecoration(labelText: 'Street Address', hintText: 'House #, Street, Area', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
        const SizedBox(height: 12),
        TextField(controller: cityCtrl, decoration: InputDecoration(labelText: 'City', hintText: 'e.g. Lahore', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
        ElevatedButton(
          onPressed: () {
            final street = streetCtrl.text.trim();
            if (street.isEmpty) return;
            final label = labelCtrl.text.trim().isEmpty ? 'Address ${_savedAddresses.length + 1}' : labelCtrl.text.trim();
            setState(() => _savedAddresses.add({'label': label, 'street': street, 'city': cityCtrl.text.trim()}));
            _saveSavedAddresses();
            Navigator.pop(dc);
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Address saved!'), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Save Address'),
        ),
      ],
    ));
  }

  void _showOrderHistoryDialog(BuildContext ctx) {
    final future = ApiService().get('/pharmacy/orders');
    showDialog(context: ctx, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.shopping_bag_outlined, color: Color(0xFF3B82F6), size: 22), SizedBox(width: 10), Text('Order History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: 480, height: 400, child: FutureBuilder(
        future: future,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final orders = snap.data?.data['orders'] as List? ?? [];
          if (orders.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.shopping_bag_outlined, size: 48, color: Color(0xFFCBD5E1)),
            SizedBox(height: 12),
            Text('No pharmacy orders yet', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
          ]));
          return ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final o = orders[i];
              final amount = o['total_amount'] ?? o['totalAmount'] ?? 0;
              final status = (o['status'] ?? 'placed').toString();
              final rawDate = o['createdAt'] ?? o['created_at'] ?? '';
              String fmtDate = '';
              try { final dt = DateTime.parse(rawDate.toString()); fmtDate = '${dt.day}/${dt.month}/${dt.year}'; } catch (_) { fmtDate = rawDate.toString(); }
              final itemNames = (o['items'] as List? ?? []).take(2).map((item) => item is Map ? (item['name'] ?? item['product_name'] ?? '').toString() : '').where((s) => s.isNotEmpty).join(', ');
              final statusColor = status == 'delivered' ? Colors.green : (status == 'cancelled' ? Colors.red : const Color(0xFFF59E0B));
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.medication_outlined, color: Color(0xFF3B82F6), size: 18)),
                title: Text(itemNames.isNotEmpty ? itemNames : 'Order #${(o['order_number'] ?? o['_id'] ?? '').toString().split('-').last}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fmtDate, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 3),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor))),
                ]),
                trailing: amount != 0 ? Text('PKR $amount', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))) : null,
                isThreeLine: true,
              );
            },
          );
        },
      )),
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))))],
    ));
  }

  void _showDeliveryPreferencesDialog(BuildContext ctx) {
    final ctrl = TextEditingController(text: _savedDeliveryInstructions);
    showDialog(context: ctx, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.local_shipping_outlined, color: Color(0xFF8B5CF6), size: 22), SizedBox(width: 10), Text('Delivery Preferences', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Delivery Instructions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('e.g. Leave at door, Ring bell twice, Call on arrival', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        const SizedBox(height: 12),
        TextField(controller: ctrl, maxLines: 3, decoration: InputDecoration(hintText: 'Add special instructions for delivery...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.all(12))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
        ElevatedButton(
          onPressed: () async {
            final text = ctrl.text.trim();
            setState(() => _savedDeliveryInstructions = text);
            if (dc.mounted) Navigator.pop(dc);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery preferences saved!'), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
            try { final prefs = await SharedPreferences.getInstance(); await prefs.setString('delivery_instructions', text); } catch (_) {}
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Save'),
        ),
      ],
    ));
  }

  void _downloadHealthData(BuildContext ctx) {
    showDialog(context: ctx, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.download_outlined, color: Color(0xFF8B5CF6), size: 22), SizedBox(width: 10), Text('Download Health Data', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: const SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('A PDF will be generated with all your health records sorted by date.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        SizedBox(height: 12),
        Text('Includes: Consultations, Prescriptions, Lab Tests, Medicine Orders', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))), ElevatedButton.icon(onPressed: () { Navigator.pop(dc); _generateHealthDataPdf(ctx); }, icon: const Icon(Icons.download_rounded, size: 16), label: const Text('Download PDF'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))],
    ));
  }

  Future<void> _generateHealthDataPdf(BuildContext ctx) async {
    try {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Preparing your health data PDF...'), backgroundColor: Colors.blue, duration: Duration(seconds: 3)));

      final api = ApiService();

      // Fetch all data using raw JSON to access all backend fields
      List appts = [];
      List labBookings = [];
      List orders = [];
      try { final r = await api.get('/appointments/getAppointments'); appts = r.data['appointments'] as List? ?? []; } catch (_) {}
      try { final r = await api.get('/laboratories/bookings/my'); labBookings = r.data['bookings'] as List? ?? []; } catch (_) {}
      try { final r = await api.get('/pharmacy/orders'); orders = r.data['orders'] as List? ?? []; } catch (_) {}

      final user = ref.read(authProvider).user;
      final patientName = user?.name ?? 'Patient';
      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year}';

      pw.ImageProvider? logoImage;
      try { final bytes = await rootBundle.load('assets/Asset 1.png'); logoImage = pw.MemoryImage(bytes.buffer.asUint8List()); } catch (_) {}

      String _fmt(dynamic rawDate) {
        try { final dt = DateTime.parse(rawDate.toString()); return '${dt.day}/${dt.month}/${dt.year}'; } catch (_) { return rawDate?.toString() ?? ''; }
      }

      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Column(children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            logoImage != null
              ? pw.Container(width: 50, height: 50, child: pw.Image(logoImage, fit: pw.BoxFit.contain))
              : pw.Text('iCare', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Health Data Report', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(patientName, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              pw.Text('Generated: $dateStr', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
            ]),
          ]),
          pw.Divider(),
        ]),
        build: (_) {
          final widgets = <pw.Widget>[];
          widgets.add(pw.SizedBox(height: 8));

          // ── Consultations ──
          if (appts.isNotEmpty) {
            widgets.add(pw.Text('Consultations (${appts.length})', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)));
            widgets.add(pw.SizedBox(height: 8));
            for (final a in appts) {
              final doctor = a['doctor_name'] ?? a['doctorName'] ?? 'Doctor';
              final fee = a['consultation_fee'];
              final feeStr = fee != null && fee != 0 ? 'PKR $fee' : 'N/A';
              widgets.add(pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 5),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('Dr. $doctor', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text('Date: ${_fmt(a['date'] ?? a['createdAt'])}  |  Status: ${a['status'] ?? ''}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
                  ])),
                  pw.Text(feeStr, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                ]),
              ));
            }
            widgets.add(pw.SizedBox(height: 12));
          }

          // ── Lab Tests ──
          if (labBookings.isNotEmpty) {
            widgets.add(pw.Text('Lab Tests (${labBookings.length})', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)));
            widgets.add(pw.SizedBox(height: 8));
            for (final b in labBookings) {
              final testName = b['testType'] ?? b['test_type'] ?? 'Lab Test';
              final labName = (b['laboratory'] is Map ? b['laboratory']['labName'] : null) ?? b['labName'] ?? 'Lab';
              final price = b['price'] ?? 0;
              widgets.add(pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 5),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(testName.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text('Lab: $labName  |  Date: ${_fmt(b['createdAt'] ?? b['test_date'])}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
                  ])),
                  pw.Text(price != 0 ? 'PKR $price' : 'N/A', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                ]),
              ));
            }
            widgets.add(pw.SizedBox(height: 12));
          }

          // ── Medicine Orders ──
          if (orders.isNotEmpty) {
            widgets.add(pw.Text('Medicine Orders (${orders.length})', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.purple)));
            widgets.add(pw.SizedBox(height: 8));
            for (final o in orders) {
              final amount = o['total_amount'] ?? o['totalAmount'] ?? 0;
              final status = o['status'] ?? 'placed';
              final itemNames = (o['items'] as List? ?? []).take(3).map((i) => i is Map ? (i['name'] ?? i['product_name'] ?? '') : '').where((s) => s.toString().isNotEmpty).join(', ');
              widgets.add(pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 5),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(itemNames.isNotEmpty ? itemNames : 'Medicine Order', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text('Date: ${_fmt(o['createdAt'])}  |  Status: $status', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
                  ])),
                  pw.Text(amount != 0 ? 'PKR $amount' : 'N/A', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.purple)),
                ]),
              ));
            }
          }

          if (appts.isEmpty && labBookings.isEmpty && orders.isEmpty) {
            widgets.add(pw.Center(child: pw.Text('No health records found.', style: const pw.TextStyle(color: PdfColors.grey))));
          }

          return widgets;
        },
      ));

      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'iCare_Health_Data_${patientName.replaceAll(' ', '_')}_$dateStr.pdf',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('PDF generation failed: $e'), backgroundColor: Colors.red));
    }
  }

  void _showPaymentMethodsDialog(BuildContext ctx) {
    showDialog(context: ctx, builder: (dc) => StatefulBuilder(builder: (dc2, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.credit_card_outlined, color: Color(0xFF10B981), size: 22), SizedBox(width: 10), Text('Payment Methods', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Saved cards', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))), const SizedBox(height: 12),
        if (_savedCards.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: Text('No cards saved yet', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)))))
        else
          ...List.generate(_savedCards.length, (i) {
            final card = _savedCards[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Row(children: [
                const Icon(Icons.credit_card_rounded, color: Color(0xFF10B981), size: 22),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('**** **** **** ${card['last4']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('${card['name']}  |  Exp: ${card['expiry']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ])),
                IconButton(icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18), onPressed: () { setState(() => _savedCards.removeAt(i)); setS(() {}); }),
              ]),
            );
          }),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () { Navigator.pop(dc); _showAddCardDialog(ctx); },
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Payment Method'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))))],
    )));
  }

  void _showAddCardDialog(BuildContext ctx) {
    final cardNumberCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final expiryCtrl = TextEditingController();
    final cvvCtrl = TextEditingController();
    String selectedType = 'Visa';
    final cardTypes = ['Visa', 'Mastercard', 'PayPak', 'UnionPay'];

    showDialog(context: ctx, builder: (dc) => StatefulBuilder(builder: (dc2, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.add_card_outlined, color: Color(0xFF10B981), size: 22), SizedBox(width: 10), Text('Add Payment Method', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Card Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))), const SizedBox(height: 8),
        Wrap(spacing: 8, children: cardTypes.map((t) => ChoiceChip(
          label: Text(t, style: TextStyle(fontSize: 12, color: selectedType == t ? Colors.white : const Color(0xFF475569))),
          selected: selectedType == t,
          onSelected: (_) => setS(() => selectedType = t),
          selectedColor: AppColors.primaryColor,
          backgroundColor: const Color(0xFFF1F5F9),
        )).toList()),
        const SizedBox(height: 14),
        TextField(controller: cardNumberCtrl, keyboardType: TextInputType.number, maxLength: 19, decoration: InputDecoration(labelText: 'Card Number', hintText: '0000 0000 0000 0000', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), prefixIcon: const Icon(Icons.credit_card_rounded, size: 18))),
        const SizedBox(height: 10),
        TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Card Holder Name', hintText: 'Ali Ahmed', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), prefixIcon: const Icon(Icons.person_outline_rounded, size: 18))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: expiryCtrl, keyboardType: TextInputType.number, maxLength: 5, decoration: InputDecoration(labelText: 'Expiry (MM/YY)', hintText: '12/28', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: cvvCtrl, keyboardType: TextInputType.number, maxLength: 4, obscureText: true, decoration: InputDecoration(labelText: 'CVV', hintText: '***', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)))),
        ]),
        const SizedBox(height: 8),
        const Row(children: [Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF94A3B8)), SizedBox(width: 4), Text('Your card details are stored securely', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))]),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
        ElevatedButton(
          onPressed: () {
            final num = cardNumberCtrl.text.replaceAll(' ', '');
            if (num.length < 13 || nameCtrl.text.isEmpty || expiryCtrl.text.isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please fill in all fields'), backgroundColor: Colors.red));
              return;
            }
            setState(() => _savedCards.add({'last4': num.length >= 4 ? num.substring(num.length - 4) : num, 'name': nameCtrl.text, 'expiry': expiryCtrl.text, 'type': selectedType}));
            Navigator.pop(dc);
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$selectedType card added successfully'), backgroundColor: Colors.green));
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Save Card'),
        ),
      ],
    )));
  }

  void _showBillingHistoryDialog(BuildContext ctx) {
    showDialog(context: ctx, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        const Icon(Icons.receipt_long_outlined, color: Color(0xFF10B981), size: 22), const SizedBox(width: 10),
        const Expanded(child: Text('Billing History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
        if (_billingLoading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      ]),
      content: SizedBox(width: 480, height: 400, child: _billingLoading
        ? const Center(child: CircularProgressIndicator())
        : _billingItems.isEmpty
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFCBD5E1)), SizedBox(height: 12), Text('No billing history yet', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)))]))
          : ListView.separated(
              itemCount: _billingItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final item = _billingItems[i];
                final rawDate = item['date'] as String? ?? '';
                String fmtDate = '';
                try { final dt = DateTime.parse(rawDate); fmtDate = '${dt.day}/${dt.month}/${dt.year}'; } catch (_) { fmtDate = rawDate; }
                final amount = item['amount'] as String? ?? '';
                final amtStr = amount.isNotEmpty ? amount : '';
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: (item['color'] as Color? ?? const Color(0xFF10B981)).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(item['icon'] as IconData? ?? Icons.receipt_rounded, color: item['color'] as Color? ?? const Color(0xFF10B981), size: 18),
                  ),
                  title: Text(item['title'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(fmtDate, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (amtStr.isNotEmpty) Text(amtStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () { Navigator.pop(dc); _downloadSingleReceipt(ctx, item); },
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.download_outlined, size: 18, color: Color(0xFF0036BC))),
                    ),
                  ]),
                );
              },
            ),
      ),
      actions: [
        TextButton(onPressed: () { Navigator.pop(dc); _loadBillingItems(); }, child: const Text('Refresh', style: TextStyle(color: Color(0xFF64748B)))),
        TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Close', style: TextStyle(color: Color(0xFF64748B)))),
      ],
    ));
  }

  Future<void> _downloadSingleReceipt(BuildContext ctx, Map<String, dynamic> item) async {
    try {
      pw.ImageProvider? logoImage;
      try { final bytes = await rootBundle.load('assets/Asset 1.png'); logoImage = pw.MemoryImage(bytes.buffer.asUint8List()); } catch (_) {}

      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year}';
      final rawDate = item['date'] as String? ?? '';
      String txnDate = '';
      try { final dt = DateTime.parse(rawDate); txnDate = '${dt.day}/${dt.month}/${dt.year}'; } catch (_) { txnDate = rawDate; }
      final amount = item['amount'] as String? ?? '';
      final amtStr = amount.isNotEmpty ? amount : 'N/A';
      final user = ref.read(authProvider).user;
      final patientName = user?.name ?? 'Patient';

      final pdf = pw.Document();
      pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(40), build: (ctx2) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (logoImage != null) pw.Container(width: 50, height: 50, child: pw.Image(logoImage)) else pw.Text('iCare', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 4),
            pw.Text('RM Health Solutions (Private) Limited', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('RECEIPT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.Text('Issued: $dateStr', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          ]),
        ]),
        pw.SizedBox(height: 20),
        pw.Divider(),
        pw.SizedBox(height: 16),
        pw.Row(children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Billed To:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text(patientName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          ])),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Transaction Date:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text(txnDate.isNotEmpty ? txnDate : 'N/A', style: const pw.TextStyle(fontSize: 12)),
          ]),
        ]),
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.grey700)),
              pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.grey700)),
            ]),
            pw.Divider(color: PdfColors.grey400),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Expanded(child: pw.Text(item['title'] as String? ?? '', style: const pw.TextStyle(fontSize: 12))),
              pw.Text(amtStr, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.Divider(color: PdfColors.grey400),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text(amtStr, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            ]),
          ]),
        ),
        pw.SizedBox(height: 30),
        pw.Center(child: pw.Text('Thank you for using iCare.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey))),
      ])));

      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'iCare_Receipt_${(item['title'] as String? ?? 'receipt').replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Receipt download failed: $e'), backgroundColor: Colors.red));
    }
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
      savedAddressSubtitle: _savedAddresses.isEmpty ? 'Tap to add' : '${_savedAddresses.length} address${_savedAddresses.length == 1 ? '' : 'es'} saved',
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
      onShowDeliveryAddress: _showDeliveryAddressesDialog, onDownloadHealthData: _downloadHealthData,
      onShowPaymentMethods: _showPaymentMethodsDialog, onShowBillingHistory: _showBillingHistoryDialog,
      onShowOrderHistory: _showOrderHistoryDialog, onShowDeliveryPreferences: _showDeliveryPreferencesDialog,
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
  final String selectedLanguage, selectedCountry, savedAddressSubtitle;
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
  final void Function(BuildContext) onShowOrderHistory, onShowDeliveryPreferences;

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
    required this.savedAddressSubtitle, required this.savedPaymentMethods,
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
    required this.onShowOrderHistory, required this.onShowDeliveryPreferences,
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
      appBar: AppBar(title: Text('settings_title'.tr(), style: const TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.w700)), centerTitle: true, backgroundColor: Colors.white, foregroundColor: AppColors.primaryColor, elevation: 0, surfaceTintColor: Colors.white),
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
        _settingsTile(icon: Icons.location_on_outlined, iconColor: const Color(0xFF10B981), title: 'Saved Addresses', subtitle: p.savedAddressSubtitle, onTap: () => p.onShowDeliveryAddress(context)),
        const Divider(height: 1),
        _settingsTile(icon: Icons.shopping_bag_outlined, iconColor: const Color(0xFF3B82F6), title: 'Order History', subtitle: 'View all pharmacy orders', onTap: () => p.onShowOrderHistory(context)),
        const Divider(height: 1),
        _settingsTile(icon: Icons.local_shipping_outlined, iconColor: const Color(0xFF8B5CF6), title: 'Delivery Preferences', subtitle: 'Set delivery instructions', onTap: () => p.onShowDeliveryPreferences(context)),
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
                title: Text(label.tr(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(isOn ? 'Currently tracking'.tr() : 'Not tracking'.tr(), style: TextStyle(fontSize: 12, color: isOn ? const Color(0xFF10B981) : const Color(0xFF94A3B8))),
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
          label: Text('logout'.tr(), style: const TextStyle(color: Color(0xFFEF4444), fontSize: 16, fontWeight: FontWeight.w600)),
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
    return Row(children: [const Icon(Icons.circle, size: 8, color: AppColors.primaryColor), const SizedBox(width: 8), Text(title.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))]);
  }

  Widget _settingsTile({required IconData icon, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(contentPadding: EdgeInsets.zero, leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)), title: Text(title.tr(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), subtitle: Text(subtitle.tr(), style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFCBD5E1)), onTap: onTap);
  }

  Widget _switchTile({required IconData icon, required String title, required String subtitle, required bool value, required void Function(bool) onChanged}) {
    return ListTile(contentPadding: EdgeInsets.zero, leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppColors.primaryColor, size: 20)), title: Text(title.tr(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), subtitle: Text(subtitle.tr(), style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))), trailing: Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primaryColor));
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
      appBar: AppBar(title: Text('settings_title'.tr(), style: const TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.w700)), centerTitle: true, backgroundColor: Colors.white, foregroundColor: AppColors.primaryColor, elevation: 0, surfaceTintColor: Colors.white),
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
                title: Text(label.tr(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(isOn ? 'Tracking'.tr() : 'Not tracking'.tr(), style: TextStyle(fontSize: 11, color: isOn ? const Color(0xFF10B981) : const Color(0xFF94A3B8))),
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
        _settingsTile(icon: Icons.location_on_outlined, iconColor: const Color(0xFF10B981), title: 'Saved Addresses', subtitle: p.savedAddressSubtitle, onTap: () => p.onShowDeliveryAddress(context)),
        const Divider(height: 1), _settingsTile(icon: Icons.shopping_bag_outlined, iconColor: const Color(0xFF3B82F6), title: 'Order History', subtitle: 'View orders', onTap: () => p.onShowOrderHistory(context)),
        const Divider(height: 1), _settingsTile(icon: Icons.local_shipping_outlined, iconColor: const Color(0xFF8B5CF6), title: 'Delivery Preferences', subtitle: 'Set delivery instructions', onTap: () => p.onShowDeliveryPreferences(context)),
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
          label: Text('logout'.tr(), style: const TextStyle(color: Color(0xFFEF4444), fontSize: 16, fontWeight: FontWeight.w600)),
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
    return Row(children: [const Icon(Icons.circle, size: 7, color: AppColors.primaryColor), const SizedBox(width: 7), Text(title.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primaryColor))]);
  }

  Widget _settingsTile({required IconData icon, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(contentPadding: EdgeInsets.zero, leading: Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: iconColor, size: 18)), title: Text(title.tr(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), subtitle: Text(subtitle.tr(), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFCBD5E1)), onTap: onTap, dense: true);
  }

  Widget _switchTile({required IconData icon, required String title, required String subtitle, required bool value, required void Function(bool) onChanged}) {
    return ListTile(contentPadding: EdgeInsets.zero, leading: Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: AppColors.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: AppColors.primaryColor, size: 18)), title: Text(title.tr(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), subtitle: Text(subtitle.tr(), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))), trailing: Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primaryColor, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap), dense: true);
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
                      label: Text('Edit'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
                  hint: Text('Select gender'.tr(), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                  decoration: _inputDeco(Icons.wc_rounded),
                  items: ['Male', 'Female', 'Other']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g.tr())))
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
                        child: Text('cancel'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
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
                            : Text('Update Profile'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
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
                Text(label.tr(), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600, letterSpacing: 0.3)),
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
    return Text(label.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)));
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