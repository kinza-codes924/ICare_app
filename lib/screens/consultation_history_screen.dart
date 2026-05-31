import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/models/medical_record.dart';
import 'package:icare/services/medical_record_service.dart';
import 'package:icare/screens/medical_record_detail.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class ConsultationHistoryScreen extends StatefulWidget {
  const ConsultationHistoryScreen({super.key});

  @override
  State<ConsultationHistoryScreen> createState() => _ConsultationHistoryScreenState();
}

class _ConsultationHistoryScreenState extends State<ConsultationHistoryScreen> {
  final MedicalRecordService _service = MedicalRecordService();
  List<MedicalRecord> _records = [];
  List<MedicalRecord> _filtered = [];
  bool _isLoading = true;
  bool _newestFirst = true; // sort order toggle
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _applyFilter();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    List<MedicalRecord> result = List.from(_records);

    // Apply search
    if (_searchQuery.isNotEmpty) {
      result = result.where((r) {
        final diagnosis = (r.diagnosis ?? '').toLowerCase();
        final doctor = r.doctor.name.toLowerCase();
        final date = DateFormat('MMM dd yyyy').format(r.createdAt).toLowerCase();
        final symptoms = r.symptoms.join(' ').toLowerCase();
        final meds = r.prescription?.medicines
                .map((m) => m.name.toLowerCase())
                .join(' ') ??
            '';
        final labs = r.labTests.join(' ').toLowerCase();
        return diagnosis.contains(_searchQuery) ||
            doctor.contains(_searchQuery) ||
            date.contains(_searchQuery) ||
            symptoms.contains(_searchQuery) ||
            meds.contains(_searchQuery) ||
            labs.contains(_searchQuery);
      }).toList();
    }

    // Apply sort
    result.sort((a, b) => _newestFirst
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));

    _filtered = result;
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final result = await _service.getMyRecords();
      if (result['success'] && mounted) {
        final list = result['records'] as List<dynamic>;
        final parsed = <MedicalRecord>[];
        for (final item in list) {
          try {
            parsed.add(MedicalRecord.fromJson(item));
          } catch (_) {}
        }
        // Sort chronologically oldest → newest (default will be overridden by _applyFilter)
        parsed.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        setState(() {
          _records = parsed;
          _applyFilter();
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
        title: Text(
          'Consultation History'.tr(),
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          // Sort toggle button
          Tooltip(
            message: _newestFirst ? 'Showing: Newest First' : 'Showing: Oldest First',
            child: InkWell(
              onTap: () {
                setState(() {
                  _newestFirst = !_newestFirst;
                  _applyFilter();
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primaryColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _newestFirst
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: 14,
                      color: AppColors.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _newestFirst ? 'Newest' : 'Oldest',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            onPressed: _loadRecords,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // ── Search Bar ──────────────────────────────────────
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText:
                              'Search by diagnosis, doctor, medicine, symptom…'.tr(),
                          hintStyle: const TextStyle(
                              fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: Color(0xFF94A3B8), size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      color: Color(0xFF94A3B8), size: 18),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: AppColors.primaryColor
                                    .withValues(alpha: 0.5),
                                width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    // ── Result count / sort info ────────────────────────
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Row(
                        children: [
                          Text(
                            _searchQuery.isNotEmpty
                                ? '${_filtered.length} result${_filtered.length == 1 ? '' : 's'} for "$_searchQuery"'
                                : '${_filtered.length} consultation${_filtered.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _searchQuery.isNotEmpty && _filtered.isEmpty
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _newestFirst
                                ? '↓ Newest first'
                                : '↑ Oldest first',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // ── Timeline / empty search state ───────────────────
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off_rounded,
                                      size: 56,
                                      color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No results for\n"$_searchQuery"',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            )
                          : _buildTimeline(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
              'Your Health Journey Starts Here',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'After your first consultation, your doctor\'s prescriptions, diagnoses, and health recommendations will automatically appear here.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What you\'ll see here:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFeatureItem(Icons.medical_services_rounded, 'Diagnoses & doctor notes'),
                  _buildFeatureItem(Icons.medication_rounded, 'Prescriptions & medicines'),
                  _buildFeatureItem(Icons.biotech_rounded, 'Lab test recommendations'),
                  _buildFeatureItem(Icons.health_and_safety_rounded, 'Assigned health programs'),
                  _buildFeatureItem(Icons.calendar_today_rounded, 'Follow-up appointments'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryColor),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return RefreshIndicator(
      onRefresh: _loadRecords,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _filtered.length,
        itemBuilder: (context, index) {
          final record = _filtered[index];
          final isLast = index == _filtered.length - 1;
          return _buildTimelineEntry(record, isLast);
        },
      ),
    );
  }

  Widget _buildTimelineEntry(MedicalRecord record, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Card content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => MedicalRecordDetailScreen(record: record),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
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
                          Text(
                            DateFormat('MMM dd, yyyy').format(record.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryColor,
                            ),
                          ),
                          Text(
                            DateFormat('hh:mm a').format(record.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (record.diagnosis != null) ...[
                        Text(
                          record.diagnosis!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        'Dr. ${record.doctor.name}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      if (record.symptoms.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: record.symptoms.take(3).map((s) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                s,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      if (record.prescription != null &&
                          record.prescription!.medicines.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.medication_rounded, size: 14, color: Color(0xFF10B981)),
                            const SizedBox(width: 6),
                            Text(
                              '${record.prescription!.medicines.length} medicine(s) prescribed',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (record.labTests.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.biotech_rounded, size: 14, color: Color(0xFF8B5CF6)),
                            const SizedBox(width: 6),
                            Text(
                              '${record.labTests.length} lab test(s) recommended',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8B5CF6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primaryColor),
                          const SizedBox(width: 4),
                          const Text(
                            'View full details',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
