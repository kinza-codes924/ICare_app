import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/services/notification_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettings extends ConsumerStatefulWidget {
  const NotificationSettings({super.key});

  @override
  ConsumerState<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends ConsumerState<NotificationSettings> {
  final Map<String, bool> _toggleStates = {
    'Notification Sound': true,
    'Send prescription to email automatically': false,
  };

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        for (final key in _toggleStates.keys.toList()) {
          final prefKey = 'notif_${key.replaceAll(' ', '_').toLowerCase()}';
          final saved = prefs.getBool(prefKey);
          if (saved != null) _toggleStates[key] = saved;
        }
      });
    }
  }

  Future<void> _saveToggle(String title, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final prefKey = 'notif_${title.replaceAll(' ', '_').toLowerCase()}';
    await prefs.setBool(prefKey, value);
    if (title == 'Send prescription to email automatically') {
      final userId = ref.read(authProvider).user?.id ?? '';
      if (userId.isNotEmpty) {
        NotificationService().updateNotificationPreferences(
          userId,
          {'emailPrescriptionAuto': value},
        ).ignore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.read(authProvider).userRole ?? '';
    final isPatient = role == 'Patient';
    final isStudent = role == 'Student';
    final isPharmacy = role == 'Pharmacy';
    final isLaboratory = role == 'Laboratory';

    List<Map<String, dynamic>> settingsList;

    if (isPatient) {
      settingsList = [
        {"id": "1", "title": "Appointment Confirmed", "onPress": () {}},
        {"id": "2", "title": "Lab Results Ready", "onPress": () {}},
        {"id": "3", "title": "New Prescription", "onPress": () {}},
        {"id": "4", "title": "Medication Reminder", "onPress": () {}},
        {"id": "5", "title": "Notification Sound", "onPress": () {}, "isToggle": true},
        {"id": "6", "title": "Email: Appointment Confirmation", "onPress": () {}, "isToggle": true},
        {"id": "7", "title": "Email: Lab Report Ready", "onPress": () {}, "isToggle": true},
        {"id": "8", "title": "Email: Prescription Sent", "onPress": () {}, "isToggle": true},
        {"id": "9", "title": "Email: Consultation Summary", "onPress": () {}, "isToggle": true},
        {"id": "10", "title": "Email: Pharmacy Order Receipt", "onPress": () {}, "isToggle": true},
      ];
    } else if (isStudent) {
      settingsList = [
        {"id": "1", "title": "New Course Updates", "onPress": () {}},
        {"id": "2", "title": "Assignment Reminders", "onPress": () {}},
        {"id": "3", "title": "Certificate Earned", "onPress": () {}},
        {"id": "4", "title": "Admin Announcements", "onPress": () {}},
      ];
    } else if (isPharmacy) {
      settingsList = [
        {"id": "1", "title": "New Orders", "onPress": () {}},
        {"id": "2", "title": "Order Status Updates", "onPress": () {}},
        {"id": "3", "title": "Low Stock Alerts", "onPress": () {}},
        {"id": "4", "title": "Customer Support Messages", "onPress": () {}},
      ];
    } else if (isLaboratory) {
      settingsList = [
        {"id": "1", "title": "New Test Requests", "onPress": () {}},
        {"id": "2", "title": "Result Ready Alerts", "onPress": () {}},
        {"id": "3", "title": "Customer Support Messages", "onPress": () {}},
      ];
    } else {
      // Doctor — patient/customer-support messages removed per product spec
      settingsList = [
        {"id": "1", "title": "New Appointment Bookings", "onPress": () {}},
      ];
    }
    if (MediaQuery.of(context).size.width > 600) {
      final userId = ref.read(authProvider).user?.id ?? '';
      return _WebNotificationSettingsScreen(
        isStudent: isStudent,
        isPatient: isPatient,
        isPharmacy: isPharmacy,
        isLaboratory: isLaboratory,
        userId: userId,
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: CustomBackButton(),
        title: CustomText(
          text: "Notification Settings".tr(),
          fontSize: 16.78,
          fontFamily: "Gilroy-Bold",
          color: AppColors.primary500,
          letterSpacing: -0.31,
          lineHeight: 1.0,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: ScallingConfig.scale(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: Utils.windowWidth(context) * 0.85,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: settingsList.map((item) {
                  final bool isToggle = item['isToggle'] ?? false;
                  final String title = item['title'] as String;
                  final bool toggleValue = _toggleStates[title] ?? false;
                  return GestureDetector(
                    onTap: isToggle ? null : item["onPress"],
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18.0,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: CustomText(
                                  text: title.tr(),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.primary500,
                                  fontFamily: "Gilroy-SemiBold",
                                ),
                              ),
                              isToggle
                                ? FlutterSwitch(
                                    width: 50.0,
                                    height: 20.0,
                                    toggleSize: 15.0,
                                    value: toggleValue,
                                    borderRadius: 30.0,
                                    padding: 2.0,
                                    toggleColor: const Color.fromRGBO(225, 225, 225, 1),
                                    activeColor: AppColors.themeBlack,
                                    inactiveColor: AppColors.darkGreyColor,
                                    onToggle: (val) {
                                      setState(() => _toggleStates[title] = val);
                                      _saveToggle(title, val);
                                    },
                                  )
                                : IconButton(
                                    onPressed: item["onPress"],
                                    icon: const Icon(
                                      Icons.arrow_forward_ios,
                                      color: AppColors.primaryColor,
                                      size: 16,
                                    ),
                                  ),
                            ],
                          ),
                        ),
                        if (item['id'] != settingsList.last['id'])
                          const Divider(
                            color: AppColors.darkGreyColor,
                            thickness: 0.2,
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: Utils.windowHeight(context) * 0.5),
            if (!isPatient)
              CustomButton(
                borderRadius: 30,
                onPressed: () {},
                label: "Delete Account".tr(),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NEW STUNNING WEB VIEW
// ═══════════════════════════════════════════════════════════════════════════

class _WebNotificationSettingsScreen extends StatefulWidget {
  final bool isStudent;
  final bool isPatient;
  final bool isPharmacy;
  final bool isLaboratory;
  final String userId;
  const _WebNotificationSettingsScreen({
    this.isStudent = false,
    this.isPatient = false,
    this.isPharmacy = false,
    this.isLaboratory = false,
    this.userId = '',
  });

  @override
  State<_WebNotificationSettingsScreen> createState() =>
      _WebNotificationSettingsScreenState();
}

class _WebNotificationSettingsScreenState
    extends State<_WebNotificationSettingsScreen> {
  late Map<String, bool> settingsState;

  @override
  void initState() {
    super.initState();
    _initDefaults();
    _loadPrefs();
  }

  void _initDefaults() {
    if (widget.isStudent) {
      settingsState = {
        "New Course Updates": true,
        "Assignment Reminders": true,
        "Certificate Earned": true,
        "Admin Announcements": false,
      };
    } else if (widget.isPatient) {
      settingsState = {
        // Push / in-app
        "Appointment Confirmed": true,
        "Lab Results Ready": true,
        "New Prescription": true,
        "Medication Reminder": true,
        "Notification Sound": true,
        // Email notifications
        "Email: Appointment Confirmation": true,
        "Email: Lab Report Ready": true,
        "Email: Prescription Sent": true,
        "Email: Consultation Summary": false,
        "Email: Pharmacy Order Receipt": true,
      };
    } else if (widget.isPharmacy) {
      settingsState = {
        "New Orders": true,
        "Order Status Updates": true,
        "Low Stock Alerts": true,
        "Customer Support Messages": false,
      };
    } else if (widget.isLaboratory) {
      settingsState = {
        "New Test Requests": true,
        "Result Ready Alerts": true,
        "Customer Support Messages": false,
        "Email: Send Report to Patient": true,
      };
    } else {
      // Doctor — patient/customer-support messages removed per product spec
      settingsState = { "New Appointment Bookings": true };
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      final updated = Map<String, bool>.from(settingsState);
      for (final key in settingsState.keys) {
        final prefKey = 'notif_${key.replaceAll(' ', '_').toLowerCase()}';
        final saved = prefs.getBool(prefKey);
        if (saved != null) updated[key] = saved;
      }
      setState(() => settingsState = updated);
    }
  }

  Future<void> _saveToggle(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final prefKey = 'notif_${key.replaceAll(' ', '_').toLowerCase()}';
    await prefs.setBool(prefKey, value);
    // Sync email preferences to backend
    if (widget.userId.isNotEmpty) {
      final Map<String, String> emailPrefMap = {
        'Email: Appointment Confirmation': 'emailAppointmentConfirm',
        'Email: Lab Report Ready': 'emailLabReport',
        'Email: Prescription Sent': 'emailPrescriptionAuto',
        'Email: Consultation Summary': 'emailConsultationSummary',
        'Email: Pharmacy Order Receipt': 'emailPharmacyReceipt',
        'Email: Send Report to Patient': 'emailLabReportToPatient',
      };
      final backendKey = emailPrefMap[key];
      if (backendKey != null) {
        NotificationService().updateNotificationPreferences(
          widget.userId,
          {backendKey: value},
        ).ignore();
      }
    }
  }

  Map<String, String> get settingDescriptions {
    if (widget.isStudent) {
      return {
        "New Course Updates":
            "Get notified when instructors publish new lessons or update course materials.",
        "Assignment Reminders":
            "Receive reminders before quiz deadlines and assignment due dates.",
        "Certificate Earned":
            "Be the first to know when you earn a new completion certificate.",
        "Admin Announcements":
            "Important platform updates and broadcast messages from administrators.",
      };
    } else if (widget.isPatient) {
      return {
        "Appointment Confirmed":
            "Get notified as soon as your doctor confirms your appointment.",
        "Lab Results Ready":
            "Receive an alert when your lab test results are ready to view.",
        "New Prescription":
            "Be notified the moment your doctor sends you a new prescription.",
        "Medication Reminder":
            "Get in-app and browser reminders to take your prescribed medications on time.",
        "Notification Sound":
            "Play a sound when you receive a new notification.",
        "Email: Appointment Confirmation":
            "Receive an email confirmation every time an appointment is booked or confirmed.",
        "Email: Lab Report Ready":
            "Get your lab report delivered to your inbox as soon as it is ready.",
        "Email: Prescription Sent":
            "Receive your prescription by email after every completed consultation.",
        "Email: Consultation Summary":
            "Get a full summary of your consultation notes sent to your email.",
        "Email: Pharmacy Order Receipt":
            "Receive a receipt by email whenever a pharmacy order is placed or delivered.",
      };
    } else if (widget.isPharmacy) {
      return {
        "New Orders":
            "Get notified instantly when a new prescription order is placed.",
        "Order Status Updates":
            "Receive alerts when an order is updated, completed, or cancelled.",
        "Low Stock Alerts":
            "Be warned when a medicine's stock falls below the minimum threshold.",
        "Customer Support Messages":
            "Receive instant alerts when the support team responds to your queries.",
      };
    } else if (widget.isLaboratory) {
      return {
        "New Test Requests":
            "Get notified when a new diagnostic test is requested for your lab.",
        "Result Ready Alerts":
            "Receive alerts when a result entry is completed and ready for review.",
        "Customer Support Messages":
            "Receive instant alerts when the support team responds to your queries.",
        "Email: Send Report to Patient":
            "Automatically send the completed lab report to the patient's email address.",
      };
    } else {
      return {
        "New Appointment Bookings":
            "Get notified when a patient books a new appointment with you.",
      };
    }
  }

  Map<String, IconData> get settingIcons {
    if (widget.isStudent) {
      return {
        "New Course Updates": Icons.library_books_rounded,
        "Assignment Reminders": Icons.assignment_late_rounded,
        "Certificate Earned": Icons.workspace_premium_rounded,
        "Admin Announcements": Icons.campaign_rounded,
      };
    } else if (widget.isPatient) {
      return {
        "Appointment Confirmed": Icons.event_available_rounded,
        "Lab Results Ready": Icons.biotech_rounded,
        "New Prescription": Icons.medication_rounded,
        "Medication Reminder": Icons.alarm_rounded,
        "Notification Sound": Icons.volume_up_rounded,
        "Email: Appointment Confirmation": Icons.email_rounded,
        "Email: Lab Report Ready": Icons.science_rounded,
        "Email: Prescription Sent": Icons.local_pharmacy_rounded,
        "Email: Consultation Summary": Icons.summarize_rounded,
        "Email: Pharmacy Order Receipt": Icons.receipt_long_rounded,
      };
    } else if (widget.isPharmacy) {
      return {
        "New Orders": Icons.shopping_bag_rounded,
        "Order Status Updates": Icons.sync_rounded,
        "Low Stock Alerts": Icons.warning_amber_rounded,
        "Customer Support Messages": Icons.support_agent_rounded,
      };
    } else if (widget.isLaboratory) {
      return {
        "New Test Requests": Icons.biotech_rounded,
        "Result Ready Alerts": Icons.assignment_turned_in_rounded,
        "Customer Support Messages": Icons.support_agent_rounded,
        "Email: Send Report to Patient": Icons.forward_to_inbox_rounded,
      };
    } else {
      return { "New Appointment Bookings": Icons.event_available_rounded };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: CustomBackButton(),
        title: CustomText(
          text: "Notification Settings".tr(),
          fontFamily: "Gilroy-Bold",
          fontSize: 20,
          color: AppColors.primaryColor,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.31,
          lineHeight: 1.0,
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left: Header Info ──
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: AppColors.primaryColor,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Push & Email Alerts".tr(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            fontFamily: "Gilroy-Bold",
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Control exactly what alerts you want to receive and how you receive them so you are never overwhelmed.".tr(),
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 48),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Preferences saved successfully.".tr(),
                                  ),
                                ),
                              );
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.save_rounded, size: 20),
                            label: Text(
                              "Save Preferences".tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: "Gilroy-SemiBold",
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 48),

                  // ── Right: List of Toggles ──
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFF1F4F9),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x05000000),
                            offset: Offset(0, 4),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: settingsState.keys.length,
                        separatorBuilder: (context, index) => const Divider(
                          color: Color(0xFFF1F5F9),
                          height: 1,
                          thickness: 1.5,
                        ),
                        itemBuilder: (context, index) {
                          final key = settingsState.keys.elementAt(index);
                          final val = settingsState[key]!;
                          final desc = settingDescriptions[key]!;
                          final icon = settingIcons[key]!;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 24,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: val
                                        ? const Color(0xFFEFF6FF)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    icon,
                                    color: val
                                        ? AppColors.primaryColor
                                        : const Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        key.tr(),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: val
                                              ? const Color(0xFF1E293B)
                                              : const Color(0xFF64748B),
                                          fontFamily: "Gilroy-SemiBold",
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        desc,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: val
                                              ? const Color(0xFF64748B)
                                              : const Color(0xFF94A3B8),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                FlutterSwitch(
                                  width: 50.0,
                                  height: 26.0,
                                  toggleSize: 18.0,
                                  value: val,
                                  borderRadius: 30.0,
                                  padding: 4.0,
                                  toggleColor: Colors.white,
                                  activeColor: AppColors.primaryColor,
                                  inactiveColor: const Color(0xFFCBD5E1),
                                  onToggle: (newVal) {
                                    setState(() {
                                      settingsState[key] = newVal;
                                    });
                                    _saveToggle(key, newVal);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
