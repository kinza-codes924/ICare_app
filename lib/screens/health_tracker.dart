import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/screens/star_click_game.dart';
import 'package:icare/services/gamification_service.dart';
import 'package:icare/services/health_tracker_service.dart';
import 'package:icare/models/health_tracker_entry.dart';
import 'package:intl/intl.dart';

class HealthTracker extends StatefulWidget {
  const HealthTracker({super.key});

  @override
  State<HealthTracker> createState() => _HealthTrackerState();
}

class _HealthTrackerState extends State<HealthTracker> {
  final GamificationService _gamificationService = GamificationService();
  final HealthTrackerService _healthTrackerService = HealthTrackerService();
  int _points = 0;
  List<dynamic> _badges = [];
  List<HealthTrackerEntry> _latestEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    // Concurrent data loading
    final results = await Future.wait([
      _gamificationService.getMyStats(),
      _healthTrackerService.getLatestEntries(),
    ]);

    final gamificationResult = results[0];
    final entriesResult = results[1];

    if (mounted) {
      setState(() {
        if (gamificationResult['success'] == true) {
          _points = gamificationResult['points'] ?? 0;
          _badges = gamificationResult['badges'] ?? [];
        }

        if (entriesResult['success'] == true) {
          _latestEntries = (entriesResult['entries'] as List)
              .map((e) => HealthTrackerEntry.fromJson(e))
              .toList();
        }
        _isLoading = false;
      });
    }
  }

  // Fallback map for rendering cards even if no data
  final List<Map<String, dynamic>> _vitalTypes = [
    {
      'type': 'Blood Pressure',
      'unit': 'mmHg',
      'icon': Icons.favorite_rounded,
      'color': const Color(0xFFEF4444),
    },
    {
      'type': 'Heart Rate',
      'unit': 'bpm',
      'icon': Icons.monitor_heart_rounded,
      'color': const Color(0xFFEC4899),
    },
    {
      'type': 'Blood Glucose',
      'unit': 'mg/dL',
      'icon': Icons.water_drop_rounded,
      'color': const Color(0xFF8B5CF6),
    },
    {
      'type': 'Weight',
      'unit': 'kg',
      'icon': Icons.monitor_weight_rounded,
      'color': const Color(0xFF3B82F6),
    },
    {
      'type': 'Temperature',
      'unit': '°C',
      'icon': Icons.thermostat_rounded,
      'color': const Color(0xFFF59E0B),
    },
    {
      'type': 'Oxygen Level',
      'unit': '%',
      'icon': Icons.air_rounded,
      'color': const Color(0xFF10B981),
    },
    {
      'type': 'Steps',
      'unit': 'steps',
      'icon': Icons.directions_walk_rounded,
      'color': const Color(0xFF06B6D4),
    },
    {
      'type': 'Sleep',
      'unit': 'hours',
      'icon': Icons.bedtime_rounded,
      'color': const Color(0xFF6366F1),
    },
    {
      'type': 'Water Intake',
      'unit': 'glasses',
      'icon': Icons.local_drink_rounded,
      'color': const Color(0xFF14B8A6),
    },
    {
      'type': 'Medication Adherence',
      'unit': '%',
      'icon': Icons.medication_rounded,
      'color': const Color(0xFFF43F5E),
    },
  ];

  void _addVitalReading(String type, String unit) {
    showDialog(
      context: context,
      builder: (context) => _AddVitalDialog(
        vitalType: type,
        unit: unit,
        onSave: (value, notes, timestamp) async {
          final res = await _healthTrackerService.addEntry(
            vitalType: type,
            value: value,
            unit: unit,
            notes: notes,
            timestamp: timestamp,
          );

          if (res['success']) {
            _loadAllData();
            _gamificationService.logMetric().then((pts) {
              if (!mounted) return;
              final awarded = (pts['pointsAwarded'] as num?)?.toInt() ?? 5;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('$type reading added! +$awarded pts 🏆'),
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 3),
              ));
            });
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to add reading: ${res['message']}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          'Health Tracker',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Gilroy-Bold',
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 40 : 20),
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 1200 : double.infinity,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHealthSummary(),
                        const SizedBox(height: 24),
                        _buildGamificationRow(isDesktop),
                        const SizedBox(height: 32),
                        const Text(
                          'Vital Signs',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isDesktop ? 3 : 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.1,
                              ),
                          itemCount: _vitalTypes.length,
                          itemBuilder: (context, index) {
                            final typeInfo = _vitalTypes[index];
                            // Find most recent reading for this type
                            HealthTrackerEntry? lastReading;
                            try {
                              lastReading = _latestEntries.firstWhere(
                                (entry) => entry.vitalType == typeInfo['type'],
                              );
                            } catch (_) {
                              lastReading = null;
                            }
                            return _buildVitalCard(typeInfo, lastReading);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHealthSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Health',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Good',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'All vitals within normal range',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalCard(Map<String, dynamic> typeInfo, HealthTrackerEntry? lastReading) {
    final Color color = typeInfo['color'];
    final bool hasData = lastReading != null;

    return InkWell(
      onTap: () => _addVitalReading(typeInfo['type'], typeInfo['unit']),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(typeInfo['icon'], color: color, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (hasData && (lastReading.status == 'Normal' ||
                            lastReading.status == 'Healthy'))
                        ? const Color(0xFF10B981).withValues(alpha: 0.1)
                        : !hasData
                        ? const Color(0xFF94A3B8).withValues(alpha: 0.1)
                        : const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    hasData ? lastReading.status : 'No Data',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color:
                          (hasData && (lastReading.status == 'Normal' ||
                              lastReading.status == 'Healthy'))
                          ? const Color(0xFF10B981)
                          : !hasData
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              typeInfo['type'],
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  hasData ? lastReading.value : '--',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    typeInfo['unit'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasData
                  ? DateFormat('MMM dd, HH:mm').format(lastReading.timestamp)
                  : 'Never updated',
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGamificationRow(bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildStreakCard()),
          const SizedBox(width: 24),
          Expanded(child: _buildBadgesCard()),
        ],
      );
    }
    return Column(
      children: [
        _buildStreakCard(),
        const SizedBox(height: 16),
        _buildBadgesCard(),
      ],
    );
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDE68A),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flash_on_rounded,
              color: Color(0xFFD97706),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '7 Day Streak!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Text(
                  'You updated your vitals 7 days in a row. Keep it up!',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => StarClickGame()),
                    );
                  },
                  icon: const Icon(Icons.videogame_asset_rounded, size: 16),
                  label: const Text(
                    'Earn Daily Points',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesCard() {
    final List<Map<String, dynamic>> badges = [
      {
        'icon': Icons.workspace_premium_rounded,
        'color': Color(0xFF3B82F6),
        'label': 'Early Bird',
      },
      {
        'icon': Icons.monitor_heart_rounded,
        'color': Color(0xFFEF4444),
        'label': 'Heart Hero',
      },
      {
        'icon': Icons.water_drop_rounded,
        'color': Color(0xFF10B981),
        'label': 'Hydrated',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Earned Badges',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          _badges.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No badges earned yet. Keep active!',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _badges.map((badge) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF3B82F6,
                                ).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.workspace_premium_rounded,
                                color: Color(0xFF3B82F6),
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              badge['name'] ?? 'N/A',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ],
      ),
    );
  }
}

