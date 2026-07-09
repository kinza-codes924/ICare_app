import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';

class ActiveOrdersScreen extends StatelessWidget {
  const ActiveOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    if (isDesktop) {
      return const _WebActiveOrdersScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBFA),
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: const CustomBackButton(),
        title: CustomText(
          text: "Active Orders".tr(),
          fontSize: 16.78,
          fontFamily: "Gilroy-Bold",
          fontWeight: FontWeight.bold,
          letterSpacing: -0.31,
          lineHeight: 1.0,
          color: AppColors.primary500,
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 2,
        itemBuilder: (context, index) {
          return const CompletedReportCard();
        },
      ),
    );
  }
}

class _WebActiveOrdersScreen extends StatelessWidget {
  const _WebActiveOrdersScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        leadingWidth: 100,
        leading: const Padding(
          padding: EdgeInsets.only(left: 40, top: 20),
          child: CustomBackButton(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Stunning Header
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 10),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Active Orders",
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontFamily: "Gilroy-Bold",
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Manage and track your ongoing laboratory orders in real-time.",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 25,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryColor, Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: const [
                        Text(
                          "Total Active",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "120",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontFamily: "Gilroy-Bold",
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search and Filter Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(50, 40, 50, 30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1600),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Recent Orders",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                        fontFamily: "Gilroy-Bold",
                      ),
                    ),
                    Container(
                      width: 350,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF94A3B8),
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: "Search orders...",
                                hintStyle: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Grid of Orders
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1600),
                child: Wrap(
                  spacing: 30,
                  runSpacing: 30,
                  alignment: WrapAlignment.start,
                  children: List.generate(
                    6,
                    (index) =>
                        const SizedBox(width: 400, child: _WebOrderCard()),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _WebOrderCard extends StatelessWidget {
  const _WebOrderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 25,
            offset: const Offset(0, 10),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.science_rounded,
                  color: AppColors.primaryColor,
                  size: 28,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Sample Ready",
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: "Gilroy-SemiBold",
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "Quantum Spar Lab",
            style: TextStyle(
              fontSize: 22,
              fontFamily: "Gilroy-Bold",
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1.5),
          const SizedBox(height: 24),
          _webInfoRow(Icons.person_outline_rounded, 'Patient', 'Sadia'),
          _webInfoRow(
            Icons.location_on_outlined,
            'Address',
            'Shahrah-e-faisal near KFC, Street 1',
            maxLines: 2,
          ),
          _webInfoRow(Icons.cake_outlined, 'Age', '32'),
          _webInfoRow(Icons.calendar_today_outlined, 'Date', '21 June 2025'),
          _webInfoRow(Icons.access_time_rounded, 'Time', '12:00 PM'),
          _webInfoRow(Icons.phone_outlined, 'Phone', '03098949375'),
        ],
      ),
    );
  }

  static Widget _webInfoRow(
    IconData icon,
    String label,
    String value, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: "Gilroy-SemiBold",
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CompletedReportCard extends StatelessWidget {
  const CompletedReportCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 19),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
            text: "Quantum Spar Lab",
            fontSize: 18,
            fontFamily: "Gilroy-Bold",
            fontWeight: FontWeight.bold,
            color: AppColors.themeDarkGrey,
          ),
          const SizedBox(height: 12),

          _infoRow('Patient Name', 'Sadia'),
          _infoRow('Address', 'Shahrah-e-faisal near KFC\nStreet 1'),
          _infoRow('Age', '32'),
          _infoRow('Date', '21 June 2025'),
          _infoRow('Time', '12:PM'),
          _infoRow('Phone Number', '03098949375'),

          const SizedBox(height: 12),

          // const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              CustomText(
                text: "Status",
                fontSize: 12,
                fontFamily: "Gilroy-Medium",
                fontWeight: FontWeight.w400,
                color: AppColors.themeDarkGrey,
              ),
              CustomText(
                text: "Sample Ready for test",
                fontSize: 12,
                fontFamily: "Gilroy-Bold",
                fontWeight: FontWeight.w400,
                color: AppColors.themeDarkGrey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
            text: label,
            fontSize: 13,
            fontFamily: "Gilroy-Medium",
            fontWeight: FontWeight.w400,
            color: AppColors.themeDarkGrey,
          ),
          CustomText(
            text: value,
            fontSize: 13,
            fontFamily: "Gilroy-SemiBold",
            fontWeight: FontWeight.w400,
            color: AppColors.themeDarkGrey,
          ),
        ],
      ),
    );
  }
}
