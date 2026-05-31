import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/bookings_history.dart';
import 'package:icare/screens/lab_reports_screen.dart';
import 'package:icare/screens/patient_prescriptions.dart';
import 'package:icare/screens/reminder_list.dart';
import 'package:icare/services/notification_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final result = await _notificationService.getNotifications();
      if (mounted) {
        setState(() {
          if (result['success'] == true) {
            _notifications = result['notifications'] ?? [];
            
            // If no notifications from API, show sample data for testing
            if (_notifications.isEmpty) {
              _notifications = _getSampleNotifications();
            }
          } else {
            _notifications = _getSampleNotifications();
            if (result['error'] != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Using sample data - API unavailable'.tr()),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _notifications = _getSampleNotifications();
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Using sample data - Connection error'.tr()),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  List<dynamic> _getSampleNotifications() {
    return [
      {
        '_id': '1',
        'type': 'appointment',
        'title': 'Appointment Confirmed',
        'message': 'Your appointment with Dr. Ahmed Khan has been confirmed for tomorrow at 10:00 AM',
        'read': false,
        'createdAt': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
      },
      {
        '_id': '2',
        'type': 'lab',
        'title': 'Lab Results Ready',
        'message': 'Your blood test results are now available. Please check your reports section.',
        'read': false,
        'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      },
      {
        '_id': '3',
        'type': 'prescription',
        'title': 'New Prescription',
        'message': 'Dr. Sara Malik has prescribed new medication for you. View details in prescriptions.',
        'read': true,
        'createdAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        '_id': '4',
        'type': 'reminder',
        'title': 'Medication Reminder',
        'message': 'Time to take your evening medication - Aspirin 100mg',
        'read': true,
        'createdAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
    ];
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      for (final n in _notifications) {
        n['read'] = true;
      }
    });
    await _notificationService.markAllAsRead();
    _loadNotificationsQuiet();
  }

  void _markAsReadOptimistic(String id) {
    // Update local state immediately so the dot disappears without a reload flash
    setState(() {
      for (final n in _notifications) {
        if (n['_id'] == id) n['read'] = true;
      }
    });
    // Fire backend call in background, reload list silently when done
    _notificationService.markAsRead(id).then((_) {
      if (mounted) _loadNotificationsQuiet();
    });
  }

  Future<void> _loadNotificationsQuiet() async {
    try {
      final result = await _notificationService.getNotifications();
      if (mounted && result['success'] == true) {
        final fresh = result['notifications'] as List? ?? [];
        if (fresh.isNotEmpty) setState(() => _notifications = fresh);
      }
    } catch (_) {}
  }

  void _navigateToContent(Map notif, String id, bool isUnread) {
    if (isUnread) _markAsReadOptimistic(id);
    final String type = notif['type'] ?? '';
    switch (type) {
      case 'appointment':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookingsHistoryScreen()));
        break;
      case 'lab':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LabReportsScreen()));
        break;
      case 'prescription':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PatientPrescriptions()));
        break;
      case 'reminder':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReminderList()));
        break;
      default:
        break;
    }
  }

  int get _unreadCount =>
      _notifications.where((n) => n['read'] == false).length;

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 600;
    return isDesktop ? _buildDesktop() : _buildMobile();
  }

  Widget _buildMobile() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: CustomBackButton(),
        title: CustomText(
          text: "Notifications".tr(),
          fontSize: 18,
          fontFamily: "Gilroy-Bold",
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Mark all read'.tr(),
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
      body: _buildBody(false),
    );
  }

  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 24,
              left: 48,
              right: 48,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xFF0F172A),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText(
                            text: "Notifications".tr(),
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                          const SizedBox(height: 2),
                          CustomText(
                            text: "Stay updated with your latest activity".tr(),
                            fontSize: 14,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ],
                      ),
                    ),
                    if (_unreadCount > 0) ...[
                      TextButton(
                        onPressed: _markAllAsRead,
                        child: Text('Mark all read'.tr()),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.mark_email_unread_rounded,
                              size: 16,
                              color: AppColors.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            CustomText(
                              text: "$_unreadCount Unread",
                              fontSize: 14,
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: _buildBody(true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDesktop) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            CustomText(
              text: "Loading notifications...".tr(),
              fontSize: 14,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_rounded,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            CustomText(
              text: "No notifications yet".tr(),
              fontSize: 16,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(
          vertical: isDesktop ? 24 : 0,
          horizontal: isDesktop ? 20 : 0,
        ),
        itemCount: _notifications.length,
        separatorBuilder: (_, _) => isDesktop
            ? const SizedBox(height: 12)
            : Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ScallingConfig.scale(20),
                ),
                child: Divider(
                  color: AppColors.grayColor.withValues(alpha: 0.3),
                  height: 1,
                ),
              ),
        itemBuilder: (context, index) {
          final notif = _notifications[index];
          final bool isUnread = notif['read'] == false;
          final String type = notif['type'] ?? 'default';
          final String title = notif['title'] ?? 'Notification';
          final String message = notif['message'] ?? '';
          final String id = notif['_id'] ?? '';
          final String time = _formatTime(notif['createdAt']);

          if (isDesktop) {
            return GestureDetector(
              onTap: () => _navigateToContent(notif, id, isUnread),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isUnread
                        ? AppColors.primaryColor.withValues(alpha: 0.3)
                        : const Color(0xFFF1F5F9),
                    width: isUnread ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isUnread
                          ? AppColors.primaryColor.withValues(alpha: 0.04)
                          : const Color(0xFF0F172A).withValues(alpha: 0.02),
                      blurRadius: isUnread ? 16 : 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _getIconColor(type).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _getIcon(type),
                        color: _getIconColor(type),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CustomText(
                                text: title,
                                color: const Color(0xFF0F172A),
                                fontWeight: isUnread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 17,
                              ),
                              CustomText(
                                text: time,
                                fontSize: 13,
                                color: const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w600,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          CustomText(
                            text: message,
                            fontSize: 14,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                            lineHeight: 1.4,
                          ),
                        ],
                      ),
                    ),
                    if (isUnread) ...[
                      const SizedBox(width: 16),
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          // Mobile item
          return GestureDetector(
            onTap: () => _navigateToContent(notif, id, isUnread),
            child: Container(
              color: isUnread
                  ? AppColors.primaryColor.withValues(alpha: 0.05)
                  : Colors.transparent,
              padding: EdgeInsets.symmetric(
                vertical: ScallingConfig.verticalScale(16),
                horizontal: ScallingConfig.scale(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _getIconColor(type).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIcon(type),
                      color: _getIconColor(type),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: CustomText(
                                text: title,
                                color: isUnread
                                    ? const Color(0xFF0F172A)
                                    : AppColors.darkGreyColor,
                                fontWeight: isUnread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 15,
                                fontFamily: "Gilroy",
                              ),
                            ),
                            if (isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        CustomText(
                          text: message,
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                          fontFamily: "Gilroy",
                          fontWeight: FontWeight.w500,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        CustomText(
                          text: time,
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                          fontFamily: "Gilroy",
                          fontWeight: FontWeight.w600,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case "appointment":
        return Icons.calendar_today_rounded;
      case "payment":
        return Icons.account_balance_wallet_rounded;
      case "reminder":
        return Icons.alarm_rounded;
      case "lab":
        return Icons.biotech_rounded;
      case "prescription":
        return Icons.medication_rounded;
      case "message":
        return Icons.forum_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case "appointment":
        return const Color(0xFF22C55E);
      case "payment":
        return const Color(0xFF3B82F6);
      case "reminder":
        return const Color(0xFFF59E0B);
      case "lab":
        return const Color(0xFF8B5CF6);
      case "prescription":
        return const Color(0xFFEF4444);
      case "message":
        return const Color(0xFF14B1FF);
      default:
        return AppColors.primaryColor;
    }
  }
}
