import 'package:flutter/material.dart';
import 'package:icare/models/referral.dart';
import 'package:icare/services/referral_service.dart';
import 'package:icare/screens/create_referral_screen.dart';
import 'package:icare/screens/referral_detail_screen.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class DoctorReferralsListScreen extends StatefulWidget {
  const DoctorReferralsListScreen({super.key});

  @override
  State<DoctorReferralsListScreen> createState() =>
      _DoctorReferralsListScreenState();
}

class _DoctorReferralsListScreenState extends State<DoctorReferralsListScreen>
    with SingleTickerProviderStateMixin {
  final ReferralService _referralService = ReferralService();
  late TabController _tabController;

  List<Referral> _sentReferrals = [];
  List<Referral> _receivedReferrals = [];
  bool _isLoadingSent = true;
  bool _isLoadingReceived = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReferrals();
  }

  Future<void> _loadReferrals() async {
    setState(() {
      _isLoadingSent = true;
      _isLoadingReceived = true;
    });

    // Load sent referrals
    final sentResult = await _referralService.getMyReferrals();
    if (sentResult['success']) {
      setState(() {
        _sentReferrals = sentResult['referrals'];
        _isLoadingSent = false;
      });
    } else {
      setState(() => _isLoadingSent = false);
    }

    // Load received referrals
    final receivedResult = await _referralService.getReceivedReferrals();
    if (receivedResult['success']) {
      setState(() {
        _receivedReferrals = receivedResult['referrals'];
        _isLoadingReceived = false;
      });
    } else {
      setState(() => _isLoadingReceived = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Referrals',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Gilroy-Bold',
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primaryColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Sent'),
                  if (_sentReferrals.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_sentReferrals.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Received'),
                  if (_receivedReferrals.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_receivedReferrals.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSentReferralsTab(), _buildReceivedReferralsTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateReferralScreen(
                patient: null, // Will need to select patient
              ),
            ),
          );
          if (result == true) {
            _loadReferrals();
          }
        },
        backgroundColor: AppColors.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('New Referral'),
      ),
    );
  }

  Widget _buildSentReferralsTab() {
    if (_isLoadingSent) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sentReferrals.isEmpty) {
      return _buildEmptyState(
        icon: Icons.send_outlined,
        title: 'No Sent Referrals',
        message: 'You haven\'t sent any referrals yet',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReferrals,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sentReferrals.length,
        itemBuilder: (context, index) {
          return _buildReferralCard(_sentReferrals[index], isSent: true);
        },
      ),
    );
  }

  Widget _buildReceivedReferralsTab() {
    if (_isLoadingReceived) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_receivedReferrals.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inbox_outlined,
        title: 'No Received Referrals',
        message: 'You haven\'t received any referrals yet',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReferrals,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _receivedReferrals.length,
        itemBuilder: (context, index) {
          return _buildReferralCard(_receivedReferrals[index], isSent: false);
        },
      ),
    );
  }

  Widget _buildReferralCard(Referral referral, {required bool isSent}) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (referral.status) {
      case ReferralStatus.pending:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.schedule;
        statusText = 'Pending';
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ReferralDetailScreen(referral: referral, isSent: isSent),
              ),
            );
            if (result == true) {
              _loadReferrals();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person,
                          size: 24,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient ID: ${referral.patientId}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isSent
                                ? 'To: ${referral.specialistDoctorId ?? "Specialist"}'
                                : 'From: ${referral.referringDoctorId}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
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
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                            ),
                          ),
                        ],
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reason',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        referral.reasonForReferral,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM dd, yyyy').format(referral.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    if (referral.status == 'pending' && !isSent)
                      const Text(
                        'Action Required',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
