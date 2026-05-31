import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrentMedicationsPage extends StatefulWidget {
  const CurrentMedicationsPage({super.key});

  @override
  State<CurrentMedicationsPage> createState() => _CurrentMedicationsPageState();
}

class _CurrentMedicationsPageState extends State<CurrentMedicationsPage> {
  List<Map<String, dynamic>> _medications = [];
  static const _prefsKey = 'current_medications_v2';

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && mounted) {
      setState(() {
        _medications = List<Map<String, dynamic>>.from(
          (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)),
        );
      });
    }
  }

  Future<void> _saveMedications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_medications));
  }

  void _addMedication(Map<String, dynamic> med) {
    setState(() => _medications.add(med));
    _saveMedications();
  }

  void _discontinue(int index) {
    setState(() {
      _medications[index]['isDiscontinued'] = true;
      _medications[index]['discontinuedDate'] = DateTime.now().toIso8601String();
    });
    _saveMedications();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_medications[index]['name']} discontinued'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<Map<String, dynamic>> get _active =>
      _medications.where((m) => !(m['isDiscontinued'] as bool? ?? false) && !_isExpired(m)).toList();

  List<Map<String, dynamic>> get _discontinued =>
      _medications.where((m) => (m['isDiscontinued'] as bool? ?? false) || _isExpired(m)).toList();

  bool _isExpired(Map<String, dynamic> m) {
    final endDate = m['endDate'] as String?;
    if (endDate == null) return false;
    try {
      return DateTime.parse(endDate).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  String _daysRemaining(Map<String, dynamic> m) {
    final endDate = m['endDate'] as String?;
    if (endDate == null) return 'Ongoing';
    try {
      final diff = DateTime.parse(endDate).difference(DateTime.now());
      if (diff.inDays < 0) return 'Expired';
      if (diff.inDays == 0) return 'Last day';
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} left';
    } catch (_) {
      return '';
    }
  }

  String _dateRange(Map<String, dynamic> m) {
    final added = m['addedDate'] as String? ?? '';
    final end = m['endDate'] as String?;
    final disc = m['discontinuedDate'] as String?;
    String from = '';
    String to = '';
    try {
      if (added.isNotEmpty) {
        final d = DateTime.parse(added);
        from = '${d.day}/${d.month}/${d.year}';
      }
      final toDate = disc ?? end;
      if (toDate != null) {
        final d = DateTime.parse(toDate);
        to = '${d.day}/${d.month}/${d.year}';
      }
    } catch (_) {}
    if (from.isEmpty) return '';
    return to.isEmpty ? 'From $from' : '$from → $to';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          'Current Medications',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _openAddMedicationSheet,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Medication'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: _medications.isEmpty
          ? _buildEmpty()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_active.isNotEmpty) ...[
                    _sectionHeader('Active Medications', Icons.check_circle_rounded, const Color(0xFF10B981)),
                    const SizedBox(height: 12),
                    ..._active.asMap().entries.map((e) => _buildMedCard(
                          e.value,
                          _medications.indexOf(e.value),
                          isActive: true,
                        )),
                    const SizedBox(height: 24),
                  ],
                  if (_discontinued.isNotEmpty) ...[
                    _sectionHeader('Medication History', Icons.history_rounded, const Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    ..._discontinued.map((m) => _buildMedCard(m, -1, isActive: false)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medication_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No medications added yet',
            style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap "Add Medication" to get started',
            style: TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openAddMedicationSheet,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Medication'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _buildMedCard(Map<String, dynamic> m, int index, {required bool isActive}) {
    final source = m['source'] as String? ?? 'Self';
    final isDoctorPrescribed = source.startsWith('Dr.');
    final remaining = _daysRemaining(m);
    final dateRange = _dateRange(m);
    final expired = _isExpired(m);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? (isDoctorPrescribed ? const Color(0xFF3B82F6).withValues(alpha: 0.3) : const Color(0xFF10B981).withValues(alpha: 0.3))
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? (isDoctorPrescribed ? const Color(0xFF3B82F6).withValues(alpha: 0.1) : const Color(0xFF10B981).withValues(alpha: 0.1))
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.medication_rounded,
                    color: isActive
                        ? (isDoctorPrescribed ? const Color(0xFF3B82F6) : const Color(0xFF10B981))
                        : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m['name'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _chip(m['frequency'] as String? ?? '', const Color(0xFF6366F1)),
                          const SizedBox(width: 6),
                          if ((m['dosage'] as String? ?? '').isNotEmpty)
                            _chip(m['dosage'] as String? ?? '', const Color(0xFF8B5CF6)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isActive || expired)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      expired ? 'Expired' : 'Discontinued',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isDoctorPrescribed ? Icons.local_hospital_rounded : Icons.person_rounded,
                  size: 13,
                  color: isDoctorPrescribed ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Text(
                  source,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDoctorPrescribed ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (dateRange.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFFCBD5E1)),
                  const SizedBox(width: 4),
                  Text(dateRange, style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w500)),
                ],
                const Spacer(),
                if (isActive && !expired)
                  Text(
                    remaining,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: remaining == 'Last day' ? Colors.orange : const Color(0xFF10B981),
                    ),
                  ),
              ],
            ),
            if ((m['notes'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                m['notes'] as String,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
            if (isActive && !expired) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmDiscontinue(index),
                  icon: const Icon(Icons.stop_circle_outlined, size: 16, color: Color(0xFFEF4444)),
                  label: const Text(
                    'Discontinue this medication',
                    style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    );
  }

  void _confirmDiscontinue(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Discontinue Medication?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(
          'Are you sure you want to discontinue "${_medications[index]['name']}"? It will be moved to your medication history.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _discontinue(index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Discontinue'),
          ),
        ],
      ),
    );
  }

  void _openAddMedicationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMedicationSheet(onAdd: _addMedication),
    );
  }
}

