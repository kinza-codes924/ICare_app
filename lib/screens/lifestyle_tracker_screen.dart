import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/services/health_tracker_service.dart';
import 'package:icare/services/gamification_service.dart';
import 'package:icare/services/consultation_service.dart';
import 'package:intl/intl.dart';

class LifestyleTrackerScreen extends StatefulWidget {
  const LifestyleTrackerScreen({super.key});

  @override
  State<LifestyleTrackerScreen> createState() => _LifestyleTrackerScreenState();
}

class _LifestyleTrackerScreenState extends State<LifestyleTrackerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final HealthTrackerService _healthTrackerService = HealthTrackerService();

  // ── Placeholder state data ──────────────────────────────────────────────
  // Vitals
  int _systolic = 120;
  int _diastolic = 80;
  double _bloodSugar = 110;
  double _weight = 70.4;
  int _heartRate = 78;
  int _spO2 = 98;

  // Lifestyle
  int _waterGlasses = 5;
  int _steps = 2500;
  double _sleepHours = 7.0;
  String _mealQuality = 'Good';

  // Medication — real prescription data
  List<Map<String, dynamic>> _rxMeds = [];
  List<bool> _rxMedTaken = [];
  bool _rxLoading = true;
  bool _medsAwardedToday = false;

  // Condition-specific
  String _conditionMode = 'General Wellness';

  // Mood
  String _selectedMood = '😊';
  int _stressLevel = 3;
  int _calories = 1450;
  int _hydrationPct = 62;

  // Menstrual cycle
  bool _periodTracking = true;
  int _cycleDay = 14;
  String _cyclePhase = 'Ovulation';

  // Points
  int _pointsToday = 0;
  final GamificationService _gamificationService = GamificationService();

  // User name (loaded from SharedPref)
  String _userName = '';

  // How many vitals have been logged today (for daily goal)
  int _loggedToday = 0;
  static const int _totalVitals = 8; // BP, Sugar, Weight, HR, SpO2, Water, Steps, Sleep

  double get _dailyGoalProgress => (_loggedToday / _totalVitals).clamp(0.0, 1.0);

  // All logs timeline (for History sheet)
  List<Map<String, dynamic>> _allLogs = [];
  bool _logsLoading = false;
  String _logFilter = 'all';
  String _dateRangeFilter = 'all';
  DateTime? _customDate;

  // Weekly / monthly goal progress (derived from _allLogs)
  double get _weeklyGoalProgress {
    final now    = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final start  = DateTime(monday.year, monday.month, monday.day);
    final cnt = _allLogs.where((l) {
      final ts = DateTime.tryParse(l['timestamp'] as String? ?? '');
      return ts != null && !ts.isBefore(start);
    }).length;
    return (cnt / (_totalVitals * 7)).clamp(0.0, 1.0);
  }

  double get _monthlyGoalProgress {
    final now   = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final days  = DateTime(now.year, now.month + 1, 0).day;
    final cnt = _allLogs.where((l) {
      final ts = DateTime.tryParse(l['timestamp'] as String? ?? '');
      return ts != null && !ts.isBefore(start);
    }).length;
    return (cnt / (_totalVitals * days)).clamp(0.0, 1.0);
  }

  String _weekLabel() {
    final now    = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return '${DateFormat('EEE, MMM d').format(monday)} – ${DateFormat('EEE, MMM d').format(sunday)}';
  }
  String _monthLabel() => DateFormat('MMMM').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadUserName();
    _loadLatestVitals();
    _loadAllLogs();
    _loadPoints();
    _loadRxMeds();
  }

  Future<void> _loadAllLogs() async {
    setState(() => _logsLoading = true);
    try {
      final result = await _healthTrackerService.getEntries(limit: 500);
      if (result['success'] == true && mounted) {
        final list = (result['entries'] as List? ?? []).cast<Map<String, dynamic>>();
        // Convert timestamps to local time for display
        for (final e in list) {
          if (e['timestamp'] is String) {
            final utc = DateTime.tryParse(e['timestamp'] as String);
            if (utc != null) e['timestamp'] = utc.toLocal().toIso8601String();
          }
        }
        list.sort((a, b) {
          final ta = DateTime.tryParse(a['timestamp'] as String? ?? '') ?? DateTime(2000);
          final tb = DateTime.tryParse(b['timestamp'] as String? ?? '') ?? DateTime(2000);
          return tb.compareTo(ta);
        });
        setState(() => _allLogs = list);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _logsLoading = false);
    }
  }

  Future<void> _loadLatestVitals() async {
    final result = await _healthTrackerService.getLatestEntries();
    if (result['success'] == true && mounted) {
      final entries = result['entries'] as List? ?? [];
      int logged = 0;
      setState(() {
        for (final e in entries) {
          final type = e['vitalType'] as String? ?? '';
          final val = e['value'] as String? ?? '';
          switch (type) {
            case 'Blood Pressure':
              final parts = val.split('/');
              if (parts.length == 2) {
                _systolic = int.tryParse(parts[0]) ?? _systolic;
                _diastolic = int.tryParse(parts[1]) ?? _diastolic;
                logged++;
              }
              break;
            case 'Blood Glucose':
              _bloodSugar = double.tryParse(val) ?? _bloodSugar;
              logged++;
              break;
            case 'Weight':
              _weight = double.tryParse(val) ?? _weight;
              logged++;
              break;
            case 'Heart Rate':
              _heartRate = int.tryParse(val) ?? _heartRate;
              logged++;
              break;
            case 'Oxygen Level':
              _spO2 = int.tryParse(val) ?? _spO2;
              logged++;
              break;
            case 'Water Intake':
              _waterGlasses = int.tryParse(val) ?? _waterGlasses;
              logged++;
              break;
            case 'Steps':
              _steps = int.tryParse(val) ?? _steps;
              logged++;
              break;
            case 'Sleep':
              _sleepHours = double.tryParse(val) ?? _sleepHours;
              logged++;
              break;
          }
        }
        _loggedToday = logged;
      });
    }
  }

  Future<void> _loadPoints() async {
    try {
      final result = await _gamificationService.getMyStats();
      if (result['success'] == true && mounted) {
        final fetched = (result['points'] ?? 0) as int;
        setState(() {
          if (fetched > _pointsToday) _pointsToday = fetched;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveVital(String vitalType, String value, String unit) async {
    setState(() => _pointsToday += 5);
    await _healthTrackerService.addEntry(vitalType: vitalType, value: value, unit: unit);
    // Persist points to backend
    _gamificationService.logMetric().then((pts) {
      if (mounted) {
        final total = (pts['totalPoints'] as num?)?.toInt();
        if (total != null) setState(() => _pointsToday = total);
      }
    });
    await _loadLatestVitals();
    _loadAllLogs();
  }

  Future<void> _loadUserName() async {
    final user = await SharedPref().getUserData();
    if (mounted) {
      setState(() {
        _userName = user?.name ?? '';
      });
    }
  }

  Future<void> _loadRxMeds() async {
    if (mounted) setState(() => _rxLoading = true);
    try {
      final patientId = await SharedPref().getUserId() ?? '';
      if (patientId.isEmpty) {
        if (mounted) setState(() => _rxLoading = false);
        return;
      }
      final prescriptions = await ConsultationService()
          .getPatientPrescriptions(patientId: patientId, limit: 5);

      // Collect all medicines from completed prescriptions (most recent first)
      final allMeds = <Map<String, dynamic>>[];
      final seenNames = <String>{};
      for (final rx in prescriptions) {
        if (rx is! Map) continue;
        final presMap = rx['prescription'];
        final medsRaw = (presMap is Map ? presMap['medicines'] : null) as List? ?? [];
        for (final m in medsRaw) {
          if (m is! Map) continue;
          final name = (m['name'] ?? '').toString().trim();
          if (name.isEmpty || seenNames.contains(name.toLowerCase())) continue;
          seenNames.add(name.toLowerCase());
          allMeds.add({
            'name': name,
            'dosage': (m['dosage'] ?? '').toString(),
            'frequency': (m['frequency'] ?? '').toString(),
            'duration': (m['duration'] ?? '').toString(),
            'instructions': (m['instructions'] ?? m['notes'] ?? '').toString(),
          });
        }
        if (allMeds.isNotEmpty) break; // use medicines from the latest prescription only
      }

      if (mounted) {
        setState(() {
          _rxMeds = allMeds;
          _rxMedTaken = List<bool>.filled(allMeds.length, false);
          _rxLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _rxLoading = false);
    }
  }

  void _onMedToggle(int index, bool val) {
    setState(() => _rxMedTaken[index] = val);
    final allTaken = _rxMedTaken.isNotEmpty && _rxMedTaken.every((t) => t);
    if (allTaken && !_medsAwardedToday) {
      setState(() {
        _medsAwardedToday = true;
        _pointsToday += 10;
      });
      _saveVital('Medication Adherence', '100', '%');
    } else if (!allTaken) {
      _saveVital('Medication Adherence', val ? '50' : '0', '%');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Generic single-field numeric dialog ────────────────────────────────
  Future<void> _showNumericDialog({
    required String title,
    required String subtitle,
    required String unit,
    required double currentValue,
    required ValueChanged<double> onSave,
    int earnPoints = 5,
  }) async {
    final controller =
        TextEditingController(text: currentValue.toStringAsFixed(currentValue == currentValue.roundToDouble() ? 0 : 1));
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LogBottomSheet(
        title: title,
        subtitle: subtitle,
        unit: unit,
        controller: controller,
        earnPoints: earnPoints,
        onSave: () {
          final val = double.tryParse(controller.text);
          if (val != null) {
            onSave(val);
            // Points will be recalculated from backend after _saveVital
          }
          Navigator.pop(ctx);
        },
      ),
    );
  }

  // ── Log Selection Sheet ────────────────────────────────────────────────
  void _showLogSelectionSheet() {
    const vitals = [
      {'id': 'Blood Pressure',   'emoji': '💓', 'unit': 'mmHg',   'isBP': true},
      {'id': 'Blood Sugar',      'emoji': '🩸', 'unit': 'mg/dL',  'isBP': false},
      {'id': 'Weight',           'emoji': '⚖️',  'unit': 'kg',     'isBP': false},
      {'id': 'Heart Rate',       'emoji': '❤️',  'unit': 'bpm',    'isBP': false},
      {'id': 'SpO2',             'emoji': '🫁', 'unit': '%',      'isBP': false},
      {'id': 'Steps',            'emoji': '🚶', 'unit': 'steps',  'isBP': false},
      {'id': 'Water Intake',     'emoji': '💧', 'unit': 'glasses','isBP': false},
      {'id': 'Sleep',            'emoji': '😴', 'unit': 'hours',  'isBP': false},
      {'id': 'Calories',         'emoji': '🔥', 'unit': 'kcal',   'isBP': false},
      {'id': 'Mood & Wellness',  'emoji': '😊', 'unit': '',       'isBP': false},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65, maxChildSize: 0.9, minChildSize: 0.4,
        builder: (_, scroll) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Align(alignment: Alignment.centerLeft,
                child: Text('What do you want to log?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)))),
            ),
            Expanded(child: GridView.count(
              controller: scroll,
              crossAxisCount: 2,
              crossAxisSpacing: 12, mainAxisSpacing: 12,
              childAspectRatio: 2.4,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: vitals.map((v) {
                return InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    if (v['id'] == 'Mood & Wellness') {
                      _showMoodPicker();
                    } else if (v['isBP'] == true) {
                      _showBPDialog();
                    } else {
                      final ctrl = TextEditingController();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _LogBottomSheet(
                          title: v['id'] as String,
                          subtitle: 'Enter your ${(v['id'] as String).toLowerCase()} reading',
                          unit: v['unit'] as String,
                          controller: ctrl,
                          earnPoints: 5,
                          onSave: () {
                            final val = ctrl.text.trim();
                            if (val.isNotEmpty) {
                              Navigator.pop(context);
                              final type = v['id'] as String;
                              // Map to backend vitalType keys
                              final typeMap = {
                                'Blood Sugar': 'Blood Glucose',
                                'SpO2': 'Oxygen Level',
                                'Water Intake': 'Water Intake',
                              };
                              _saveVital(typeMap[type] ?? type, val, v['unit'] as String);
                            }
                          },
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(children: [
                      Text(v['emoji'] as String, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(v['id'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        if ((v['unit'] as String).isNotEmpty)
                          Text(v['unit'] as String, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      ])),
                    ]),
                  ),
                );
              }).toList(),
            )),
          ]),
        ),
      ),
    );
  }

  // ── History Sheet ─────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredAllLogs {
    var logs = _logFilter == 'all'
        ? List<Map<String, dynamic>>.from(_allLogs)
        : _allLogs.where((l) => (l['vitalType'] ?? '') == _logFilter).toList();

    if (_dateRangeFilter == 'custom' && _customDate != null) {
      final key = DateFormat('yyyy-MM-dd').format(_customDate!);
      logs = logs.where((l) {
        final ts = DateTime.tryParse(l['timestamp'] as String? ?? '');
        return ts != null && DateFormat('yyyy-MM-dd').format(ts) == key;
      }).toList();
    } else if (_dateRangeFilter != 'all') {
      final days = _dateRangeFilter == '7days' ? 7
          : _dateRangeFilter == '30days' ? 30
          : _dateRangeFilter == '60days' ? 60
          : 90;
      final cutoff = DateTime.now().subtract(Duration(days: days));
      logs = logs.where((l) {
        final ts = DateTime.tryParse(l['timestamp'] as String? ?? '');
        return ts != null && ts.isAfter(cutoff);
      }).toList();
    }
    return logs;
  }

  Widget _buildDateChip(String label, String value, StateSetter setModal) {
    final selected = _dateRangeFilter == value;
    return InkWell(
      onTap: () {
        setState(() { _dateRangeFilter = value; if (value != 'custom') _customDate = null; });
        setModal(() {});
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primaryColor : const Color(0xFFE2E8F0)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF64748B))),
      ),
    );
  }

  Widget _buildCalChip(StateSetter setModal) {
    final selected = _dateRangeFilter == 'custom';
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _customDate ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() { _dateRangeFilter = 'custom'; _customDate = picked; });
          setModal(() {});
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primaryColor : const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_rounded, size: 14,
              color: selected ? Colors.white : const Color(0xFF64748B)),
          if (selected && _customDate != null) ...[
            const SizedBox(width: 4),
            Text(DateFormat('MMM d').format(_customDate!),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ]),
      ),
    );
  }

  void _showMyLogs() {
    const vitalTypes = ['all', 'Blood Pressure', 'Blood Glucose', 'Weight',
      'Heart Rate', 'Oxygen Level', 'Steps', 'Water Intake', 'Sleep', 'Calories'];
    const vitalLabels = {'all': 'All Vitals', 'Blood Pressure': 'BP', 'Blood Glucose': 'Sugar',
      'Weight': 'Weight', 'Heart Rate': 'Heart Rate', 'Oxygen Level': 'SpO2',
      'Steps': 'Steps', 'Water Intake': 'Water', 'Sleep': 'Sleep', 'Calories': 'Calories'};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setModal) {
        final filtered = _filteredAllLogs;

        // Group by date key (yyyy-MM-dd)
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final log in filtered) {
          final ts = DateTime.tryParse(log['timestamp'] as String? ?? '');
          if (ts == null) continue;
          final key = DateFormat('yyyy-MM-dd').format(ts);
          grouped.putIfAbsent(key, () => []).add(log);
        }
        final dateKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        String dateHeader(String key) {
          final dt  = DateTime.parse(key);
          final now = DateTime.now();
          final todayKey     = DateFormat('yyyy-MM-dd').format(now);
          final yesterdayKey = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
          if (key == todayKey)     return 'Today  •  ${DateFormat('MMMM d, yyyy').format(dt)}';
          if (key == yesterdayKey) return 'Yesterday  •  ${DateFormat('MMMM d, yyyy').format(dt)}';
          return DateFormat('EEEE  •  MMMM d, yyyy').format(dt);
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.88, maxChildSize: 0.95, minChildSize: 0.4,
          builder: (_, scroll) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(children: [
                  const Text('History', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                  const Spacer(),
                  Text('${_allLogs.length} entries', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ]),
              ),
              // Vital type dropdown
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                child: Row(children: [
                  const Text('Filter:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                  const SizedBox(width: 10),
                  Expanded(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                      value: _logFilter,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                      items: vitalTypes.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(vitalLabels[t] ?? t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      )).toList(),
                      onChanged: (val) { setState(() => _logFilter = val ?? 'all'); setModal(() {}); },
                    )),
                  )),
                ]),
              ),
              // Date range chips
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _buildDateChip('All', 'all', setModal),
                    const SizedBox(width: 6),
                    _buildDateChip('7 Days', '7days', setModal),
                    const SizedBox(width: 6),
                    _buildDateChip('30 Days', '30days', setModal),
                    const SizedBox(width: 6),
                    _buildDateChip('60 Days', '60days', setModal),
                    const SizedBox(width: 6),
                    _buildDateChip('90 Days', '90days', setModal),
                    const SizedBox(width: 6),
                    _buildCalChip(setModal),
                  ]),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(
                child: _logsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.history_rounded, size: 56, color: Color(0xFFCBD5E1)),
                        const SizedBox(height: 12),
                        const Text('No entries yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 4),
                        const Text('Tap "Log More" to record your first entry.', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                      ]))
                    : ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                        itemCount: dateKeys.length,
                        itemBuilder: (_, gi) {
                          final key     = dateKeys[gi];
                          final entries = grouped[key]!;
                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // Date header
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(color: AppColors.primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
                                  child: Text(dateHeader(key), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryColor)),
                                ),
                                const SizedBox(width: 8),
                                Text('${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                              ]),
                            ),
                            // Card grid
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1.55,
                              ),
                              itemCount: entries.length,
                              itemBuilder: (_, i) {
                                final log = entries[i];
                                final ts  = DateTime.tryParse(log['timestamp'] as String? ?? '');
                                final time = ts != null ? DateFormat('hh:mm a').format(ts) : '';
                                final type = log['vitalType'] as String? ?? '';
                                final val  = log['value']    as String? ?? '';
                                final unit = log['unit']     as String? ?? '';
                                return _HistoryCard(type: type, value: val, unit: unit, time: time);
                              },
                            ),
                            const SizedBox(height: 8),
                          ]);
                        },
                      ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  // ── BP dialog (two fields) ──────────────────────────────────────────────
  Future<void> _showBPDialog() async {
    final sysCtrl = TextEditingController(text: _systolic.toString());
    final diaCtrl = TextEditingController(text: _diastolic.toString());
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BPBottomSheet(
        sysCtrl: sysCtrl,
        diaCtrl: diaCtrl,
        onSave: () {
          final sys = int.tryParse(sysCtrl.text);
          final dia = int.tryParse(diaCtrl.text);
          if (sys != null && dia != null) {
            setState(() {
              _systolic = sys;
              _diastolic = dia;
            });
            _saveVital('Blood Pressure', '$sys/$dia', 'mmHg');
          }
          Navigator.pop(ctx);
        },
      ),
    );
  }

  // ── Mood picker dialog ─────────────────────────────────────────────────
  Future<void> _showMoodPicker() async {
    const moods = ['😊', '😐', '😔', '😡', '😴', '🤒'];
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How are you feeling today?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Wrap(
          spacing: 16,
          children: moods
              .map((m) => GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMood = m;
                        _pointsToday += 5;
                      });
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: m == _selectedMood
                            ? AppColors.primaryColor.withValues(alpha: 0.12)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: m == _selectedMood
                              ? AppColors.primaryColor
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(m, style: const TextStyle(fontSize: 32)),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          'Health Tracker',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 18,
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _showMyLogs,
            icon: const Icon(Icons.history_rounded, size: 16),
            label: const Text('History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryColor),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  '$_pointsToday pts',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeroHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllTab(),
                _buildVitalsTab(),
                _buildLifestyleTab(),
                _buildMedicationTab(),
                _buildConditionTab(),
                _buildMoodTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero header ─────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, ${_userName.isNotEmpty ? _userName : 'there'} 👋',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              fontFamily: 'Gilroy-Bold',
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Your Health Today',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Daily Goal',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B)),
                        ),
                        Text(
                          '${(_dailyGoalProgress * 100).toInt()}% Complete',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _dailyGoalProgress,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // ── Weekly Goal ─────────────────────────────────────────
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(children: [
                        const Icon(Icons.calendar_view_week_rounded, size: 11, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        const Text('Weekly', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      ]),
                      Text(_weekLabel(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _weeklyGoalProgress,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ── Monthly Goal ─────────────────────────────────────────
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(children: [
                        const Icon(Icons.calendar_month_rounded, size: 11, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 4),
                        const Text('Monthly', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      ]),
                      Text(_monthLabel(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _monthlyGoalProgress,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 20)),
                    Text(
                      '$_pointsToday',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFB45309),
                      ),
                    ),
                    const Text('pts',
                        style:
                            TextStyle(fontSize: 10, color: Color(0xFFB45309))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab bar ─────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    const tabs = [
      _TabMeta('All', Icons.grid_view_rounded),
      _TabMeta('Vitals', Icons.favorite_outline_rounded),
      _TabMeta('Lifestyle', Icons.directions_walk_rounded),
      _TabMeta('Medication', Icons.medication_outlined),
      _TabMeta('Condition', Icons.health_and_safety_outlined),
      _TabMeta('Mood', Icons.sentiment_satisfied_alt_outlined),
    ];

    return Container(
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primaryColor,
              unselectedLabelColor: const Color(0xFF94A3B8),
              indicatorColor: AppColors.primaryColor,
              indicatorWeight: 2,
              labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
              labelPadding: const EdgeInsets.symmetric(horizontal: 10),
              tabs: tabs
                  .map((t) => Tab(
                        height: 38,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(t.icon, size: 13),
                            const SizedBox(width: 4),
                            Text(t.label),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          // ── Log More button in tab row ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: GestureDetector(
              onTap: _showLogSelectionSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Log More',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Tab 0 — ALL (overview of everything)
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildAllTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Overview', 'All your health data at a glance'),
          const SizedBox(height: 12),

          // ── Vitals summary ──────────────────────────────────────────
          _overviewSection(
            title: 'Vitals',
            icon: Icons.favorite_outline_rounded,
            iconColor: const Color(0xFFEF4444),
            onViewAll: () => _tabController.animateTo(1),
            child: Column(
              children: [
                _buildQuickTiles(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _miniTile('💓', '$_heartRate bpm', 'Heart Rate',
                          const Color(0xFFFFFBEB),
                          onTap: () => _showNumericDialog(
                            title: 'Heart Rate',
                            subtitle: 'Enter your resting heart rate in BPM',
                            unit: 'BPM',
                            currentValue: _heartRate.toDouble(),
                            onSave: (v) {
                              setState(() => _heartRate = v.toInt());
                              _saveVital('Heart Rate', v.toInt().toString(), 'bpm');
                            },
                          )),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _miniTile('🫁', '$_spO2%', 'SpO2',
                          const Color(0xFFECFDF5),
                          onTap: () => _showNumericDialog(
                            title: 'SpO2 Level',
                            subtitle: 'Enter your blood oxygen saturation (%)',
                            unit: '%',
                            currentValue: _spO2.toDouble(),
                            onSave: (v) {
                              setState(() => _spO2 = v.toInt().clamp(0, 100));
                              _saveVital('Oxygen Level', v.toInt().clamp(0, 100).toString(), '%');
                            },
                          )),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Lifestyle summary ───────────────────────────────────────
          _overviewSection(
            title: 'Lifestyle',
            icon: Icons.directions_walk_rounded,
            iconColor: const Color(0xFFF59E0B),
            onViewAll: () => _tabController.animateTo(2),
            child: Row(
              children: [
                Expanded(
                  child: _miniTile('💧', '$_waterGlasses/8', 'Water',
                      const Color(0xFFEFF6FF),
                      onTap: () => _showNumericDialog(
                        title: 'Water Intake',
                        subtitle: 'How many glasses of water have you had?',
                        unit: 'glasses',
                        currentValue: _waterGlasses.toDouble(),
                        onSave: (v) {
                          setState(() => _waterGlasses = v.toInt().clamp(0, 20));
                          _saveVital('Water Intake', v.toInt().clamp(0, 20).toString(), 'glasses');
                        },
                      )),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniTile('🚶', '$_steps', 'Steps',
                      const Color(0xFFFFFBEB),
                      onTap: () => _showNumericDialog(
                        title: 'Steps',
                        subtitle: 'Enter your step count for today',
                        unit: 'steps',
                        currentValue: _steps.toDouble(),
                        onSave: (v) {
                          setState(() => _steps = v.toInt());
                          _saveVital('Steps', v.toInt().toString(), 'steps');
                        },
                      )),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniTile('😴', '${_sleepHours.toStringAsFixed(1)}h',
                      'Sleep', const Color(0xFFF5F3FF),
                      onTap: () => _showNumericDialog(
                        title: 'Sleep',
                        subtitle: 'How many hours did you sleep last night?',
                        unit: 'hours',
                        currentValue: _sleepHours,
                        onSave: (v) {
                          setState(() => _sleepHours = v.clamp(0, 24));
                          _saveVital('Sleep', v.clamp(0, 24).toStringAsFixed(1), 'hours');
                        },
                      )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Medication summary ──────────────────────────────────────
          _overviewSection(
            title: 'Medication',
            icon: Icons.medication_outlined,
            iconColor: const Color(0xFF10B981),
            onViewAll: () => _tabController.animateTo(3),
            child: () {
              final takenC = _rxMedTaken.where((t) => t).length;
              final totalC = _rxMeds.length;
              final allDone = totalC > 0 && takenC == totalC;
              return Row(
                children: [
                  Expanded(child: _miniTile(allDone ? '✅' : '⏰', allDone ? 'Taken' : '$takenC/$totalC', "Today's Dose", allDone ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB))),
                  const SizedBox(width: 10),
                  Expanded(child: _miniTile(allDone ? '✅' : '❌', allDone ? 'On Track' : 'Pending', 'Adherence', allDone ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2))),
                ],
              );
            }(),
          ),
          const SizedBox(height: 16),

          // ── Mood summary ────────────────────────────────────────────
          _overviewSection(
            title: 'Mood & Wellness',
            icon: Icons.sentiment_satisfied_alt_outlined,
            iconColor: const Color(0xFF8B5CF6),
            onViewAll: () => _tabController.animateTo(5),
            child: Row(
              children: [
                Expanded(
                  child: _miniTile(
                      _selectedMood, 'Today', 'Mood', const Color(0xFFF5F3FF)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniTile('😰', 'Level $_stressLevel/5', 'Stress',
                      const Color(0xFFFEF2F2)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniTile(
                      '🔥', '$_calories kcal', 'Calories', const Color(0xFFFFFBEB)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _overviewSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onViewAll,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onViewAll,
                child: Text(
                  'View All →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Tab 1 — VITALS
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildVitalsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Vitals', 'Tap any card to log manually'),
          const SizedBox(height: 12),
          // Quick overview tiles row
          _buildQuickTiles(),
          const SizedBox(height: 20),
          // Detailed vital cards
          _vitalCard(
            icon: Icons.favorite_rounded,
            iconColor: const Color(0xFFEF4444),
            bgColor: const Color(0xFFFEF2F2),
            label: 'Blood Pressure',
            value: '$_systolic/$_diastolic',
            unit: 'mmHg',
            status: _bpStatus,
            statusColor: _bpStatusColor,
            onTap: _showBPDialog,
          ),
          const SizedBox(height: 12),
          _vitalCard(
            icon: Icons.water_drop_rounded,
            iconColor: const Color(0xFF3B82F6),
            bgColor: const Color(0xFFEFF6FF),
            label: 'Blood Sugar',
            value: _bloodSugar.toStringAsFixed(0),
            unit: 'mg/dL',
            status: _bloodSugar < 100
                ? 'Normal'
                : _bloodSugar < 126
                    ? 'Pre-diabetic'
                    : 'High',
            statusColor: _bloodSugar < 100
                ? Colors.green
                : _bloodSugar < 126
                    ? Colors.orange
                    : Colors.red,
            onTap: () => _showNumericDialog(
              title: 'Blood Sugar',
              subtitle: 'Enter your fasting blood sugar reading',
              unit: 'mg/dL',
              currentValue: _bloodSugar,
              onSave: (v) {
                setState(() => _bloodSugar = v);
                _saveVital('Blood Glucose', v.toStringAsFixed(0), 'mg/dL');
              },
            ),
          ),
          const SizedBox(height: 12),
          _vitalCard(
            icon: Icons.monitor_weight_outlined,
            iconColor: const Color(0xFF8B5CF6),
            bgColor: const Color(0xFFF5F3FF),
            label: 'Weight',
            value: _weight.toStringAsFixed(1),
            unit: 'kg',
            status: 'BMI: 25.8',
            statusColor: Colors.orange,
            onTap: () => _showNumericDialog(
              title: 'Weight',
              subtitle: 'Enter your current body weight',
              unit: 'kg',
              currentValue: _weight,
              onSave: (v) {
                setState(() => _weight = v);
                _saveVital('Weight', v.toStringAsFixed(1), 'kg');
              },
            ),
          ),
          const SizedBox(height: 12),
          _vitalCard(
            icon: Icons.monitor_heart_outlined,
            iconColor: const Color(0xFFF59E0B),
            bgColor: const Color(0xFFFFFBEB),
            label: 'Heart Rate',
            value: _heartRate.toString(),
            unit: 'BPM',
            status: _heartRate < 60
                ? 'Low'
                : _heartRate <= 100
                    ? 'Normal'
                    : 'High',
            statusColor: _heartRate < 60 || _heartRate > 100
                ? Colors.red
                : Colors.green,
            onTap: () => _showNumericDialog(
              title: 'Heart Rate',
              subtitle: 'Enter your resting heart rate in BPM',
              unit: 'BPM',
              currentValue: _heartRate.toDouble(),
              onSave: (v) {
                setState(() => _heartRate = v.toInt());
                _saveVital('Heart Rate', v.toInt().toString(), 'bpm');
              },
            ),
          ),
          const SizedBox(height: 12),
          _vitalCard(
            icon: Icons.air_rounded,
            iconColor: const Color(0xFF10B981),
            bgColor: const Color(0xFFECFDF5),
            label: 'SpO2 (Oxygen)',
            value: '$_spO2',
            unit: '%',
            status: _spO2 >= 95 ? 'Normal' : 'Low — See Doctor',
            statusColor: _spO2 >= 95 ? Colors.green : Colors.red,
            onTap: () => _showNumericDialog(
              title: 'SpO2 Level',
              subtitle: 'Enter your blood oxygen saturation (%)',
              unit: '%',
              currentValue: _spO2.toDouble(),
              onSave: (v) {
                setState(() => _spO2 = v.toInt().clamp(0, 100));
                _saveVital('Oxygen Level', v.toInt().clamp(0, 100).toString(), '%');
              },
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildQuickTiles() {
    return Row(
      children: [
        Expanded(
          child: _miniTile(
            '💓',
            '$_systolic/$_diastolic',
            'BP',
            const Color(0xFFFEF2F2),
            onTap: _showBPDialog,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniTile(
            '🩸',
            '${_bloodSugar.toStringAsFixed(0)} mg',
            'Sugar',
            const Color(0xFFEFF6FF),
            onTap: () => _showNumericDialog(
              title: 'Blood Sugar',
              subtitle: 'Enter your fasting blood sugar reading',
              unit: 'mg/dL',
              currentValue: _bloodSugar,
              onSave: (v) {
                setState(() => _bloodSugar = v);
                _saveVital('Blood Glucose', v.toStringAsFixed(0), 'mg/dL');
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniTile(
            '⚖️',
            '${_weight.toStringAsFixed(1)} kg',
            'Weight',
            const Color(0xFFF5F3FF),
            onTap: () => _showNumericDialog(
              title: 'Weight',
              subtitle: 'Enter your current body weight',
              unit: 'kg',
              currentValue: _weight,
              onSave: (v) {
                setState(() => _weight = v);
                _saveVital('Weight', v.toStringAsFixed(1), 'kg');
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniTile(String emoji, String value, String label, Color bg,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A))),
            Text(label,
                style:
                    const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  String get _bpStatus {
    if (_systolic < 120 && _diastolic < 80) return 'Normal';
    if (_systolic < 130 && _diastolic < 80) return 'Elevated';
    if (_systolic < 140 || _diastolic < 90) return 'High Stage 1';
    return 'High Stage 2';
  }

  Color get _bpStatusColor {
    if (_systolic < 120 && _diastolic < 80) return Colors.green;
    if (_systolic < 130) return Colors.orange;
    return Colors.red;
  }

  Widget _vitalCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
    required String unit,
    required String status,
    required Color statusColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(value,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A))),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(unit,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(status,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_note_rounded,
                color: Color(0xFFCBD5E1), size: 20),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Tab 2 — LIFESTYLE
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildLifestyleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Lifestyle', 'Track daily habits'),
          const SizedBox(height: 12),

          // Water intake — circular progress
          GestureDetector(
            onTap: () => _showNumericDialog(
              title: 'Water Intake',
              subtitle: 'How many glasses of water have you had?',
              unit: 'glasses',
              currentValue: _waterGlasses.toDouble(),
              onSave: (v) {
                setState(() => _waterGlasses = v.toInt().clamp(0, 20));
                _saveVital('Water Intake', v.toInt().clamp(0, 20).toString(), 'glasses');
              },
            ),
            child: _waterCard(),
          ),
          const SizedBox(height: 12),

          // Steps
          _lifestyleCard(
            emoji: '🚶',
            label: 'Steps Today',
            value: '$_steps',
            unit: 'steps',
            target: '10,000 goal',
            progress: (_steps / 10000).clamp(0.0, 1.0),
            progressColor: const Color(0xFFF59E0B),
            onTap: () => _showNumericDialog(
              title: 'Steps',
              subtitle: 'Enter your step count for today',
              unit: 'steps',
              currentValue: _steps.toDouble(),
              onSave: (v) {
                setState(() => _steps = v.toInt());
                _saveVital('Steps', v.toInt().toString(), 'steps');
              },
            ),
          ),
          const SizedBox(height: 12),

          // Sleep
          _lifestyleCard(
            emoji: '😴',
            label: 'Sleep',
            value: _sleepHours.toStringAsFixed(1),
            unit: 'hours',
            target: '8 hrs goal',
            progress: (_sleepHours / 8).clamp(0.0, 1.0),
            progressColor: const Color(0xFF8B5CF6),
            onTap: () => _showNumericDialog(
              title: 'Sleep',
              subtitle: 'How many hours did you sleep last night?',
              unit: 'hours',
              currentValue: _sleepHours,
              onSave: (v) {
                setState(() => _sleepHours = v.clamp(0, 24));
                _saveVital('Sleep', v.clamp(0, 24).toStringAsFixed(1), 'hours');
              },
            ),
          ),
          const SizedBox(height: 12),

          // Meal quality
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🥗', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 10),
                    Text('Diet / Meal Quality',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['Excellent', 'Good', 'Fair', 'Poor']
                      .map((q) => GestureDetector(
                            onTap: () =>
                                setState(() => _mealQuality = q),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _mealQuality == q
                                    ? AppColors.primaryColor
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(q,
                                  style: TextStyle(
                                    color: _mealQuality == q
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  )),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _waterCard() {
    final pct = (_waterGlasses / 8).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: pct,
                  strokeWidth: 7,
                  backgroundColor: const Color(0xFFDBEAFE),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                  strokeCap: StrokeCap.round,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💧', style: TextStyle(fontSize: 18)),
                    Text('$_waterGlasses/8',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E40AF))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Water Intake',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text('$_waterGlasses of 8 glasses',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                Text(
                  _waterGlasses >= 8
                      ? '🎉 Daily goal reached!'
                      : 'Tap to log more glasses',
                  style: TextStyle(
                    fontSize: 12,
                    color: _waterGlasses >= 8
                        ? Colors.green
                        : AppColors.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.add_rounded,
                  color: Color(0xFF3B82F6), size: 20),
              onPressed: () =>
                  setState(() => _waterGlasses = (_waterGlasses + 1).clamp(0, 20)),
              tooltip: 'Add a glass',
            ),
          ),
        ],
      ),
    );
  }

  Widget _lifestyleCard({
    required String emoji,
    required String label,
    required String value,
    required String unit,
    required String target,
    required double progress,
    required Color progressColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Text(label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
                const Spacer(),
                Text(target,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A))),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(unit,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF94A3B8))),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Tab 3 — MEDICATION
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildMedicationTab() {
    if (_rxLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final takenCount = _rxMedTaken.where((t) => t).length;
    final total = _rxMeds.length;
    final allTaken = total > 0 && takenCount == total;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Medication', 'Track your prescriptions'),
          const SizedBox(height: 12),

          // Summary chips
          Row(
            children: [
              _medChip('💊', '$takenCount/$total', 'Taken', const Color(0xFFECFDF5), Colors.green),
              const SizedBox(width: 10),
              _medChip('⚠️', '${total - takenCount}', 'Pending', const Color(0xFFFEF2F2), Colors.red),
            ],
          ),
          const SizedBox(height: 16),

          // All taken banner
          if (allTaken)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(children: const [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text('All medications taken today! +10 pts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF166534)))),
              ]),
            ),

          // No prescriptions state
          if (total == 0)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(children: [
                Icon(Icons.medication_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text('No active prescriptions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                const Text('Your doctor-prescribed medications will appear here', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ]),
            ),

          // Medication list
          ..._rxMeds.asMap().entries.map((e) => _rxMedCard(e.key, e.value)),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Prescription tracking is for reminders only. Always follow your doctor\'s advice.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _rxMedCard(int index, Map<String, dynamic> med) {
    final taken = _rxMedTaken.length > index ? _rxMedTaken[index] : false;
    final frequency = (med['frequency'] as String? ?? '').isNotEmpty ? med['frequency'] as String : null;
    final dosage = (med['dosage'] as String? ?? '').isNotEmpty ? med['dosage'] as String : null;
    final instructions = (med['instructions'] as String? ?? '').isNotEmpty ? med['instructions'] as String : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: taken ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: taken ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              taken ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: taken ? Colors.green : const Color(0xFFCBD5E1),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${med['name']}${dosage != null ? ' — $dosage' : ''}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                if (frequency != null) ...[
                  const SizedBox(height: 2),
                  Text(frequency, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
                if (instructions != null) ...[
                  const SizedBox(height: 2),
                  Text(instructions, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ],
            ),
          ),
          Switch(
            value: taken,
            activeThumbColor: AppColors.primaryColor,
            onChanged: (v) => _onMedToggle(index, v),
          ),
        ],
      ),
    );
  }

  Widget _medChip(
      String emoji, String count, String label, Color bg, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(count,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: textColor)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ],
        ),
      ),
    );
  }


  // ════════════════════════════════════════════════════════════════════════
  // Tab 4 — CONDITION-SPECIFIC
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildConditionTab() {
    final conditionCards = {
      'General Wellness': [
        _CondItem('🏃', 'Daily Exercise', 'Did you exercise today?', false),
        _CondItem('🥦', 'Balanced Diet', 'Ate fruits/vegetables?', true),
        _CondItem('💤', 'Good Sleep', 'Slept 7+ hours?', true),
      ],
      'Diabetes': [
        _CondItem('🩸', 'Morning Sugar', 'Logged fasting glucose?', false),
        _CondItem('💊', 'Insulin/Meds', 'Taken as prescribed?', true),
        _CondItem('🦶', 'Foot Check', 'Daily foot inspection done?', false),
        _CondItem('🥗', 'Carb Intake', 'Tracked carbohydrates?', true),
      ],
      'Hypertension': [
        _CondItem('❤️', 'BP Logged', 'Blood pressure recorded?', true),
        _CondItem('🧂', 'Low Salt', 'Avoided high-sodium foods?', false),
        _CondItem('🚶', 'Light Walk', 'Done 30-min walk?', false),
        _CondItem('😌', 'Stress Check', 'Practiced relaxation?', true),
      ],
    };

    final items = conditionCards[_conditionMode] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Condition-Specific', 'Personalized tracking'),
          const SizedBox(height: 12),

          // Mode selector
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: conditionCards.keys.map((mode) {
                final selected = _conditionMode == mode;
                return Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _conditionMode = mode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color:
                            selected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 6,
                                )
                              ]
                            : [],
                      ),
                      child: Text(
                        mode,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.primaryColor
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Checklist items
          ...items.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Text(item.emoji,
                        style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A))),
                          Text(item.subtitle,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Checkbox(
                      value: item.checked,
                      activeColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      onChanged: (v) =>
                          setState(() => item.checked = v ?? false),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Tab 5 — MOOD & MENTAL
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildMoodTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Mood & Mental Health', 'How are you feeling?'),
          const SizedBox(height: 12),

          // Mood selector card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryColor.withValues(alpha: 0.07),
                  const Color(0xFFEFF6FF),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.primaryColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's Mood",
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                const Text('Tap an emoji to log how you feel',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _showMoodPicker,
                  child: Row(
                    children: [
                      Text(_selectedMood,
                          style: const TextStyle(fontSize: 48)),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _moodLabel(_selectedMood),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryColor),
                          ),
                          Text('Tap to change',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Stress level
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Stress Level',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    5,
                    (i) => GestureDetector(
                      onTap: () =>
                          setState(() => _stressLevel = i + 1),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _stressLevel == i + 1
                                  ? _stressColor(i + 1)
                                  : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                              border: _stressLevel == i + 1
                                  ? Border.all(
                                      color: _stressColor(i + 1),
                                      width: 2)
                                  : null,
                            ),
                            child: Center(
                              child: Text('${i + 1}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: _stressLevel == i + 1
                                        ? Colors.white
                                        : const Color(0xFF94A3B8),
                                  )),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            i == 0
                                ? 'Low'
                                : i == 4
                                    ? 'High'
                                    : '',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Calories & Hydration row
          Row(
            children: [
              Expanded(
                child: _moodMetricCard(
                  emoji: '🔥',
                  label: 'Calories',
                  value: '$_calories',
                  unit: 'kcal',
                  color: const Color(0xFFEF4444),
                  onTap: () => _showNumericDialog(
                    title: 'Calories',
                    subtitle: 'Estimated calories consumed today',
                    unit: 'kcal',
                    currentValue: _calories.toDouble(),
                    onSave: (v) =>
                        setState(() => _calories = v.toInt()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _moodMetricCard(
                  emoji: '💧',
                  label: 'Hydration',
                  value: '$_hydrationPct',
                  unit: '%',
                  color: const Color(0xFF3B82F6),
                  onTap: () => _showNumericDialog(
                    title: 'Hydration',
                    subtitle: 'Estimated hydration level (%)',
                    unit: '%',
                    currentValue: _hydrationPct.toDouble(),
                    onSave: (v) => setState(
                        () => _hydrationPct = v.toInt().clamp(0, 100)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Menstrual Cycle tracker
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🌸', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Menstrual Cycle',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A))),
                          Text('Cycle day tracking',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Switch(
                      value: _periodTracking,
                      activeThumbColor: const Color(0xFFEC4899),
                      onChanged: (v) =>
                          setState(() => _periodTracking = v),
                    ),
                  ],
                ),
                if (_periodTracking) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Day $_cycleDay of cycle',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A))),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDF2F8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(_cyclePhase,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFEC4899))),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Color(0xFFEC4899)),
                            onPressed: () => setState(() {
                              _cycleDay =
                                  (_cycleDay - 1).clamp(1, 35);
                              _cyclePhase = _getCyclePhase(_cycleDay);
                            }),
                          ),
                          Text('$_cycleDay',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFEC4899))),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline,
                                color: Color(0xFFEC4899)),
                            onPressed: () => setState(() {
                              _cycleDay =
                                  (_cycleDay + 1).clamp(1, 35);
                              _cyclePhase = _getCyclePhase(_cycleDay);
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _cycleDay / 28,
                      backgroundColor: const Color(0xFFFDF2F8),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFEC4899)),
                      minHeight: 8,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _moodMetricCard({
    required String emoji,
    required String label,
    required String value,
    required String unit,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF64748B))),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: color)),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(unit,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _moodLabel(String emoji) {
    const map = {
      '😊': 'Happy',
      '😐': 'Neutral',
      '😔': 'Sad',
      '😡': 'Angry',
      '😴': 'Tired',
      '🤒': 'Unwell',
    };
    return map[emoji] ?? 'Unknown';
  }

  Color _stressColor(int level) {
    const colors = [
      Color(0xFF10B981),
      Color(0xFF84CC16),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF991B1B),
    ];
    return colors[(level - 1).clamp(0, 4)];
  }

  String _getCyclePhase(int day) {
    if (day <= 5) return 'Menstruation';
    if (day <= 13) return 'Follicular';
    if (day <= 16) return 'Ovulation';
    if (day <= 28) return 'Luteal';
    return 'Extended';
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                fontFamily: 'Gilroy-Bold')),
        Text(subtitle,
            style:
                const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bottom sheet — generic numeric log
// ═══════════════════════════════════════════════════════════════════════════
class _LogBottomSheet extends StatelessWidget {
  const _LogBottomSheet({
    required this.title,
    required this.subtitle,
    required this.unit,
    required this.controller,
    required this.onSave,
    required this.earnPoints,
  });

  final String title;
  final String subtitle;
  final String unit;
  final TextEditingController controller;
  final VoidCallback onSave;
  final int earnPoints;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Log $title',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
            ],
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSave(),
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w900),
            decoration: InputDecoration(
              suffixText: unit,
              suffixStyle: const TextStyle(
                  fontSize: 16, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                    color: AppColors.primaryColor, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text('+$earnPoints points on save',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB45309))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Save Entry',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bottom sheet — Blood Pressure (two fields)
// ═══════════════════════════════════════════════════════════════════════════
class _BPBottomSheet extends StatelessWidget {
  const _BPBottomSheet({
    required this.sysCtrl,
    required this.diaCtrl,
    required this.onSave,
  });

  final TextEditingController sysCtrl;
  final TextEditingController diaCtrl;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Log Blood Pressure',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          const Text('Enter your systolic and diastolic readings',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _bpField(sysCtrl, 'Systolic', 'mmHg', context),
              ),
              const SizedBox(width: 12),
              const Text('/',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFFCBD5E1))),
              const SizedBox(width: 12),
              Expanded(
                child: _bpField(diaCtrl, 'Diastolic', 'mmHg', context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('⭐', style: TextStyle(fontSize: 14)),
                SizedBox(width: 6),
                Text('+5 points on save',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB45309))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Save Entry',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bpField(TextEditingController ctrl, String label, String unit,
      BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        suffixStyle:
            const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: AppColors.primaryColor, width: 2),
        ),
      ),
    );
  }
}

// ── Simple data classes ──────────────────────────────────────────────────
class _TabMeta {
  final String label;
  final IconData icon;
  const _TabMeta(this.label, this.icon);
}


class _CondItem {
  final String emoji;
  final String title;
  final String subtitle;
  bool checked;
  _CondItem(this.emoji, this.title, this.subtitle, this.checked);
}

// ── History card (card-style grid item) ──────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final String type, value, unit, time;
  const _HistoryCard({required this.type, required this.value, required this.unit, required this.time});

  static const _vitalColors = <String, int>{
    'Blood Pressure': 0xFFEF4444,
    'Blood Glucose':  0xFFF59E0B,
    'Weight':         0xFF8B5CF6,
    'Heart Rate':     0xFFEC4899,
    'Oxygen Level':   0xFF3B82F6,
    'Steps':          0xFF10B981,
    'Water Intake':   0xFF3B82F6,
    'Sleep':          0xFF6366F1,
    'Calories':       0xFFF97316,
    'Temperature':    0xFFFF6B35,
    'Medication Adherence': 0xFF10B981,
  };

  static const _vitalIcons = <String, IconData>{
    'Blood Pressure': Icons.favorite_rounded,
    'Blood Glucose':  Icons.bloodtype_rounded,
    'Weight':         Icons.monitor_weight_rounded,
    'Heart Rate':     Icons.show_chart_rounded,
    'Oxygen Level':   Icons.air_rounded,
    'Steps':          Icons.directions_walk_rounded,
    'Water Intake':   Icons.water_drop_rounded,
    'Sleep':          Icons.nights_stay_rounded,
    'Calories':       Icons.local_fire_department_rounded,
    'Temperature':    Icons.thermostat_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colorHex = _vitalColors[type] ?? 0xFF6366F1;
    final color = Color(colorHex);
    final icon = _vitalIcons[type] ?? Icons.monitor_heart_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.07), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, color: color, size: 11),
            ),
            Flexible(child: Text(time, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis)),
          ]),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(type, style: const TextStyle(fontSize: 8, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 1),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (unit.isNotEmpty)
                Text(unit, style: const TextStyle(fontSize: 7, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
