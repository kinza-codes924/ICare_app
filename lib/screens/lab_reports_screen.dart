import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icare/services/laboratory_service.dart';
import 'package:icare/services/medical_record_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

const Color primaryColor = Color(0xFF0B2D6E);
const Color secondaryColor = Color(0xFF1565C0);
const Color accentColor = Color(0xFF0EA5E9);

class LabReportsScreen extends StatefulWidget {
  const LabReportsScreen({super.key});

  @override
  State<LabReportsScreen> createState() => _LabReportsScreenState();
}

class _LabReportsScreenState extends State<LabReportsScreen>
    with SingleTickerProviderStateMixin {
  final LaboratoryService _labService = LaboratoryService();
  final MedicalRecordService _medService = MedicalRecordService();
  bool _isLoading = true;
  List<dynamic> _completedBookings = [];
  List<dynamic> _advisedPrescriptions = []; // prescriptions with lab tests
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _searchFilter = 'patient'; // patient, mr_number, doctor, contact

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final role = (await SharedPref().getUserRole())?.toLowerCase();
      final userData = await SharedPref().getUserData();
      final patientId = userData?.id ?? '';

      List<dynamic> bookings = [];

      if (role == 'patient' || role == 'student') {
        bookings = await _labService.getMyBookings();
      } else if (role == 'laboratory' || role == 'lab_technician') {
        final profile = await _labService.getProfile();
        final labId = profile['_id'];
        if (labId == null) throw 'Laboratory profile ID not found';
        bookings = await _labService.getBookings(labId);
      } else {
        bookings = await _labService.getMyBookings();
      }

      // For patients/students: also fetch prescriptions with lab tests
      List<dynamic> advised = [];
      if ((role == 'patient' || role == 'student') && patientId.isNotEmpty) {
        try {
          final medResult = await _medService.getMyRecords();
          if (medResult['success'] == true) {
            final records = medResult['records'] as List<dynamic>;
            advised = records.where((r) {
              final labTests = (r['labTests'] as List?) ??
                  (r['prescription'] is Map ? (r['prescription']['labTests'] as List?) : null) ?? [];
              return labTests.isNotEmpty;
            }).toList();
          }
        } catch (_) {}
      }

      setState(() {
        _completedBookings = List<dynamic>.from(bookings);
        _advisedPrescriptions = advised;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading lab reports: $e');
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> _filterBookings(List<dynamic> bookings) {
    if (_searchQuery.isEmpty) return bookings;

    return bookings.where((booking) {
      final query = _searchQuery.toLowerCase();
      switch (_searchFilter) {
        case 'patient':
          final name = (booking['patientName'] ?? booking['patient_name'] ?? booking['patient']?['name'] ?? booking['contactName'] ?? '').toString().toLowerCase();
          return name.contains(query);
        case 'mr_number':
          final mr = (booking['mrNumber'] ?? booking['mr_number'] ?? booking['patient']?['mrNumber'] ?? '').toString().toLowerCase();
          return mr.contains(query);
        case 'doctor':
          final doc = (booking['referredBy'] ?? booking['referred_by'] ?? booking['doctor']?['name'] ?? '').toString().toLowerCase();
          return doc.contains(query);
        case 'contact':
          final contact = (booking['contact'] ?? booking['patient_phone'] ?? booking['patient']?['contact'] ?? '').toString().toLowerCase();
          return contact.contains(query);
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 700;
    bool isDone(dynamic b) {
      final s = (b['status'] ?? '').toString();
      return s == 'completed' || s == 'reporting_done' || s == 'reporting-done';
    }

    final completed = _filterBookings(_completedBookings.where(isDone).toList());
    final pending = _filterBookings(_completedBookings
        .where((b) => !isDone(b) && b['status'] != 'cancelled')
        .toList());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        automaticallyImplyLeading: false,
        title: const Text(
          'Records',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Gilroy-Bold',
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _fetchReports,
            icon: Icon(Icons.refresh_rounded, color: primaryColor),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: primaryColor,
                  labelColor: primaryColor,
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                  tabs: [
                    Tab(text: 'COMPLETED (${completed.length})'),
                    Tab(text: 'PENDING (${pending.length})'),
                    Tab(text: 'ADVISED (${_advisedPrescriptions.length})'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 900 : double.infinity,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() => _searchQuery = value);
                              },
                              decoration: InputDecoration(
                                hintText: 'Search records...',
                                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 20),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: primaryColor, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButton<String>(
                              value: _searchFilter,
                              underline: const SizedBox(),
                              icon: const Icon(Icons.arrow_drop_down_rounded, color: primaryColor),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'patient', child: Text('Patient Name')),
                                DropdownMenuItem(value: 'mr_number', child: Text('MR Number')),
                                DropdownMenuItem(value: 'doctor', child: Text('Doctor Name')),
                                DropdownMenuItem(value: 'contact', child: Text('Contact Number')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _searchFilter = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 900 : double.infinity,
                      ),
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildReportList(
                            completed,
                            showResults: true,
                            isDesktop: isDesktop,
                          ),
                          _buildReportList(
                            pending,
                            showResults: false,
                            isDesktop: isDesktop,
                          ),
                          _buildAdvisedList(isDesktop: isDesktop),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAdvisedList({required bool isDesktop}) {
    if (_advisedPrescriptions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.biotech_outlined, size: 56, color: Color(0xFF94A3B8)),
              SizedBox(height: 16),
              Text('No advised lab tests',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              SizedBox(height: 8),
              Text('Tests your doctor has advised will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _advisedPrescriptions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final rx = _advisedPrescriptions[i] as Map<String, dynamic>;
        final doctorName = (rx['doctor']?['name'] ?? rx['doctorName'] ?? 'Doctor').toString();
        final dateStr = rx['createdAt'] != null
            ? DateFormat('MMM dd, yyyy').format(DateTime.parse(rx['createdAt'].toString()).toLocal())
            : '';
        final labTests = (rx['labTests'] as List?) ??
            (rx['prescription'] is Map ? (rx['prescription']['labTests'] as List?) : null) ?? [];
        final diagnosis = (rx['diagnosis'] ?? rx['diagnoses']?[0]?['diagnosis'] ?? '').toString();

        return GestureDetector(
          onTap: () => _showAdvisedTestsDialog(context, doctorName, dateStr, labTests, diagnosis),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDDD6FE), width: 1.5),
              boxShadow: [
                BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF8B5CF6)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doctorName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        if (dateStr.isNotEmpty)
                          Text(dateStr,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${labTests.length} test${labTests.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
                  ),
                ]),
                if (diagnosis.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Diagnosis: $diagnosis',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 10),
                ...labTests.take(3).map((t) {
                  final testName = t is Map
                      ? (t['testName'] ?? t['name'] ?? '').toString()
                      : t.toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      const Icon(Icons.biotech_rounded, size: 14, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(testName, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)))),
                    ]),
                  );
                }),
                if (labTests.length > 3)
                  Text('+${labTests.length - 3} more — tap to view all',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tableCell(String text, {bool isHeader = false, bool bold = false, bool small = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 11 : (small ? 11 : 13),
          fontWeight: (isHeader || bold) ? FontWeight.w700 : FontWeight.w400,
          color: color ?? (isHeader ? const Color(0xFF64748B) : const Color(0xFF0F172A)),
        ),
      ),
    );
  }

  void _showAdvisedTestsDialog(BuildContext context, String doctorName, String date,
      List labTests, String diagnosis) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.biotech_rounded, color: Color(0xFF8B5CF6), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Advised Lab Tests', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                      Text('$doctorName • $date', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                ),
              ]),
              if (diagnosis.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                  child: Text('Diagnosis: $diagnosis',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF065F46))),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ...labTests.map((t) {
                final testName = t is Map
                    ? (t['testName'] ?? t['name'] ?? '').toString()
                    : t.toString();
                final instructions = t is Map ? (t['instructions'] ?? '').toString() : '';
                final isUrgent = t is Map ? (t['isUrgent'] == true) : false;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDDD6FE)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.biotech_rounded, size: 16, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(testName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          if (instructions.isNotEmpty)
                            Text(instructions, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(4)),
                        child: const Text('URGENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                      ),
                  ]),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportList(
    List<dynamic> bookings, {
    required bool showResults,
    required bool isDesktop,
  }) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                showResults
                    ? Icons.receipt_long_rounded
                    : Icons.hourglass_empty_rounded,
                size: 48,
                color: primaryColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              showResults ? 'No completed tests yet' : 'No pending tests',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              showResults
                  ? 'Completed test results will appear here'
                  : 'All pending bookings will appear here',
              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isDesktop ? 28 : 16),
      itemCount: bookings.length,
      itemBuilder: (ctx, i) =>
          _buildReportCard(bookings[i], showResults: showResults),
    );
  }

  Widget _buildReportCard(dynamic booking, {required bool showResults}) {
    final testName = (booking['testName'] ?? booking['test_type'] ?? booking['testType'] ?? 'Lab Test').toString();
    final patientName = (booking['patientName'] ?? booking['patient_name'] ?? booking['contactName'] ?? '').toString();
    final mrNumber = (booking['mrNumber'] ?? booking['mr_number'] ?? '').toString();
    final referredBy = (booking['referredBy'] ?? booking['referred_by'] ?? '').toString();
    final contact = (booking['contact'] ?? booking['patient_phone'] ?? '').toString();
    final dateStr = (booking['date'] ?? booking['test_date'] ?? booking['createdAt'] ?? '').toString();
    DateTime? dateObj = DateTime.tryParse(dateStr);
    final formattedDate = dateObj != null
        ? DateFormat('dd MMM yyyy').format(dateObj)
        : '—';
    final status = (booking['status'] ?? 'pending').toString();
    final resultNotes = (booking['reportNotes'] ?? booking['report_notes'] ?? booking['resultNotes'] ?? '').toString();
    final reportUrl = (booking['reportUrl'] ?? booking['report_url'] ?? '').toString();
    final bookingNumber = (booking['bookingNumber'] ?? '#—').toString();
    final bool isAbnormal = booking['isAbnormal'] ?? booking['is_abnormal'] ?? false;
    final List<dynamic> results = (booking['results'] as List<dynamic>?) ?? [];
    final bool isDone = status == 'completed' || status == 'reporting_done' || status == 'reporting-done';

    Color statusColor;
    Color statusBg;
    IconData statusIcon;

    switch (status) {
      case 'completed':
        statusColor = const Color(0xFF10B981);
        statusBg = const Color(0xFFD1FAE5);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'confirmed':
        statusColor = const Color(0xFF3B82F6);
        statusBg = const Color(0xFFDBEAFE);
        statusIcon = Icons.schedule_rounded;
        break;
      case 'cancelled':
        statusColor = const Color(0xFFEF4444);
        statusBg = const Color(0xFFFEE2E2);
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusBg = const Color(0xFFFEF3C7);
        statusIcon = Icons.pending_actions_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withValues(alpha: 0.04),
                  secondaryColor.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.biotech_rounded,
                    color: primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            testName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (isAbnormal) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ABNORMAL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 2,
                        children: [
                          if (patientName.isNotEmpty)
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.person_rounded, size: 13, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Text(patientName, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            ]),
                          if (mrNumber.isNotEmpty)
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.badge_outlined, size: 13, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Text('MR# $mrNumber', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ]),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text(formattedDate, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                          ]),
                          if (referredBy.isNotEmpty)
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.medical_services_outlined, size: 13, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Text('Dr. $referredBy', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ]),
                          if (contact.isNotEmpty)
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Text(contact, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ]),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        status[0].toUpperCase() + status.substring(1),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Results Body ───────────────────────────────────────
          if (showResults && isDone) ...[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Booking ID chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      bookingNumber,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569), fontFamily: 'monospace'),
                    ),
                  ),

                  // Structured results table
                  if (results.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.table_chart_rounded, color: primaryColor, size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Text('Test Findings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    ]),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2.5),
                            1: FlexColumnWidth(1.5),
                            2: FlexColumnWidth(1.2),
                            3: FlexColumnWidth(2),
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                              children: [
                                _tableCell('Parameter', isHeader: true),
                                _tableCell('Value', isHeader: true),
                                _tableCell('Unit', isHeader: true),
                                _tableCell('Ref. Range', isHeader: true),
                              ],
                            ),
                            ...results.map((r) {
                              final row = r as Map<String, dynamic>;
                              final severity = (row['severity'] ?? 'normal').toString();
                              final isAbn = severity == 'abnormal' || severity == 'critical';
                              return TableRow(
                                decoration: BoxDecoration(
                                  color: isAbn ? const Color(0xFFFFF1F2) : Colors.white,
                                ),
                                children: [
                                  _tableCell(row['testParameter']?.toString() ?? '', bold: true),
                                  _tableCell(row['value']?.toString() ?? '', color: isAbn ? const Color(0xFFDC2626) : null, bold: isAbn),
                                  _tableCell(row['unit']?.toString() ?? ''),
                                  _tableCell(row['referenceRange']?.toString() ?? '', small: true),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Notes / text findings
                  if (resultNotes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.notes_rounded, color: primaryColor, size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Text('Remarks / Notes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    ]),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(resultNotes, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.6)),
                    ),
                  ],

                  // No findings warning — only if BOTH are empty and no report URL
                  if (results.isEmpty && resultNotes.isEmpty && reportUrl.isEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 16),
                        SizedBox(width: 8),
                        Expanded(child: Text('No findings entered — report document may be uploaded separately.', style: TextStyle(fontSize: 12, color: Color(0xFF92400E)))),
                      ]),
                    ),
                  ],

                  if (reportUrl.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: reportUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Report link copied to clipboard!'), backgroundColor: Color(0xFF10B981), behavior: SnackBarBehavior.floating),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy Report Link', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (!showResults) ...[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(
                    Icons.hourglass_bottom_rounded,
                    color: Color(0xFFF59E0B),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Awaiting lab results — booked for $formattedDate',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