class _AddVitalDialog extends StatefulWidget {
  final String vitalType;
  final String unit;
  final Function(String value, String? notes, DateTime? timestamp) onSave;

  const _AddVitalDialog({
    required this.vitalType,
    required this.unit,
    required this.onSave,
  });

  @override
  State<_AddVitalDialog> createState() => _AddVitalDialogState();
}

class _AddVitalDialogState extends State<_AddVitalDialog> {
  final _valueController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _selectedDateTime;

  // Vitals that need text input (not pure numbers)
  bool get _isTextInput =>
      widget.vitalType == 'Blood Pressure'; // e.g. 120/80

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (_valueController.text.isEmpty) return;
    widget.onSave(
      _valueController.text,
      _notesController.text.isEmpty ? null : _notesController.text,
      _selectedDateTime,
    );
    Navigator.pop(context);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? DateTime.now()),
      );

      if (time != null && mounted) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add ${widget.vitalType} Reading',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _valueController,
                keyboardType: _isTextInput
                    ? TextInputType.text
                    : const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: 'Value',
                  hintText: widget.vitalType == 'Blood Pressure'
                      ? 'e.g. 120/80'
                      : 'Enter reading',
                  suffixText: widget.unit,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Add any notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDateTime,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDateTime != null
                            ? DateFormat('MMM dd, yyyy HH:mm').format(_selectedDateTime!)
                            : 'Select Date & Time (Optional)',
                        style: TextStyle(
                          color: _selectedDateTime != null
                              ? Colors.black87
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
