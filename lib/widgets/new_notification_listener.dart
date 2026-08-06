import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icare/services/notification_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/notify_tone.dart';
import 'package:icare/screens/notifications.dart';

/// Wraps the app and polls for new notifications, showing a temporary
/// auto-dismissing top banner (tap to open, plays a system alert sound)
/// whenever one arrives that wasn't there on the previous poll — same
/// mechanism as ReminderBannerListener, generalized to any notification
/// instead of just water/medication/appointment reminders.
class NewNotificationListener extends StatefulWidget {
  final Widget child;
  const NewNotificationListener({super.key, required this.child});

  @override
  State<NewNotificationListener> createState() => _NewNotificationListenerState();
}

class _NewNotificationListenerState extends State<NewNotificationListener> {
  Timer? _poller;
  Set<String> _seenIds = {};
  bool _firstPoll = true;

  @override
  void initState() {
    super.initState();
    _poll();
    _poller = Timer.periodic(const Duration(seconds: 20), (_) => _poll());
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    // Only poll once a session token exists — otherwise every unauthenticated
    // screen (login, signup, public catalog) would hit a 401 every 20s.
    final token = await SharedPref().getToken();
    if (token == null || token.isEmpty) return;
    try {
      final result = await NotificationService().getNotifications();
      if (!mounted || result['success'] != true) return;
      final list = (result['notifications'] as List?) ?? [];
      final currentIds = list.map((n) => (n is Map ? n['_id'] : null)?.toString() ?? '').where((id) => id.isNotEmpty).toSet();

      if (_firstPoll) {
        // First poll just establishes the baseline — nothing "new" yet,
        // this just reflects whatever was already sitting in the inbox.
        _firstPoll = false;
        _seenIds = currentIds;
        return;
      }

      final newIds = currentIds.difference(_seenIds);
      _seenIds = currentIds;
      if (newIds.isEmpty) return;

      final newest = list.firstWhere(
        (n) => n is Map && newIds.contains(n['_id']?.toString()),
        orElse: () => null,
      );
      if (newest is Map) _showBanner(newest);
    } catch (_) {}
  }

  void _showBanner(Map notif) {
    if (!mounted) return;
    playNotifyTone();
    HapticFeedback.mediumImpact();

    final title = notif['title']?.toString() ?? 'New notification';
    final body = notif['message']?.toString() ?? '';

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _NotifBanner(
        title: title,
        body: body,
        onDismiss: () { try { entry.remove(); } catch (_) {} },
        onTap: () {
          try { entry.remove(); } catch (_) {}
          final ctx = _navigatorKeyContext();
          if (ctx != null) {
            Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const NotificationScreen()));
          }
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        Overlay.of(context).insert(entry);
        Future.delayed(const Duration(seconds: 6), () {
          try { entry.remove(); } catch (_) {}
        });
      } catch (e) {
        debugPrint('⚠️ NewNotificationListener overlay error: $e');
      }
    });
  }

  BuildContext? _navigatorKeyContext() => mounted ? context : null;

  @override
  Widget build(BuildContext context) => widget.child;
}

// ── Banner UI (mirrors _ReminderBanner's look) ──────────────────────────────

class _NotifBanner extends StatefulWidget {
  final String title, body;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _NotifBanner({
    required this.title, required this.body,
    required this.onDismiss, required this.onTap,
  });

  @override
  State<_NotifBanner> createState() => _NotifBannerState();
}

class _NotifBannerState extends State<_NotifBanner> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SlideTransition(
        position: _slide,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: widget.onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: const Border(left: BorderSide(color: Color(0xFF1A73E8), width: 4)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFF1A73E8).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.notifications_rounded, color: Color(0xFF1A73E8), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (widget.body.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(widget.body, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                        onPressed: widget.onDismiss,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
