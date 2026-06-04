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
import 'package:icare/services/gamification_service.dart';
import 'package:icare/screens/login_activity_screen.dart';
import 'package:icare/screens/patient_lab_orders.dart';
import 'package:icare/screens/prescriptions.dart' show PrescriptionsScreen;
import 'package:icare/services/health_settings_service.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/utils.dart' show buildProfileImageProvider;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../utils/water_notif_stub.dart'
    if (dart.library.html) '../utils/water_notif_web.dart';
import '../utils/daily_reminder_stub.dart'
    if (dart.library.html) '../utils/daily_reminder_web.dart';
import 'package:icare/services/reminder_service.dart';

// 1 reward point = 0.01 PKR (100 pts = 1 PKR). Configurable from backend.
const double _kPointToPkr = 0.01;

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
  final GamificationService _gamificationService = GamificationService();
  int _totalPoints = 0;
  List<dynamic> _pointsHistory = [];
  bool _prescriptionEmailEnabled = true;

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

  // Reminders
  TimeOfDay? _medReminderTime;
  TimeOfDay? _healthCheckReminderTime;
  bool _appointmentRemindersEnabled = true;

  // Diagnostics
  bool _preferHomeSample = false;
  String _reportDelivery = 'In-app';

  // Learning
  bool _courseNotificationsEnabled = false;

  // Notification preferences (loaded from API + cached in SharedPreferences)
  Map<String, bool> _notifPrefs = {
    'new_orders': true, 'order_dispatched': true, 'delivery_updates': true,
    'system_alerts': true, 'booking_updates': true, 'doctor_messages': true,
    'promotions': false, 'sound_notifications': true,
  };

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
    _loadPointsData();
    _loadReminderAndDiagnosticsPrefs();
    _loadNotifPrefs();
  }

  Future<void> _loadPointsData() async {
    try {
      final result = await _gamificationService.getMyStats();
      if (result['success'] == true && mounted) {
        setState(() {
          _totalPoints = (result['points'] ?? result['totalPoints'] ?? 0) as int;
          final history = result['history'] ?? result['activities'] ?? result['transactions'] ?? [];
          _pointsHistory = history is List ? history : [];
        });
      }
    } catch (_) {}
    // Load prescription email preference
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _prescriptionEmailEnabled = prefs.getBool('prescription_email_enabled') ?? true);
    } catch (_) {}
  }

  Future<void> _loadReminderAndDiagnosticsPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          final medTime = prefs.getString('med_reminder_time');
          if (medTime != null) {
            final parts = medTime.split(':');
            if (parts.length == 2) {
              _medReminderTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts[1]) ?? 0);
            }
          }
          final healthTime = prefs.getString('health_check_reminder_time');
          if (healthTime != null) {
            final parts = healthTime.split(':');
            if (parts.length == 2) {
              _healthCheckReminderTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts[1]) ?? 0);
            }
          }
          _appointmentRemindersEnabled = prefs.getBool('appointment_reminders_enabled') ?? true;
          _preferHomeSample = prefs.getBool('prefer_home_sample') ?? false;
          _reportDelivery = prefs.getString('report_delivery_method') ?? 'In-app';
          _courseNotificationsEnabled = prefs.getBool('course_notifications_enabled') ?? false;
        });
        // Re-schedule JS daily reminders so they survive page refresh
        if (_medReminderTime != null) {
          scheduleDailyReminder('medication', 'Medication Reminder 💊', 'Time to take your medication. Stay on track!', _medReminderTime!.hour, _medReminderTime!.minute);
        }
        if (_healthCheckReminderTime != null) {
          scheduleDailyReminder('health_check', 'Health Check Reminder ❤️', 'Time to log your health metrics (BP, weight, etc.).', _healthCheckReminderTime!.hour, _healthCheckReminderTime!.minute);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadNotifPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Load from SharedPreferences first (fast)
      final cached = <String, bool>{};
      for (final key in _notifPrefs.keys) {
        final v = prefs.getBool('notif_$key');
        if (v != null) cached[key] = v;
      }
      if (cached.isNotEmpty && mounted) setState(() => _notifPrefs = {..._notifPrefs, ...cached});
      // Then sync from API
      final res = await ApiService().get('/notifications/preferences');
      final data = res.data as Map<String, dynamic>?;
      if (data?['success'] == true && data?['preferences'] is Map) {
        final remote = Map<String, dynamic>.from(data!['preferences'] as Map);
        final updated = <String, bool>{};
        for (final key in _notifPrefs.keys) {
          if (remote[key] is bool) updated[key] = remote[key] as bool;
        }
        if (updated.isNotEmpty && mounted) setState(() => _notifPrefs = {..._notifPrefs, ...updated});
        // Cache locally
        for (final e in updated.entries) {
          await prefs.setBool('notif_${e.key}', e.value);
        }
      }
    } catch (_) {}
  }

  Future<void> _saveNotifPref(String key, bool value) async {
    setState(() => _notifPrefs = {..._notifPrefs, key: value});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_$key', value);
      await ApiService().put('/notifications/preferences', {key: value});
    } catch (_) {}
  }

  Future<void> _togglePrescriptionEmail(bool value) async {
    setState(() => _prescriptionEmailEnabled = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('prescription_email_enabled', value);
      // Sync to backend user settings
      await ApiService().put('/auth/update-settings', {'prescriptionEmailEnabled': value});
    } catch (_) {}
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

  Future<void> _loadUserData() async {
    ref.read(authProvider).user;
    // Load 2FA status from backend
    try {
      final result = await _securityService.getSecuritySettings();
      if (mounted && result['success'] == true) {
        setState(() => _is2FAEnabled = result['settings']?['twoFactorEnabled'] == true);
      }
    } catch (_) {}
    // Load prescription email preference from backend (source of truth)
    try {
      final resp = await ApiService().get('/auth/profile');
      if (mounted && resp.data['success'] == true) {
        final emailEnabled = resp.data['user']?['prescriptionEmailEnabled'] as bool? ?? true;
        setState(() => _prescriptionEmailEnabled = emailEnabled);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('prescription_email_enabled', emailEnabled);
      }
    } catch (_) {}
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
          final labPrefs = settings['labPreferences'] as Map<String, dynamic>?;
          if (labPrefs != null) {
            final method = labPrefs['reportDeliveryMethod'] as String?;
            if (method != null && method.isNotEmpty) _reportDelivery = method;
            _preferHomeSample = labPrefs['homeSampleCollection'] as bool? ?? _preferHomeSample;
          }
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
    if (value) {
      setState(() {});
      final result = await _securityService.setup2FA();
      if (!mounted) return;
      if (result['success'] == true) {
        _show2FASetupDialog(
          qrCode: result['qrCode']?.toString() ?? '',
          manualKey: result['manualKey']?.toString() ?? '',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message']?.toString() ?? 'Failed to start 2FA setup. Please try again.'),
          backgroundColor: Colors.red,
        ));
      }
    } else {
      final result = await _securityService.disable2FA();
      if (!mounted) return;
      setState(() => _is2FAEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['success'] == true ? '2FA has been disabled.' : '2FA disabled.'),
        backgroundColor: Colors.orange,
      ));
    }
  }

  void _show2FASetupDialog({required String qrCode, required String manualKey}) {
    final otpController = TextEditingController();
    bool verifying = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.qr_code_2_rounded, color: AppColors.primaryColor, size: 22)),
          const SizedBox(width: 10),
          const Text('Enable 2FA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        content: SizedBox(width: double.maxFinite,child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Step 1
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBFDBFE))),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Step 1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6))),
              SizedBox(height: 4),
              Text('Install Google Authenticator or Authy on your phone.', style: TextStyle(fontSize: 13, color: Color(0xFF1E40AF), height: 1.4)),
            ]),
          ),
          const SizedBox(height: 12),
          // Step 2 — QR code
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBBF7D0))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Step 2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
              const SizedBox(height: 4),
              const Text('Scan this QR code with the app:', style: TextStyle(fontSize: 13, color: Color(0xFF166534), height: 1.4)),
              const SizedBox(height: 12),
              if (qrCode.isNotEmpty)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(qrCode.contains(',') ? qrCode.split(',').last : qrCode),
                      width: 200,
                      height: 200,
                    ),
                  ),
                ),
              if (manualKey.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text("Can't scan? Enter this key manually:", style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => Clipboard.setData(ClipboardData(text: manualKey)),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
                    child: Row(children: [
                      Expanded(child: Text(manualKey, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF374151), letterSpacing: 1))),
                      const Icon(Icons.copy, size: 14, color: Color(0xFF9CA3AF)),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          // Step 3 — enter code
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFDE68A))),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Step 3', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
              SizedBox(height: 4),
              Text('Enter the 6-digit code shown in the app to confirm:', style: TextStyle(fontSize: 13, color: Color(0xFF92400E), height: 1.4)),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: false,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: '000000',
              hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 8),
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5)),
            ),
          ),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280)))),
          ElevatedButton(
            onPressed: verifying ? null : () async {
              if (otpController.text.length < 6) return;
              setModal(() => verifying = true);
              final result = await _securityService.enable2FAWithOtp(otpController.text.trim());
              if (!ctx.mounted) return;
              if (result['success'] == true) {
                setState(() => _is2FAEnabled = true);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google Authenticator 2FA enabled!'), backgroundColor: Colors.green));
              } else {
                setModal(() => verifying = false);
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Invalid code. Please try again.'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: verifying ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Verify & Enable'),
          ),
        ],
      )),
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
      content: SizedBox(width: double.maxFinite,child: Form(key: fk, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
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
      content: SizedBox(width: double.maxFinite,child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      content: SizedBox(width: double.maxFinite,child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      content: SizedBox(width: double.maxFinite,child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      content: SizedBox(width: double.maxFinite,child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      content: SizedBox(width: double.maxFinite,child: Column(mainAxisSize: MainAxisSize.min, children: [
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
      content: SizedBox(width: double.maxFinite,child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      content: SizedBox(width: double.maxFinite, height: 340,child: _savedAddresses.isEmpty
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
      content: SizedBox(width: double.maxFinite,child: Column(mainAxisSize: MainAxisSize.min, children: [
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
      content: SizedBox(width: double.maxFinite, height: 400,child: FutureBuilder(
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
      content: SizedBox(width: double.maxFinite,child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      content: SizedBox(width: double.maxFinite,child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      content: SizedBox(width: double.maxFinite,child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      content: SizedBox(width: double.maxFinite, height: 400,child: _billingLoading
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

  Future<void> _setMedReminder(TimeOfDay? time) async {
    setState(() => _medReminderTime = time);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (time != null) {
        await prefs.setString('med_reminder_time', '${time.hour}:${time.minute}');
        await ReminderService().createReminder({'title': 'Take your medication', 'type': 'medication', 'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}', 'isRecurring': true});
        scheduleDailyReminder('medication', 'Medication Reminder 💊', 'Time to take your medication. Stay on track!', time.hour, time.minute);
      } else {
        await prefs.remove('med_reminder_time');
        cancelDailyReminder('medication');
      }
    } catch (_) {}
  }

  Future<void> _setHealthCheckReminder(TimeOfDay? time) async {
    setState(() => _healthCheckReminderTime = time);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (time != null) {
        await prefs.setString('health_check_reminder_time', '${time.hour}:${time.minute}');
        await ReminderService().createReminder({'title': 'Log your health metrics', 'type': 'health_check', 'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}', 'isRecurring': true});
        scheduleDailyReminder('health_check', 'Health Check Reminder ❤️', 'Time to log your health metrics (BP, weight, etc.).', time.hour, time.minute);
      } else {
        await prefs.remove('health_check_reminder_time');
        cancelDailyReminder('health_check');
      }
    } catch (_) {}
  }

  Future<void> _toggleAppointmentReminders(bool value) async {
    setState(() => _appointmentRemindersEnabled = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('appointment_reminders_enabled', value);
    } catch (_) {}
  }

  Future<void> _togglePreferHomeSample(bool value) async {
    setState(() => _preferHomeSample = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('prefer_home_sample', value);
    } catch (_) {}
    try {
      await _healthSettingsService.updateLabPreferences({
        'homeSampleCollection': value,
        'reportDeliveryMethod': _reportDelivery,
      });
    } catch (_) {}
  }

  Future<void> _setReportDelivery(String method) async {
    setState(() => _reportDelivery = method);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('report_delivery_method', method);
    } catch (_) {}
    try {
      await _healthSettingsService.updateLabPreferences({
        'reportDeliveryMethod': method,
        'homeSampleCollection': _preferHomeSample,
      });
    } catch (_) {}
  }

  Future<void> _toggleCourseNotifications(bool value) async {
    setState(() => _courseNotificationsEnabled = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('course_notifications_enabled', value);
    } catch (_) {}
  }

  void _showFeeDialog(BuildContext ctx) {
    final ctrl = TextEditingController();
    bool saving = false;
    showDialog(context: ctx, builder: (dc) => StatefulBuilder(builder: (dc2, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.attach_money_rounded, color: Color(0xFF10B981), size: 24), SizedBox(width: 10), Text('Consultation Fee', style: TextStyle(fontWeight: FontWeight.w800))]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Set your consultation fee (PKR)', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))), const SizedBox(height: 12),
        TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true, decoration: InputDecoration(hintText: 'e.g. 2000', prefixText: 'PKR ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: const Color(0xFFF8FAFC))),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel')), ElevatedButton(onPressed: saving ? null : () async { final fee = double.tryParse(ctrl.text.trim()); if (fee == null || fee < 0) return; setS(() => saving = true); try { final svc = DoctorService(); await svc.updateConsultationFee(fee); if (dc2.mounted) Navigator.pop(dc2); if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Consultation fee set to PKR ${fee.toInt()}'), backgroundColor: Colors.green)); } catch (e) { if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red)); } setS(() => saving = false); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'))],
    )));
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).userRole ?? '';
    final user = ref.watch(authProvider).user;
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
      biometricAvailable: _biometricAvailable, prescriptionEmailEnabled: _prescriptionEmailEnabled,
      trackerToggles: _trackerToggles, healthModeEnabled: _healthModeEnabled,
      selectedConditions: _selectedConditions,
      medicalConditions: _medicalConditions, allergies: _allergies,
      currentMedications: _currentMedications, healthGoals: _healthGoals,
      waterReminderMinutes: _waterReminderMinutes, selectedLanguage: _selectedLanguage,
      selectedCountry: _selectedCountry,
      savedAddressSubtitle: _savedAddresses.isEmpty ? 'Tap to add' : '${_savedAddresses.length} address${_savedAddresses.length == 1 ? '' : 'es'} saved',
      savedPaymentMethods: _savedPaymentMethods, billingHistory: _billingHistory,
      totalPoints: _totalPoints, pointsHistory: _pointsHistory,
      medReminderTime: _medReminderTime, healthCheckReminderTime: _healthCheckReminderTime,
      appointmentRemindersEnabled: _appointmentRemindersEnabled,
      preferHomeSample: _preferHomeSample, reportDelivery: _reportDelivery,
      onToggle2FA: _toggle2FA, onToggleBiometrics: _toggleBiometrics,
      onTogglePrescriptionEmail: _togglePrescriptionEmail,
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
      onSetMedReminder: _setMedReminder, onSetHealthCheckReminder: _setHealthCheckReminder,
      onToggleAppointmentReminders: _toggleAppointmentReminders,
      onTogglePreferHomeSample: _togglePreferHomeSample, onSetReportDelivery: _setReportDelivery,
      courseNotificationsEnabled: _courseNotificationsEnabled,
      onToggleCourseNotifications: _toggleCourseNotifications,
      notifPrefs: _notifPrefs,
      onSaveNotifPref: _saveNotifPref,
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
  final bool prescriptionEmailEnabled;
  final List<String> selectedConditions;
  final String medicalConditions, allergies, currentMedications, healthGoals;
  final int waterReminderMinutes;
  final String selectedLanguage, selectedCountry, savedAddressSubtitle;
  final List<String> savedPaymentMethods, billingHistory;
  final Map<String, bool> trackerToggles;
  final int totalPoints;
  final List<dynamic> pointsHistory;
  // Reminders
  final TimeOfDay? medReminderTime;
  final TimeOfDay? healthCheckReminderTime;
  final bool appointmentRemindersEnabled;
  // Diagnostics
  final bool preferHomeSample;
  final String reportDelivery;
  // Learning
  final bool courseNotificationsEnabled;
  final void Function(bool) onToggleCourseNotifications;
  // Notification preferences
  final Map<String, bool> notifPrefs;
  final void Function(String, bool) onSaveNotifPref;
  final void Function(bool) onToggle2FA, onToggleBiometrics, onTogglePrescriptionEmail;
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
  // Reminder setters (callbacks)
  final void Function(TimeOfDay?) onSetMedReminder;
  final void Function(TimeOfDay?) onSetHealthCheckReminder;
  final void Function(bool) onToggleAppointmentReminders;
  // Diagnostics setters
  final void Function(bool) onTogglePreferHomeSample;
  final void Function(String) onSetReportDelivery;

  const _SettingsLayoutParams({
    required this.role, required this.user,
    required this.isPatient, required this.isPharmacy, required this.isLaboratory,
    required this.isDoctor, required this.isStudent, required this.isInstructor,
    required this.is2FAEnabled, required this.isBiometricEnabled,
    required this.biometricAvailable, required this.prescriptionEmailEnabled,
    required this.healthModeEnabled, required this.selectedConditions,
    required this.medicalConditions, required this.allergies,
    required this.currentMedications, required this.healthGoals,
    required this.waterReminderMinutes, required this.selectedLanguage,
    required this.selectedCountry,
    required this.savedAddressSubtitle, required this.savedPaymentMethods,
    required this.billingHistory, required this.trackerToggles,
    required this.totalPoints, required this.pointsHistory,
    required this.medReminderTime, required this.healthCheckReminderTime,
    required this.appointmentRemindersEnabled,
    required this.preferHomeSample, required this.reportDelivery,
    required this.onToggle2FA, required this.onToggleBiometrics,
    required this.onTogglePrescriptionEmail,
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
    required this.onSetMedReminder, required this.onSetHealthCheckReminder,
    required this.onToggleAppointmentReminders,
    required this.onTogglePreferHomeSample, required this.onSetReportDelivery,
    required this.courseNotificationsEnabled, required this.onToggleCourseNotifications,
    required this.notifPrefs, required this.onSaveNotifPref,
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
        if (p.isPatient) ...[_remindersCard(context), const SizedBox(height: 24)],
        if (p.isPatient) ...[_rewardsCard(context), const SizedBox(height: 24)],
        if (p.isPatient) ...[_diagnosticsCard(context), const SizedBox(height: 24)],
        if (p.isPatient) ...[_privacyCard(context), const SizedBox(height: 24)],
        if (p.isPatient) ...[_paymentCard(context), const SizedBox(height: 24)],
        _contactCard(context), const SizedBox(height: 24),
        if (p.isPatient) ...[_pharmacyCard(context), const SizedBox(height: 24)],
        if (p.isPatient || p.isStudent || p.isInstructor) ...[_learningCard(context), const SizedBox(height: 24)],
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
            child: ClipOval(child: () {
              final img = buildProfileImageProvider(p.user?.profilePicture);
              if (img != null) return Image(image: img, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Text((p.user?.name ?? 'U').substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryColor)));
              return Text((p.user?.name ?? 'U').substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryColor));
            }())),
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
        _settingsTile(icon: Icons.receipt_long_outlined, iconColor: const Color(0xFF0036BC), title: 'My Prescriptions', subtitle: 'View prescriptions from your doctors', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrescriptionsScreen()))),
        const Divider(height: 1),
        _settingsTile(icon: Icons.flag_outlined, iconColor: const Color(0xFF10B981), title: 'Health Goals', subtitle: p.healthGoals.isEmpty ? 'Tap to set goals' : p.healthGoals, onTap: () => p.onShowHealthGoals(context)),
      ])));
  }

  // ── NOTIFICATIONS ──
  Widget _notificationsCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Notifications'), const SizedBox(height: 16),
        if (p.isLaboratory) ...[
          _switchTile(icon: Icons.notifications_active_outlined, title: 'New Test Requests', subtitle: 'Required • Cannot be turned off', value: true, onChanged: (_) {}),
          const Divider(height: 1),
          _switchTile(icon: Icons.biotech_outlined, title: 'Sample Collection Status', subtitle: 'Updates on sample pickup & processing', value: p.notifPrefs['delivery_updates'] ?? true, onChanged: (v) => p.onSaveNotifPref('delivery_updates', v)),
          const Divider(height: 1),
          _switchTile(icon: Icons.upload_file_outlined, title: 'Result Upload Reminders', subtitle: 'Reminders to upload pending test results', value: p.notifPrefs['booking_updates'] ?? true, onChanged: (v) => p.onSaveNotifPref('booking_updates', v)),
          const Divider(height: 1),
          _switchTile(icon: Icons.warning_amber_outlined, title: 'System Alerts', subtitle: 'Platform & maintenance notifications', value: p.notifPrefs['system_alerts'] ?? true, onChanged: (v) => p.onSaveNotifPref('system_alerts', v)),
          const Divider(height: 1),
          _switchTile(icon: Icons.volume_up_outlined, title: 'Sound Notifications', subtitle: 'Play sound for notifications', value: p.notifPrefs['sound_notifications'] ?? true, onChanged: (v) => p.onSaveNotifPref('sound_notifications', v)),
        ] else if (p.isPharmacy) ...[
          _switchTile(icon: Icons.notifications_active_outlined, title: 'New Orders', subtitle: 'Required • Cannot be turned off', value: true, onChanged: (_) {}),
          const Divider(height: 1),
          _switchTile(icon: Icons.local_shipping_outlined, title: 'Order Dispatched', subtitle: 'Notify when order is out for delivery', value: p.notifPrefs['order_dispatched'] ?? true, onChanged: (v) => p.onSaveNotifPref('order_dispatched', v)),
          const Divider(height: 1),
          _switchTile(icon: Icons.update_rounded, title: 'Delivery Status Updates', subtitle: 'Real-time delivery tracking notifications', value: p.notifPrefs['delivery_updates'] ?? true, onChanged: (v) => p.onSaveNotifPref('delivery_updates', v)),
          const Divider(height: 1),
          _switchTile(icon: Icons.warning_amber_outlined, title: 'System Alerts', subtitle: 'Platform & maintenance notifications', value: p.notifPrefs['system_alerts'] ?? true, onChanged: (v) => p.onSaveNotifPref('system_alerts', v)),
          const Divider(height: 1),
          _switchTile(icon: Icons.volume_up_outlined, title: 'Sound Notifications', subtitle: 'Play sound for notifications', value: p.notifPrefs['sound_notifications'] ?? true, onChanged: (v) => p.onSaveNotifPref('sound_notifications', v)),
        ] else ...[
          _switchTile(icon: Icons.calendar_today_outlined, title: 'Booking Updates', subtitle: 'Appointment confirmations & changes', value: p.notifPrefs['booking_updates'] ?? true, onChanged: (v) => p.onSaveNotifPref('booking_updates', v)),
          const Divider(height: 1),
          _switchTile(icon: Icons.message_outlined, title: 'Doctor Messages', subtitle: 'Messages from providers', value: p.notifPrefs['doctor_messages'] ?? true, onChanged: (v) => p.onSaveNotifPref('doctor_messages', v)),
          const Divider(height: 1),
          _switchTile(icon: Icons.local_offer_outlined, title: 'Promotions & Offers', subtitle: 'Special deals & health tips', value: p.notifPrefs['promotions'] ?? false, onChanged: (v) => p.onSaveNotifPref('promotions', v)),
          const Divider(height: 1),
          _switchTile(icon: Icons.volume_up_outlined, title: 'Sound Notifications', subtitle: 'Play sound for notifications', value: p.notifPrefs['sound_notifications'] ?? true, onChanged: (v) => p.onSaveNotifPref('sound_notifications', v)),
          if (p.isPatient) ...[
            const Divider(height: 1),
            _switchTile(icon: Icons.email_outlined, title: 'Send Prescription to Email', subtitle: 'Automatically email prescriptions after consultation', value: p.prescriptionEmailEnabled, onChanged: p.onTogglePrescriptionEmail),
          ],
        ],
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

  // ── REMINDERS & NOTIFICATIONS ──
  Widget _remindersCard(BuildContext context) {
    final waterLabels = {'30': '30 min', '60': '1 hr', '120': '2 hrs', '180': '3 hrs'};
    final waterLabel = waterLabels[p.waterReminderMinutes.toString()] ?? '1 hr';
    String fmtTime(TimeOfDay? t) => t == null ? 'Not set' : t.format(context);
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Reminders & Notifications'), const SizedBox(height: 16),
        _settingsTile(icon: Icons.medication_outlined, iconColor: const Color(0xFF8B5CF6), title: 'Medication Reminder', subtitle: fmtTime(p.medReminderTime), onTap: () async {
          final picked = await showTimePicker(context: context, initialTime: p.medReminderTime ?? const TimeOfDay(hour: 8, minute: 0));
          if (picked != null) p.onSetMedReminder(picked);
        }),
        const Divider(height: 1),
        _settingsTile(icon: Icons.water_drop_outlined, iconColor: const Color(0xFF3B82F6), title: 'Water Reminder', subtitle: 'Every $waterLabel', onTap: () => p.onShowWaterReminder(context)),
        const Divider(height: 1),
        _settingsTile(icon: Icons.monitor_heart_outlined, iconColor: const Color(0xFFEF4444), title: 'Health Check Reminder', subtitle: fmtTime(p.healthCheckReminderTime), onTap: () async {
          final picked = await showTimePicker(context: context, initialTime: p.healthCheckReminderTime ?? const TimeOfDay(hour: 8, minute: 0));
          if (picked != null) p.onSetHealthCheckReminder(picked);
        }),
        const Divider(height: 1),
        _switchTile(icon: Icons.calendar_today_outlined, title: 'Appointment Reminders', subtitle: 'Get reminded before appointments', value: p.appointmentRemindersEnabled, onChanged: p.onToggleAppointmentReminders),
      ])));
  }

  // ── DIAGNOSTICS SETTINGS ──
  Widget _diagnosticsCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Diagnostics Settings'), const SizedBox(height: 16),
        _settingsTile(icon: Icons.science_outlined, iconColor: const Color(0xFF3B82F6), title: 'Test History', subtitle: 'View past lab bookings', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientLabOrdersScreen()))),
        const Divider(height: 1),
        _switchTile(icon: Icons.home_outlined, title: 'Home Sample Collection', subtitle: 'Prefer home sample collection', value: p.preferHomeSample, onChanged: p.onTogglePreferHomeSample),
        const Divider(height: 1),
        _settingsTile(icon: Icons.assignment_outlined, iconColor: const Color(0xFF8B5CF6), title: 'Report Delivery', subtitle: p.reportDelivery, onTap: () => _showReportDeliverySheet(context)),
      ])));
  }

  void _showReportDeliverySheet(BuildContext context) {
    final options = ['In-app', 'Email only', 'Both'];
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Padding(padding: EdgeInsets.all(16), child: Text('Report Delivery Method', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
      const Divider(height: 1),
      ...options.map((opt) => ListTile(title: Text(opt), trailing: p.reportDelivery == opt ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)) : null, onTap: () { p.onSetReportDelivery(opt); Navigator.pop(context); })),
      const SizedBox(height: 8),
    ])));
  }

  // ── REWARDS ──
  Widget _rewardsCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Rewards & Points'), const SizedBox(height: 16),
        _rewardPointsBanner(),
        const SizedBox(height: 12),
        _settingsTile(icon: Icons.stars_outlined, iconColor: const Color(0xFFF59E0B), title: 'Reward Points', subtitle: '${p.totalPoints} pts total', onTap: () => _showRewardPointsDialog(context)),
        const Divider(height: 1),
        _settingsTile(icon: Icons.history_outlined, iconColor: const Color(0xFFF59E0B), title: 'Reward History', subtitle: p.pointsHistory.isEmpty ? 'No activity yet' : '${p.pointsHistory.length} activities', onTap: () => _showRewardHistoryDialog(context)),
        const Divider(height: 1),
        _settingsTile(icon: Icons.swap_horiz_outlined, iconColor: const Color(0xFFF59E0B), title: 'Redemption History', subtitle: 'View redeemed rewards', onTap: () => _showRedemptionHistoryDialog(context)),
      ])));
  }

  Widget _rewardPointsBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.stars_rounded, color: Colors.white, size: 32),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${p.totalPoints}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
          const Text('Total Points', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
          Text('≈ PKR ${(p.totalPoints * _kPointToPkr).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ]),
      ]),
    );
  }

  void _showRewardPointsDialog(BuildContext context) {
    showDialog(context: context, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 24), SizedBox(width: 10), Text('My Points', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18))]),
      content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.stars_rounded, color: Colors.white, size: 40),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.totalPoints}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
              const Text('Reward Points', style: TextStyle(fontSize: 13, color: Colors.white70)),
              Text('≈ PKR ${(p.totalPoints * _kPointToPkr).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.white60)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        const Text('Points are earned by:\n• Logging vitals (+5 pts each)\n• Completing daily goals (+10 pts)\n• Taking all medications (+10 pts)\n• Attending consultations (+15 pts)', style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.6)),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () { Navigator.pop(dc); _showRedeemRewardsDialog(context); }, icon: const Icon(Icons.redeem_rounded, size: 18), label: const Text('Redeem Points'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
      ])),
      actions: [ElevatedButton(onPressed: () => Navigator.pop(dc), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Close'))],
    ));
  }

  void _showRedeemRewardsDialog(BuildContext context) {
    final rewards = [
      {'id': 'free_consultation', 'title': 'Free Consultation', 'cost': 1000, 'icon': Icons.video_call_rounded, 'color': const Color(0xFF10B981)},
      {'id': 'lab_test_discount', 'title': 'Lab Test Discount (20%)', 'cost': 500, 'icon': Icons.science_outlined, 'color': const Color(0xFF3B82F6)},
    ];
    final gamSvc = GamificationService();
    showDialog(context: context, builder: (dc) => StatefulBuilder(builder: (dc2, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.redeem_rounded, color: Color(0xFF10B981), size: 24), SizedBox(width: 10), Text('Redeem Points', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18))]),
      content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [
        ...rewards.map((r) {
          final cost = r['cost'] as int;
          final hasEnough = p.totalPoints >= cost;
          final icon = r['icon'] as IconData;
          final color = r['color'] as Color;
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('$cost pts required', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ])),
              ElevatedButton(
                onPressed: hasEnough ? () async {
                  Navigator.pop(dc2);
                  try {
                    final result = await gamSvc.redeemReward(r['id'] as String);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? (result['success'] == true ? 'Reward redeemed!' : 'Redemption failed')), backgroundColor: result['success'] == true ? Colors.green : Colors.red));
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to redeem: $e'), backgroundColor: Colors.red));
                  }
                } : null,
                style: ElevatedButton.styleFrom(backgroundColor: hasEnough ? const Color(0xFF10B981) : const Color(0xFFCBD5E1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                child: Text(hasEnough ? 'Redeem' : 'Not enough', style: const TextStyle(fontSize: 12)),
              ),
            ]),
          ));
        }),
        const Divider(),
        const Text('1 pt = PKR 0.01 • Rate may change by platform', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dc2), child: const Text('Close'))],
    )));
  }

  void _showRedemptionHistoryDialog(BuildContext context) {
    final gamSvc = GamificationService();
    showDialog(context: context, builder: (dc) => FutureBuilder<Map<String, dynamic>>(
      future: gamSvc.getMyStats(),
      builder: (_, snap) {
        List<dynamic> redemptions = [];
        if (snap.hasData && snap.data!['success'] == true) {
          final data = snap.data!;
          redemptions = (data['redemptions'] ?? data['redeemedRewards'] ?? []) as List<dynamic>;
        }
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [Icon(Icons.swap_horiz_outlined, color: Color(0xFFF59E0B), size: 22), SizedBox(width: 10), Text('Redemption History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
          content: SizedBox(width: double.maxFinite, height: 280, child: snap.connectionState == ConnectionState.waiting
            ? const Center(child: CircularProgressIndicator())
            : redemptions.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.swap_horiz_outlined, size: 48, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 12),
                  const Text('No redemptions yet', style: TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: () { Navigator.pop(dc); _showRedeemRewardsDialog(context); }, icon: const Icon(Icons.redeem_rounded, size: 16), label: const Text('Redeem Points'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
                ]))
              : ListView.separated(
                  itemCount: redemptions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = redemptions[i];
                    final title = (item is Map ? item['title'] ?? item['rewardId'] ?? 'Reward' : 'Reward').toString();
                    final pts = (item is Map ? item['points'] ?? item['cost'] ?? 0 : 0) as num;
                    final date = (item is Map ? item['createdAt'] ?? item['date'] ?? '' : '').toString();
                    String dateStr = '';
                    try { dateStr = date.isNotEmpty ? DateFormat('MMM d, yyyy').format(DateTime.parse(date).toLocal()) : ''; } catch (_) {}
                    return ListTile(dense: true,
                      leading: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.redeem_rounded, color: Color(0xFF10B981), size: 16)),
                      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: dateStr.isNotEmpty ? Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))) : null,
                      trailing: Text('-$pts pts', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                    );
                  },
                ),
          ),
          actions: [ElevatedButton(onPressed: () => Navigator.pop(dc), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Close'))],
        );
      },
    ));
  }

  void _showRewardHistoryDialog(BuildContext context) {
    showDialog(context: context, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.history_rounded, color: Color(0xFFF59E0B), size: 22), SizedBox(width: 10), Text('Reward History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: double.maxFinite,height: 300, child: p.pointsHistory.isEmpty
        ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_outlined, size: 48, color: Color(0xFFCBD5E1)), SizedBox(height: 12), Text('No reward history yet', style: TextStyle(color: Color(0xFF64748B)))]))
        : ListView.separated(
            itemCount: p.pointsHistory.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final item = p.pointsHistory[i];
              final pts = (item is Map ? item['points'] ?? item['amount'] ?? 0 : 0) as num;
              final reason = (item is Map ? item['reason'] ?? item['activity'] ?? item['description'] ?? 'Activity' : 'Activity').toString();
              final date = (item is Map ? item['createdAt'] ?? item['date'] ?? '' : '').toString();
              String dateStr = '';
              try { dateStr = date.isNotEmpty ? DateFormat('MMM d, yyyy').format(DateTime.parse(date).toLocal()) : ''; } catch (_) {}
              return ListTile(
                dense: true,
                leading: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 16)),
                title: Text(reason, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: dateStr.isNotEmpty ? Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))) : null,
                trailing: Text('+$pts pts', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B))),
              );
            },
          ),
      ),
      actions: [ElevatedButton(onPressed: () => Navigator.pop(dc), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Close'))],
    ));
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
        _settingsTile(icon: Icons.trending_up_outlined, iconColor: const Color(0xFF8B5CF6), title: 'Progress Tracking', subtitle: 'View your course completion', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Courses()))),
        const Divider(height: 1),
        _switchTile(icon: Icons.notifications_active_outlined, title: 'Notifications for New Courses', subtitle: 'Get notified about new offerings', value: p.courseNotificationsEnabled, onChanged: p.onToggleCourseNotifications),
      ])));
  }

  // ── SECURITY ──
  Widget _securityCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Security'), const SizedBox(height: 16),
        _settingsTile(icon: Icons.lock_outline, iconColor: const Color(0xFF64748B), title: 'Change Password', subtitle: 'Update your password', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePassword()))),
        const Divider(height: 1),
        _settingsTile(icon: Icons.history_outlined, iconColor: const Color(0xFF64748B), title: 'Login Activity', subtitle: 'Review recent login sessions', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginActivityScreen()))),
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
            subtitle: 'Set your consultation fee (PKR)',
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
        const Divider(height: 1),
        _settingsTile(icon: Icons.verified_outlined, iconColor: const Color(0xFF10B981), title: 'DRAP Guidelines', subtitle: 'Drug Regulatory Authority of Pakistan', onTap: () async { try { await launchUrl(Uri.parse('https://www.dra.gov.pk'), mode: LaunchMode.externalApplication); } catch (_) {} }),
        const Divider(height: 1),
        _settingsTile(icon: Icons.policy_outlined, iconColor: const Color(0xFF3B82F6), title: 'Drug Policy', subtitle: 'National drug laws & regulations', onTap: () async { try { await launchUrl(Uri.parse('https://www.dra.gov.pk/laws-regulations/'), mode: LaunchMode.externalApplication); } catch (_) {} }),
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
        if (p.isPatient) ...[_remindersCard(context), const SizedBox(height: 16)],
        if (p.isPatient) ...[_rewardsCard(context), const SizedBox(height: 16)],
        if (p.isPatient) ...[_diagnosticsCard(context), const SizedBox(height: 16)],
        if (p.isPatient) ...[_privacyCard(context), const SizedBox(height: 16)],
        if (p.isPatient) ...[_paymentCard(context), const SizedBox(height: 16)],
        _contactCard(context), const SizedBox(height: 16),
        if (p.isPatient) ...[_pharmacyCard(context), const SizedBox(height: 16)],
        if (p.isPatient || p.isStudent || p.isInstructor) ...[_learningCard(context), const SizedBox(height: 16)],
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
            child: ClipOval(child: () {
              final img = buildProfileImageProvider(p.user?.profilePicture);
              if (img != null) return Image(image: img, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Text((p.user?.name ?? 'U').substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryColor)));
              return Text((p.user?.name ?? 'U').substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryColor));
            }())),
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
        _settingsTile(icon: Icons.receipt_long_outlined, iconColor: const Color(0xFF0036BC), title: 'My Prescriptions', subtitle: 'View prescriptions from your doctors', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrescriptionsScreen()))),
        const Divider(height: 1),
        _settingsTile(icon: Icons.flag_outlined, iconColor: const Color(0xFF10B981), title: 'Health Goals', subtitle: p.healthGoals.isEmpty ? 'Tap to set goals' : p.healthGoals, onTap: () => p.onShowHealthGoals(context)),
      ])));
  }

  Widget _notificationsCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Notifications'), const SizedBox(height: 12),
        if (p.isLaboratory) ...[
          _switchTile(icon: Icons.notifications_active_outlined, title: 'New Test Requests', subtitle: 'Required • Cannot be turned off', value: true, onChanged: (_) {}),
          const Divider(height: 1), _switchTile(icon: Icons.biotech_outlined, title: 'Sample Collection Status', subtitle: 'Updates on sample pickup & processing', value: p.notifPrefs['delivery_updates'] ?? true, onChanged: (v) => p.onSaveNotifPref('delivery_updates', v)),
          const Divider(height: 1), _switchTile(icon: Icons.upload_file_outlined, title: 'Result Upload Reminders', subtitle: 'Reminders to upload pending results', value: p.notifPrefs['booking_updates'] ?? true, onChanged: (v) => p.onSaveNotifPref('booking_updates', v)),
          const Divider(height: 1), _switchTile(icon: Icons.warning_amber_outlined, title: 'System Alerts', subtitle: 'Platform & maintenance notifications', value: p.notifPrefs['system_alerts'] ?? true, onChanged: (v) => p.onSaveNotifPref('system_alerts', v)),
          const Divider(height: 1), _switchTile(icon: Icons.volume_up_outlined, title: 'Sound Notifications', subtitle: 'Play sound', value: p.notifPrefs['sound_notifications'] ?? true, onChanged: (v) => p.onSaveNotifPref('sound_notifications', v)),
        ] else if (p.isPharmacy) ...[
          _switchTile(icon: Icons.notifications_active_outlined, title: 'New Orders', subtitle: 'Required • Cannot be turned off', value: true, onChanged: (_) {}),
          const Divider(height: 1), _switchTile(icon: Icons.local_shipping_outlined, title: 'Order Dispatched', subtitle: 'Notify when order is out for delivery', value: p.notifPrefs['order_dispatched'] ?? true, onChanged: (v) => p.onSaveNotifPref('order_dispatched', v)),
          const Divider(height: 1), _switchTile(icon: Icons.update_rounded, title: 'Delivery Status Updates', subtitle: 'Real-time delivery tracking notifications', value: p.notifPrefs['delivery_updates'] ?? true, onChanged: (v) => p.onSaveNotifPref('delivery_updates', v)),
          const Divider(height: 1), _switchTile(icon: Icons.warning_amber_outlined, title: 'System Alerts', subtitle: 'Platform & maintenance notifications', value: p.notifPrefs['system_alerts'] ?? true, onChanged: (v) => p.onSaveNotifPref('system_alerts', v)),
          const Divider(height: 1), _switchTile(icon: Icons.volume_up_outlined, title: 'Sound Notifications', subtitle: 'Play sound', value: p.notifPrefs['sound_notifications'] ?? true, onChanged: (v) => p.onSaveNotifPref('sound_notifications', v)),
        ] else ...[
          _switchTile(icon: Icons.calendar_today_outlined, title: 'Booking Updates', subtitle: 'Appointment confirmations & changes', value: p.notifPrefs['booking_updates'] ?? true, onChanged: (v) => p.onSaveNotifPref('booking_updates', v)),
          const Divider(height: 1), _switchTile(icon: Icons.message_outlined, title: 'Doctor Messages', subtitle: 'Messages from providers', value: p.notifPrefs['doctor_messages'] ?? true, onChanged: (v) => p.onSaveNotifPref('doctor_messages', v)),
          const Divider(height: 1), _switchTile(icon: Icons.local_offer_outlined, title: 'Promotions & Offers', subtitle: 'Special deals', value: p.notifPrefs['promotions'] ?? false, onChanged: (v) => p.onSaveNotifPref('promotions', v)),
          const Divider(height: 1), _switchTile(icon: Icons.volume_up_outlined, title: 'Sound Notifications', subtitle: 'Play sound', value: p.notifPrefs['sound_notifications'] ?? true, onChanged: (v) => p.onSaveNotifPref('sound_notifications', v)),
          if (p.isPatient) ...[
            const Divider(height: 1), _switchTile(icon: Icons.email_outlined, title: 'Send Prescription to Email', subtitle: 'Auto email prescriptions after consultation', value: p.prescriptionEmailEnabled, onChanged: p.onTogglePrescriptionEmail),
          ],
        ],
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

  Widget _remindersCard(BuildContext context) {
    final waterLabels = {'30': '30 min', '60': '1 hr', '120': '2 hrs', '180': '3 hrs'};
    final waterLabel = waterLabels[p.waterReminderMinutes.toString()] ?? '1 hr';
    String formatTime(TimeOfDay? t) => t == null ? 'Not set' : t.format(context);
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Reminders & Notifications'), const SizedBox(height: 12),
        _settingsTile(icon: Icons.medication_outlined, iconColor: const Color(0xFF8B5CF6), title: 'Medication Reminder', subtitle: formatTime(p.medReminderTime), onTap: () async {
          final picked = await showTimePicker(context: context, initialTime: p.medReminderTime ?? const TimeOfDay(hour: 8, minute: 0));
          if (picked != null) p.onSetMedReminder(picked);
        }),
        const Divider(height: 1),
        _settingsTile(icon: Icons.water_drop_outlined, iconColor: const Color(0xFF3B82F6), title: 'Water Reminder', subtitle: 'Every $waterLabel', onTap: () => p.onShowWaterReminder(context)),
        const Divider(height: 1),
        _settingsTile(icon: Icons.monitor_heart_outlined, iconColor: const Color(0xFFEF4444), title: 'Health Check Reminder', subtitle: formatTime(p.healthCheckReminderTime), onTap: () async {
          final picked = await showTimePicker(context: context, initialTime: p.healthCheckReminderTime ?? const TimeOfDay(hour: 8, minute: 0));
          if (picked != null) p.onSetHealthCheckReminder(picked);
        }),
        const Divider(height: 1),
        _switchTile(icon: Icons.calendar_today_outlined, title: 'Appointment Reminders', subtitle: 'Get reminded before appointments', value: p.appointmentRemindersEnabled, onChanged: p.onToggleAppointmentReminders),
      ])));
  }

  Widget _diagnosticsCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Diagnostics Settings'), const SizedBox(height: 12),
        _settingsTile(icon: Icons.science_outlined, iconColor: const Color(0xFF3B82F6), title: 'Test History', subtitle: 'View past lab bookings', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientLabOrdersScreen()))),
        const Divider(height: 1),
        _switchTile(icon: Icons.home_outlined, title: 'Home Sample Collection', subtitle: 'Prefer home sample collection', value: p.preferHomeSample, onChanged: p.onTogglePreferHomeSample),
        const Divider(height: 1),
        _settingsTile(icon: Icons.assignment_outlined, iconColor: const Color(0xFF8B5CF6), title: 'Report Delivery', subtitle: p.reportDelivery, onTap: () => _showReportDeliverySheet(context)),
      ])));
  }

  void _showReportDeliverySheet(BuildContext context) {
    final options = ['In-app', 'Email only', 'Both'];
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Padding(padding: EdgeInsets.all(16), child: Text('Report Delivery Method', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
      const Divider(height: 1),
      ...options.map((opt) => ListTile(title: Text(opt), trailing: p.reportDelivery == opt ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)) : null, onTap: () { p.onSetReportDelivery(opt); Navigator.pop(context); })),
      const SizedBox(height: 8),
    ])));
  }

  Widget _rewardsCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Rewards & Points'), const SizedBox(height: 12),
        _rewardPointsBanner(),
        const SizedBox(height: 12),
        _settingsTile(icon: Icons.stars_outlined, iconColor: const Color(0xFFF59E0B), title: 'Reward Points', subtitle: '${p.totalPoints} pts total', onTap: () => _showRewardPointsDialog(context)),
        const Divider(height: 1), _settingsTile(icon: Icons.history_outlined, iconColor: const Color(0xFFF59E0B), title: 'Reward History', subtitle: p.pointsHistory.isEmpty ? 'No activity yet' : '${p.pointsHistory.length} activities', onTap: () => _showRewardHistoryDialog(context)),
        const Divider(height: 1), _settingsTile(icon: Icons.swap_horiz_outlined, iconColor: const Color(0xFFF59E0B), title: 'Redemption History', subtitle: 'View redeemed rewards', onTap: () => _showRedemptionHistoryDialog(context)),
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
        const Divider(height: 1), _settingsTile(icon: Icons.trending_up_outlined, iconColor: const Color(0xFF8B5CF6), title: 'Progress Tracking', subtitle: 'View course completion', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Courses()))),
        const Divider(height: 1), _switchTile(icon: Icons.notifications_active_outlined, title: 'Notifications for New Courses', subtitle: 'Get notified', value: p.courseNotificationsEnabled, onChanged: p.onToggleCourseNotifications),
      ])));
  }

  Widget _securityCard(BuildContext context) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Security'), const SizedBox(height: 12),
        _settingsTile(icon: Icons.lock_outline, iconColor: const Color(0xFF64748B), title: 'Change Password', subtitle: 'Update password', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePassword()))),
        const Divider(height: 1), _settingsTile(icon: Icons.history_outlined, iconColor: const Color(0xFF64748B), title: 'Login Activity', subtitle: 'Review sessions', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginActivityScreen()))),
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
            subtitle: 'Set your consultation fee (PKR)',
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
        const Divider(height: 1),
        _settingsTile(icon: Icons.verified_outlined, iconColor: const Color(0xFF10B981), title: 'DRAP Guidelines', subtitle: 'Drug Regulatory Authority of Pakistan', onTap: () async { try { await launchUrl(Uri.parse('https://www.dra.gov.pk'), mode: LaunchMode.externalApplication); } catch (_) {} }),
        const Divider(height: 1),
        _settingsTile(icon: Icons.policy_outlined, iconColor: const Color(0xFF3B82F6), title: 'Drug Policy', subtitle: 'National drug laws & regulations', onTap: () async { try { await launchUrl(Uri.parse('https://www.dra.gov.pk/laws-regulations/'), mode: LaunchMode.externalApplication); } catch (_) {} }),
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

  Widget _rewardPointsBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.stars_rounded, color: Colors.white, size: 32),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${p.totalPoints}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
          const Text('Total Points', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
          Text('≈ PKR ${(p.totalPoints * _kPointToPkr).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ]),
      ]),
    );
  }

  void _showRewardPointsDialog(BuildContext context) {
    showDialog(context: context, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 24), SizedBox(width: 10), Text('My Points', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18))]),
      content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.stars_rounded, color: Colors.white, size: 40),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.totalPoints}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
              const Text('Reward Points', style: TextStyle(fontSize: 13, color: Colors.white70)),
              Text('≈ PKR ${(p.totalPoints * _kPointToPkr).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.white60)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        const Text('Points are earned by:\n• Logging vitals (+5 pts each)\n• Completing daily goals (+10 pts)\n• Taking all medications (+10 pts)\n• Attending consultations (+15 pts)', style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.6)),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () { Navigator.pop(dc); _showRedeemRewardsDialog(context); }, icon: const Icon(Icons.redeem_rounded, size: 18), label: const Text('Redeem Points'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
      ])),
      actions: [ElevatedButton(onPressed: () => Navigator.pop(dc), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Close'))],
    ));
  }

  void _showRedeemRewardsDialog(BuildContext context) {
    final rewards = [
      {'id': 'free_consultation', 'title': 'Free Consultation', 'cost': 1000, 'icon': Icons.video_call_rounded, 'color': const Color(0xFF10B981)},
      {'id': 'lab_test_discount', 'title': 'Lab Test Discount (20%)', 'cost': 500, 'icon': Icons.science_outlined, 'color': const Color(0xFF3B82F6)},
    ];
    final gamSvc = GamificationService();
    showDialog(context: context, builder: (dc) => StatefulBuilder(builder: (dc2, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.redeem_rounded, color: Color(0xFF10B981), size: 24), SizedBox(width: 10), Text('Redeem Points', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18))]),
      content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [
        ...rewards.map((r) {
          final cost = r['cost'] as int;
          final hasEnough = p.totalPoints >= cost;
          final icon = r['icon'] as IconData;
          final color = r['color'] as Color;
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('$cost pts required', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ])),
              ElevatedButton(
                onPressed: hasEnough ? () async {
                  Navigator.pop(dc2);
                  try {
                    final result = await gamSvc.redeemReward(r['id'] as String);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? (result['success'] == true ? 'Reward redeemed!' : 'Redemption failed')), backgroundColor: result['success'] == true ? Colors.green : Colors.red));
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to redeem: $e'), backgroundColor: Colors.red));
                  }
                } : null,
                style: ElevatedButton.styleFrom(backgroundColor: hasEnough ? const Color(0xFF10B981) : const Color(0xFFCBD5E1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                child: Text(hasEnough ? 'Redeem' : 'Not enough', style: const TextStyle(fontSize: 12)),
              ),
            ]),
          ));
        }),
        const Divider(),
        const Text('1 pt = PKR 0.01 • Rate may change by platform', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dc2), child: const Text('Close'))],
    )));
  }

  void _showRedemptionHistoryDialog(BuildContext context) {
    final gamSvc = GamificationService();
    showDialog(context: context, builder: (dc) => FutureBuilder<Map<String, dynamic>>(
      future: gamSvc.getMyStats(),
      builder: (_, snap) {
        List<dynamic> redemptions = [];
        if (snap.hasData && snap.data!['success'] == true) {
          final data = snap.data!;
          redemptions = (data['redemptions'] ?? data['redeemedRewards'] ?? []) as List<dynamic>;
        }
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [Icon(Icons.swap_horiz_outlined, color: Color(0xFFF59E0B), size: 22), SizedBox(width: 10), Text('Redemption History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
          content: SizedBox(width: double.maxFinite, height: 280, child: snap.connectionState == ConnectionState.waiting
            ? const Center(child: CircularProgressIndicator())
            : redemptions.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.swap_horiz_outlined, size: 48, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 12),
                  const Text('No redemptions yet', style: TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: () { Navigator.pop(dc); _showRedeemRewardsDialog(context); }, icon: const Icon(Icons.redeem_rounded, size: 16), label: const Text('Redeem Points'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
                ]))
              : ListView.separated(
                  itemCount: redemptions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = redemptions[i];
                    final title = (item is Map ? item['title'] ?? item['rewardId'] ?? 'Reward' : 'Reward').toString();
                    final pts = (item is Map ? item['points'] ?? item['cost'] ?? 0 : 0) as num;
                    final date = (item is Map ? item['createdAt'] ?? item['date'] ?? '' : '').toString();
                    String dateStr = '';
                    try { dateStr = date.isNotEmpty ? DateFormat('MMM d, yyyy').format(DateTime.parse(date).toLocal()) : ''; } catch (_) {}
                    return ListTile(dense: true,
                      leading: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.redeem_rounded, color: Color(0xFF10B981), size: 16)),
                      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: dateStr.isNotEmpty ? Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))) : null,
                      trailing: Text('-$pts pts', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                    );
                  },
                ),
          ),
          actions: [ElevatedButton(onPressed: () => Navigator.pop(dc), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Close'))],
        );
      },
    ));
  }

  void _showRewardHistoryDialog(BuildContext context) {
    showDialog(context: context, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.history_rounded, color: Color(0xFFF59E0B), size: 22), SizedBox(width: 10), Text('Reward History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      content: SizedBox(width: double.maxFinite,height: 300, child: p.pointsHistory.isEmpty
        ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_outlined, size: 48, color: Color(0xFFCBD5E1)), SizedBox(height: 12), Text('No reward history yet', style: TextStyle(color: Color(0xFF64748B)))]))
        : ListView.separated(
            itemCount: p.pointsHistory.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final item = p.pointsHistory[i];
              final pts = (item is Map ? item['points'] ?? item['amount'] ?? 0 : 0) as num;
              final reason = (item is Map ? item['reason'] ?? item['activity'] ?? item['description'] ?? 'Activity' : 'Activity').toString();
              final date = (item is Map ? item['createdAt'] ?? item['date'] ?? '' : '').toString();
              String dateStr = '';
              try { dateStr = date.isNotEmpty ? DateFormat('MMM d, yyyy').format(DateTime.parse(date).toLocal()) : ''; } catch (_) {}
              return ListTile(
                dense: true,
                leading: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 16)),
                title: Text(reason, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: dateStr.isNotEmpty ? Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))) : null,
                trailing: Text('+$pts pts', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B))),
              );
            },
          ),
      ),
      actions: [ElevatedButton(onPressed: () => Navigator.pop(dc), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Close'))],
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROFILE EDIT CARD — Approach 2: Global Toggle (View ↔ Edit)
// ═══════════════════════════════════════════════════════════════════════════

class _ProfileEditCard extends ConsumerStatefulWidget {
  final _SettingsLayoutParams p;
  const _ProfileEditCard({required this.p});
  @override
  ConsumerState<_ProfileEditCard> createState() => _ProfileEditCardState();
}

class _ProfileEditCardState extends ConsumerState<_ProfileEditCard> {
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
      final response = await ApiService().put('/users/profile', {
        'name': _nameCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'age': _ageCtrl.text.trim(),
        if (_gender != null) 'gender': _gender,
      });
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        Map<String, dynamic> userMap;
        if (data is Map && data['user'] is Map) {
          userMap = Map<String, dynamic>.from(data['user'] as Map);
        } else if (data is Map && (data.containsKey('_id') || data.containsKey('id'))) {
          userMap = Map<String, dynamic>.from(data);
        } else {
          userMap = data is Map ? Map<String, dynamic>.from(data) : {};
        }
        if (userMap.isNotEmpty) {
          final existing = ref.read(authProvider).user;
          if (existing != null && userMap['profilePicture'] == null) {
            userMap['profilePicture'] = existing.profilePicture;
          }
          final updatedUser = app_user.User.fromJson(userMap);
          ref.read(authProvider.notifier).setUser(updatedUser);
        }
      }
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
                    child: ClipOval(child: () {
                      final img = buildProfileImageProvider(u?.profilePicture);
                      if (img != null) return Image(image: img, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Text((u?.name ?? 'U').substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primaryColor)));
                      return Text((u?.name ?? 'U').substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primaryColor));
                    }()),
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