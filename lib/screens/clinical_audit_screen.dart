import 'package:flutter/material.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/drag_scroll.dart';

/// Clinical Audit & QA — the doctor's own quality figures.
///
/// Every number on this screen used to be written into the file: a 94% quality
/// score, 98% documentation, 100% prescription accuracy, 85% follow-up, and a
/// "Record #21 approved by Senior Medical Officer" that pointed at no record.
/// Nothing was fetched and nothing ever moved, so a doctor reading it was being
/// shown an invented judgement of their own work. It reads
/// GET /doctors/me/clinical-audit now, which derives each figure from that
/// doctor's completed consultations.
///
/// A metric with nothing behind it yet shows "Not enough data" rather than a
/// flattering default — an empty record must never read as 100%.
class ClinicalAuditScreen extends StatefulWidget {
  const ClinicalAuditScreen({super.key});

  @override
  State<ClinicalAuditScreen> createState() => _ClinicalAuditScreenState();
}

class _ClinicalAuditScreenState extends State<ClinicalAuditScreen> {
  final _api = ApiService();

  bool _isLoading = true;
  String? _error;
  int? _qualityScore;
  int _totalConsultations = 0;
  List<Map<String, dynamic>> _metrics = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/doctors/me/clinical-audit');
      final data = res.data;
      if (data is Map && data['success'] == true) {
        setState(() {
          _qualityScore = (data['qualityScore'] as num?)?.toInt();
          _totalConsultations = (data['totalConsultations'] as num?)?.toInt() ?? 0;
          _metrics = List<Map<String, dynamic>>.from(
            (data['metrics'] as List? ?? []).map((m) => Map<String, dynamic>.from(m as Map)),
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data is Map ? data['message']?.toString() : null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load your audit figures';
          _isLoading = false;
        });
      }
    }
  }

  Color _colourFor(int value) {
    if (value >= 85) return const Color(0xFF16A34A);
    if (value >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: CustomBackButton(),
        centerTitle: true,
        title: const Text(
          'Clinical Audit & QA',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DragScroll(
              builder: (context, controller) => SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      _buildNotice(_error!, isError: true),
                      const SizedBox(height: 20),
                    ],
                    _buildQualityScore(),
                    const SizedBox(height: 28),
                    const Text(
                      'Performance Metrics',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Calculated from your own completed consultations.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    ..._metrics.map(_buildMetricTile),
                    if (_metrics.isEmpty && _error == null)
                      _buildNotice(
                        'No completed consultations yet — figures appear here '
                        'once you have seen patients through the platform.',
                      ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildNotice(String text, {bool isError = false}) {
    final colour = isError ? const Color(0xFFDC2626) : const Color(0xFF64748B);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colour.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              size: 18, color: colour),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: colour)),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityScore() {
    final score = _qualityScore;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF334155)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: score == null ? 0 : score / 100,
                  strokeWidth: 8,
                  color: score == null ? Colors.white24 : _colourFor(score),
                  backgroundColor: Colors.white10,
                ),
              ),
              Text(
                score == null ? '—' : '$score%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quality Score',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  score == null
                      ? 'Not enough data yet.'
                      // No comparison against a "hospital average" is claimed:
                      // no such figure is computed anywhere, and the old copy
                      // asserted one.
                      : 'The average of your measurable metrics, across '
                        '$_totalConsultations completed consultation'
                        '${_totalConsultations == 1 ? '' : 's'}.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(Map<String, dynamic> metric) {
    final value = (metric['value'] as num?)?.toInt();
    final label = metric['label']?.toString() ?? '';
    final detail = metric['detail']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                value == null ? 'Not enough data' : '$value%',
                style: TextStyle(
                  fontSize: value == null ? 12 : 16,
                  fontWeight: FontWeight.w900,
                  color: value == null
                      ? const Color(0xFF94A3B8)
                      : _colourFor(value),
                ),
              ),
            ],
          ),
          if (value != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 6,
                backgroundColor: const Color(0xFFF1F5F9),
                color: _colourFor(value),
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Every figure says what it counted, so the doctor can check it
          // against their own records rather than take the number on trust.
          Text(
            detail,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
