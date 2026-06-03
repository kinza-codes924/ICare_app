import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/services/laboratory_service.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/screens/lab_booking_details.dart';
import 'package:intl/intl.dart';
import 'package:icare/utils/error_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class PatientLabOrdersScreen extends ConsumerStatefulWidget {
  const PatientLabOrdersScreen({super.key});

  @override
  ConsumerState<PatientLabOrdersScreen> createState() => _PatientLabOrdersScreenState();
}

class _PatientLabOrdersScreenState extends ConsumerState<PatientLabOrdersScreen> {
  final LaboratoryService _labService = LaboratoryService();
  List<dynamic> _labOrders = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _ratedBookings = {};

  @override
  void initState() {
    super.initState();
    _fetchLabOrders();
  }

  Future<void> _fetchLabOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orders = await _labService.getMyBookings();
      setState(() {
        _labOrders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = ErrorHandler.getFriendlyMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _showLabComplaintDialog(dynamic order) async {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String category = 'Delayed Results';
    bool sending = false;
    final bookingNumber = order['bookingNumber'] ?? order['_id'] ?? 'N/A';
    final labName = order['laboratory']?['labName'] ?? 'Laboratory';
    final testName = order['testName'] ?? 'Lab Test';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.report_problem_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 10),
            Text('Register Complaint', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          content: SingleChildScrollView(
            child: SizedBox(
              width: double.maxFinite,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Booking: #$bookingNumber • $testName', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 16),
                const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: ['Delayed Results', 'Wrong Test', 'Poor Service', 'Report Error', 'Other']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setSt(() => category = v ?? category),
                ),
                const SizedBox(height: 12),
                const Text('Subject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: subjectCtrl,
                  decoration: InputDecoration(
                    hintText: 'Brief subject of complaint',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: messageCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Describe your complaint in detail...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: sending ? null : () async {
                if (subjectCtrl.text.trim().isEmpty || messageCtrl.text.trim().isEmpty) return;
                setSt(() => sending = true);
                final user = ref.read(authProvider).user;
                final body = '''
Complaint Category: $category
Booking Number: #$bookingNumber
Test Name: $testName
Lab: $labName

Patient Details:
Name: ${user?.name ?? 'N/A'}
Email: ${user?.email ?? 'N/A'}
Phone: ${user?.phoneNumber ?? 'N/A'}
User ID: ${user?.id ?? 'N/A'}

Subject: ${subjectCtrl.text.trim()}

Message:
${messageCtrl.text.trim()}
''';
                final mailUri = Uri(
                  scheme: 'mailto',
                  path: 'icareofficialapp@gmail.com',
                  queryParameters: {
                    'subject': '[Lab Complaint] $category - Booking #$bookingNumber',
                    'body': body,
                  },
                );
                if (ctx.mounted) Navigator.pop(ctx);
                await launchUrl(mailUri, mode: LaunchMode.externalApplication);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Complaint submitted. Our team will respond within 24 hours.'), backgroundColor: Color(0xFF10B981)),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Submit Complaint'),
            ),
          ],
        ),
      ),
    );
    subjectCtrl.dispose();
    messageCtrl.dispose();
  }

