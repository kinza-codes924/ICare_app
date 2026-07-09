import 'package:flutter/material.dart';
import 'package:icare/models/referral.dart';
import 'package:icare/services/referral_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class ReferralDetailScreen extends StatefulWidget {
  final Referral referral;
  final bool isSent;

  const ReferralDetailScreen({
    super.key,
    required this.referral,
    required this.isSent,
  });

  @override
  State<ReferralDetailScreen> createState() => _ReferralDetailScreenState();
}

class _ReferralDetailScreenState extends State<ReferralDetailScreen> {
  final ReferralService _referralService = ReferralService();
  final _summaryController = TextEditingController();
  final _declineReasonController = TextEditingController();
  bool _isLoading = false;

  Future<void> _acceptReferral() async {
    setState(() => _isLoading = true);
    final result = await _referralService.acceptReferral(widget.referral.id);
    setState(() => _isLoading = false);

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referral accepted'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _declineReferral() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Referral'),
        content: TextField(
          controller: _declineReasonController,
          decoration: const InputDecoration(hintText: 'Reason for declining'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final result = await _referralService.declineReferral(
                widget.referral.id,
                _declineReasonController.text,
              );
              setState(() => _isLoading = false);
              if (result['success'] && mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeReferral() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Referral'),
        content: TextField(
          controller: _summaryController,
          decoration: const InputDecoration(hintText: 'Consultation summary'),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final result = await _referralService.completeReferral(
                widget.referral.id,
                _summaryController.text,
              );
              setState(() => _isLoading = false);
              if (result['success'] && mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Referral Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildPatientCard(),
            const SizedBox(height: 16),
            _buildDoctorCards(),
            const SizedBox(height: 16),
            _buildReasonCard(),
            const SizedBox(height: 16),
            _buildClinicalNotesCard(),
            if (widget.referral.specialistNotes != null) ...[
              const SizedBox(height: 16),
              _buildSpecialistNotesCard(),
            ],
            if (widget.referral.rejectionReason != null) ...[
              const SizedBox(height: 16),
              _buildDeclineReasonCard(),
            ],
            if (!widget.isSent && widget.referral.status == ReferralStatus.pending) ...[
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
            if (!widget.isSent && widget.referral.status == ReferralStatus.accepted) ...[
              const SizedBox(height: 24),
              _buildCompleteButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (widget.referral.status) {
      case ReferralStatus.pending:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.schedule;
        statusText = 'Pending Review';
        break;
      case ReferralStatus.accepted:
        statusColor = const Color(0xFF3B82F6);
        statusIcon = Icons.check_circle_outline;
        statusText = 'Accepted';
        break;
      case ReferralStatus.completed:
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        statusText = 'Completed';
        break;
      case ReferralStatus.rejected:
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel_outlined;
        statusText = 'Declined';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Created ${DateFormat('MMM dd, yyyy').format(widget.referral.createdAt)}',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard() {
    return _buildInfoCard(
      'Patient Information',
      Icons.person,
      AppColors.primaryColor,
      [
        _buildInfoRow('Patient ID', widget.referral.patientId),
      ],
    );
  }

  Widget _buildDoctorCards() {
    return Column(
      children: [
        _buildInfoCard(
          'Referring Doctor',
          Icons.medical_services,
          const Color(0xFF3B82F6),
          [
            _buildInfoRow('Doctor ID', widget.referral.referringDoctorId),
          ],
        ),
        if (widget.referral.specialistDoctorId != null) ...[
          const SizedBox(height: 16),
          _buildInfoCard(
            'Specialist',
            Icons.local_hospital,
            const Color(0xFF8B5CF6),
            [
              _buildInfoRow('Specialist ID', widget.referral.specialistDoctorId!),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildReasonCard() {
    return _buildInfoCard(
      'Reason for Referral',
      Icons.description,
      const Color(0xFFF59E0B),
      [
        Text(
          widget.referral.reasonForReferral,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildClinicalNotesCard() {
    return _buildInfoCard(
      'Clinical Summary',
      Icons.note_alt,
      const Color(0xFF10B981),
      [
        Text(
          widget.referral.clinicalSummary,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildSpecialistNotesCard() {
    return _buildInfoCard(
      'Specialist Notes',
      Icons.summarize,
      const Color(0xFF10B981),
      [
        Text(
          widget.referral.specialistNotes!,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildDeclineReasonCard() {
    return _buildInfoCard(
      'Rejection Reason',
      Icons.info_outline,
      const Color(0xFFEF4444),
      [
        Text(
          widget.referral.rejectionReason!,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : _declineReferral,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Decline'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _acceptReferral,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Accept'),
          ),
        ),
      ],
    );
  }

  Widget _buildCompleteButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _completeReferral,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text('Complete Referral'),
      ),
    );
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _declineReasonController.dispose();
    super.dispose();
  }
}
