import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/services/appointment_service.dart';
import 'package:icare/services/doctor_service.dart';
import 'package:icare/screens/doctor_reviews.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class DoctorAnalytics extends StatefulWidget {
  const DoctorAnalytics({super.key});
  @override
  State<DoctorAnalytics> createState() => _DoctorAnalyticsState();
}

class _DoctorAnalyticsState extends State<DoctorAnalytics> {
  final AppointmentService _appointmentService = AppointmentService();
  final DoctorService _doctorService = DoctorService();

  // Raw data — stored as plain maps to avoid any type-cast issues
  List<dynamic> _appointments = [];
  List<dynamic> _reviews = [];
  Map<String, dynamic> _stats = {};

  bool _isLoading = true;
  String _selectedPeriod = 'This Month';
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      // Load appointments
      try {
        final r = await _appointmentService.getMyAppointmentsDetailed();
        if (mounted && r['success'] == true) {
          // Accept either parsed AppointmentDetail list or raw list
          final raw = r['appointments'];
          setState(() {
            _appointments = (raw is List) ? raw : [];
          });
        }
      } catch (_) {}

      // Load stats
      try {
        final r = await _doctorService.getStats();
        if (mounted && r['success'] == true) {
          setState(() => _stats = (r['stats'] as Map<String, dynamic>?) ?? {});
        }
      } catch (_) {}

      // Load reviews
      try {
        final r = await _doctorService.getMyPatientReviews();
        if (mounted && r['success'] == true) {
          final raw = r['reviews'];
          setState(() => _reviews = (raw is List) ? raw : []);
        }
      } catch (_) {}

    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Period / date helpers ────────────────────────────────────────────────

