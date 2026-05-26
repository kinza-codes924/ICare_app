import 'package:flutter/material.dart';
import 'package:icare/services/instructor_service.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class InstructorEarningsScreen extends StatefulWidget {
  const InstructorEarningsScreen({super.key});

  @override
  State<InstructorEarningsScreen> createState() =>
      _InstructorEarningsScreenState();
}

class _InstructorEarningsScreenState extends State<InstructorEarningsScreen> {
  final InstructorService _instructorService = InstructorService();
  bool _isLoading = true;
  Map<String, dynamic> _summary = {};
  List<dynamic> _payouts = [];

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _instructorService.getEarningsSummary();
      final payouts = await _instructorService.getPayoutHistory();
      if (mounted) {
        setState(() {
          _summary = summary;
          _payouts = payouts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Earnings & Payouts',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEarnings,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWalletCard(),
                    const SizedBox(height: 32),
                    const Text(
                      'Payout History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _payouts.isEmpty
                        ? _buildEmptyPayouts()
                        : _buildPayoutsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWalletCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AVAILABLE BALANCE',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'PKR ${_summary['availableBalance'] ?? '0.00'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildMiniStat(
                'Lifetime',
                'PKR ${_summary['lifetimeEarnings'] ?? '0.00'}',
              ),
              const SizedBox(width: 40),
              _buildMiniStat(
                'This Month',
                'PKR ${_summary['monthlyEarnings'] ?? '0.00'}',
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payout request submitted!')),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Withdraw Funds',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPayoutsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _payouts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final payout = _payouts[index];
        final date = DateTime.parse(
          payout['date'] ?? DateTime.now().toIso8601String(),
        );
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payout to Bank',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy').format(date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'PKR ${payout['amount']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    payout['status'] ?? 'Completed',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyPayouts() {
    return const Center(
      child: Text(
        'No payout history found.',
        style: TextStyle(color: Color(0xFF64748B)),
      ),
    );
  }
}
