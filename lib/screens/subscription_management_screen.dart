import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/models/subscription.dart';
import 'package:icare/utils/theme.dart';

/// Subscription Management Screen
///
/// Allows patients to view current subscription and upgrade to premium tiers
/// Shows subscription benefits, pricing, and chronic care packages
class SubscriptionManagementScreen extends ConsumerStatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  ConsumerState<SubscriptionManagementScreen> createState() => _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState extends ConsumerState<SubscriptionManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Subscription? _currentSubscription;
  bool _isLoading = true;
  bool _isYearly = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSubscription();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscription() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));

    // In real implementation, fetch from backend
    setState(() {
      _currentSubscription = Subscription.getFreeSubscription('current_user_id');
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subscription Plans',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Gilroy-Bold',
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Choose the plan that fits your needs',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
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
                Tab(text: 'SUBSCRIPTION PLANS'),
                Tab(text: 'CHRONIC CARE'),
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
                _buildSubscriptionPlansTab(),
                _buildChronicCareTab(),
              ],
            ),
    );
  }

  Widget _buildSubscriptionPlansTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_currentSubscription != null) ...[
          _buildCurrentPlanCard(),
          const SizedBox(height: 24),
        ],
        _buildBillingToggle(),
        const SizedBox(height: 24),
        const Text(
          'Available Plans',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 16),
        _buildPlanCard(Subscription.getFreeSubscription('user'), isCurrentPlan: _currentSubscription?.tier == SubscriptionTier.free),
        _buildPlanCard(Subscription.getBasicSubscription('user'), isCurrentPlan: _currentSubscription?.tier == SubscriptionTier.basic),
        _buildPlanCard(Subscription.getPremiumSubscription('user'), isCurrentPlan: _currentSubscription?.tier == SubscriptionTier.premium, isRecommended: true),
        _buildPlanCard(Subscription.getEnterpriseSubscription('user'), isCurrentPlan: _currentSubscription?.tier == SubscriptionTier.enterprise),
      ],
    );
  }

  Widget _buildChronicCareTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF166534)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Chronic care packages provide comprehensive management for specific conditions',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF166534),
                    fontFamily: 'Gilroy-Medium',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Chronic Care Packages',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 16),
        _buildChronicCareCard(ChronicCarePackage.getDiabetesCarePackage()),
        _buildChronicCareCard(ChronicCarePackage.getHypertensionCarePackage()),
        _buildChronicCareCard(ChronicCarePackage.getHeartCarePackage()),
      ],
    );
  }

  Widget _buildCurrentPlanCard() {
    if (_currentSubscription == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
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
            'Current Plan',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontFamily: 'Gilroy-Medium',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getTierName(_currentSubscription!.tier),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontFamily: 'Gilroy-Bold',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currentSubscription!.tier == SubscriptionTier.free
                ? 'Free forever'
                : '\$${_isYearly ? _currentSubscription!.yearlyPrice.toStringAsFixed(2) : _currentSubscription!.monthlyPrice.toStringAsFixed(2)}/${_isYearly ? "year" : "month"}',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isYearly = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isYearly ? AppColors.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Monthly',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: !_isYearly ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isYearly = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isYearly ? AppColors.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      'Yearly',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _isYearly ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      'Save 17%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _isYearly ? Colors.white70 : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Subscription subscription, {bool isCurrentPlan = false, bool isRecommended = false}) {
    final price = _isYearly ? subscription.yearlyPrice : subscription.monthlyPrice;
    final isFree = subscription.tier == SubscriptionTier.free;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRecommended ? AppColors.primaryColor : const Color(0xFFF1F5F9),
          width: isRecommended ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRecommended)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: const Text(
                'RECOMMENDED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getTierName(subscription.tier),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Gilroy-Bold',
                      ),
                    ),
                    if (isCurrentPlan)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Current',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isFree)
                  const Text(
                    'Free',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryColor,
                      fontFamily: 'Gilroy-Bold',
                    ),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '\$',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryColor,
                        ),
                      ),
                      Text(
                        price.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryColor,
                          fontFamily: 'Gilroy-Bold',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Text(
                          '/${_isYearly ? "year" : "month"}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                ...subscription.features.map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, size: 20, color: Color(0xFF10B981)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isCurrentPlan ? null : () => _upgradePlan(subscription),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrentPlan ? const Color(0xFFE2E8F0) : AppColors.primaryColor,
                      foregroundColor: isCurrentPlan ? const Color(0xFF64748B) : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isCurrentPlan ? 'Current Plan' : 'Upgrade'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChronicCareCard(ChronicCarePackage package) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  package.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Gilroy-Bold',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  package.targetCondition,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '\$',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    Text(
                      (_isYearly ? package.yearlyPrice : package.monthlyPrice).toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryColor,
                        fontFamily: 'Gilroy-Bold',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        '/${_isYearly ? "year" : "month"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
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
                  package.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Included Services:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...package.includedServices.map((service) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, size: 18, color: Color(0xFF10B981)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              service,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _enrollInChronicCare(package),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Enroll Now'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTierName(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.basic:
        return 'Basic';
      case SubscriptionTier.premium:
        return 'Premium';
      case SubscriptionTier.enterprise:
        return 'Enterprise';
    }
  }

  void _upgradePlan(Subscription subscription) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Upgrade to ${_getTierName(subscription.tier)}'),
        content: Text(
          'You are about to upgrade to the ${_getTierName(subscription.tier)} plan for \$${(_isYearly ? subscription.yearlyPrice : subscription.monthlyPrice).toStringAsFixed(2)}/${_isYearly ? "year" : "month"}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Upgraded to ${_getTierName(subscription.tier)}'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _enrollInChronicCare(ChronicCarePackage package) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enroll in ${package.name}'),
        content: Text(
          'You are about to enroll in the ${package.name} for \$${(_isYearly ? package.yearlyPrice : package.monthlyPrice).toStringAsFixed(2)}/${_isYearly ? "year" : "month"}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Enrolled in ${package.name}'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
