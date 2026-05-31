import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/services/subscription_service.dart';
import 'package:icare/widgets/back_button.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  List<dynamic> _plans = [];
  Map<String, dynamic>? _mySubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final plans = await _subscriptionService.getPlans();
      final subscription = await _subscriptionService.getMySubscription();

      setState(() {
        _plans = plans;
        _mySubscription = subscription;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: const Text('Unable to load data. Please try again.')));
      }
    }
  }

  Future<void> _subscribe(String planId) async {
    try {
      final result = await _subscriptionService.subscribe(
        planId: planId,
        paymentMethod: 'Card',
        transactionId: 'TXN${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription activated successfully!'),
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Subscription failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: const Text('Something went wrong. Please try again.')));
      }
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
          'Subscriptions'.tr(),
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_mySubscription != null) ...[
                    _buildCurrentSubscription(),
                    const SizedBox(height: 32),
                  ],
                  const Text(
                    'Available Plans',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._plans.map((plan) => _buildPlanCard(plan)),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentSubscription() {
    final plan = _mySubscription!['plan'] as Map<String, dynamic>?;
    final status = _mySubscription!['status'] ?? 'active';
    final endDate = _mySubscription!['endDate'] != null
        ? DateTime.parse(_mySubscription!['endDate'])
        : null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Plan',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      plan?['name'] ?? 'Subscription',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
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
          if (endDate != null) ...[
            const SizedBox(height: 16),
            Text(
              'Valid until ${endDate.day}/${endDate.month}/${endDate.year}',
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final name = plan['name'] ?? '';
    final type = plan['type'] ?? '';
    final price = plan['price'] ?? 0;
    final duration = plan['duration'] ?? 1;
    final features = plan['features'] as List? ?? [];
    final benefits = plan['benefits'] as Map<String, dynamic>? ?? {};
    final hasActiveSubscription =
        _mySubscription != null && _mySubscription!['status'] == 'active';

    Color typeColor;
    switch (type) {
      case 'Premium':
        typeColor = const Color(0xFF8B5CF6);
        break;
      case 'Family':
        typeColor = const Color(0xFF3B82F6);
        break;
      case 'Chronic Care':
        typeColor = const Color(0xFFEF4444);
        break;
      case 'Preventive':
        typeColor = const Color(0xFF10B981);
        break;
      default:
        typeColor = const Color(0xFF64748B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: typeColor.withValues(alpha: 0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: typeColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        type,
                        style: TextStyle(
                          fontSize: 14,
                          color: typeColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'PKR $price',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: typeColor,
                      ),
                    ),
                    Text(
                      '/$duration month${duration > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Benefits:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                if (benefits['discountedConsultations'] != null &&
                    benefits['discountedConsultations'] > 0)
                  _buildBenefitItem(
                    '${benefits['discountedConsultations']}% off consultations',
                    typeColor,
                  ),
                if (benefits['freeLabTests'] != null &&
                    benefits['freeLabTests'] > 0)
                  _buildBenefitItem(
                    '${benefits['freeLabTests']} free lab tests/month',
                    typeColor,
                  ),
                if (benefits['priorityBooking'] == true)
                  _buildBenefitItem('Priority booking', typeColor),
                if (benefits['freeHealthPrograms'] != null &&
                    benefits['freeHealthPrograms'] > 0)
                  _buildBenefitItem(
                    '${benefits['freeHealthPrograms']} free health programs',
                    typeColor,
                  ),
                if (benefits['familyMembers'] != null &&
                    benefits['familyMembers'] > 1)
                  _buildBenefitItem(
                    'Up to ${benefits['familyMembers']} family members',
                    typeColor,
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: hasActiveSubscription
                        ? null
                        : () => _subscribe(plan['_id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: typeColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      hasActiveSubscription
                          ? 'Already Subscribed'
                          : 'Subscribe Now',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
