import 'package:flutter/material.dart';
import 'package:icare/screens/create_reminder.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';
import 'package:icare/services/reminder_service.dart';
import 'package:icare/services/google_calendar_service.dart';

// ─────────────────────────────────────────────────────────────────────────────

class ReminderList extends StatefulWidget {
  const ReminderList({super.key});
  @override
  State<ReminderList> createState() => _ReminderListState();
}

class _ReminderListState extends State<ReminderList> with SingleTickerProviderStateMixin {
  final ReminderService _reminderService = ReminderService();
  final GoogleCalendarService _gcal = GoogleCalendarService();
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Map<String, String> _parseScheduled(String? s) {
    if (s == null || s.isEmpty) return {'date': '', 'time': ''};
    try {
      final dt = DateTime.parse(s);
      return {
        'date': DateFormat('dd MMM yyyy').format(dt),
        'time': DateFormat('hh:mm a').format(dt),
      };
    } catch (_) {
      return {'date': '', 'time': s};
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final raw = await _reminderService.getMyReminders();
      if (mounted) {
        setState(() {
          _reminders = raw.map<Map<String, dynamic>>((r) {
            final p = _parseScheduled(r['scheduledFor'] as String?);
            return {
              '_id': r['_id'] ?? '',
              'title': r['title'] ?? 'Reminder',
              'date': p['date']!,
              'time': p['time']!,
              'instructions': r['message'] ?? '',
              'isDoctor': r['type'] == 'doctor_assigned',
              'scheduledFor': r['scheduledFor'],
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(String id) async {
    await _reminderService.deleteReminder(id);
    _load();
  }

  Future<void> _syncToGoogleCalendar() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final signedIn = _gcal.isSignedIn || await _gcal.signIn();
      if (!signedIn) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google sign-in cancelled'), backgroundColor: Colors.orange),
          );
        }
        return;
      }
      if (_reminders.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No reminders to sync'), backgroundColor: Colors.orange),
          );
        }
        return;
      }
      final result = await _gcal.syncReminders(_reminders);
      if (mounted) {
        final s = result['success'] ?? 0;
        final f = result['failed'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(f == 0
                ? '$s reminder${s == 1 ? '' : 's'} synced to Google Calendar'
                : '$s synced, $f failed'),
            backgroundColor: f == 0 ? const Color(0xFF059669) : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ── Grouping ──────────────────────────────────────────────────────────────

  int _hour(Map<String, dynamic> r) {
    try {
      final s = r['scheduledFor'] as String?;
      if (s == null) return -1;
      return DateTime.parse(s).hour;
    } catch (_) { return -1; }
  }

  String _group(Map<String, dynamic> r) {
    final h = _hour(r);
    if (h < 0) return 'Unscheduled';
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  static const _groupOrder = ['Morning', 'Afternoon', 'Evening', 'Unscheduled'];
  static const _groupIcons = {
    'Morning': Icons.wb_sunny_rounded,
    'Afternoon': Icons.wb_cloudy_rounded,
    'Evening': Icons.nightlight_rounded,
    'Unscheduled': Icons.schedule_rounded,
  };
  static const _groupColors = {
    'Morning': Color(0xFFF59E0B),
    'Afternoon': Color(0xFF3B82F6),
    'Evening': Color(0xFF7C3AED),
    'Unscheduled': Color(0xFF64748B),
  };

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final r in _reminders) {
      map.putIfAbsent(_group(r), () => []).add(r);
    }
    return map;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 700;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        leading: const CustomBackButton(),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Reminders',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),
        shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        actions: [
          _isSyncing
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  onPressed: _syncToGoogleCalendar,
                  tooltip: 'Sync to Google Calendar',
                  icon: const Icon(Icons.calendar_month_outlined, color: Color(0xFF0036BC)),
                ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _reminders.isEmpty ? _buildEmpty() : _buildList(isDesktop),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateReminder()),
          );
          if (res == true) _load();
        },
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('Add Reminder', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildList(bool isDesktop) {
    final grouped = _grouped;
    return CustomScrollView(
      slivers: [
        // ── Progress header ─────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(isDesktop ? 40 : 16, 20, isDesktop ? 40 : 16, 8),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 780 : double.infinity),
                child: _buildProgressHeader(),
              ),
            ),
          ),
        ),

        // ── Groups ───────────────────────────────────────────────────────────
        for (final groupKey in _groupOrder)
          if (grouped.containsKey(groupKey)) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(isDesktop ? 40 : 16, 20, isDesktop ? 40 : 16, 10),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isDesktop ? 780 : double.infinity),
                    child: _buildGroupHeader(groupKey),
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final r = grouped[groupKey]![i];
                  return Padding(
                    padding: EdgeInsets.fromLTRB(isDesktop ? 40 : 16, 0, isDesktop ? 40 : 16, 12),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isDesktop ? 780 : double.infinity),
                        child: _ReminderCard(
                          reminder: r,
                          index: i,
                          groupColor: _groupColors[groupKey] ?? AppColors.primaryColor,
                          onDelete: () => _delete(r['_id'] as String),
                          onEdit: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const CreateReminder(isEdit: true)),
                            );
                            _load();
                          },
                        ),
                      ),
                    ),
                  );
                },
                childCount: grouped[groupKey]!.length,
              ),
            ),
          ],

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildProgressHeader() {
    final total = _reminders.length;
    final doctorCount = _reminders.where((r) => r['isDoctor'] == true).length;
    final selfCount = total - doctorCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0036BC), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0036BC).withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          // Circle count
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$total', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                Text('total', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's Reminders", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _statPill(Icons.medical_services_rounded, '$doctorCount Doctor-Assigned'),
                    const SizedBox(width: 8),
                    _statPill(Icons.person_rounded, '$selfCount My Reminders'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String group) {
    final color = _groupColors[group] ?? const Color(0xFF64748B);
    final icon = _groupIcons[group] ?? Icons.schedule_rounded;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(group, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.alarm_add_rounded, size: 72, color: AppColors.primaryColor.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 24),
            const Text(
              'No reminders yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a reminder and never miss\nyour medications or appointments.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.6),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                final res = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateReminder()),
                );
                if (res == true) _load();
              },
              icon: const Icon(Icons.add_alarm_rounded),
              label: const Text('Add First Reminder', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Reminder Card with entrance animation
// ─────────────────────────────────────────────────────────────────────────────

class _ReminderCard extends StatefulWidget {
  final Map<String, dynamic> reminder;
  final int index;
  final Color groupColor;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ReminderCard({
    required this.reminder,
    required this.index,
    required this.groupColor,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<_ReminderCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Stagger by index
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reminder;
    final isDoctor = r['isDoctor'] == true;
    final color = isDoctor ? const Color(0xFF3B82F6) : AppColors.primaryColor;
    final title = r['title'] as String? ?? 'Reminder';
    final time = r['time'] as String? ?? '';
    final date = r['date'] as String? ?? '';
    final instructions = r['instructions'] as String? ?? '';

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Colored time pillar ───────────────────────────────────
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.5)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  // ── Main content ──────────────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isDoctor ? Icons.medical_services_rounded : Icons.alarm_rounded,
                                  color: color,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    // Type + time row
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        _badge(
                                          isDoctor ? 'Doctor-Assigned' : 'My Reminder',
                                          isDoctor ? const Color(0xFF3B82F6) : AppColors.primaryColor,
                                        ),
                                        if (time.isNotEmpty)
                                          _infoChip(Icons.access_time_rounded, time, widget.groupColor),
                                        if (date.isNotEmpty)
                                          _infoChip(Icons.calendar_today_rounded, date, const Color(0xFF64748B)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // ── Actions ─────────────────────────────────
                              PopupMenuButton<String>(
                                onSelected: (val) {
                                  if (val == 'edit') widget.onEdit();
                                  if (val == 'delete') {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: const Text('Delete Reminder', style: TextStyle(fontWeight: FontWeight.w800)),
                                        content: Text('Delete "$title"?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                          ElevatedButton(
                                            onPressed: () { Navigator.pop(ctx); widget.onDelete(); },
                                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white, elevation: 0),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 16, color: Color(0xFF0036BC)), SizedBox(width: 8), Text('Edit')])),
                                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Color(0xFFEF4444)))])),
                                ],
                                icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8), size: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ],
                          ),

                          // Instructions (only if non-empty)
                          if (instructions.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                instructions,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
                              ),
                            ),
                          ],
                        ],
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

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
