import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/models/lab_test.dart';
import 'package:icare/screens/tabs.dart';
import 'package:icare/services/laboratory_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

class ConfirmBookingScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final List<LabTest> selectedTests;

  const ConfirmBookingScreen({
    super.key,
    required this.bookingData,
    required this.selectedTests,
  });

  @override
  State<ConfirmBookingScreen> createState() => _ConfirmBookingScreenState();
}

class _ConfirmBookingScreenState extends State<ConfirmBookingScreen> {
  final LaboratoryService _labService = LaboratoryService();
  bool _isLoading = false;

  double get _totalPrice {
    double total = 0;
    for (var test in widget.selectedTests) {
      final price = (test.price as num).toDouble();
      total += price > 0 ? price : 3000;
    }
    return total;
  }

  Future<void> _processBooking() async {
    setState(() => _isLoading = true);
    try {
      final labId = widget.bookingData['labId'];
      final testNames = widget.selectedTests.map((e) => e.name).join(', ');
      final bookingDetails = {
        'testType': testNames,
        'test_type': testNames,
        'testName': testNames,
        'date': widget.bookingData['date'],
        'testDate': widget.bookingData['date'],
        'time': widget.bookingData['time'],
        'contactLocation': widget.bookingData['address'],
        'city': widget.bookingData['city'],
        'homeSample': widget.bookingData['homeSample'],
        'collection_type': widget.bookingData['homeSample'] == true ? 'home' : 'walk-in',
        'totalAmount': _totalPrice,
        'contactName': 'Patient User',
        'contactPhone': '0000000000',
        'age': 25,
      };

      await _labService.createBooking(labId, bookingDetails);

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking failed. Please try again.'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              'Booking Successful!'.tr(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your lab test has been booked successfully. You can track it in your profile.'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (ctx) => const TabsScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Go to Home'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0B2D6E);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Text(
          'Booking Summary'.tr(),
          style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Laboratory Information'.tr()),
              _buildDetailCard([
                _buildInfoLine(
                  Icons.business_rounded,
                  'Lab Name'.tr(),
                  widget.bookingData['labTitle'] ?? 'Green Lab',
                ),
                _buildInfoLine(
                  Icons.location_on_rounded,
                  'Location'.tr(),
                  widget.bookingData['city'] ?? 'Default City',
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader('Schedule Details'.tr()),
              _buildDetailCard([
                _buildInfoLine(
                  Icons.calendar_today_rounded,
                  'Date'.tr(),
                  widget.bookingData['date'] ?? 'Jan 1, 2024',
                ),
                _buildInfoLine(
                  Icons.access_time_rounded,
                  'Time'.tr(),
                  widget.bookingData['time'] ?? '10:00 AM',
                ),
                _buildInfoLine(
                  Icons.home_rounded,
                  'Sample Type'.tr(),
                  widget.bookingData['homeSample']
                      ? 'Home Collection'.tr()
                      : 'Walk-in'.tr(),
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader('Selected Tests'.tr()),
              _buildDetailCard(
                widget.selectedTests
                    .map((t) => _buildTestLine(t.name, 'PKR ${(t.price as num) > 0 ? t.price : 3000}'))
                    .toList(),
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Payment Summary'.tr()),
              _buildDetailCard([
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount'.tr(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'PKR $_totalPrice',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _processBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Confirm & Pay'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xFF64748B),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDetailCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0D47A1)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTestLine(String name, String price) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            price,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
            ),
          ),
        ],
      ),
    );
  }
}
