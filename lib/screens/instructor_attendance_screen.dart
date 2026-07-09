import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

/// Instructor attendance — sessions listed by name; tap a session to see
/// every enrolled student's attendance for it.
class InstructorAttendanceScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const InstructorAttendanceScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<InstructorAttendanceScreen> createState() =>
      _InstructorAttendanceScreenState();
}

class _InstructorAttendanceScreenState
    extends State<InstructorAttendanceScreen> {
  final LmsService _lms = LmsService();
  List<dynamic> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sessions = await _lms.getCourseAttendanceSessions(widget.courseId);
      // Sort by session name (then date for same-named sessions)
      sessions.sort((a, b) {
        final t = (a['sessionTitle']?.toString() ?? '')
            .toLowerCase()
            .compareTo((b['sessionTitle']?.toString() ?? '').toLowerCase());
        if (t != 0) return t;
        return (b['sessionDate']?.toString() ?? '')
            .compareTo(a['sessionDate']?.toString() ?? '');
      });
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      return DateFormat('EEE, d MMM yyyy').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Column(
          children: [
            const Text('Attendance',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A))),
            Text(widget.courseTitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy_rounded,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No attendance sessions yet',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A))),
                      const SizedBox(height: 8),
                      const Text(
                        'Attendance is recorded automatically\nwhen you run live sessions.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sessions.length,
                    itemBuilder: (_, i) {
                      final s = _sessions[i];
                      final title =
                          s['sessionTitle']?.toString() ?? 'Live Session';
                      final date = _fmtDate(s['sessionDate']?.toString());
                      final presentCount = (s['records'] as List? ?? [])
                          .where((r) => r['status'] == 'present')
                          .length;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.video_call_rounded,
                                color: AppColors.primaryColor),
                          ),
                          title: Text(title,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A))),
                          subtitle: Text(
                              '$date  ·  $presentCount present',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF64748B))),
                          trailing: const Icon(Icons.chevron_right_rounded,
                              color: Color(0xFF94A3B8)),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _SessionAttendanceDetail(
                                sessionId: s['_id']?.toString() ?? '',
                                sessionTitle: title,
                                sessionDate: date,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _SessionAttendanceDetail extends StatefulWidget {
  final String sessionId;
  final String sessionTitle;
  final String sessionDate;

  const _SessionAttendanceDetail({
    required this.sessionId,
    required this.sessionTitle,
    required this.sessionDate,
  });

  @override
  State<_SessionAttendanceDetail> createState() =>
      _SessionAttendanceDetailState();
}

class _SessionAttendanceDetailState extends State<_SessionAttendanceDetail> {
  final LmsService _lms = LmsService();
  List<dynamic> _students = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _lms.getAttendanceSessionDetail(widget.sessionId);
      final students = List<dynamic>.from(data['students'] ?? []);
      // Present students first, then alphabetical
      students.sort((a, b) {
        final sa = a['status'] == 'present' ? 0 : 1;
        final sb = b['status'] == 'present' ? 0 : 1;
        if (sa != sb) return sa - sb;
        return (a['name']?.toString() ?? '')
            .toLowerCase()
            .compareTo((b['name']?.toString() ?? '').toLowerCase());
      });
      if (mounted) {
        setState(() {
          _students = students;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      return DateFormat('h:mm a').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentCount =
        _students.where((s) => s['status'] == 'present').length;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Column(
          children: [
            Text(widget.sessionTitle,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(widget.sessionDate,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary bar
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('${_students.length}', 'Enrolled',
                          const Color(0xFF0036BC)),
                      _stat('$presentCount', 'Present',
                          const Color(0xFF10B981)),
                      _stat('${_students.length - presentCount}', 'Absent',
                          const Color(0xFFEF4444)),
                    ],
                  ),
                ),
                Expanded(
                  child: _students.isEmpty
                      ? const Center(
                          child: Text('No enrolled students',
                              style: TextStyle(color: Color(0xFF64748B))))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _students.length,
                          itemBuilder: (_, i) {
                            final s = _students[i];
                            final present = s['status'] == 'present';
                            final joined = _fmtTime(s['joinedAt']?.toString());
                            final left = _fmtTime(s['leftAt']?.toString());
                            final mins = s['durationMinutes'];
                            String detail = '';
                            if (present) {
                              if (joined.isNotEmpty) detail = 'Joined $joined';
                              if (left.isNotEmpty) detail += ' · Left $left';
                              if (mins != null) detail += ' · $mins min';
                            }
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: present
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFFEF2F2),
                                    child: Text(
                                      (s['name']?.toString() ?? 'S')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: present
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(s['name']?.toString() ?? 'Student',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0F172A))),
                                        if (detail.isNotEmpty)
                                          Text(detail,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: present
                                          ? const Color(0xFFECFDF5)
                                          : const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      present ? 'Present' : 'Absent',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: present
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      ],
    );
  }
}
