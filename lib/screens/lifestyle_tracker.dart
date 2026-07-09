import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/screens/my_learning.dart';
import 'package:icare/services/lifestyle_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════════════════════

class HealthLog {
  final String id;
  final String type;
  final String name;
  final dynamic value;
  final String unit;
  final DateTime timestamp;
  final int colorHex;

  const HealthLog({
    required this.id,
    required this.type,
    required this.name,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.colorHex,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    'value': value,
    'unit': unit,
    'timestamp': timestamp.toIso8601String(),
    'colorHex': colorHex,
  };

  factory HealthLog.fromJson(Map<String, dynamic> j) => HealthLog(
    id: j['id'] as String,
    type: j['type'] as String,
    name: j['name'] as String,
    value: j['value'],
    unit: j['unit'] as String,
    timestamp: DateTime.parse(j['timestamp'] as String).toLocal(),
    colorHex: j['colorHex'] as int,
  );

  String get dateKey => DateFormat('yyyy-MM-dd').format(timestamp);
  String get timeLabel => DateFormat('hh:mm a').format(timestamp);
}

// ═══════════════════════════════════════════════════════════════════════════
// VITALS CONFIG
// ═══════════════════════════════════════════════════════════════════════════

class _VitalCfg {
  final String id, name, unit, hint;
  final IconData icon;
  final int color;
  final bool isMood, isWater, isSteps, isBP;
  const _VitalCfg({
    required this.id, required this.name, required this.unit,
    required this.hint, required this.icon, required this.color,
    this.isMood = false, this.isWater = false,
    this.isSteps = false, this.isBP = false,
  });
}

const _vitals = [
  _VitalCfg(id:'bp',          name:'Blood Pressure', unit:'mmHg', hint:'120/80', icon:Icons.favorite_rounded,              color:0xFFEF4444, isBP:true),
  _VitalCfg(id:'sugar',       name:'Blood Sugar',    unit:'mg/dL',hint:'100',    icon:Icons.bloodtype_rounded,             color:0xFFF59E0B),
  _VitalCfg(id:'weight',      name:'Weight',         unit:'kg',   hint:'70',     icon:Icons.monitor_weight_rounded,        color:0xFF8B5CF6),
  _VitalCfg(id:'heart_rate',  name:'Heart Rate',     unit:'bpm',  hint:'72',     icon:Icons.show_chart_rounded,            color:0xFFEC4899),
  _VitalCfg(id:'spo2',        name:'SpO2',           unit:'%',    hint:'98',     icon:Icons.air_rounded,                   color:0xFF3B82F6),
  _VitalCfg(id:'temperature', name:'Temperature',    unit:'°C',   hint:'37.0',   icon:Icons.thermostat_rounded,            color:0xFFFF6B35),
  _VitalCfg(id:'steps',       name:'Steps',          unit:'steps',hint:'5000',   icon:Icons.directions_walk_rounded,       color:0xFF10B981, isSteps:true),
  _VitalCfg(id:'calories',    name:'Calories',       unit:'kcal', hint:'500',    icon:Icons.local_fire_department_rounded, color:0xFFF97316),
  _VitalCfg(id:'water',       name:'Water Intake',   unit:'glasses',hint:'2',    icon:Icons.water_drop_rounded,            color:0xFF3B82F6, isWater:true),
  _VitalCfg(id:'mood',        name:'Mood & Wellness',unit:'',     hint:'',       icon:Icons.sentiment_satisfied_rounded,   color:0xFF8B5CF6, isMood:true),
];

// ═══════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class LifestyleTrackerScreen extends StatefulWidget {
  const LifestyleTrackerScreen({super.key});
  @override
  State<LifestyleTrackerScreen> createState() => _LifestyleTrackerScreenState();
}

class _LifestyleTrackerScreenState extends State<LifestyleTrackerScreen> {
  // Lifestyle API data
  double _waterIntake = 0;
  double _sleepHours  = 0;
  int    _steps       = 0;
  bool   _apiLoading  = true;

  // Health logs (local)
  List<HealthLog> _logs = [];

  // My-Logs filter
  String _logFilter = 'all';
  String _dateRangeFilter = 'all'; // all, 7days, 30days, 60days, 90days

  @override
  void initState() {
    super.initState();
    _loadApiData();
    _loadLogs();
  }

  // ── API data ───────────────────────────────────────────────────────────────