  Future<void> _showRateLabDialog(dynamic order) async {
    double rating = 0;
    final commentCtrl = TextEditingController();
    bool submitting = false;
    final bookingId = order['_id']?.toString() ?? '';
    final labName = order['laboratory']?['labName'] ?? 'Laboratory';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 22),
            SizedBox(width: 10),
            Text('Rate Laboratory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          content: SizedBox(
            width: 340,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('How was your experience with $labName?', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => GestureDetector(
                onTap: () => setSt(() => rating = i + 1.0),
                child: Icon(rating > i ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFF59E0B), size: 40),
              ))),
              const SizedBox(height: 16),
              TextField(
                controller: commentCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Leave a comment (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Skip')),
            ElevatedButton(
              onPressed: (submitting || rating == 0) ? null : () async {
                setSt(() => submitting = true);
                try {
                  await _labService.submitBookingRating(bookingId, rating.toInt(), commentCtrl.text.trim());
                  setState(() => _ratedBookings.add(bookingId));
                } catch (_) {}
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thank you for your rating!'), backgroundColor: Color(0xFF10B981)),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Submit Rating'),
            ),
          ],
        ),
      ),
    );
    commentCtrl.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'confirmed':
        return const Color(0xFF3B82F6);
      case 'completed':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'confirmed':
        return Icons.check_circle_outline_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline_rounded;
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
          'My Lab Tests'.tr(),
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
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 16),
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchLabOrders,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _labOrders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.biotech_rounded,
                      size: 64,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No Lab Tests Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your doctor will order lab tests when needed',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchLabOrders,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _labOrders.length,
                itemBuilder: (context, index) {
                  final order = _labOrders[index];
                  return _buildLabOrderCard(order);
                },
              ),
            ),
    );
  }

  Widget _buildLabOrderCard(dynamic order) {
    final status = order['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final rawTestName = (order['testName'] ?? 'Lab Test').toString();
    // Truncate very long test names (multiple tests comma-separated)
    final testParts = rawTestName.split(',');
    final testName = testParts.length > 2
        ? '${testParts[0].trim()}, ${testParts[1].trim()} +${testParts.length - 2} more'
        : rawTestName;
    final bookingNumber = order['bookingNumber'] ?? 'N/A';
    final labName = order['laboratory']?['labName'] ?? 'Laboratory';
    final labCity = order['laboratory']?['city'] ?? '';
    DateTime? parsedDate;
    try {
      if (order['date'] != null) {
        parsedDate = DateTime.parse(order['date'].toString().replaceAll('/', '-'));
      }
    } catch (_) {}
    final date = parsedDate != null
        ? DateFormat('MMM dd, yyyy').format(parsedDate)
        : 'Not scheduled';
    final hasReport =
        order['reportUrl'] != null && order['reportUrl'].toString().isNotEmpty;
    final isAbnormal = order['isAbnormal'] == true;
    final isCritical = order['criticalAlert'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCritical
              ? const Color(0xFFEF4444)
              : isAbnormal
              ? const Color(0xFFF59E0B)
              : const Color(0xFFE2E8F0),
          width: isCritical ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Booking #$bookingNumber',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Critical/Abnormal Alert
          if (isCritical || isAbnormal)
            Container(
              padding: const EdgeInsets.all(12),
              color: isCritical
                  ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(
                    isCritical ? Icons.warning_rounded : Icons.info_rounded,
                    color: isCritical
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFF59E0B),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCritical
                          ? 'CRITICAL: Abnormal results detected - Contact your doctor immediately'
                          : 'Some results are outside normal range',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isCritical
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Laboratory Info
                Row(
                  children: [
                    const Icon(
                      Icons.local_hospital_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$labName${labCity.isNotEmpty ? ' • $labCity' : ''}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Date
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),

                // Report Status
                if (hasReport) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Report Available',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Navigate to lab booking details
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    LabBookingDetails(booking: order),
                              ),
                            );
                          },
                          child: const Text('View Report'),
                        ),
                      ],
                    ),
                  ),
                ],
                // Rating & Complaint buttons for completed orders
                if (status.toLowerCase() == 'completed') ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    if (!_ratedBookings.contains(order['_id']?.toString() ?? ''))
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRateLabDialog(order),
                          icon: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                          label: const Text('Rate Lab', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB45309),
                            side: const BorderSide(color: Color(0xFFF59E0B)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    if (!_ratedBookings.contains(order['_id']?.toString() ?? ''))
                      const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showLabComplaintDialog(order),
                        icon: const Icon(Icons.report_problem_rounded, size: 16, color: Color(0xFFEF4444)),
                        label: const Text('Complaint', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