// ── Add Medication Bottom Sheet ────────────────────────────────────────────────
class _AddMedicationSheet extends StatefulWidget {
  final void Function(Map<String, dynamic>) onAdd;
  const _AddMedicationSheet({required this.onAdd});

  @override
  State<_AddMedicationSheet> createState() => _AddMedicationSheetState();
}

class _AddMedicationSheetState extends State<_AddMedicationSheet> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();
  final _durationController = TextEditingController();
  String _frequency = 'BD';
  bool _hasDuration = false;

  static const _frequencies = ['OD', 'BD', 'TDS', 'QID', 'SOS', 'STAT', 'Weekly'];

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter medication name'), backgroundColor: Colors.red),
      );
      return;
    }
    final now = DateTime.now();
    DateTime? endDate;
    if (_hasDuration && _durationController.text.trim().isNotEmpty) {
      final days = int.tryParse(_durationController.text.trim());
      if (days != null && days > 0) endDate = now.add(Duration(days: days));
    }
    widget.onAdd({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': _nameController.text.trim(),
      'dosage': _dosageController.text.trim(),
      'frequency': _frequency,
      'notes': _notesController.text.trim(),
      'addedDate': now.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'source': 'Self',
      'isDiscontinued': false,
      'discontinuedDate': null,
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_nameController.text.trim()} added to Current Medications'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Add Medication', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: 20),
          _label('Medicine Name *'),
          _field(_nameController, 'e.g. Paracetamol 500mg'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Dosage'),
                    _field(_dosageController, 'e.g. 500mg'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Frequency'),
                    DropdownButtonFormField<String>(
                      value: _frequency,
                      decoration: _inputDec(),
                      items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                      onChanged: (v) => setState(() => _frequency = v!),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Switch(
                value: _hasDuration,
                activeColor: AppColors.primaryColor,
                onChanged: (v) => setState(() => _hasDuration = v),
              ),
              const SizedBox(width: 8),
              const Text('Set duration', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          if (_hasDuration) ...[
            const SizedBox(height: 8),
            _label('Duration (days)'),
            _field(_durationController, 'e.g. 7', inputType: TextInputType.number),
          ],
          const SizedBox(height: 16),
          _label('Notes (optional)'),
          _field(_notesController, 'e.g. Take after food', maxLines: 2),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: const Text('Save Medication'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
  );

  Widget _field(TextEditingController ctrl, String hint, {int maxLines = 1, TextInputType? inputType}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: inputType,
        decoration: _inputDec(hint: hint),
      );

  InputDecoration _inputDec({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
  );
}