  Future<void> _loadApiData() async {
    setState(() => _apiLoading = true);
    try {
      final r = await LifestyleService.getTodayData();
      final d = r['data'] ?? {};
      if (mounted) {
        setState(() {
        _waterIntake = (d['waterIntake'] ?? 0).toDouble();
        _sleepHours  = (d['sleepHours']  ?? 0).toDouble();
        _steps       = (d['steps']       ?? 0) as int;
        _apiLoading  = false;
      });
      }
    } catch (_) {
      if (mounted) setState(() => _apiLoading = false);
    }
  }

  Future<void> _updateApiData({double? water, double? sleep, int? steps}) async {
    try {
      await LifestyleService.updateData(waterIntake: water, sleepHours: sleep, steps: steps);
      if (water  != null) setState(() => _waterIntake = water);
      if (sleep  != null) setState(() => _sleepHours  = sleep);
      if (steps  != null) setState(() => _steps       = steps);
    } catch (_) {}
  }

  // ── Log persistence ────────────────────────────────────────────────────────

  Future<void> _loadLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString('health_logs_v2');
      if (raw != null && mounted) {
        final decoded = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        setState(() => _logs = decoded.map(HealthLog.fromJson).toList());
      }
    } catch (_) {}
  }

  Future<void> _saveLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('health_logs_v2', jsonEncode(_logs.map((l) => l.toJson()).toList()));
    } catch (_) {}
  }

  void _addLog(HealthLog log) {
    setState(() => _logs.insert(0, log));
    _saveLogs();
  }

  // ── Grouped logs ──────────────────────────────────────────────────────────

  List<HealthLog> get _filteredLogs {
    var logs = _logFilter == 'all' ? _logs : _logs.where((l) => l.type == _logFilter).toList();

    if (_dateRangeFilter == 'custom' && _customDate != null) {
      final key = DateFormat('yyyy-MM-dd').format(_customDate!);
      logs = logs.where((l) => l.dateKey == key).toList();
    } else if (_dateRangeFilter != 'all') {
      final now = DateTime.now();
      final days = _dateRangeFilter == '7days' ? 7
          : _dateRangeFilter == '30days' ? 30
          : _dateRangeFilter == '60days' ? 60
          : 90;
      final cutoff = now.subtract(Duration(days: days));
      logs = logs.where((l) => l.timestamp.isAfter(cutoff)).toList();
    }

    return logs;
  }

  Map<String, List<HealthLog>> get _groupedLogs {
    final map = <String, List<HealthLog>>{};
    for (final log in _filteredLogs) {
      map.putIfAbsent(log.dateKey, () => []).add(log);
    }
    final sorted = Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
    return sorted;
  }

  List<HealthLog> get _todayLogs {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _logs.where((l) => l.dateKey == today).toList();
  }

  // ── Goal helpers ──────────────────────────────────────────────────────────

  String _weekLabel() {
    final now    = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return '${DateFormat('EEEE, MMM d').format(monday)} – ${DateFormat('EEEE, MMM d').format(sunday)}';
  }

  String _monthLabel() => DateFormat('MMMM').format(DateTime.now());

  // ── Log More Sheet ─────────────────────────────────────────────────────────

  void _showLogMore() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogMoreSheet(
        onSelectVital: (v) { Navigator.pop(context); _showLogEntry(v); },
      ),
    );
  }

  // ── Log Entry ─────────────────────────────────────────────────────────────

  void _showLogEntry(_VitalCfg vital) {
    if (vital.isMood) { _showMoodPicker(vital); return; }
    showDialog(context: context, builder: (_) => _LogEntryDialog(
      vital: vital,
      onSave: (value) {
        final now = DateTime.now();
        _addLog(HealthLog(
          id:        '${vital.id}_${now.millisecondsSinceEpoch}',
          type:      vital.id,
          name:      vital.name,
          value:     value,
          unit:      vital.unit,
          timestamp: now,
          colorHex:  vital.color,
        ));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${vital.name} logged at ${DateFormat('hh:mm a').format(now)}'),
          backgroundColor: Color(vital.color),
          duration: const Duration(seconds: 2),
        ));
      },
    ));
  }

  void _showMoodPicker(_VitalCfg vital) {
    const moods = [
      {'emoji': '😊', 'label': 'Great',   'value': 'Great'},
      {'emoji': '🙂', 'label': 'Good',    'value': 'Good'},
      {'emoji': '😐', 'label': 'Okay',    'value': 'Okay'},
      {'emoji': '😔', 'label': 'Low',     'value': 'Low'},
      {'emoji': '😢', 'label': 'Not Well','value': 'Not Well'},
    ];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.sentiment_satisfied_rounded, color: Color(0xFF8B5CF6), size: 22)),
          const SizedBox(width: 12),
          const Text('How are you feeling?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: Wrap(
          spacing: 12, runSpacing: 12,
          children: moods.map((m) => InkWell(
            onTap: () {
              Navigator.pop(context);
              final now = DateTime.now();
              _addLog(HealthLog(id: 'mood_${now.millisecondsSinceEpoch}', type: 'mood', name: 'Mood & Wellness',
                value: m['value'], unit: '', timestamp: now, colorHex: 0xFF8B5CF6));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Mood logged: ${m['emoji']} ${m['label']}'),
                backgroundColor: const Color(0xFF8B5CF6),
              ));
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(m['emoji']!, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 4),
                Text(m['label']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              ]),
            ),
          )).toList(),
        ),
      ),
    );
  }

  // ── My Logs Sheet ─────────────────────────────────────────────────────────

  void _showMyLogs() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setModal) {
        final grouped = _groupedLogs;
        final dateKeys = grouped.keys.toList();

        String dateHeader(String key) {
          final dt  = DateTime.parse(key);
          final now = DateTime.now();
          final today     = DateFormat('yyyy-MM-dd').format(now);
          final yesterday = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
          if (key == today)     return 'Today  •  ${DateFormat('MMMM d, yyyy').format(dt)}';
          if (key == yesterday) return 'Yesterday  •  ${DateFormat('MMMM d, yyyy').format(dt)}';
          return DateFormat('EEEE  •  MMMM d, yyyy').format(dt);
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, scroll) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              // Handle
              Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(children: [
                  const Text('History', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                  const Spacer(),
                  if (_logs.isNotEmpty)
                    Text('${_logs.length} entries', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                ]),
              ),

              // History By dropdown
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(children: [
                  const Text('History By:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _logFilter,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('All Vitals', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                            ..._vitals.map((v) => DropdownMenuItem(
                              value: v.id,
                              child: Row(children: [
                                Icon(v.icon, size: 14, color: Color(v.color)),
                                const SizedBox(width: 8),
                                Text(v.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ]),
                            )),
                          ],
                          onChanged: (val) {
                            setState(() => _logFilter = val ?? 'all');
                            setModal(() {});
                          },
                        ),
                      ),
                    ),
                  ),
                ]),
              ),

              // Date Range Filter
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDateRangeChip('All', 'all', setModal),
                      const SizedBox(width: 8),
                      _buildDateRangeChip('7 Days', '7days', setModal),
                      const SizedBox(width: 8),
                      _buildDateRangeChip('30 Days', '30days', setModal),
                      const SizedBox(width: 8),
                      _buildDateRangeChip('60 Days', '60days', setModal),
                      const SizedBox(width: 8),
                      _buildDateRangeChip('90 Days', '90days', setModal),
                      const SizedBox(width: 8),
                      _buildCalendarChip(setModal),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Log list
              Expanded(
                child: _filteredLogs.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.history_rounded, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 14),
                        const Text('No logs yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 6),
                        const Text('Tap "Log More" to record your first entry.', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                      ]))
                    : ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                        itemCount: dateKeys.length,
                        itemBuilder: (_, gi) {
                          final key     = dateKeys[gi];
                          final entries = grouped[key]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date header
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(dateHeader(key),
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryColor)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                                ]),
                              ),
                              // Card grid layout
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1.1,
                                ),
                                itemCount: entries.length,
                                itemBuilder: (_, i) => _VitalLogCard(log: entries[i]),
                              ),
                              const SizedBox(height: 4),
                            ],
                          );
                        },
                      ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _buildDateRangeChip(String label, String value, StateSetter setModal) {
    final isSelected = _dateRangeFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _dateRangeFilter = value;
          if (value != 'custom') _customDate = null;
        });
        setModal(() {});
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  DateTime? _customDate;

  Widget _buildCalendarChip(StateSetter setModal) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _customDate ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() {
            _dateRangeFilter = 'custom';
            _customDate = picked;
          });
          setModal(() {});
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Icon(
          Icons.calendar_today_rounded,
          size: 18,
          color: Color(0xFF64748B),
        ),
      ),
    );
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
        title: const Text('Lifestyle Tracker',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900)),
        actions: [
          TextButton.icon(
            onPressed: _showMyLogs,
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('History', style: TextStyle(fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryColor),
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)), onPressed: _loadApiData),
        ],
        shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showLogMore,
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log More', style: TextStyle(fontWeight: FontWeight.w800)),
        elevation: 3,
      ),
      body: _apiLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadApiData,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(isDesktop ? 40 : 16, 20, isDesktop ? 40 : 16, 100),
                    sliver: SliverList(delegate: SliverChildListDelegate([
                      Center(child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isDesktop ? 780 : double.infinity),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCarePlanCard(),
                            const SizedBox(height: 24),

                            // ── Daily Activity ───────────────────────────────
                            _sectionTitle('Daily Activity'),
                            const SizedBox(height: 12),
                            _buildActivityCard('Water Intake',   '${_waterIntake.toStringAsFixed(1)} / 3.0 L',  _waterIntake / 3.0,  Icons.water_drop_rounded,      const Color(0xFF3B82F6), () => _updateApiData(water: _waterIntake + 0.25)),
                            const SizedBox(height: 10),
                            _buildActivityCard('Sleep Duration', '${_sleepHours.toStringAsFixed(1)} / 8.0 hrs', _sleepHours / 8.0,   Icons.nights_stay_rounded,     const Color(0xFF8B5CF6), () => _updateApiData(sleep: _sleepHours + 0.5)),
                            const SizedBox(height: 10),
                            _buildActivityCard('Steps',          '$_steps / 10,000',                            _steps / 10000.0,    Icons.directions_run_rounded,  const Color(0xFF10B981), null, manualInput: true),
                            const SizedBox(height: 28),

                            // ── Goals ────────────────────────────────────────
                            _sectionTitle('Goals'),
                            const SizedBox(height: 12),
                            _GoalCard(
                              title: 'Daily Goal', period: 'Today',
                              color: const Color(0xFF3B82F6),
                              icon: Icons.today_rounded,
                              rows: [
                                _GoalRow('Water', '${_waterIntake.toStringAsFixed(1)}L', '3L',  _waterIntake / 3.0),
                                _GoalRow('Sleep', '${_sleepHours.toStringAsFixed(1)}h',  '8h',  _sleepHours / 8.0),
                                _GoalRow('Steps', '$_steps',                             '10k', _steps / 10000.0),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _GoalCard(
                              title: 'Weekly Goal', period: _weekLabel(),
                              color: const Color(0xFF10B981),
                              icon: Icons.calendar_view_week_rounded,
                              rows: [
                                _GoalRow('Water', '${(_waterIntake * 7).toStringAsFixed(1)}L', '21L',   (_waterIntake * 7) / 21.0),
                                _GoalRow('Sleep', '${(_sleepHours * 7).toStringAsFixed(1)}h',  '56h',   (_sleepHours * 7) / 56.0),
                                _GoalRow('Steps', '${_steps * 7}',                             '70,000', (_steps * 7) / 70000.0),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _GoalCard(
                              title: 'Monthly Goal', period: _monthLabel(),
                              color: const Color(0xFF7C3AED),
                              icon: Icons.calendar_month_rounded,
                              rows: [
                                _GoalRow('Water', '${(_waterIntake * 30).toStringAsFixed(1)}L', '90L',    (_waterIntake * 30) / 90.0),
                                _GoalRow('Sleep', '${(_sleepHours * 30).toStringAsFixed(1)}h',  '240h',   (_sleepHours * 30) / 240.0),
                                _GoalRow('Steps', '${_steps * 30}',                             '300,000', (_steps * 30) / 300000.0),
                              ],
                            ),

                            // ── Today's Vitals ────────────────────────────────
                            if (_todayLogs.isNotEmpty) ...[
                              const SizedBox(height: 28),
                              _sectionTitle("Today's Vitals"),
                              const SizedBox(height: 12),
                              ..._todayLogs.map((log) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _VitalLogTile(log: log),
                              )),
                            ],
                          ],
                        ),
                      )),
                    ])),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Section title helper ──────────────────────────────────────────────────

  Widget _sectionTitle(String text) => Text(text,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)));

  // ── Activity card ─────────────────────────────────────────────────────────

  Widget _buildActivityCard(String title, String subtitle, double progress,
      IconData icon, Color color, VoidCallback? onQuickAdd, {bool manualInput = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A))),
            Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF64748B))),
          ])),
          if (manualInput)
            IconButton(
              onPressed: () => _showStepsInput(),
              icon: Icon(Icons.edit_rounded, color: color, size: 20),
              tooltip: 'Log steps',
            )
          else if (onQuickAdd != null)
            IconButton(onPressed: onQuickAdd, icon: Icon(Icons.add_circle_rounded, color: color, size: 28)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(progress >= 1.0 ? Colors.green : color),
            minHeight: 8,
          ),
        ),
      ]),
    );
  }

  void _showStepsInput() {
    final ctrl = TextEditingController(text: _steps > 0 ? '$_steps' : '');
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(children: [
        Icon(Icons.directions_walk_rounded, color: Color(0xFF10B981), size: 22),
        SizedBox(width: 10),
        Text('Log Steps', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: ctrl, autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: 'Enter steps', suffixText: 'steps',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true, fillColor: const Color(0xFFF8FAFC),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [500, 1000, 2000, 5000].map((n) =>
          ActionChip(label: Text('+$n'), onPressed: () { ctrl.text = '${(_steps + n)}'; })
        ).toList()),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () {
            final val = int.tryParse(ctrl.text.trim());
            if (val != null && val >= 0) {
              Navigator.pop(context);
              _updateApiData(steps: val);
              final now = DateTime.now();
              _addLog(HealthLog(id: 'steps_${now.millisecondsSinceEpoch}', type: 'steps', name: 'Steps',
                value: '$val', unit: 'steps', timestamp: now, colorHex: 0xFF10B981));
            }
          },
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  // ── Care Plan card ────────────────────────────────────────────────────────

  Widget _buildCarePlanCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 12),
          const Expanded(child: Text('Care Plan Insights', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 12),
        Text('Your target water intake is vital today. Watch Module 3 of your active Health Program.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, height: 1.5)),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyLearningScreen())),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF6366F1), elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
          child: const Text('Review Health Program', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LOG MORE SHEET — searchable vitals list
// ═══════════════════════════════════════════════════════════════════════════

class _LogMoreSheet extends StatefulWidget {
  final void Function(_VitalCfg) onSelectVital;
  const _LogMoreSheet({required this.onSelectVital});
  @override
  State<_LogMoreSheet> createState() => _LogMoreSheetState();
}

class _LogMoreSheetState extends State<_LogMoreSheet> {
  final _searchCtrl = TextEditingController();
  List<_VitalCfg> _filtered = _vitals;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.4,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Log a Vital', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search vitals…',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (q) => setState(() {
                _filtered = _vitals.where((v) => v.name.toLowerCase().contains(q.toLowerCase())).toList();
              }),
            ),
          ])),
          Expanded(child: ListView.separated(
            controller: scroll,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            itemCount: _filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final v = _filtered[i];
              final color = Color(v.color);
              return InkWell(
                onTap: () => widget.onSelectVital(v),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(v.icon, color: color, size: 20)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(v.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      if (v.unit.isNotEmpty) Text('e.g. ${v.hint} ${v.unit}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      if (v.isMood) const Text('Tap to select mood', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ])),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  ]),
                ),
              );
            },
          )),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LOG ENTRY DIALOG
// ═══════════════════════════════════════════════════════════════════════════

class _LogEntryDialog extends StatefulWidget {
  final _VitalCfg vital;
  final void Function(String value) onSave;
  const _LogEntryDialog({required this.vital, required this.onSave});
  @override
  State<_LogEntryDialog> createState() => _LogEntryDialogState();
}

class _LogEntryDialogState extends State<_LogEntryDialog> {
  final _ctrl = TextEditingController();
  final _sysCtrl = TextEditingController(); // BP systolic
  final _diaCtrl = TextEditingController(); // BP diastolic

  @override
  void dispose() { _ctrl.dispose(); _sysCtrl.dispose(); _diaCtrl.dispose(); super.dispose(); }

  void _handleSave() {
    String val;
    if (widget.vital.isBP) {
      final sys = _sysCtrl.text.trim();
      final dia = _diaCtrl.text.trim();
      if (sys.isEmpty || dia.isEmpty) return;
      val = '$sys/$dia';
    } else {
      val = _ctrl.text.trim();
      if (val.isEmpty) return;
    }
    Navigator.pop(context);
    widget.onSave(val);
  }

  @override
  Widget build(BuildContext context) {
    final v     = widget.vital;
    final color = Color(v.color);
    final now   = DateTime.now();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(v.icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Text(v.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 4),
        Text('Record in ${v.unit.isEmpty ? "units" : v.unit}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        const SizedBox(height: 14),

        // Blood Pressure: two fields
        if (v.isBP)
          Row(children: [
            Expanded(child: _field(_sysCtrl, 'Systolic', 'e.g. 120', color)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('/', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300, color: Color(0xFF64748B)))),
            Expanded(child: _field(_diaCtrl, 'Diastolic', 'e.g. 80', color)),
          ])
        // Water: quick-add glasses
        else if (v.isWater)
          Column(children: [
            _field(_ctrl, 'Glasses', 'e.g. 2', color, type: TextInputType.number),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [1, 2, 3, 4].map((n) =>
              ActionChip(label: Text('+$n glass${n > 1 ? "es" : ""}'), onPressed: () {
                final cur = int.tryParse(_ctrl.text) ?? 0;
                _ctrl.text = '${cur + n}';
              })
            ).toList()),
          ])
        else
          _field(_ctrl, v.name, v.hint, color, type: v.isSteps ? TextInputType.number : TextInputType.text),

        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
          const SizedBox(width: 5),
          Text(DateFormat('dd MMM yyyy  •  hh:mm a').format(now), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ]),
        const SizedBox(height: 16),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _handleSave,
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Save Entry', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint, Color color, {TextInputType? type}) {
    return TextField(
      controller: ctrl, autofocus: true, keyboardType: type,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: 1.5)),
        filled: true, fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

// ── Card-style history item (matches Health Tracker card design) ─────────────
class _VitalLogCard extends StatelessWidget {
  final HealthLog log;
  const _VitalLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final vConfig = _vitals.firstWhere((v) => v.id == log.type, orElse: () => _vitals.last);
    final color = Color(log.colorHex);
    final displayVal = log.type == 'mood'
        ? _moodEmoji(log.value?.toString() ?? '')
        : log.value?.toString() ?? '--';
    final unitLabel = log.type == 'mood' ? '' : log.unit;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(vConfig.icon, color: color, size: 14),
              ),
              Text(
                log.timeLabel,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const Spacer(),
          Text(
            log.name,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  displayVal,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (unitLabel.isNotEmpty)
            Text(
              unitLabel,
              style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }

  static String _moodEmoji(String val) {
    switch (val) {
      case 'Great':    return '😊';
      case 'Good':     return '🙂';
      case 'Okay':     return '😐';
      case 'Low':      return '😔';
      case 'Not Well': return '😢';
      default:         return '😐';
    }
  }
}

// ── Row-style history item ─────────────────────────────────────────────────
class _VitalLogTile extends StatelessWidget {
  final HealthLog log;
  const _VitalLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final vConfig = _vitals.firstWhere((v) => v.id == log.type, orElse: () => _vitals.last);
    final color   = Color(log.colorHex);
    final displayVal = log.type == 'mood'
        ? '${_moodEmoji(log.value?.toString() ?? '')} ${log.value}'
        : '${log.value}${log.unit.isNotEmpty ? ' ${log.unit}' : ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(vConfig.icon, color: color, size: 16)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(log.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          Text(displayVal, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ])),
        Text(log.timeLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
      ]),
    );
  }

  String _moodEmoji(String val) {
    switch (val) {
      case 'Great':    return '😊';
      case 'Good':     return '🙂';
      case 'Okay':     return '😐';
      case 'Low':      return '😔';
      case 'Not Well': return '😢';
      default:         return '😐';
    }
  }
}

// ── Goal row data ─────────────────────────────────────────────────────────

class _GoalRow {
  final String label, current, target;
  final double progress;
  const _GoalRow(this.label, this.current, this.target, this.progress);
}

// ── Goal card ─────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  final String title, period;
  final Color color;
  final IconData icon;
  final List<_GoalRow> rows;

  const _GoalCard({
    required this.title, required this.period, required this.color,
    required this.icon, required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16)),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
            child: Text(period, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
        const SizedBox(height: 14),
        ...rows.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(r.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              Text('${r.current} / ${r.target}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            ]),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: r.progress.clamp(0.0, 1.0),
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(r.progress >= 1.0 ? Colors.green : AppColors.primaryColor),
                minHeight: 6,
              ),
            ),
          ]),
        )),
      ]),
    );
  }
}
