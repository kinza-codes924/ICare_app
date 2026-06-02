import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lab_result.dart';
import '../widgets/back_button.dart';
import '../providers/auth_provider.dart';
import '../services/laboratory_service.dart';
import 'lab_result_entry_screen.dart';
import '../widgets/rating_dialog.dart';

class LabBookingDetails extends ConsumerWidget {
  final Map<String, dynamic> booking;

  const LabBookingDetails({super.key, required this.booking});

  /// Safely parse results from raw booking data — handles null, wrong types,
  /// and legacy formats without throwing.
  List<LabResult> _parseResults(dynamic raw) {
    try {
      if (raw == null || raw is! List) return [];
      return raw.map((r) {
        try {
          if (r is! Map) return null;
          return LabResult.fromJson(Map<String, dynamic>.from(r));
        } catch (_) {
          return null;
        }
      }).whereType<LabResult>().toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawRole = ref.watch(authProvider).userRole;
    // Normalize: backend stores 'lab' → frontend normalizes to 'Lab', but
    // some paths produce 'Laboratory'. Accept both.
    final isLab = rawRole.toLowerCase() == 'lab' ||
        rawRole.toLowerCase() == 'laboratory';

    final status =
        (booking['status'] ?? 'pending').toString().replaceAll('-', '_');

    // Support all field name variants
    final testName = booking['test_type']?.toString() ??
        booking['testType']?.toString() ??
        booking['testName']?.toString() ??
        booking['name']?.toString() ??
        'Test';

    final dateStr = booking['test_date']?.toString() ??
        booking['testDate']?.toString() ??
        booking['date']?.toString() ??
        booking['createdAt']?.toString() ??
        '';
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();

    // Patient name — try all possible fields
    String patientName = 'Unknown Patient';
    try {
      patientName = booking['patient_name']?.toString() ??
          booking['patientName']?.toString() ??
          (booking['patient'] is Map
              ? (booking['patient']['name']?.toString() ??
                  booking['patient']['username']?.toString())
              : null) ??
          'Unknown Patient';
    } catch (_) {}

    final results = _parseResults(booking['results']);
    final hasCriticalAlert = booking['criticalAlert'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          'Lab Booking Details',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Gilroy-Bold',
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasCriticalAlert) _buildCriticalAlert(),
            _buildInfoCard(testName, status, date, patientName, isLab, context),
            const SizedBox(height: 24),
            if (isLab) _buildActionButtons(context, status),
            if (!isLab && status.toLowerCase() == 'completed')
              _buildRateLabButton(context),
            const SizedBox(height: 24),
            if (results.isNotEmpty) _buildResultsSection(results),
          ],
        ),
      ),
    );
  }

  Widget _buildRateLabButton(BuildContext context) {
    final labService = LaboratoryService();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => showRatingDialog(
            context: context,
            title: 'Rate Your Lab Experience',
            subtitle: 'How was your experience with this test?',
            onSubmit: (rating, satisfied, comment) async {
              await labService.rateBooking(
                bookingId: booking['_id'],
                rating: rating,
                comment: comment,
              );
            },
          ),
          icon: const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
          label: const Text(
            'Rate this Lab',
            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFF59E0B)),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Color(0xFFF59E0B)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildCriticalAlert() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300, width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CRITICAL ALERT',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This test contains critical values requiring immediate attention',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String testName,
    String status,
    DateTime date,
    String patientName,
    bool isLab,
    BuildContext context,
  ) {
    final labName = booking['lab']?['name']?.toString() ??
        booking['labName']?.toString() ??
        booking['laboratory']?['name']?.toString() ??
        '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  testName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          if (labName.isNotEmpty) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: isLab ? null : () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B2D6E).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF0B2D6E), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Text(labName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        ]),
                        const SizedBox(height: 12),
                        const Text('Laboratory', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                        const SizedBox(height: 16),
                        if ((booking['lab']?['address'] ?? booking['labAddress'] ?? '').toString().isNotEmpty)
                          Row(children: [
                            const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(booking['lab']?['address'] ?? booking['labAddress'] ?? '', style: const TextStyle(fontSize: 13)),
                          ]),
                        if ((booking['lab']?['phone'] ?? booking['labPhone'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(children: [
                              const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(booking['lab']?['phone'] ?? booking['labPhone'] ?? '', style: const TextStyle(fontSize: 13)),
                            ]),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_hospital_rounded, size: 14, color: Color(0xFF0B2D6E)),
                  const SizedBox(width: 4),
                  Text(
                    labName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isLab ? const Color(0xFF64748B) : const Color(0xFF0B2D6E),
                      decoration: isLab ? null : TextDecoration.underline,
                    ),
                  ),
                  if (!isLab) ...[
                    const SizedBox(width: 2),
                    const Icon(Icons.open_in_new_rounded, size: 12, color: Color(0xFF0B2D6E)),
                  ],
                ],
              ),
            ),
          ],
          const Divider(height: 24),
          if ((booking['doctor']?['name'] ?? booking['orderedBy'] ?? '').toString().isNotEmpty)
            _buildInfoRow(
              Icons.medical_services_rounded,
              'Ordered By',
              'Dr. ${booking['doctor']?['name'] ?? booking['orderedBy'] ?? 'N/A'}',
            ),
          _buildInfoRow(
            Icons.person_rounded,
            'Patient Name',
            patientName,
          ),
          _buildInfoRow(
            Icons.calendar_today_rounded,
            'Test Prescription Date',
            DateFormat('MMM dd, yyyy').format(date),
          ),
          if ((booking['referredBy'] ?? booking['referred_by'] ?? '').toString().isNotEmpty)
            _buildInfoRow(
              Icons.medical_services_rounded,
              'Referred By',
              'Dr. ${booking['referredBy'] ?? booking['referred_by'] ?? 'N/A'}',
            ),
          _buildInfoRow(
            Icons.location_on_rounded,
            'Collection Type',
            (booking['collectionType'] ?? booking['collection_type'] ?? booking['type'] ?? 'In-Lab').toString().replaceAll('in-house', 'In-Lab').replaceAll('in-lab', 'In-Lab').replaceAll('home', 'Home Collection'),
          ),
          if ((booking['doctorNotes'] ?? booking['doctor_notes'] ?? booking['notes'] ?? '').toString().isNotEmpty)
            _buildInfoRow(
              Icons.notes_rounded,
              "Doctor's Notes",
              booking['doctorNotes'] ?? booking['doctor_notes'] ?? booking['notes'] ?? '',
            ),
          if ((booking['sampleCollectedBy'] ?? '').toString().isNotEmpty)
            _buildInfoRow(
              Icons.person_outline_rounded,
              'Sample Collected By',
              booking['sampleCollectedBy'] ?? 'N/A',
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData? icon, String label, String value, {String? customIconPath}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (customIconPath != null)
            Image.asset(customIconPath, width: 18, height: 18, color: const Color(0xFF64748B))
          else if (icon != null)
            Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final label = _statusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase().replaceAll('-', '_')) {
      case 'pending': return 'PENDING';
      case 'confirmed': return 'ACCEPTED';
      case 'sample_collected': return 'SAMPLE COLLECTED';
      case 'awaiting_reports': return 'AWAITING REPORTS';
      case 'reporting_done': return 'REPORTING DONE';
      case 'completed': return 'COMPLETED';
      case 'cancelled': return 'CANCELLED';
      case 'declined': return 'DECLINED';
      default: return status.toUpperCase().replaceAll('_', ' ');
    }
  }

  Widget _buildResultsSection(List<LabResult> results) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Test Results',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          ...results.map((result) => _buildResultItem(result)),
        ],
      ),
    );
  }

  Widget _buildResultItem(LabResult result) {
    final severityColor = _getSeverityColor(result.severity);
    final severityIcon = _getSeverityIcon(result.severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: severityColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.isAbnormal ? severityColor : const Color(0xFFE2E8F0),
          width: result.isAbnormal ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(severityIcon, color: severityColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.testParameter,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (result.isAbnormal)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: severityColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    result.severity.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Value',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${result.value} ${result.unit}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: result.isAbnormal
                          ? severityColor
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (result.referenceRange != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Reference Range',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.referenceRange!.displayText} ${result.unit}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'abnormal':
        return Colors.orange;
      case 'borderline':
        return Colors.yellow.shade700;
      case 'normal':
      default:
        return Colors.green;
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Icons.error_rounded;
      case 'abnormal':
        return Icons.warning_rounded;
      case 'borderline':
        return Icons.info_rounded;
      case 'normal':
      default:
        return Icons.check_circle_rounded;
    }
  }

  Widget _buildActionButtons(BuildContext context, String currentStatus) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Management Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 16),
        if (currentStatus.toLowerCase() == 'pending' || currentStatus.toLowerCase() == 'new request')
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  'Accept',
                  Icons.check_circle_outline_rounded,
                  Colors.green,
                  () => _updateStatus(context, 'accepted'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  'Decline',
                  Icons.cancel_outlined,
                  Colors.red,
                  () => _updateStatus(context, 'declined'),
                ),
              ),
            ],
          ),
        if (currentStatus.toLowerCase() == 'accepted' || currentStatus.toLowerCase() == 'confirmed')
          _buildActionButton(
            context,
            'Mark Sample Collected',
            Icons.science_rounded,
            Colors.orange,
            () => _updateStatus(context, 'sample_collected'),
          ),
        if (currentStatus.toLowerCase() == 'sample_collected' || 
            currentStatus.toLowerCase() == 'sample-collected' ||
            currentStatus.toLowerCase() == 'sample collected')
          _buildActionButton(
            context,
            'Enter Results',
            Icons.biotech_rounded,
            const Color(0xFF8B5CF6),
            () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => LabResultEntryScreen(booking: booking),
                ),
              );
              if (result == true && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        if (currentStatus.toLowerCase() == 'awaiting_reports' || 
            currentStatus.toLowerCase() == 'awaiting-reports' ||
            currentStatus.toLowerCase() == 'awaiting reports')
          _buildActionButton(
            context,
            'Mark Reporting Done',
            Icons.done_all_rounded,
            Colors.green,
            () => _updateStatus(context, 'reporting_done'),
          ),
        // reporting_done → Mark Completed
        if (currentStatus.toLowerCase() == 'reporting_done' ||
            currentStatus.toLowerCase() == 'reporting-done')
          _buildActionButton(
            context,
            'Mark as Completed',
            Icons.check_circle_rounded,
            Colors.green,
            () => _updateStatus(context, 'completed'),
          ),
        // completed — show re-enter results option
        if (currentStatus.toLowerCase() == 'completed')
          _buildActionButton(
            context,
            'View / Update Results',
            Icons.biotech_rounded,
            const Color(0xFF8B5CF6),
            () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => LabResultEntryScreen(booking: booking),
                ),
              );
            },
          ),
        // Cancel button for non-terminal statuses
        if (!['completed', 'cancelled', 'declined', 'reporting_done'].contains(currentStatus.toLowerCase()))
          _buildActionButton(
            context,
            'Cancel Booking',
            Icons.cancel_outlined,
            Colors.red,
            () => _updateStatus(context, 'cancelled'),
          ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    // Cancellation / decline requires a mandatory reason
    if (newStatus == 'cancelled' || newStatus == 'declined') {
      final reasonController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            newStatus == 'declined' ? 'Decline Booking' : 'Cancel Booking',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please provide a reason (required):',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter reason...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Reason is required to cancel/decline')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(newStatus == 'declined' ? 'Decline' : 'Cancel Booking'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      final labService = LaboratoryService();
      await labService.updateBookingStatus(booking['_id'], newStatus);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $newStatus')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Something went wrong. Please try again.')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase().replaceAll('_', '-')) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'sample-collected':
        return Colors.indigo;
      case 'awaiting-reports':
        return const Color(0xFF8B5CF6);
      case 'reporting-done':
        return const Color(0xFF10B981);
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'declined':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
