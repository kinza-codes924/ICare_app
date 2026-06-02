import 'package:flutter/material.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';

class DelieveredOrder extends StatelessWidget {
  const DelieveredOrder({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 900;

    final List<Map<String, dynamic>> orders = [
      {
        "id": "ORD-0988",
        "status": "Delivered",
        "color": const Color(0xFF10B981),
        "products": [
          {"name": "Multivitamin", "image": ImagePaths.capsule},
          {"name": "Syrup", "image": ImagePaths.capsule2},
        ],
        "patient": "Sarah Ahmed",
        "date": "18 June 2025",
        "time": "02:00 PM",
        "amount": "3,400",
      },
      {
        "id": "ORD-0985",
        "status": "Delivered",
        "color": const Color(0xFF10B981),
        "products": [
          {"name": "Capsule", "image": ImagePaths.capsule},
        ],
        "patient": "Ali Raza",
        "date": "17 June 2025",
        "time": "11:30 AM",
        "amount": "1,800",
      },
      {
        "id": "ORD-0982",
        "status": "Delivered",
        "color": const Color(0xFF10B981),
        "products": [
          {"name": "Tablets", "image": ImagePaths.capsule2},
          {"name": "Inhaler", "image": ImagePaths.capsule},
        ],
        "patient": "Fatima Bilal",
        "date": "16 June 2025",
        "time": "04:45 PM",
        "amount": "5,100",
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: CustomScrollView(
        slivers: [
          // Stunning Sticky Header
          SliverAppBar(
            expandedHeight: 220,
            floating: true,
            pinned: true,
            backgroundColor: AppColors.white,
            elevation: 0,
            leading: const CustomBackButton(),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF10B981).withValues(alpha: 0.05),
                      Colors.white,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(isWeb ? 60 : 20, 40, 40, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CustomText(
                        text: "ORDER HISTORY",
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF10B981),
                        letterSpacing: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: CustomText(
                              text: "Delivered Orders",
                              fontSize: isWeb ? 36 : 24,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          if (isWeb)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 16,
                                    color: Color(0xFF64748B),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Last 30 Days",
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Search and Stats (Web)
          if (isWeb)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 60,
                  vertical: 24,
                ),
                child: Row(
                  children: [
                    _buildStatMiniCard(
                      "Total Delivered",
                      "842",
                      const Color(0x00002982),
                    ),
                    const SizedBox(width: 24),
                    _buildStatMiniCard(
                      "Success Rate",
                      "98.2%",
                      const Color(0xFF10B981),
                    ),
                    const Spacer(),
                    Container(
                      width: 300,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const TextField(
                        decoration: InputDecoration(
                          hintText: "Search ID, Patient...",
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: Color(0xFF94A3B8),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Orders List/Grid
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
                          mainAxisExtent: 260,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildModernOrderCard(orders[i], isWeb),
                      childCount: orders.length,
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildModernOrderCard(orders[i], isWeb),
                      childCount: orders.length,
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildStatMiniCard(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomText(
          text: label,
          fontSize: 13,
          color: const Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
        const SizedBox(height: 4),
        CustomText(
          text: value,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF0F172A),
        ),
      ],
    );
  }

  Widget _buildModernOrderCard(Map<String, dynamic> order, bool isWeb) {
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
              // Product Stack
              Stack(
                children: List.generate(
                  order['products'].length > 2 ? 2 : order['products'].length,
                  (index) => Container(
                    margin: EdgeInsets.only(left: index * 20.0),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Image.asset(
                      order['products'][index]['image'],
                      height: 32,
                      width: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Order Identity
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      text: order['id'],
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                    const SizedBox(height: 4),
                    CustomText(
                      text: "Patient: ${order['patient']}",
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
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 12,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    CustomText(
                      text: order['status'],
                      color: order['color'],
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ],
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
                    text: order['date'],
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                  CustomText(
                    text: "PKR ${order['amount']}",
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF10B981),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF0FDF4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  children: const [
                    Text(
                      "Order Receipt",
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.description_rounded,
                      size: 12,
                      color: Color(0xFF10B981),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
