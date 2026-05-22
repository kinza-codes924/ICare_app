import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/models/referral.dart';
import 'package:icare/utils/theme.dart';
import 'package:intl/intl.dart';

/// Referral Management Screen
///
/// For specialists to manage incoming referrals from GPs
/// Workflow: GP creates referral → Specialist accepts/rejects → Appointment scheduled
class ReferralManagementScreen extends ConsumerStatefulWidget {
  const ReferralManagementScreen({super.key});

  @override
  ConsumerState<ReferralManagementScreen> createState() => _ReferralManagementScreenState();
}

class _ReferralManagementScreenState extends ConsumerState<ReferralManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  final List<Referral> _pendingReferrals = [];
  final List<Referral> _acceptedReferrals = [];
  final List<Referral> _completedReferrals = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReferrals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReferrals() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    // In real implementation, fetch from backend
    setState(() => _isLoading = false);
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
              'Referral Management',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Gilroy-Bold',
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'Manage incoming patient referrals',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                fontFamily: 'Gilroy-Medium',
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadReferrals,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryColor),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: Colors.white,
                child: Row(
                  children: [
                    _buildStatChip('Pending', _pendingReferrals.length, const Color(0xFFF59E0B)),
                    const SizedBox(width: 12),
                    _buildStatChip('Accepted', _acceptedReferrals.length, const Color(0xFF3B82F6)),
                    const SizedBox(width: 12),
                    _buildStatChip('Completed', _completedReferrals.length, const Color(0xFF10B981)),
                  ],
                ),
              ),
              Container(
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
                    Tab(text: 'PENDING'),
                    Tab(text: 'ACCEPTED'),
                    Tab(text: 'COMPLETED'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingList(),
                _buildAcceptedList(),
                _buildCompletedList(),
              ],
            ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color, fontFamily: 'Gilroy-Bold'),
            ),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingList() {
    if (_pendingReferrals.isEmpty) {
      return _buildEmptyState('No pending referrals', Icons.inbox_rounded);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _pendingReferrals.length,
      itemBuilder: (ctx, i) => _buildPendingReferralCard(_pendingReferrals[i]),
    );
  }

  Widget _buildAcceptedList() {
    if (_acceptedReferrals.isEmpty) {
      return _buildEmptyState('No accepted referrals', Icons.check_circle_outline);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _acceptedReferrals.length,
      itemBuilder: (ctx, i) => _buildAcceptedReferralCard(_acceptedReferrals[i]),
    );
  }

  Widget _buildCompletedList() {
    if (_completedReferrals.isEmpty) {
      return _buildEmptyState('No completed referrals', Icons.done_all);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _completedReferrals.length,
      itemBuilder: (ctx, i) => _buildCompletedReferralCard(_completedReferrals[i]),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: AppColors.primaryColor.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildPendingReferralCard(Referral referral) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFEF3C7), width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFF59E0B).withValues(alpha: 0.1), const Color(0xFFF59E0B).withValues(alpha: 0.05)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_add, color: Color(0xFFF59E0B), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient ID: ${referral.patientId.substring(0, 8)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Gilroy-Bold'),
                          ),
                          Text(
                            'Referred by Dr. ${referral.referringDoctorId.substring(0, 8)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getUrgencyColor(referral.urgency).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        referral.urgency.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _getUrgencyColor(referral.urgency),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.medical_services, 'Specialty', referral.specialtyRequired),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.assignment, 'Reason', referral.reasonForReferral),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    referral.clinicalSummary,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectReferral(referral),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => _acceptReferral(referral),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Accept Referral'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedReferralCard(Referral referral) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF3B82F6), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Patient ID: ${referral.patientId.substring(0, 8)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _scheduleAppointment(referral),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Schedule Appointment'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedReferralCard(Referral referral) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD1FAE5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.done_all, color: Color(0xFF10B981), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Patient ID: ${referral.patientId.substring(0, 8)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            'Completed ${DateFormat('MMM dd').format(referral.completedAt!)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)))),
      ],
    );
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'urgent':
        return const Color(0xFFEF4444);
      case 'routine':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  void _acceptReferral(Referral referral) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral accepted'), backgroundColor: Color(0xFF10B981)),
    );
  }

  void _rejectReferral(Referral referral) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral rejected'), backgroundColor: Color(0xFFEF4444)),
    );
  }

  void _scheduleAppointment(Referral referral) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Schedule appointment')),
    );
  }
}
