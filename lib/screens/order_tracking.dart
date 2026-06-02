import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:intl/intl.dart';

class OrderTrackingScreen extends StatelessWidget {
  final Map<String, dynamic>? order;
  const OrderTrackingScreen({super.key, this.order});

  static const _statusSteps = [
    'pending',
    'confirmed',
    'preparing',
    'out_for_delivery',
    'completed',
  ];

  static const _stepLabels = [
    'Order Placed',
    'Order Confirmed',
    'Being Prepared',
    'Out for Delivery',
    'Delivered',
  ];

  static const _stepIcons = [
    Icons.shopping_cart_rounded,
    Icons.check_circle_rounded,
    Icons.inventory_2_rounded,
    Icons.local_shipping_rounded,
    Icons.home_rounded,
  ];

  int _currentStep(String status) {
    final idx = _statusSteps.indexOf(status.toLowerCase());
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final rawStatus = (order?['status'] as String? ?? 'pending').toLowerCase();
    final currentStep = _currentStep(rawStatus);
    final orderId = order?['id']?.toString() ?? '';
    final orderDate = order?['date']?.toString() ?? '';
    final pharmacyName = order?['pharmacy']?.toString() ?? 'Pharmacy';
    final amount = order?['amount']?.toString() ?? '0';
    final products = (order?['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: CustomText(
          text: 'Order Tracking'.tr(),
          fontFamily: 'Gilroy-Bold',
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: AppColors.primary500,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order info card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.receipt_long_rounded, color: AppColors.primaryColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              orderId.isNotEmpty ? 'Order $orderId' : 'Order',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              pharmacyName,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _statusColor(rawStatus).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(rawStatus),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _statusColor(rawStatus),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _infoTile('Order Date', orderDate.isNotEmpty ? orderDate : '—'),
                      _infoTile('Amount', 'PKR $amount'),
                      _infoTile('Items', '${products.length}'),
                    ],
                  ),
                  if (products.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Items', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                    const SizedBox(height: 8),
                    ...products.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.fiber_manual_record, size: 8, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p['name']?.toString() ?? 'Medicine',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Tracking steps
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tracking',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 20),
                  ...List.generate(_statusSteps.length, (i) {
                    final isDone = i <= currentStep;
                    final isCurrent = i == currentStep;
                    return _buildStep(
                      icon: _stepIcons[i],
                      label: _stepLabels[i],
                      isDone: isDone,
                      isCurrent: isCurrent,
                      isLast: i == _statusSteps.length - 1,
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required IconData icon,
    required String label,
    required bool isDone,
    required bool isCurrent,
    required bool isLast,
  }) {
    final color = isDone
        ? (isCurrent ? AppColors.primaryColor : const Color(0xFF10B981))
        : const Color(0xFFE2E8F0);
    final textColor = isDone ? const Color(0xFF0F172A) : const Color(0xFF94A3B8);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDone ? color.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: isDone ? color : const Color(0xFFE2E8F0), width: 2),
              ),
              child: Icon(icon, size: 18, color: isDone ? color : const Color(0xFFCBD5E1)),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isDone ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                  color: textColor,
                ),
              ),
              if (isCurrent)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Current Status',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryColor),
                  ),
                ),
            ],
          ),
        ),
        if (!isLast) const SizedBox(height: 40),
      ],
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed': return const Color(0xFF10B981);
      case 'out_for_delivery': return const Color(0xFFF59E0B);
      case 'preparing': return const Color(0xFF6366F1);
      case 'confirmed': return const Color(0xFF3B82F6);
      case 'cancelled': return const Color(0xFFEF4444);
      default: return const Color(0xFF94A3B8);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed': return 'Delivered';
      case 'out_for_delivery': return 'In Transit';
      case 'preparing': return 'Preparing';
      case 'confirmed': return 'Confirmed';
      case 'cancelled': return 'Cancelled';
      default: return 'Pending';
    }
  }
}
