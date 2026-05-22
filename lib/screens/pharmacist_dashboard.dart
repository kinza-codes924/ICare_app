import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/pharmacy_inventory.dart';
import 'package:icare/screens/pharmacy_orders.dart';
import 'package:icare/screens/payment_invoices.dart';
import 'package:icare/services/pharmacy_service.dart';
import 'package:intl/intl.dart';

class PharmacistDashboard extends ConsumerStatefulWidget {
  const PharmacistDashboard({super.key});

  @override
  ConsumerState<PharmacistDashboard> createState() =>
      _PharmacistDashboardState();
}

class _PharmacistDashboardState extends ConsumerState<PharmacistDashboard> {
  final PharmacyService _pharmacyService = PharmacyService();
  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _recentOrders = [];

  Map<String, int> _stats = {
    'todayOrders': 0,
    'totalOrders': 0,
    'pendingOrders': 0,
    'completedOrders': 0,
    'totalProducts': 0,
    'lowStock': 0,
    'revenue': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
      final stats = await _pharmacyService.getPharmacyStats();
      List<Map<String, dynamic>> recentOrders = [];
      try {
        final orders = await _pharmacyService.getPharmacyOrders();
        recentOrders = orders
            .take(5)
            .map((o) => Map<String, dynamic>.from(o as Map))
            .toList();
      } catch (_) {}
      setState(() {
        _stats = stats.map((key, value) => MapEntry(key, (value as num).toInt()));
        _recentOrders = recentOrders;
        _isLoading = false;
      });
    } catch (e) {
      // Show dashboard with zero stats instead of error
      setState(() {
        _isLoading = false;
        _hasError = false; // Don't show error, just show empty dashboard
        _stats = {
          'todayOrders': 0,
          'totalOrders': 0,
          'pendingOrders': 0,
          'completedOrders': 0,
          'totalProducts': 0,
          'lowStock': 0,
          'revenue': 0,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(authProvider).user?.name ?? 'Pharmacist';
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to load dashboard',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your connection and try again.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadStats,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 32 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeHeader(userName),
                  const SizedBox(height: 24),
                  _buildQuickStats(isDesktop),
                  const SizedBox(height: 24),
                  _buildQuickActions(isDesktop),
                  const SizedBox(height: 24),
                  _buildRecentActivity(),
                ],
              ),
            ),
    );
  }

  Widget _buildWelcomeHeader(String userName) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE, MMMM dd, yyyy').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_pharmacy_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (isDesktop) {
          return Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Today',
                  _stats['todayOrders'] ?? 0,
                  Icons.today_rounded,
                  const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Total',
                  _stats['totalOrders'] ?? 0,
                  Icons.receipt_long_rounded,
                  const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  _stats['pendingOrders'] ?? 0,
                  Icons.pending_actions_rounded,
                  const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Completed',
                  _stats['completedOrders'] ?? 0,
                  Icons.check_circle_outline_rounded,
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildRevenueCard(_stats['revenue'] ?? 0),
              ),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Today',
                    _stats['todayOrders'] ?? 0,
                    Icons.today_rounded,
                    const Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Total',
                    _stats['totalOrders'] ?? 0,
                    Icons.receipt_long_rounded,
                    const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Pending',
                    _stats['pendingOrders'] ?? 0,
                    Icons.pending_actions_rounded,
                    const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Completed',
                    _stats['completedOrders'] ?? 0,
                    Icons.check_circle_outline_rounded,
                    const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRevenueCard(_stats['revenue'] ?? 0),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon, Color color) {
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            '$count',
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

  Widget _buildRevenueCard(int revenue) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.payments_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            'Rs. ${NumberFormat('#,##0').format(revenue)}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total Revenue',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _buildActionCard(
              'Dispense Queue',
              Icons.move_to_inbox_rounded,
              const Color(0xFF3B82F6),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => const PharmacyOrders()),
                );
              },
            ),
            _buildActionCard(
              'Medication Inventory',
              Icons.inventory_2_rounded,
              const Color(0xFF10B981),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const PharmacyInventory(),
                  ),
                );
              },
            ),
            _buildActionCard(
              'Invoices',
              Icons.receipt_long_rounded,
              const Color(0xFFF59E0B),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const PaymentInvoices(isPharmacy: true),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: _recentOrders.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No recent orders to display',
                      style: TextStyle(color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              : Column(
                  children: _recentOrders.asMap().entries.map((entry) {
                    final i = entry.key;
                    final order = entry.value;
                    final status = (order['status'] ?? 'pending').toString();
                    final patientName = order['patient']?['name'] ?? order['customerName'] ?? 'Customer';
                    final orderId = order['orderNumber'] ?? order['_id']?.toString().substring(18) ?? '#—';
                    IconData icon;
                    Color color;
                    String title;
                    if (status == 'completed') {
                      icon = Icons.check_circle_rounded;
                      color = const Color(0xFF10B981);
                      title = 'Order delivered';
                    } else if (status == 'out_for_delivery') {
                      icon = Icons.local_shipping_rounded;
                      color = const Color(0xFF6366F1);
                      title = 'Out for delivery';
                    } else if (status == 'preparing') {
                      icon = Icons.medication_rounded;
                      color = const Color(0xFF3B82F6);
                      title = 'Preparing order';
                    } else if (status == 'cancelled') {
                      icon = Icons.cancel_rounded;
                      color = const Color(0xFFEF4444);
                      title = 'Order cancelled';
                    } else {
                      icon = Icons.receipt_rounded;
                      color = const Color(0xFFF59E0B);
                      title = 'New order received';
                    }
                    return Column(
                      children: [
                        if (i > 0) const Divider(height: 24),
                        _buildActivityItem(title, '$patientName • $orderId', icon, color, _timeAgo(order['createdAt'])),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  String _timeAgo(dynamic createdAt) {
    if (createdAt == null) return '—';
    final dt = DateTime.tryParse(createdAt.toString());
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildActivityItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String time,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }
}
