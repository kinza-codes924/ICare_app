import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/services/clinical_audit_service.dart';
import 'package:icare/utils/theme.dart';

/// Clinical Audit & QA Dashboard
///
/// Shows quality assurance metrics across the connected virtual hospital
/// Tracks consultation quality, prescription compliance, and clinical standards
class ClinicalAuditDashboardScreen extends ConsumerStatefulWidget {
  const ClinicalAuditDashboardScreen({super.key});

  @override
  ConsumerState<ClinicalAuditDashboardScreen> createState() => _ClinicalAuditDashboardScreenState();
}

class _ClinicalAuditDashboardScreenState extends ConsumerState<ClinicalAuditDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  SystemQualityMetrics? _systemMetrics;
  String _selectedPeriod = 'This Month';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMetrics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);

    final auditService = ClinicalAuditService();
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 30));

    final metrics = await auditService.getSystemQualityMetrics(startDate, endDate);

    setState(() {
      _systemMetrics = metrics;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Clinical Audit & QA',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Gilroy-Bold',
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Quality assurance metrics',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedPeriod,
            onSelected: (value) => setState(() => _selectedPeriod = value),
            itemBuilder: (ctx) => ['Today', 'This Week', 'This Month', 'This Year']
                .map((p) => PopupMenuItem(value: p, child: Text(p)))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(_selectedPeriod, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primaryColor,
              labelColor: AppColors.primaryColor,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFamily: 'Gilroy-Bold'),
              tabs: const [
                Tab(text: 'OVERVIEW'),
                Tab(text: 'QUALITY METRICS'),
                Tab(text: 'FLAGGED REVIEWS'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildQualityMetricsTab(),
                _buildFlaggedReviewsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    if (_systemMetrics == null) return const SizedBox();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryColor,
                AppColors.primaryColor.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overall Quality Score',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  fontFamily: 'Gilroy-Medium',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_systemMetrics!.averageQualityScore}',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontFamily: 'Gilroy-Bold',
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12, left: 4),
                    child: Text(
                      '/100',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Based on ${_systemMetrics!.totalConsultations} consultations',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Quality Breakdown',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 16),
        _buildQualityScoreCard(
          'Documentation Completeness',
          _systemMetrics!.documentationCompleteness,
          Icons.description,
          const Color(0xFF3B82F6),
        ),
        _buildQualityScoreCard(
          'Clinical Reasoning',
          _systemMetrics!.clinicalReasoningScore,
          Icons.psychology,
          const Color(0xFF8B5CF6),
        ),
        _buildQualityScoreCard(
          'Prescription Appropriateness',
          _systemMetrics!.prescriptionAppropriatenessScore,
          Icons.medication,
          const Color(0xFF10B981),
        ),
        _buildQualityScoreCard(
          'Follow-up Planning',
          _systemMetrics!.followUpPlanScore,
          Icons.event_repeat,
          const Color(0xFFF59E0B),
        ),
        const SizedBox(height: 24),
        const Text(
          'System Performance',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 16),
        _buildPerformanceCard(
          'Consultations Flagged',
          '${_systemMetrics!.consultationsFlaggedForReview}',
          '${((_systemMetrics!.consultationsFlaggedForReview / _systemMetrics!.totalConsultations) * 100).toStringAsFixed(1)}% of total',
          Icons.flag,
          const Color(0xFFF59E0B),
        ),
        _buildPerformanceCard(
          'Lab Turnaround Time',
          '${_systemMetrics!.averageLabTurnaroundTime} days',
          'Average processing time',
          Icons.science,
          const Color(0xFF8B5CF6),
        ),
        _buildPerformanceCard(
          'Pharmacy Fulfillment',
          '${_systemMetrics!.averagePharmacyFulfillmentTime} hours',
          'Average delivery time',
          Icons.local_shipping,
          const Color(0xFF10B981),
        ),
        _buildPerformanceCard(
          'Prescription Compliance',
          '${_systemMetrics!.prescriptionComplianceRate}%',
          'Following clinical guidelines',
          Icons.check_circle,
          const Color(0xFF3B82F6),
        ),
      ],
    );
  }

  Widget _buildQualityMetricsTab() {
    if (_systemMetrics == null) return const SizedBox();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Quality Indicators',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 16),
        _buildMetricDetailCard(
          'Documentation Completeness',
          _systemMetrics!.documentationCompleteness,
          'Measures completeness of patient history, examination findings, diagnosis, and treatment plan documentation.',
          [
            'Chief complaint recorded',
            'History of present illness documented',
            'Physical examination findings noted',
            'Diagnosis with ICD code',
            'Treatment plan specified',
          ],
        ),
        _buildMetricDetailCard(
          'Clinical Reasoning',
          _systemMetrics!.clinicalReasoningScore,
          'Evaluates the logical connection between symptoms, examination findings, and diagnosis.',
          [
            'Diagnosis matches symptoms',
            'ICD code provided',
            'Differential diagnosis considered',
            'Examination supports diagnosis',
          ],
        ),
        _buildMetricDetailCard(
          'Prescription Appropriateness',
          _systemMetrics!.prescriptionAppropriatenessScore,
          'Assesses prescription safety, documentation, and adherence to clinical guidelines.',
          [
            'Clinical justification documented',
            'Allergy check performed',
            'Drug interaction screening',
            'Proper dosage instructions',
            'Duration specified',
          ],
        ),
        _buildMetricDetailCard(
          'Follow-up Planning',
          _systemMetrics!.followUpPlanScore,
          'Ensures appropriate follow-up care is planned, especially for chronic conditions and lab tests.',
          [
            'Follow-up scheduled for chronic conditions',
            'Lab test review plan documented',
            'Patient education provided',
            'Next steps clearly communicated',
          ],
        ),
      ],
    );
  }

  Widget _buildFlaggedReviewsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFD97706)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_systemMetrics?.consultationsFlaggedForReview ?? 0} consultations require quality review',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF92400E),
                    fontFamily: 'Gilroy-Medium',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Recent Flagged Consultations',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 16),
        _buildFlaggedConsultationCard(
          'Consultation #12847',
          'Dr. Sarah Johnson',
          'Missing vital signs',
          'Medium',
          const Color(0xFFF59E0B),
        ),
        _buildFlaggedConsultationCard(
          'Consultation #12839',
          'Dr. Mike Chen',
          'Incomplete documentation',
          'High',
          const Color(0xFFEF4444),
        ),
        _buildFlaggedConsultationCard(
          'Consultation #12831',
          'Dr. Emily Davis',
          'Missing follow-up plan',
          'High',
          const Color(0xFFEF4444),
        ),
      ],
    );
  }

  Widget _buildQualityScoreCard(String label, int score, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '$score%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
              fontFamily: 'Gilroy-Bold',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(String label, String value, String subtitle, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
              fontFamily: 'Gilroy-Bold',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDetailCard(String title, int score, String description, List<String> criteria) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryColor.withValues(alpha: 0.05),
                  AppColors.primaryColor.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Gilroy-Bold',
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getScoreColor(score).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$score%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _getScoreColor(score),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Evaluation Criteria:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                ...criteria.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlaggedConsultationCard(String consultationId, String doctor, String issue, String severity, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.flag, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      consultationId,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      doctor,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  severity,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    issue,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
                side: const BorderSide(color: AppColors.primaryColor),
              ),
              child: const Text('Review Consultation'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return const Color(0xFF10B981);
    if (score >= 75) return const Color(0xFF3B82F6);
    if (score >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}
