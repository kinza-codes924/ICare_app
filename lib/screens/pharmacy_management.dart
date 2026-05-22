import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/models/app_enums.dart';
import 'package:icare/screens/cancelled_orders.dart';
import 'package:icare/screens/delievered_order.dart';
import 'package:icare/screens/filters.dart';
import 'package:icare/screens/recieved_orders.dart';
import 'package:icare/screens/transit_order.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/custom_text_input.dart';
import 'package:icare/widgets/order_type-card.dart';
import 'package:icare/widgets/section_header.dart';
import 'package:icare/widgets/seller_products.dart';
import 'package:icare/widgets/svg_wrapper.dart';

class PharmacyManagementScreen extends StatelessWidget {
  const PharmacyManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 900;

    if (isDesktop) {
      return _buildWebLayout(context);
    }

    return Scaffold(
      appBar: AppBar(
        leading: CustomBackButton(),
        automaticallyImplyLeading: false,
        title: CustomText(
          text: 'Pharmacy Management',
          fontFamily: "Gilroy-Bold",
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.primary500,
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              CustomInputField(
                width: Utils.windowWidth(context) * 0.9,
                hintText: "Search",
                trailingIcon: SvgWrapper(
                  assetPath: ImagePaths.filters,
                  onPress: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => FiltersScreen()),
                    );
                  },
                ),
                leadingIcon: SvgWrapper(assetPath: ImagePaths.search),
              ),
              SizedBox(height: ScallingConfig.scale(20)),
              SectionHeader(
                title: "Order Details",
                margin: EdgeInsets.symmetric(
                  horizontal: ScallingConfig.scale(10),
                ),
                showAction: false,
              ),
              SizedBox(height: ScallingConfig.scale(20)),
              SizedBox(
                width: Utils.windowWidth(context),
                height: Utils.windowHeight(context) * 0.6,
                child: GridView(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.all(20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isDesktop ? 5 : 2,
                    mainAxisExtent: isDesktop
                        ? 380
                        : Utils.windowHeight(context) *
                              0.27, // Increased from 340
                    crossAxisSpacing: isDesktop ? 24 : 20,
                    mainAxisSpacing: isDesktop ? 24 : 20,
                  ),
                  children: [
                    OrderTypecard(
                      type: OrderType.recent,
                      title: "Recent Orders",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (ctx) => RecievedOrders()),
                        );
                      },
                    ),
                    OrderTypecard(
                      type: OrderType.delivered,
                      title: "Delivered Orders",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => DelieveredOrder(),
                          ),
                        );
                      },
                    ),
                    OrderTypecard(
                      type: OrderType.cancelled,
                      title: "Cancelled Orders",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => CancelledOrders(),
                          ),
                        );
                      },
                    ),
                    OrderTypecard(
                      type: OrderType.inTransit,
                      title: "In-Transit Orders",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => TransitOrderScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: ScallingConfig.scale(20)),
              SectionHeader(
                title: "My Products",
                margin: EdgeInsets.symmetric(
                  horizontal: ScallingConfig.scale(15),
                ),
                onActionTap: () {
                  // Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => MyOrdersScreen() ));
                },
                showAction: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // Background Decorative Elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryColor.withValues(alpha: 0.03),
              ),
            ),
          ),

          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
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
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryColor.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.medication_liquid_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomText(
                          text: "PHARMACY PORTAL",
                          fontSize: 12,
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                        const SizedBox(height: 4),
                        CustomText(
                          text: "Inventory Management",
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -1,
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Modern Search
                    Container(
                      width: 350,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Search stock or orders...",
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF94A3B8),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 18,
                          ),
                          suffixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: Color(0xFF64748B),
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 50),

                // Stats Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAnimatedHeader("Order Statistics"),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          CustomText(
                            text: "Last 30 Days",
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Dynamic Orders Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                    mainAxisExtent:
                        260, // Increased from 240 to eliminate 4px overflow
                  ),
                  itemBuilder: (context, index) {
                    final List<Map<String, dynamic>> stats = [
                      {
                        "title": "Recent Orders",
                        "count": "128",
                        "trend": "+12%",
                        "icon": Icons.analytics_rounded,
                        "color": const Color(0xFF6366F1),
                        "onTap": () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (ctx) => RecievedOrders()),
                        ),
                      },
                      {
                        "title": "Delivered",
                        "count": "842",
                        "trend": "+5.4%",
                        "icon": Icons.verified_user_rounded,
                        "color": const Color(0xFF10B981),
                        "onTap": () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => DelieveredOrder(),
                          ),
                        ),
                      },
                      {
                        "title": "Cancelled",
                        "count": "15",
                        "trend": "-2%",
                        "icon": Icons.report_gmailerrorred_rounded,
                        "color": const Color(0xFFEF4444),
                        "onTap": () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => CancelledOrders(),
                          ),
                        ),
                      },
                      {
                        "title": "In Transit",
                        "count": "42",
                        "trend": "+8%",
                        "icon": Icons.speed_rounded,
                        "color": const Color(0xFFF59E0B),
                        "onTap": () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => TransitOrderScreen(),
                          ),
                        ),
                      },
                    ];
                    final stat = stats[index];
                    return _buildModernOrderCard(context, stat);
                  },
                ),

                const SizedBox(height: 60),

                // Products Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAnimatedHeader("Stock Inventory"),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF334155)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.add_circle_outline_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              CustomText(
                                text: "Add New Item",
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Products Grid Container
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SellerProducts(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primaryColor,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 12),
        CustomText(
          text: title,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1E293B),
          letterSpacing: -0.5,
        ),
      ],
    );
  }

  Widget _buildModernOrderCard(
    BuildContext context,
    Map<String, dynamic> stat,
  ) {
    final Color color = stat['color'];
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: stat['onTap'],
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  top: -20,
                  right: -20,
                  child: Icon(
                    stat['icon'],
                    size: 140,
                    color: color.withValues(alpha: 0.03),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    28,
                    28,
                    28,
                    28,
                  ), // Original padding was EdgeInsets.all(28)
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(stat['icon'], color: color, size: 24),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: stat['trend'].startsWith('+')
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              stat['trend'],
                              style: TextStyle(
                                color: stat['trend'].startsWith('+')
                                    ? const Color(0xFF166534)
                                    : const Color(0xFF991B1B),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            const Color(0xFF0F172A),
                            const Color(0xFF0F172A).withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: CustomText(
                          text: stat['count'],
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          CustomText(
                            text: stat['title'],
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_right_alt_rounded,
                            color: color.withValues(alpha: 0.4),
                            size: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
