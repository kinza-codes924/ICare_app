import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/reminder_event_stub.dart'
    if (dart.library.html) '../utils/reminder_event_web.dart';

/// Wraps the app and listens for icare-reminder JS events (web).
/// Shows a coloured top banner for water, medication, health-check reminders.
class ReminderBannerListener extends StatefulWidget {
  final Widget child;
  const ReminderBannerListener({super.key, required this.child});

  @override
  State<ReminderBannerListener> createState() => _ReminderBannerListenerState();
}

class _ReminderBannerListenerState extends State<ReminderBannerListener> {
  StreamSubscription<Map<String, String>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = reminderEventStream.listen(_onReminder);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onReminder(Map<String, String> event) {
    if (!mounted) return;
    final type  = event['type']  ?? '';
    final title = event['title'] ?? 'Reminder';
    final body  = event['body']  ?? '';

    IconData icon  = Icons.notifications_outlined;
    Color    color = const Color(0xFF6366F1);
    switch (type) {
      case 'water':        icon = Icons.water_drop_outlined;     color = const Color(0xFF3B82F6); break;
      case 'medication':   icon = Icons.medication_outlined;     color = const Color(0xFF8B5CF6); break;
      case 'health_check': icon = Icons.favorite_outline;        color = const Color(0xFFEF4444); break;
      case 'appointment':  icon = Icons.calendar_today_outlined; color = const Color(0xFF10B981); break;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ReminderBanner(
        title: title,
        body: body,
        icon: icon,
        color: color,
        onDismiss: () { try { entry.remove(); } catch (_) {} },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        Overlay.of(context).insert(entry);
        Future.delayed(const Duration(seconds: 8), () {
          try { entry.remove(); } catch (_) {}
        });
      } catch (e) {
        debugPrint('⚠️ ReminderBanner overlay error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ── Banner UI ──────────────────────────────────────────────────────────────

class _ReminderBanner extends StatefulWidget {
  final String title, body;
  final IconData icon;
  final Color color;
  final VoidCallback onDismiss;

  const _ReminderBanner({
    required this.title, required this.body,
    required this.icon, required this.color, required this.onDismiss,
  });

  @override
  State<_ReminderBanner> createState() => _ReminderBannerState();
}

class _ReminderBannerState extends State<_ReminderBanner> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border(left: BorderSide(color: widget.color, width: 4)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: widget.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                      child: Icon(widget.icon, color: widget.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B))),
                          if (widget.body.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(widget.body, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
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
    );
  }
}
