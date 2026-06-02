import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/receipt.dart';
import 'package:icare/services/laboratory_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/custom_text_input.dart';
import 'package:intl/intl.dart';

class FillLabForm extends StatefulWidget {
  final Map<String, dynamic>? labData;
  final List<String>? selectedTests;
  final String? prescriptionId;

  const FillLabForm({super.key, this.labData, this.selectedTests, this.prescriptionId});

  @override
  State<FillLabForm> createState() => _FillLabFormState();
}

class _FillLabFormState extends State<FillLabForm> {
  final _labService = LaboratoryService();

  final _nameController = TextEditingController();
  final _patientNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _ageController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _homeSample = false;
  bool _isLoading = false;
  String _selectedGender = 'Male';

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _timeController.text = "10:00 AM";
    if (widget.labData?['address'] != null) {
      _locationController.text = widget.labData?['address'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _patientNameController.dispose();
    _locationController.dispose();
    _ageController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _bookNow() async {
    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _patientNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('🔍 LAB BOOKING DEBUG - Full labData: ${widget.labData}');
      final labId = widget.labData?['_id'] ?? widget.labData?['id'];
      debugPrint('🔍 LAB BOOKING DEBUG - Extracted labId: $labId');
      debugPrint('🔍 LAB BOOKING DEBUG - labData keys: ${widget.labData?.keys.toList()}');
      
      if (labId == null) {
        throw Exception("Laboratory ID missing");
      }

      // Backend expects: testType (required), testDate (optional), notes (optional)
      final tests = widget.selectedTests ?? ["Complete Blood Count (CBC)"];
      final bookingData = {
        'testType': tests.join(', '),
        'test_type': tests.join(', '),
        'testDate': _dateController.text,
        'date': _dateController.text,
        // Send patient details as separate fields
        'patientName': _patientNameController.text.trim(),
        'patient_name': _patientNameController.text.trim(),
        'patientAge': _ageController.text.trim(),
        'patient_age': _ageController.text.trim(),
        'patientGender': _selectedGender,
        'patient_gender': _selectedGender,
        'patientPhone': _phoneController.text.trim(),
        'patient_phone': _phoneController.text.trim(),
        'patientAddress': _locationController.text.trim(),
        'patient_address': _locationController.text.trim(),
        'collectionType': _homeSample ? 'home' : 'in-lab',
        'collection_type': _homeSample ? 'home' : 'in-lab',
        'notes': 'Requester: ${_nameController.text.trim()}, Time: ${_timeController.text}',
        if (widget.prescriptionId != null && widget.prescriptionId!.isNotEmpty)
          'prescriptionId': widget.prescriptionId,
        if (widget.prescriptionId != null && widget.prescriptionId!.isNotEmpty)
          'medicalRecordId': widget.prescriptionId,
      };

      debugPrint('🔍 LAB BOOKING DEBUG - Booking data: $bookingData');
      debugPrint('🔍 LAB BOOKING DEBUG - Calling createBooking with labId: $labId');
      
      final booking = await _labService.createBooking(labId, bookingData);
      
      debugPrint('✅ LAB BOOKING DEBUG - Booking created successfully: $booking');

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => REceiptScreen(
              bookingData: booking,
              labName:
                  widget.labData?['labName'] ??
                  widget.labData?['name'] ??
                  "Lab",
            ),
          ),
        );
      }
    } catch (e) {
      log("Booking error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = ResponsiveHelper.isDesktop(context);

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              leading: const CustomBackButton(),
              automaticallyImplyLeading: false,
              title: const CustomText(text: "Fill this form"),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (isDesktop
                ? _buildWebLayout(context)
                : _buildMobileLayout(context)),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          CustomText(
            text: "Selected Tests",
            width: Utils.windowWidth(context) * 0.9,
            color: AppColors.themeDarkGrey,
            fontSize: 14,
            fontFamily: "Gilroy-Bold",
          ),
          SizedBox(height: ScallingConfig.scale(10)),
          ...(widget.selectedTests ?? ["Complete Blood Count (CBC)"]).map(
            (test) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: Utils.windowWidth(context) * 0.9,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ScheduledTest(name: test),
                    const CustomText(
                      text: "PKR 3000",
                      fontSize: 12,
                      fontFamily: "vGilroy-SemiBold",
                      color: AppColors.primary500,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: ScallingConfig.scale(15)),
          CustomText(
            text: "Add Details",
            width: Utils.windowWidth(context) * 0.9,
            color: AppColors.themeDarkGrey,
            fontSize: 14,
            fontFamily: "Gilroy-Bold",
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomInputField(
                controller: _nameController,
                hintText: "Your Name",
                borderRadius: 0,
                hintStyle: TextStyle(
                  color: AppColors.grayColor.withAlpha(70),
                  fontFamily: "Gilroy-Medium",
                  fontSize: 14.78,
                ),
                width: Utils.windowWidth(context) * 0.4,
                borderType: const Border(
                  bottom: BorderSide(color: AppColors.lightGrey10, width: 1.5),
                ),
              ),
              SizedBox(width: ScallingConfig.scale(20)),
              CustomInputField(
                controller: _patientNameController,
                hintText: "Patient Name",
                borderRadius: 0,
                hintStyle: TextStyle(
                  color: AppColors.grayColor.withAlpha(70),
                  fontFamily: "Gilroy-Medium",
                  fontSize: 14.78,
                ),
                width: Utils.windowWidth(context) * 0.4,
                borderType: const Border(
                  bottom: BorderSide(color: AppColors.lightGrey10, width: 1.5),
                ),
              ),
            ],
          ),
          SizedBox(height: ScallingConfig.scale(15)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomInputField(
                controller: _locationController,
                hintText: "Address",
                borderRadius: 0,
                hintStyle: TextStyle(
                  color: AppColors.grayColor.withAlpha(70),
                  fontFamily: "Gilroy-Medium",
                  fontSize: 14.78,
                ),
                width: Utils.windowWidth(context) * 0.4,
                borderType: const Border(
                  bottom: BorderSide(color: AppColors.lightGrey10, width: 1.5),
                ),
              ),
              SizedBox(width: ScallingConfig.scale(20)),
              CustomInputField(
                controller: _ageController,
                hintText: "Age",
                borderRadius: 0,
                hintStyle: TextStyle(
                  color: AppColors.grayColor.withAlpha(70),
                  fontFamily: "Gilroy-Medium",
                  fontSize: 14.78,
                ),
                width: Utils.windowWidth(context) * 0.4,
                borderType: const Border(
                  bottom: BorderSide(color: AppColors.lightGrey10, width: 1.5),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          SizedBox(height: ScallingConfig.scale(15)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomInputField(
                controller: _dateController,
                hintText: "Date",
                borderRadius: 0,
                hintStyle: TextStyle(
                  color: AppColors.grayColor.withAlpha(70),
                  fontFamily: "Gilroy-Medium",
                  fontSize: 14.78,
                ),
                width: Utils.windowWidth(context) * 0.4,
                borderType: const Border(
                  bottom: BorderSide(color: AppColors.lightGrey10, width: 1.5),
                ),
              ),
              SizedBox(width: ScallingConfig.scale(20)),
              CustomInputField(
                controller: _timeController,
                hintText: "Time",
                borderRadius: 0,
                hintStyle: TextStyle(
                  color: AppColors.grayColor.withAlpha(70),
                  fontFamily: "Gilroy-Medium",
                  fontSize: 14.78,
                ),
                width: Utils.windowWidth(context) * 0.4,
                borderType: const Border(
                  bottom: BorderSide(color: AppColors.lightGrey10, width: 1.5),
                ),
              ),
            ],
          ),
          SizedBox(height: ScallingConfig.scale(15)),
          CustomInputField(
            controller: _phoneController,
            hintText: "Phone Number",
            borderRadius: 0,
            hintStyle: TextStyle(
              color: AppColors.grayColor.withAlpha(70),
              fontFamily: "Gilroy-Medium",
              fontSize: 14.78,
            ),
            width: Utils.windowWidth(context) * 0.9,
            borderType: const Border(
              bottom: BorderSide(color: AppColors.lightGrey10, width: 1.5),
            ),
            keyboardType: TextInputType.phone,
          ),
          SizedBox(height: ScallingConfig.scale(15)),
          // Gender selector
          SizedBox(
            width: Utils.windowWidth(context) * 0.9,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CustomText(text: "Gender", fontSize: 13, fontFamily: "Gilroy-Bold"),
                const SizedBox(height: 8),
                Row(
                  children: ['Male', 'Female', 'Other'].map((g) => Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedGender = g),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedGender == g ? AppColors.primaryColor : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          g,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selectedGender == g ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          SizedBox(height: ScallingConfig.scale(15)),
          // Collection Type
          SizedBox(
            width: Utils.windowWidth(context) * 0.9,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CustomText(text: "Sample Collection", fontSize: 13, fontFamily: "Gilroy-Bold"),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _homeSample = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_homeSample ? AppColors.primaryColor : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.business_rounded, size: 16, color: !_homeSample ? Colors.white : const Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text('In-Lab', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: !_homeSample ? Colors.white : const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _homeSample = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _homeSample ? const Color(0xFF0EA5E9) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.home_rounded, size: 16, color: _homeSample ? Colors.white : const Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text('Home Sample', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _homeSample ? Colors.white : const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: ScallingConfig.scale(20)),
          CustomButton(
            label: "Book Now",
            width: Utils.windowWidth(context) * 0.9,
            borderRadius: 35,
            onPressed: _bookNow,
          ),
        ],
      ),
    );
  }

  Widget _buildWebLayout(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Web Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                ),
                const SizedBox(width: 10),
                const CustomText(
                  text: "Book a Lab Test",
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Gilroy-Bold",
                ),
                const Spacer(),
                const Row(
                  children: [
                    Icon(Icons.security_rounded, color: Colors.green, size: 18),
                    SizedBox(width: 8),
                    CustomText(
                      text: "Secure Checkout",
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(60),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 50,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CustomText(
                        text: "Selected Tests",
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                      const SizedBox(height: 20),
                      ...(widget.selectedTests ??
                              ["Complete Blood Count (CBC)"])
                          .map(
                            (test) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(child: ScheduledTest(name: test)),
                                  const SizedBox(width: 20),
                                  CustomText(
                                    text: "PKR 3000",
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      const SizedBox(height: 48),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 48),

                      const CustomText(
                        text: "Add Details",
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                      const SizedBox(height: 8),
                      const CustomText(
                        text:
                            "Please provide the information for the person who will be tested.",
                        fontSize: 15,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          Expanded(
                            child: _buildWebInputField(
                              "Your Name",
                              "Enter your name",
                              Icons.person_outline_rounded,
                              _nameController,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildWebInputField(
                              "Patient Name",
                              "Enter patient name",
                              Icons.people_outline_rounded,
                              _patientNameController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _buildWebInputField(
                              "Address",
                              "Enter patient address",
                              Icons.location_on_outlined,
                              _locationController,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildWebInputField(
                              "Age",
                              "Enter patient age",
                              Icons.calendar_today_rounded,
                              _ageController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _buildWebInputField(
                              "Date",
                              "Select Date",
                              Icons.calendar_month_rounded,
                              _dateController,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildWebInputField(
                              "Time",
                              "Select Time",
                              Icons.access_time_rounded,
                              _timeController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildWebInputField(
                        "Phone Number",
                        "Enter phone number",
                        Icons.phone_outlined,
                        _phoneController,
                      ),
                      const SizedBox(height: 32),

                      // ── Gender ────────────────────────────────────────────
                      const CustomText(text: "Gender", fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      const SizedBox(height: 12),
                      Row(
                        children: ['Male', 'Female', 'Other'].map((g) => Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedGender = g),
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _selectedGender == g ? AppColors.primaryColor : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedGender == g ? AppColors.primaryColor : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                g,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedGender == g ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 32),

                      // ── Sample Collection ─────────────────────────────────
                      const CustomText(text: "Sample Collection", fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _homeSample = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: !_homeSample ? AppColors.primaryColor : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: !_homeSample ? AppColors.primaryColor : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.business_rounded, size: 18, color: !_homeSample ? Colors.white : const Color(0xFF64748B)),
                                    const SizedBox(width: 8),
                                    Text('In-Lab', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: !_homeSample ? Colors.white : const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _homeSample = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: _homeSample ? const Color(0xFF0EA5E9) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _homeSample ? const Color(0xFF0EA5E9) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.home_rounded, size: 18, color: _homeSample ? Colors.white : const Color(0xFF64748B)),
                                    const SizedBox(width: 8),
                                    Text('Home Sample', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _homeSample ? Colors.white : const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 60),

                      SizedBox(
                        width: double.infinity,
                        child: CustomButton(
                          height: 60,
                          borderRadius: 16,
                          label: "Book Now",
                          onPressed: _bookNow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebInputField(
    String label,
    String hint,
    IconData icon,
    TextEditingController controller,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomText(
          text: label,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF334155),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              icon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

class ScheduledTest extends StatelessWidget {
  final String name;
  const ScheduledTest({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ScallingConfig.scale(8),
        vertical: ScallingConfig.verticalScale(4),
      ),
      decoration: BoxDecoration(
        color: AppColors.secondaryColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: CustomText(
        text: name,
        color: AppColors.white,
        fontFamily: "Gilroy-SemiBold",
        fontSize: 12,
      ),
    );
  }
}
