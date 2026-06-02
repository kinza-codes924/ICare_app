import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/select_payment_method.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';

class REceiptScreen extends StatelessWidget {
  final Map<String, dynamic>? bookingData;
  final String labName;

  const REceiptScreen({
    super.key,
    this.bookingData,
    this.labName = "Quantum Spar Lab",
  });

  @override
  Widget build(BuildContext context) {
    // Support both 'tests' list and 'test_type' string
    final rawTests = bookingData?['tests'];
    final List<String> tests;
    if (rawTests is List && rawTests.isNotEmpty) {
      tests = rawTests.cast<String>();
    } else if (bookingData?['test_type'] != null) {
      // test_type is a comma-separated string like "CBC, Blood Sugar"
      tests = bookingData!['test_type'].toString().split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    } else if (bookingData?['testType'] != null) {
      tests = bookingData!['testType'].toString().split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    } else {
      tests = [];
    }
    
    // Calculate price: Rs. 3000 per test
    final int testCount = tests.isNotEmpty ? tests.length : 1;
    final totalPrice = bookingData?['totalPrice'] ?? bookingData?['price'] ?? (testCount * 3000);
    final date = bookingData?['test_date'] ?? bookingData?['date'] ?? "Not set";
    final time = bookingData?['time'] ?? "Not set";
    final bookingId = bookingData?['_id'] ?? bookingData?['id'] ?? "N/A";

    return Scaffold(
      appBar: AppBar(
        leading: const CustomBackButton(),
        automaticallyImplyLeading: false,
        title: CustomText(
          text: "Booking Receipt",
          fontFamily: "Gilroy-Bold",
          fontSize: 16.78,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.31,
          lineHeight: 1.0,
          color: AppColors.primary500,
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: ScallingConfig.scale(30)),
              Container(
                width: Utils.windowWidth(context) * 0.9,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 60,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: CustomText(
                        text: "Booking Confirmed!",
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.themeDarkGrey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildRow("Lab Name", labName),
                    _buildRow(
                      "Booking ID",
                      bookingId.toString().substring(
                        bookingId.toString().length > 8
                            ? bookingId.toString().length - 8
                            : 0,
                      ),
                    ),
                    _buildRow("Date", date),
                    _buildRow("Time", time),
                    const SizedBox(height: 16),
                    const CustomText(
                      text: "Selected Tests:",
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    const SizedBox(height: 8),
                    ...tests.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: CustomText(
                          text: "• $t",
                          fontSize: 13,
                          color: AppColors.grayColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const CustomText(
                          text: "Total Amount",
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        CustomText(
                          text: "PKR $totalPrice",
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: ScallingConfig.scale(40)),
              CustomButton(
                label: "Pay Now",
                width: Utils.windowWidth(context) * 0.9,
                borderRadius: 35,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => SelectPaymentMethod(
                        labBookingId: bookingId,
                        amount: totalPrice.toDouble(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const CustomText(
                  text: "Back to Home",
                  color: AppColors.grayColor,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CustomText(text: label, color: AppColors.grayColor, fontSize: 14),
          CustomText(text: value, fontWeight: FontWeight.bold, fontSize: 14),
        ],
      ),
    );
  }
}
