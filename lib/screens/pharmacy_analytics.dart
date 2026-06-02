import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/services/pharmacy_service.dart';
import 'package:intl/intl.dart';

class PharmacyAnalytics extends StatefulWidget {
  const PharmacyAnalytics({super.key});

  @override
  State<PharmacyAnalytics> createState() => _PharmacyAnalyticsState();
}

class _PharmacyAnalyticsState extends State<PharmacyAnalytics> {
  final PharmacyService _pharmacyService = PharmacyService();
  String _selectedPeriod = 'This Month';
  DateTimeRange? _customRange;
  bool _isLoading = true;

  Map<String, dynamic> _stats = {
    'totalRevenue': 0,
    'totalOrders': 0,
    'ordersAccepted': 0,
    'ordersCompleted': 0,
    'averageOrderValue': 0.0,
    'averageProcessTime': '0h 0m',
    'responseTime': '0m',
    'failedDeliveries': 0,
    'outOfStockCount': 0,
    'complaintsCount': 0,
    'averageRating': 0.0,
    'topSellingProducts': [],
  };

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      setState(() => _isLoading = true);
      final analytics = await _pharmacyService.getAnalytics();
      setState(() {
        _stats = analytics;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: const Text('Unable to load data. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          'Revenue & Analytics',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Gilroy-Bold',
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF64748B)),
            tooltip: 'Custom Date Range',
            onPressed: _pickDateRange,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 40 : 20),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 1200 : double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPeriodSelector(),
                      const SizedBox(height: 24),
                      _buildRevenueCards(isDesktop),
                      const SizedBox(height: 24),
                      _buildOrderMetrics(isDesktop),
                      const SizedBox(height: 24),
                      _buildPerformanceMetrics(isDesktop),
                      const SizedBox(height: 24),
                      _buildQualityMetrics(isDesktop),
                      const SizedBox(height: 24),
                      _buildTopSellingProducts(),
                      const SizedBox(height: 24),
                      _buildOrdersBreakdown(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _customRange ?? DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      ),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.primaryColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _selectedPeriod = 'Custom';
      });
    }
  }

  Widget _buildPeriodSelector() {
    final periods = ['This Week', 'This Month', 'This Year'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: periods.map((period) {
              final isSelected = period == _selectedPeriod;
              return Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPeriod = period;
                      _customRange = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      period,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_customRange != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.date_range_rounded, size: 16, color: AppColors.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Custom: ${DateFormat('dd MMM yyyy').format(_customRange!.start)} – ${DateFormat('dd MMM yyyy').format(_customRange!.end)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryColor),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() { _customRange = null; _selectedPeriod = 'This Month'; }),
                  child: const Icon(Icons.close_rounded, size: 16, color: AppColors.primaryColor),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRevenueCards(bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (isDesktop) {
          return Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Revenue',
                  'PKR ${_stats['totalRevenue']}',
                  Icons.attach_money_rounded,
                  const Color(0xFF10B981),
                  '+12.5%',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Total Orders',
                  '${_stats['totalOrders']}',
                  Icons.shopping_bag_rounded,
                  const Color(0xFF3B82F6),
                  '+8.2%',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Avg Order Value',
                  'PKR ${(_stats['averageOrderValue'] ?? 0.0).toStringAsFixed(0)}',
                  Icons.trending_up_rounded,
                  const Color(0xFF8B5CF6),
                  '+5.1%',
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildStatCard(
              'Total Revenue',
              'PKR ${_stats['totalRevenue']}',
              Icons.attach_money_rounded,
              const Color(0xFF10B981),
              '+12.5%',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Orders',
                    '${_stats['totalOrders']}',
                    Icons.shopping_bag_rounded,
                    const Color(0xFF3B82F6),
                    '+8.2%',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Avg Value',
                    'PKR ${(_stats['averageOrderValue'] ?? 0.0).toStringAsFixed(0)}',
                    Icons.trending_up_rounded,
                    const Color(0xFF8B5CF6),
                    '+5.1%',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrderMetrics(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),
          isDesktop
              ? Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        'Total Submitted',
                        '${_stats['totalOrders']}',
                        Icons.receipt_long_rounded,
                        const Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricItem(
                        'Total Accepted',
                        '${_stats['ordersAccepted']}',
                        Icons.check_circle_outline_rounded,
                        const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricItem(
                        'Total Completed',
                        '${_stats['ordersCompleted']}',
                        Icons.task_alt_rounded,
                        const Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildMetricItem(
                      'Total Submitted',
                      '${_stats['totalOrders']}',
                      Icons.receipt_long_rounded,
                      const Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 12),
                    _buildMetricItem(
                      'Total Accepted',
                      '${_stats['ordersAccepted']}',
                      Icons.check_circle_outline_rounded,
                      const Color(0xFF10B981),
                    ),
                    const SizedBox(height: 12),
                    _buildMetricItem(
                      'Total Completed',
                      '${_stats['ordersCompleted']}',
                      Icons.task_alt_rounded,
                      const Color(0xFF8B5CF6),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),
          isDesktop
              ? Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        'Avg Process Time',
                        _stats['averageProcessTime'] ?? '0h 0m',
                        Icons.timer_outlined,
                        const Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricItem(
                        'Response Time',
                        _stats['responseTime'] ?? '0m',
                        Icons.speed_rounded,
                        const Color(0xFF14B8A6),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildMetricItem(
                      'Avg Process Time',
                      _stats['averageProcessTime'] ?? '0h 0m',
                      Icons.timer_outlined,
                      const Color(0xFF6366F1),
                    ),
                    const SizedBox(height: 12),
                    _buildMetricItem(
                      'Response Time',
                      _stats['responseTime'] ?? '0m',
                      Icons.speed_rounded,
                      const Color(0xFF14B8A6),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildQualityMetrics(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quality Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),
          isDesktop
              ? Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        'Failed Deliveries',
                        '${_stats['failedDeliveries']}',
                        Icons.local_shipping_outlined,
                        const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricItem(
                        'Out of Stock',
                        '${_stats['outOfStockCount']}',
                        Icons.inventory_2_outlined,
                        const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricItem(
                        'Complaints',
                        '${_stats['complaintsCount']}',
                        Icons.report_problem_outlined,
                        const Color(0xFFEC4899),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricItem(
                        'Avg Rating',
                        '${(_stats['averageRating'] ?? 0.0).toStringAsFixed(1)} ⭐',
                        Icons.star_rounded,
                        const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricItem(
                            'Failed Deliveries',
                            '${_stats['failedDeliveries']}',
                            Icons.local_shipping_outlined,
                            const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricItem(
                            'Out of Stock',
                            '${_stats['outOfStockCount']}',
                            Icons.inventory_2_outlined,
                            const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricItem(
                            'Complaints',
                            '${_stats['complaintsCount']}',
                            Icons.report_problem_outlined,
                            const Color(0xFFEC4899),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricItem(
                            'Avg Rating',
                            '${(_stats['averageRating'] ?? 0.0).toStringAsFixed(1)} ⭐',
                            Icons.star_rounded,
                            const Color(0xFFF59E0B),
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

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    String change,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  change,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellingProducts() {
    final topProducts = _stats['topSellingProducts'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Selling Products',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),
          if (topProducts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No product data available',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            )
          else
            ...topProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _getRankColor(index).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: _getRankColor(index),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '${product['sales'] ?? 0} units sold',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'PKR ${product['revenue'] ?? 0}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildOrdersBreakdown() {
    final completed = (_stats['ordersCompleted'] as num?)?.toInt() ?? 0;
    final processing = (_stats['ordersProcessing'] as num?)?.toInt() ?? 0;
    final pending = (_stats['ordersPending'] as num?)?.toInt() ?? 0;
    final cancelled = (_stats['failedDeliveries'] as num?)?.toInt() ?? 0;
    final total = completed + processing + pending + cancelled;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Orders Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),
          _buildBreakdownItem('Completed', completed, total, const Color(0xFF10B981)),
          _buildBreakdownItem('Processing', processing, total, const Color(0xFF3B82F6)),
          _buildBreakdownItem('Pending', pending, total, const Color(0xFFF59E0B)),
          _buildBreakdownItem('Cancelled', cancelled, total, const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(String label, int count, int total, Color color) {
    final percentage = total > 0 ? count / total : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFFF59E0B);
      case 1:
        return const Color(0xFF94A3B8);
      case 2:
        return const Color(0xFFCD7F32);
      default:
        return const Color(0xFF64748B);
    }
  }
}
