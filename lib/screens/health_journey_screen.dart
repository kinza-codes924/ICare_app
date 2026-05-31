import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/services/health_tracker_service.dart';
import 'package:icare/services/health_settings_service.dart';
import 'package:icare/models/health_tracker_entry.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/utils/theme.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class HealthJourneyScreen extends StatefulWidget {
  const HealthJourneyScreen({super.key});

  @override
  State<HealthJourneyScreen> createState() => _HealthJourneyScreenState();
}

class _HealthJourneyScreenState extends State<HealthJourneyScreen> {
  final HealthTrackerService _trackerService = HealthTrackerService();
  final HealthSettingsService _settingsService = HealthSettingsService();

  bool _isLoading = true;
  bool _healthModeEnabled = false;
  List<String> _selectedConditions = [];
  List<Map<String, dynamic>> _vitalData = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);

    try {
      final result = await _trackerService.getDashboard();

      if (result['success'] && mounted) {
        setState(() {
          _healthModeEnabled = result['healthModeEnabled'] ?? false;
          _selectedConditions = List<String>.from(result['selectedConditions'] ?? []);
          _vitalData = List<Map<String, dynamic>>.from(result['vitals'] ?? []);
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _getVitalConfig(String vitalKey) {
    final configs = {
      'bloodPressure': {
        'name': 'Blood Pressure',
        'icon': Icons.favorite_rounded,
        'color': const Color(0xFFEF4444),
        'unit': 'mmHg',
      },
      'bloodSugar': {
        'name': 'Blood Glucose',
        'icon': Icons.water_drop_rounded,
        'color': const Color(0xFF8B5CF6),
        'unit': 'mg/dL',
      },
      'weight': {
        'name': 'Weight',
        'icon': Icons.monitor_weight_rounded,
        'color': const Color(0xFF3B82F6),
        'unit': 'kg',
      },
      'water': {
        'name': 'Water Intake',
        'icon': Icons.local_drink_rounded,
        'color': const Color(0xFF14B8A6),
        'unit': 'glasses',
      },
      'medication': {
        'name': 'Medication Adherence',
        'icon': Icons.medication_rounded,
        'color': const Color(0xFFF43F5E),
        'unit': '%',
      },
      'steps': {
        'name': 'Steps',
        'icon': Icons.directions_walk_rounded,
        'color': const Color(0xFF06B6D4),
        'unit': 'steps',
      },
      'sleep': {
        'name': 'Sleep',
        'icon': Icons.bedtime_rounded,
        'color': const Color(0xFF6366F1),
        'unit': 'hours',
      },
      'heartRate': {
        'name': 'Heart Rate',
        'icon': Icons.monitor_heart_rounded,
        'color': const Color(0xFFEC4899),
        'unit': 'bpm',
      },
      'temperature': {
        'name': 'Temperature',
        'icon': Icons.thermostat_rounded,
        'color': const Color(0xFFF59E0B),
        'unit': '°C',
      },
      'oxygenLevel': {
        'name': 'Oxygen Level',
        'icon': Icons.air_rounded,
        'color': const Color(0xFF10B981),
        'unit': '%',
      },
    };
    return configs[vitalKey] ?? {};
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
          'My Health Journey',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Gilroy-Bold',
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            onPressed: _loadDashboard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
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
                        _buildHealthModeCard(),
                        const SizedBox(height: 24),
                        if (_vitalData.isEmpty)
                          _buildEmptyState()
                        else ...[
                          const Text(
                            'Your Health Vitals',
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
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isDesktop ? 4 : 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.45,
                            ),
                            itemCount: _vitalData.length,
                            itemBuilder: (context, index) {
                              final vitalInfo = _vitalData[index];
                              return _buildVitalCard(vitalInfo);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHealthModeCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _healthModeEnabled
              ? [const Color(0xFF10B981), const Color(0xFF059669)]
              : [const Color(0xFF64748B), const Color(0xFF475569)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: (_healthModeEnabled ? const Color(0xFF10B981) : const Color(0xFF64748B))
                .withValues(alpha: 0.3),
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
            child: Icon(
              _healthModeEnabled ? Icons.health_and_safety_rounded : Icons.dashboard_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _healthModeEnabled ? 'Health Mode Active' : 'Health Mode Inactive',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _healthModeEnabled
                      ? _selectedConditions.join(', ')
                      : 'Showing all vitals',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _healthModeEnabled
                      ? 'Tracking vitals for your conditions'
                      : 'Enable Health Mode in Settings',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalCard(Map<String, dynamic> vitalInfo) {
    final vitalKey = vitalInfo['vitalKey'];
    final config = _getVitalConfig(vitalKey);
    final latestEntry = vitalInfo['latestEntry'] != null
        ? HealthTrackerEntry.fromJson(vitalInfo['latestEntry'])
        : null;
    final summary = vitalInfo['summary'] != null
        ? VitalSummary.fromJson(vitalInfo['summary'])
        : null;

    final Color color = config['color'] ?? Colors.grey;
    final bool hasData = latestEntry != null;

    return GestureDetector(
      onTap: () => _showAddVitalDialog(
        vitalKey: vitalKey,
        vitalType: config['name'] ?? vitalKey,
        unit: config['unit'] ?? '',
        currentValue: hasData ? latestEntry.value : '',
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 6,
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(config['icon'], color: color, size: 15),
                ),
                if (hasData)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: (latestEntry.status == 'Normal' || latestEntry.status == 'Healthy')
                          ? const Color(0xFF10B981).withValues(alpha: 0.1)
                          : const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      latestEntry.status,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: (latestEntry.status == 'Normal' || latestEntry.status == 'Healthy')
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  )
                else
                  const Icon(Icons.add_circle_outline_rounded,
                      color: Color(0xFF94A3B8), size: 14),
              ],
            ),
            const Spacer(),
            Text(
              config['name'] ?? '',
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    hasData ? latestEntry.value : '--',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: hasData ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    config['unit'] ?? '',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              hasData
                  ? DateFormat('MMM dd').format(latestEntry.timestamp)
                  : 'Tap to add',
              style: TextStyle(
                fontSize: 9,
                color: hasData ? const Color(0xFF94A3B8) : color,
                fontWeight: hasData ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddVitalDialog({
    required String vitalKey,
    required String vitalType,
    required String unit,
    required String currentValue,
  }) {
    final bool isBP = vitalType == 'Blood Pressure';

    if (isBP) {
      // BP needs two fields
      final parts = currentValue.split('/');
      final sysCtrl = TextEditingController(text: parts.isNotEmpty ? parts[0] : '');
      final diaCtrl = TextEditingController(text: parts.length > 1 ? parts[1] : '');
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _JourneyBPSheet(
          sysCtrl: sysCtrl,
          diaCtrl: diaCtrl,
          onSave: () async {
            final sys = sysCtrl.text.trim();
            final dia = diaCtrl.text.trim();
            if (sys.isNotEmpty && dia.isNotEmpty) {
              await _trackerService.addEntry(
                vitalType: 'Blood Pressure',
                value: '$sys/$dia',
                unit: 'mmHg',
              );
              Navigator.pop(ctx);
              _loadDashboard();
            }
          },
        ),
      );
    } else {
      final ctrl = TextEditingController(text: currentValue);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _JourneyVitalSheet(
          title: vitalType,
          unit: unit,
          controller: ctrl,
          onSave: () async {
            final val = ctrl.text.trim();
            if (val.isNotEmpty) {
              await _trackerService.addEntry(
                vitalType: vitalType,
                value: val,
                unit: unit,
              );
              Navigator.pop(ctx);
              _loadDashboard();
            }
          },
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.timeline_rounded,
                color: AppColors.primaryColor,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Start Your Health Journey',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Track your vitals in the Health Tracker to see your health journey here.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom sheet for single-value vitals ────────────────────────────────
class _JourneyVitalSheet extends StatelessWidget {
  final String title;
  final String unit;
  final TextEditingController controller;
  final VoidCallback onSave;

  const _JourneyVitalSheet({
    required this.title,
    required this.unit,
    required this.controller,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Log $title',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text('Enter your $title reading',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSave(),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            decoration: InputDecoration(
              suffixText: unit,
              suffixStyle: const TextStyle(fontSize: 16, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
              ),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Save',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom sheet for Blood Pressure (two fields) ────────────────────────
class _JourneyBPSheet extends StatelessWidget {
  final TextEditingController sysCtrl;
  final TextEditingController diaCtrl;
  final VoidCallback onSave;

  const _JourneyBPSheet({
    required this.sysCtrl,
    required this.diaCtrl,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Log Blood Pressure',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          const Text('Enter systolic and diastolic readings',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _bpField(sysCtrl, 'Systolic', context)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('/', style: TextStyle(fontSize: 32, color: Color(0xFFCBD5E1))),
              ),
              Expanded(child: _bpField(diaCtrl, 'Diastolic', context, onDone: onSave)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Save',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bpField(TextEditingController ctrl, String label, BuildContext context, {VoidCallback? onDone}) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      autofocus: label == 'Systolic',
      textInputAction: label == 'Systolic' ? TextInputAction.next : TextInputAction.done,
      onSubmitted: label == 'Diastolic' ? (_) => onDone?.call() : null,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'mmHg',
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
        ),
      ),
    );
  }
}
