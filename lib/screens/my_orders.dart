import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/services/order_service.dart';
import 'package:icare/services/pharmacy_service.dart';
import 'package:icare/screens/order_tracking.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class MyOrdersScreen extends ConsumerStatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  ConsumerState<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends ConsumerState<MyOrdersScreen> {
  final OrderService _orderService = OrderService();
  final PharmacyService _pharmacyService = PharmacyService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];
  final Set<String> _ratedOrders = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      setState(() => _isLoading = true);
      final orders = await _orderService.getMyOrders();
      setState(() {
        _orders = orders
            .map(
              (o) => {
                '_id': o['_id'],
                'id':
                    o['orderNumber'] ??
                    '#${o['_id'].toString().substring(0, 8)}',
                'status': _formatStatus(o['status'] ?? 'pending'),
                'color': _getStatusColor(o['status'] ?? 'pending'),
                'products':
                    (o['items'] as List?)
                        ?.map(
                          (item) => {
                            'name': item['productName'] ?? 'Unknown',
                            'image': ImagePaths.capsule,
                          },
                        )
                        .toList() ??
                    [],
                'pharmacy': 'Pharmacy',
                'date': o['createdAt'] != null
                    ? DateFormat(
                        'dd MMM yyyy',
                      ).format(DateTime.parse(o['createdAt']))
                    : 'N/A',
                'amount': (o['totalAmount'] ?? 0).toString(),
                'qty': (o['items'] as List?)?.length ?? 0,
                'isDelivered': o['status'] == 'completed',
              },
            )
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to load data. Please try again.'.tr())));
      }
    }
  }

  Future<void> _showComplaintDialog(Map<String, dynamic> order) async {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String category = 'Late Delivery';
    bool sending = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.report_problem_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 10),
            Text('Register Complaint', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 380,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Order: ${order['id']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 16),
                const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: ['Late Delivery', 'Wrong Medicine', 'Damaged Product', 'Poor Service', 'Other']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setSt(() => category = v ?? category),
                ),
                const SizedBox(height: 12),
                const Text('Subject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: subjectCtrl,
                  decoration: InputDecoration(
                    hintText: 'Brief subject of complaint',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: messageCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Describe your complaint in detail...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: sending ? null : () async {
                if (subjectCtrl.text.trim().isEmpty || messageCtrl.text.trim().isEmpty) return;
                setSt(() => sending = true);
                final user = ref.read(authProvider).user;
                final body = '''
Complaint Category: $category
Order Number: ${order['id']}
Pharmacy: ${order['pharmacy'] ?? 'N/A'}
Order Amount: PKR ${order['amount']}
Order Date: ${order['date']}

Patient Details:
Name: ${user?.name ?? 'N/A'}
Email: ${user?.email ?? 'N/A'}
Phone: ${user?.phoneNumber ?? 'N/A'}
User ID: ${user?.id ?? 'N/A'}

Subject: ${subjectCtrl.text.trim()}

Message:
${messageCtrl.text.trim()}
''';
                final mailUri = Uri(
                  scheme: 'mailto',
                  path: 'icareofficialapp@gmail.com',
                  queryParameters: {
                    'subject': '[Complaint] $category - Order ${order['id']}',
                    'body': body,
                  },
                );
                if (ctx.mounted) Navigator.pop(ctx);
                await launchUrl(mailUri, mode: LaunchMode.externalApplication);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Complaint submitted. Our team will respond within 24 hours.'), backgroundColor: Color(0xFF10B981)),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Submit Complaint'),
            ),
          ],
        ),
      ),
    );
    subjectCtrl.dispose();
    messageCtrl.dispose();
  }

  Future<void> _showRatePharmacyDialog(Map<String, dynamic> order) async {
    double rating = 0;
    final commentCtrl = TextEditingController();
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 22),
            SizedBox(width: 10),
            Text('Rate Pharmacy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          content: SizedBox(
            width: 340,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('How was your experience with ${order['pharmacy']}?', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => GestureDetector(
                onTap: () => setSt(() => rating = i + 1.0),
                child: Icon(rating > i ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFF59E0B), size: 40),
              ))),
              const SizedBox(height: 16),
              TextField(
                controller: commentCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Leave a comment (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Skip')),
            ElevatedButton(
              onPressed: (submitting || rating == 0) ? null : () async {
                setSt(() => submitting = true);
                try {
                  await _pharmacyService.submitOrderRating(order['_id'] ?? '', rating.toInt(), commentCtrl.text.trim());
                  setState(() => _ratedOrders.add(order['_id'] ?? ''));
                } catch (_) {}
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thank you for your rating!'), backgroundColor: Color(0xFF10B981)),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Submit Rating'),
            ),
          ],
        ),
      ),
    );
    commentCtrl.dispose();
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'preparing':
        return 'Preparing';
      case 'out_for_delivery':
        return 'In Transit';
      case 'completed':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'out_for_delivery':
        return const Color(0xFFF59E0B);
      case 'preparing':
        return const Color(0xFF6366F1);
      case 'confirmed':
        return const Color(0xFF3B82F6);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 900;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: CustomText(
            text: "My Orders".tr(),
            fontFamily: "Gilroy-Bold",
            fontSize: 16.78,
            fontWeight: FontWeight.bold,
            color: AppColors.primary500,
          ),
          automaticallyImplyLeading: false,
          leading: const CustomBackButton(),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_orders.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: CustomText(
            text: "My Orders".tr(),
            fontFamily: "Gilroy-Bold",
            fontSize: 16.78,
            fontWeight: FontWeight.bold,
            color: AppColors.primary500,
          ),
          automaticallyImplyLeading: false,
          leading: const CustomBackButton(),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'No orders yet'.tr(),
                style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: CustomScrollView(
        slivers: [
          // Stunning Header
          SliverAppBar(
            expandedHeight: 220,
            floating: true,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: const CustomBackButton(),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryColor.withValues(alpha: 0.05),
                      Colors.white,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isWeb ? 60 : 20,
                    40,
                    isWeb ? 60 : 40,
                    20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CustomText(
                        text: "PURCHASE HISTORY".tr(),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryColor,
                        letterSpacing: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: CustomText(
                              text: "My Personal Orders".tr(),
                              fontSize: isWeb ? 36 : 24,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          if (isWeb) _buildHeaderStats(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Search and Filters (Web only)
          if (isWeb)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 60,
                  vertical: 24,
                ),
                child: Row(
                  children: [
                    _buildFilterChip("All Orders".tr(), true),
                    const SizedBox(width: 12),
                    _buildFilterChip("Delivered".tr(), false),
                    const SizedBox(width: 12),
                    _buildFilterChip("Pending".tr(), false),
                    const Spacer(),
                    _buildSearchBar(),
                  ],
                ),
              ),
            ),

          // Orders Content
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: isWeb ? 60 : 20,
              vertical: isWeb ? 0 : 20,
            ),
            sliver: isWeb
                ? SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 550,
                          mainAxisExtent: 280,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) =>
                          _buildModernOrderCard(context, _orders[i], isWeb),
                      childCount: _orders.length,
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) =>
                          _buildModernOrderCard(context, _orders[i], isWeb),
                      childCount: _orders.length,
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeaderStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: const [
          Icon(Icons.shopping_bag_rounded, size: 16, color: Color(0xFF64748B)),
          SizedBox(width: 8),
          Text(
            "Total: 24 Orders",
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 12),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: Color(0xFF64748B),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: 300,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search an order...".tr(),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: Color(0xFF94A3B8),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryColor : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isActive ? AppColors.primaryColor : const Color(0xFFE2E8F0),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primaryColor.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: CustomText(
        text: label,
        color: isActive ? Colors.white : const Color(0xFF64748B),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildModernOrderCard(
    BuildContext context,
    Map<String, dynamic> order,
    bool isWeb,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: isWeb ? 0 : 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Product Image Display
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Image.asset(
                  (order['products'] as List).isNotEmpty ? order['products'][0]['image'] : ImagePaths.capsule,
                  height: 48,
                  width: 48,
                ),
              ),
              const SizedBox(width: 20),
              // Order Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      text: (order['products'] as List).isNotEmpty ? order['products'][0]['name'] : 'Pharmacy Order',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                    const SizedBox(height: 4),
                    CustomText(
                      text: "${order['pharmacy']} • Qty: ${order['qty']}",
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: order['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CustomText(
                  text: order['status'],
                  color: order['color'],
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    text: order['isDelivered']
                        ? "Delivered on ${order['date']}"
                        : "Order Date: ${order['date']}",
                    fontSize: 12,
                    color: order['isDelivered']
                        ? const Color(0xFF10B981)
                        : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                  CustomText(
                    text: "RS. ${order['amount']}",
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryColor,
                  ),
                ],
              ),
              if (!order['isDelivered'])
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => const OrderTrackingScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "Track Order".tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_ratedOrders.contains(order['_id']))
                      GestureDetector(
                        onTap: () => _showRatePharmacyDialog(order),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                            SizedBox(width: 4),
                            Text('Rate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
                          ]),
                        ),
                      ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showComplaintDialog(order),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.report_problem_rounded, size: 14, color: Color(0xFFEF4444)),
                          SizedBox(width: 4),
                          Text('Complaint', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                        ]),
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
}
