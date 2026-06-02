import 'package:flutter/material.dart';
import '../services/laboratory_service.dart';
import 'package:intl/intl.dart';
import 'package:icare/screens/lab_bookings_management.dart';
import 'package:icare/screens/lab_tests_management.dart';
import 'package:icare/screens/lab_reports_screen.dart';
import 'package:icare/screens/lab_analytics.dart';
import 'package:icare/screens/payment_invoices.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'dart:async';
import 'package:icare/screens/lab_supplies_management.dart';
import 'package:icare/services/lab_supply_service.dart';
import 'package:icare/utils/error_handler.dart';
// import removed: my_appointments_list (patient feature, not relevant to lab);

class LaboratoryDashboard extends StatefulWidget {
  const LaboratoryDashboard({super.key});

  @override
  State<LaboratoryDashboard> createState() => _LaboratoryDashboardState();
}

class _LaboratoryDashboardState extends State<LaboratoryDashboard>
    with SingleTickerProviderStateMixin {
  final LaboratoryService _labService = LaboratoryService();
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _labProfile;
  String? _error;
  Timer? _refreshTimer;
  int _lastKnownBookingCount = 0;
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  int _lowStockCount = 0;

  // Premium Theme Colors
  final Color primaryColor = const Color(0xFF0B2D6E);
  final Color secondaryColor = const Color(0xFF1565C0);
  final Color accentColor = const Color(0xFF0EA5E9);
  final Color backgroundColor = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeIn),
    );
    _loadData();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_isLoading) {
        _checkForNewBookings();
      }
    });
  }

  Future<void> _checkForNewBookings() async {
    try {
      if (_labProfile == null) return;
      final stats = await _labService.getDashboardStats(_labProfile!['_id']);
      final currentCount = stats['totalBookings'] ?? 0;

      if (currentCount > _lastKnownBookingCount && _lastKnownBookingCount > 0) {
        _showNewBookingNotification();
      }
      _lastKnownBookingCount = currentCount;

      // Always update stats so completed/pending counts stay live
      if (mounted) {
        setState(() {
          _stats = stats;
        });
      }
    } catch (e) {
      debugPrint('Error auto-refreshing: $e');
    }
  }

  void _showNewBookingNotification() {
    SmartDialog.showToast(
      '',
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_active_rounded, color: Colors.white),
            const SizedBox(width: 12),
            const Text(
              'New Lab Booking Received!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () {
                SmartDialog.dismiss();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const LabBookingsManagement(),
                  ),
                );
              },
              child: const Text(
                'VIEW',
                style: TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
      displayTime: const Duration(seconds: 5),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _animationController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('🔍 LAB DASHBOARD - Loading profile...');
      final profile = await _labService.getProfile();
      debugPrint('🔍 LAB DASHBOARD - Profile loaded: ${profile['labName'] ?? profile['lab_name']}');
      debugPrint('🔍 LAB DASHBOARD - Profile _id: ${profile['_id']}');
      debugPrint('🔍 LAB DASHBOARD - Profile keys: ${profile.keys.toList()}');
      
      debugPrint('🔍 LAB DASHBOARD - Fetching dashboard stats for labId: ${profile['_id']}');
      final stats = await _labService.getDashboardStats(profile['_id']);
      debugPrint('✅ LAB DASHBOARD - Stats loaded: $stats');

      // Load low stock alerts (optional feature, don't fail if endpoint missing)
      try {
        final lowStockData = await LabSupplyService.getLowStockAlerts();
        _lowStockCount = lowStockData['count'] ?? 0;
      } catch (e) {
        // Endpoint may not exist yet - gracefully ignore
        debugPrint('Low stock alerts not available: $e');
        _lowStockCount = 0;
      }

      setState(() {
        _labProfile = profile;
        _stats = stats;
        _lastKnownBookingCount = stats['totalBookings'] ?? 0;
        _isLoading = false;
      });
      _animationController?.forward();
    } catch (e) {
      debugPrint('❌ LAB DASHBOARD - Error loading data: $e');
      setState(() {
        _error = ErrorHandler.getFriendlyMessage(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Loading dashboard...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error: $_error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: _fadeAnimation != null
                    ? FadeTransition(
                        opacity: _fadeAnimation!,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildWelcomeCard(isMobile),
                            const SizedBox(height: 24),
                            if (_lowStockCount > 0) ...[
                              _buildLowStockAlert(isMobile),
                              const SizedBox(height: 24),
                            ],
                            _buildStatsGrid(isMobile),
                            const SizedBox(height: 16),
                            _buildLabRevenueCard(),
                            const SizedBox(height: 32),
                            _buildQuickActions(isMobile),
                            const SizedBox(height: 32),
                            _buildRecentActivity(isMobile),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWelcomeCard(isMobile),
                          const SizedBox(height: 24),
                          if (_lowStockCount > 0) ...[
                            _buildLowStockAlert(isMobile),
                            const SizedBox(height: 24),
                          ],
                          _buildStatsGrid(isMobile),
                          const SizedBox(height: 16),
                          _buildLabRevenueCard(),
                          const SizedBox(height: 32),
                          _buildQuickActions(isMobile),
                          const SizedBox(height: 32),
                          _buildRecentActivity(isMobile),
                        ],
                      ),
              ),
            ),
    );
  }

  Widget _buildWelcomeCard(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.science,
              size: 150,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Icon(
                    Icons.biotech,
                    size: isMobile ? 40 : 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _labProfile?['labName'] ?? 'Laboratory Dashboard',
                        style: TextStyle(
                          fontSize: isMobile ? 22 : 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Welcome back! Here\'s your overview',
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      if (!isMobile) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: accentColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _labProfile?['city'] ?? 'Location not set',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => const LabBookingsManagement(),
                      ),
                    );
                    _loadData();
                  },
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildLowStockAlert(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade600, Colors.orange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const LabSuppliesManagement()),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Low Stock Alert',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_lowStockCount ${_lowStockCount == 1 ? 'item needs' : 'items need'} restocking',
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabRevenueCard() {
    final revenue = (_stats?['revenue'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B2D6E), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2D6E).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.payments_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PKR $revenue',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Total Revenue',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(bool isMobile) {
    final stats = [
      {
        'title': 'Today',
        'value': _stats?['todayBookings']?.toString() ?? '0',
        'icon': Icons.today_rounded,
        'trend': 'New',
      },
      {
        'title': 'Total',
        'value': _stats?['totalBookings']?.toString() ?? '0',
        'icon': Icons.calendar_month_rounded,
        'trend': '+12%',
      },
      {
        'title': 'Pending',
        'value': _stats?['pendingBookings']?.toString() ?? '0',
        'icon': Icons.pending_actions_rounded,
        'trend': 'Needs Action',
      },
      {
        'title': 'Completed',
        'value': _stats?['completedBookings']?.toString() ?? '0',
        'icon': Icons.task_alt_rounded,
        'trend': '+8%',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isMobile ? 1.05 : 1.3,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isMobile ? 10 : 12),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        stat['icon'] as IconData,
                        size: isMobile ? 22 : 26,
                        color: primaryColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: stat['trend'] == 'Needs Action'
                            ? Colors.orange.withValues(alpha: 0.1)
                            : stat['trend'] == 'New'
                            ? accentColor.withValues(alpha: 0.1)
                            : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        stat['trend'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: stat['trend'] == 'Needs Action'
                              ? Colors.orange[800]
                              : stat['trend'] == 'New'
                              ? accentColor
                              : Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat['value'] as String,
                      style: TextStyle(
                        fontSize: isMobile ? 28 : 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B), // Slate 800
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stat['title'] as String,
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        color: const Color(0xFF64748B), // Slate 500
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(foregroundColor: primaryColor),
              child: const Text(
                'View All',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildActionButton(
                  'New Requests',
                  Icons.pending_actions_rounded,
                  () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => const LabBookingsManagement(
                          title: 'New Requests',
                          initialFilter: 'pending',
                        ),
                      ),
                    );
                    _loadData();
                  },
                  isMobile,
                ),
                _buildActionButton(
                  'Records',
                  Icons.folder_copy_rounded,
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => const LabReportsScreen(),
                    ),
                  ),
                  isMobile,
                ),
                _buildActionButton(
                  'Orders',
                  Icons.list_alt_rounded,
                  () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => const LabBookingsManagement(),
                      ),
                    );
                    _loadData();
                  },
                  isMobile,
                ),
                _buildActionButton(
                  'Test Catalog',
                  Icons.science_rounded,
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => const LabTestsManagement(),
                    ),
                  ),
                  isMobile,
                ),
                _buildActionButton(
                  'Analytics',
                  Icons.analytics_outlined,
                  () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const LabAnalytics()),
                  ),
                  isMobile,
                ),
                _buildActionButton(
                  'Invoices',
                  Icons.receipt_long_rounded,
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => const PaymentInvoices(),
                    ),
                  ),
                  isMobile,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onTap,
    bool isMobile,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: primaryColor.withValues(alpha: 0.05),
        splashColor: primaryColor.withValues(alpha: 0.1),
        child: Container(
          width: isMobile ? 140 : 160,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 20,
            vertical: isMobile ? 16 : 20,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: primaryColor,
                  size: isMobile ? 24 : 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                  fontSize: isMobile ? 13 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(bool isMobile) {
    final recentActivity = _stats?['recentActivity'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: isMobile ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: recentActivity.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No recent activity to display',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: recentActivity.asMap().entries.map((entry) {
                      final index = entry.key;
                      final activity = entry.value;

                      final status =
                          activity['status']?.toString().toLowerCase() ??
                          'unknown';
                      IconData icon = Icons.info_outline;
                      Color color = accentColor;
                      String title = 'Booking Updated';

                      if (status == 'completed') {
                        icon = Icons.check_circle_outline;
                        color = Colors.green;
                        title = 'Booking Completed';
                      } else if (status == 'pending') {
                        icon = Icons.pending_actions_outlined;
                        color = Colors.orange;
                        title = 'New Booking Received';
                      } else if (status == 'confirmed') {
                        icon = Icons.event_available_outlined;
                        color = primaryColor;
                        title = 'Booking Confirmed';
                      } else if (status == 'cancelled') {
                        icon = Icons.cancel_outlined;
                        color = Colors.red;
                        title = 'Booking Cancelled';
                      }

                      final patientName =
                          activity['patient']?['name'] ?? 'Patient';
                      final testName =
                          (activity['tests'] as List<dynamic>?)
                              ?.map((t) => t['testName'])
                              .join(', ') ??
                          'Test';
                      final parsedDate =
                          DateTime.tryParse(
                            activity['createdAt'] ?? activity['date'] ?? '',
                          ) ??
                          DateTime.now();
                      final timeString = DateFormat(
                        'MMM d, hh:mm a',
                      ).format(parsedDate);

                      return Column(
                        children: [
                          _buildActivityItem(
                            icon,
                            title,
                            'Patient: $patientName\nTest: $testName',
                            timeString,
                            color,
                          ),
                          if (index < recentActivity.length - 1)
                            const Divider(height: 1, indent: 64, endIndent: 20),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(
    IconData icon,
    String title,
    String subtitle,
    String time,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