  DateTime get _periodStart {
    final now = DateTime.now();
    if (_customRange != null) {
      return DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day);
    }
    switch (_selectedPeriod) {
      case 'This Week':
        return DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      case 'This Year':
        return DateTime(now.year, 1, 1);
      default: // This Month
        return DateTime(now.year, now.month, 1);
    }
  }

  DateTime get _periodEnd {
    final now = DateTime.now();
    if (_customRange != null) {
      return DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day)
          .add(const Duration(days: 1));
    }
    switch (_selectedPeriod) {
      case 'This Week':
        final mon = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        return mon.add(const Duration(days: 7));
      case 'This Year':
        return DateTime(now.year + 1, 1, 1);
      default:
        return DateTime(now.year, now.month + 1, 1);
    }
  }

  String get _periodLabel {
    final s = _periodStart;
    final e = _periodEnd.subtract(const Duration(days: 1));
    if (_selectedPeriod == 'Custom' || _customRange != null) {
      return '${DateFormat('d MMM').format(s)} – ${DateFormat('d MMM yyyy').format(e)}';
    }
    if (_selectedPeriod == 'This Week') {
      return '${DateFormat('EEE d MMM').format(s)} – ${DateFormat('EEE d MMM').format(e)}';
    }
    if (_selectedPeriod == 'This Year') return DateFormat('yyyy').format(s);
    return DateFormat('MMMM yyyy').format(s);
  }

  bool _inPeriod(dynamic appt) {
    try {
      // Support both AppointmentDetail and raw Map
      DateTime? date;
      if (appt is Map) {
        final raw = appt['date'] ?? appt['appointmentDate'] ?? appt['scheduledDate'];
        if (raw is String) date = DateTime.tryParse(raw);
        if (raw is DateTime) date = raw;
      } else {
        // AppointmentDetail
        try { date = (appt as dynamic).date as DateTime?; } catch (_) {}
      }
      if (date == null) return false;
      final d = DateTime(date.year, date.month, date.day);
      return !d.isBefore(_periodStart) && d.isBefore(_periodEnd);
    } catch (_) { return false; }
  }

  String _statusOf(dynamic appt) {
    try {
      if (appt is Map) return (appt['status'] as String? ?? '').toLowerCase();
      return ((appt as dynamic).status as String? ?? '').toLowerCase();
    } catch (_) { return ''; }
  }

  // ── Computed stats ────────────────────────────────────────────────────────

  List<dynamic> get _filtered => _appointments.where(_inPeriod).toList();

  int get _total     => _filtered.length;
  int get _completed => _filtered.where((a) => _statusOf(a) == 'completed').length;
  int get _pending   => _filtered.where((a) => _statusOf(a) == 'pending').length;
  int get _cancelled => _filtered.where((a) => _statusOf(a) == 'cancelled').length;
  int get _missed    => _filtered.where((a) => _statusOf(a) == 'missed').length;

  double get _consultationFee {
    final v = _stats['consultationFee'] ?? _stats['fee'] ?? 0;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }
  double get _periodRevenue  => _completed * _consultationFee;
  num    get _allTimeRevenue => (_stats['revenue'] is num) ? _stats['revenue'] as num : 0;
  String get _avgRating {
    // Prefer computed from actual reviews over stats
    if (_reviews.isNotEmpty) {
      final nums = _reviews.map((r) => (r['rating'] as num?)?.toDouble() ?? 0.0).where((v) => v > 0);
      if (nums.isNotEmpty) {
        final avg = nums.reduce((a, b) => a + b) / nums.length;
        return avg.toStringAsFixed(1);
      }
    }
    final v = _stats['avgRating'] ?? _stats['rating'];
    return v != null ? '$v' : '0.0';
  }

  String get _satisfaction {
    // Compute from actual reviews if available
    if (_reviews.isNotEmpty) {
      final satisfied = _reviews.where((r) => r['satisfied'] != false).length;
      final pct = (satisfied / _reviews.length * 100).round();
      return '$pct%';
    }
    final v = _stats['satisfaction'];
    return v != null ? '$v' : '0%';
  }
  String get _avgConsultationTime {
    final v = _stats['avgConsultationMinutes'];
    if (v == null) return '—';
    final mins = (v is num) ? v.toDouble() : double.tryParse('$v');
    if (mins == null) return '—';
    return '${mins % 1 == 0 ? mins.toInt() : mins} min';
  }

  // Last-month revenue
  double get _lastMonthRevenue {
    final now = DateTime.now();
    final lms = DateTime(now.year, now.month - 1, 1);
    final lme = DateTime(now.year, now.month, 1);
    final cnt = _appointments.where((a) {
      if (_statusOf(a) != 'completed') return false;
      try {
        DateTime? d;
        if (a is Map) {
          final raw = a['date'] ?? a['appointmentDate'];
          if (raw is String) d = DateTime.tryParse(raw);
          if (raw is DateTime) d = raw;
        } else {
          try { d = (a as dynamic).date as DateTime?; } catch (_) {}
        }
        if (d == null) return false;
        return !d.isBefore(lms) && d.isBefore(lme);
      } catch (_) { return false; }
    }).length;
    return cnt * _consultationFee;
  }

  // ── Pick custom range ─────────────────────────────────────────────────────

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _customRange ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      helpText: 'Select date range',
    );
    if (picked != null && mounted) {
      setState(() { _customRange = picked; _selectedPeriod = 'Custom'; });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Text('Revenue & Analytics'.tr(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isWide ? 40 : 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isWide ? 1000 : double.infinity),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPeriodSelector(),
                        const SizedBox(height: 20),
                        _buildRevenueSection(),
                        const SizedBox(height: 20),
                        _buildStatsGrid(isWide),
                        const SizedBox(height: 20),
                        _buildReviewsSection(),
                        const SizedBox(height: 20),
                        _buildBreakdown(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ── Period selector ───────────────────────────────────────────────────────

  Widget _buildPeriodSelector() {
    const periods = ['This Week', 'This Month', 'This Year'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                ),
                child: Row(
                  children: periods.map((p) {
                    final sel = _selectedPeriod == p;
                    return Expanded(child: GestureDetector(
                      onTap: () => setState(() { _selectedPeriod = p; _customRange = null; }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(p, textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                color: sel ? Colors.white : const Color(0xFF64748B))),
                      ),
                    ));
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _pickRange,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                ),
                child: Icon(Icons.date_range_rounded,
                    color: _customRange != null ? AppColors.primaryColor : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF94A3B8)),
          const SizedBox(width: 5),
          Text(_periodLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        ]),
      ],
    );
  }

  // ── Revenue cards ─────────────────────────────────────────────────────────

  Widget _buildRevenueSection() {
    String fmt(num v) => 'PKR ${v.toStringAsFixed(0)}';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.payments_rounded, color: Color(0xFF10B981), size: 20)),
          const SizedBox(width: 10),
          const Text('Revenue', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _revenueBox('Last Month', fmt(_lastMonthRevenue), const Color(0xFF8B5CF6))),
          const SizedBox(width: 12),
          Expanded(child: _revenueBox('This Period', fmt(_periodRevenue), const Color(0xFF10B981))),
        ]),
        const SizedBox(height: 12),
        _revenueBox('All-time Total', fmt(_allTimeRevenue), const Color(0xFF3B82F6)),
      ]),
    );
  }

  Widget _revenueBox(String label, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(amount, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
      ]),
    );
  }

  // ── Stats grid ────────────────────────────────────────────────────────────

  Widget _buildStatsGrid(bool isWide) {
    final cards = [
      _StatItem('Total', '$_total', Icons.calendar_month_rounded, const Color(0xFF3B82F6)),
      _StatItem('Completed', '$_completed', Icons.check_circle_rounded, const Color(0xFF10B981)),
      _StatItem('Missed', '$_missed', Icons.warning_rounded, const Color(0xFF64748B)),
      _StatItem('Reviews', '${_reviews.length}', Icons.rate_review_rounded, const Color(0xFF8B5CF6), onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DoctorReviews()));
      }),
      _StatItem('Satisfaction', _satisfaction, Icons.sentiment_very_satisfied_rounded, const Color(0xFF6366F1)),
      _StatItem('Avg. Rating', _avgRating, Icons.star_rounded, const Color(0xFFF59E0B)),
      _StatItem('Avg. Consult', _avgConsultationTime, Icons.timer_rounded, const Color(0xFF0EA5E9)),
    ];

    if (isWide) {
      return Column(children: [
        Row(children: cards.take(4).map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: _statCard(c)))).toList()),
        const SizedBox(height: 12),
        Row(children: [
          ...cards.skip(4).map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: _statCard(c)))),
          const Expanded(child: SizedBox()),
        ]),
      ]);
    }
    return Column(children: [
      Row(children: [Expanded(child: _statCard(cards[0])), const SizedBox(width: 12), Expanded(child: _statCard(cards[1]))]),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: _statCard(cards[2])), const SizedBox(width: 12), Expanded(child: _statCard(cards[3]))]),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: _statCard(cards[4])), const SizedBox(width: 12), Expanded(child: _statCard(cards[5]))]),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: _statCard(cards[6])), const Expanded(child: SizedBox())]),
    ]);
  }

  Widget _statCard(_StatItem item) {
    final inner = Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(border: Border.all(color: item.color.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: item.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(item.icon, color: item.color, size: 20)),
          if (item.onTap != null) ...[const Spacer(), Icon(Icons.chevron_right_rounded, color: item.color.withValues(alpha: 0.6), size: 18)],
        ]),
        const SizedBox(height: 10),
        Text(item.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        const SizedBox(height: 3),
        Text(item.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
      ]),
    );
    if (item.onTap != null) {
      return InkWell(onTap: item.onTap, borderRadius: BorderRadius.circular(14), child: inner);
    }
    return inner;
  }

  // ── Reviews section ───────────────────────────────────────────────────────

  Widget _buildReviewsSection() {
    if (_reviews.isEmpty) return const SizedBox.shrink();
    final preview = _reviews.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Recent Reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DoctorReviews())),
            child: const Text('View all'),
          ),
        ]),
        const SizedBox(height: 8),
        ...preview.map((r) {
          final name      = r['patientName']?.toString() ?? 'Patient';
          final rating    = r['rating'];
          final comment   = r['comment']?.toString() ?? '';
          final satisfied = r['satisfied'] != false;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)))),
                  if (rating != null)
                    Row(children: List.generate(5, (i) => Icon(
                      i < (rating as num) ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 14, color: const Color(0xFFF59E0B),
                    ))),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: satisfied ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(satisfied ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
                          size: 11, color: satisfied ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                      const SizedBox(width: 4),
                      Text(satisfied ? 'Satisfied' : 'Not satisfied',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: satisfied ? const Color(0xFF16A34A) : const Color(0xFFDC2626))),
                    ]),
                  ),
                ]),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(comment, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                ],
              ]),
            ),
          );
        }),
      ]),
    );
  }

  // ── Breakdown ─────────────────────────────────────────────────────────────

  Widget _buildBreakdown() {
    final items = [
      ('Completed', _completed, const Color(0xFF10B981)),
      ('Pending',   _pending,   const Color(0xFFF59E0B)),
      ('Cancelled', _cancelled, const Color(0xFFEF4444)),
      ('Missed',    _missed,    const Color(0xFF64748B)),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Appointment Breakdown', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        const SizedBox(height: 16),
        ...items.map((t) {
          final pct = _total > 0 ? t.$2 / _total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(t.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                Text('${t.$2}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: t.$3)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: pct.clamp(0.0, 1.0), backgroundColor: t.$3.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(t.$3), minHeight: 7)),
            ]),
          );
        }),
      ]),
    );
  }

  BoxDecoration _cardDeco({Border? border}) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: border ?? Border.all(color: const Color(0xFFE2E8F0)),
    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3))],
  );
}

class _StatItem {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _StatItem(this.label, this.value, this.icon, this.color, {this.onTap});
}
