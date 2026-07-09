import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/choose_location_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_drop_down.dart';
import 'package:icare/widgets/custom_text.dart';

class PharmacyFilterScreen extends StatefulWidget {
  const PharmacyFilterScreen({super.key});

  @override
  State<PharmacyFilterScreen> createState() => _PharmacyFilterScreenState();
}

class _PharmacyFilterScreenState extends State<PharmacyFilterScreen> {
  final List<String> medicineCategoryList = [
    'Pain Relief',
    'Antibiotics',
    'Vitamins & Supplements',
    'Diabetes Care',
    'Heart & BP',
    'Skin Care',
    'Cold & Flu',
  ];

  final List<String> medicineTypeList = [
    'Tablet',
    'Capsule',
    'Syrup',
    'Injection',
    'Cream / Ointment',
    'Drops',
  ];

  final List<String> brandManufacturerList = [
    'Pfizer',
    'GSK',
    'Novartis',
    'Sanofi',
    'Abbott',
    'Getz Pharma',
  ];

  final List<String> deliveryOptionList = [
    'Home Delivery',
    'Store Pickup',
    'Express Delivery',
  ];

  final List<String> reviewsList = [
    '1+ Stars',
    '2+ Stars',
    '3+ Stars',
    '4+ Stars',
    '5 Stars',
  ];

  /// 🔹 Selected values (centralized)
  String? _selectedMedicineCategory;
  String? _selectedMedicineType;
  String? _selectedBrandManufacturer;
  String? _selectedDeliveryOption;
  String? _selectedReviews;

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 900;

    if (isDesktop) {
      return _buildWebLayout(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: CustomText(
          text: "Filter",
          fontSize: 16.78,
          fontFamily: "Gilroy-Bold",
          fontWeight: FontWeight.bold,
          letterSpacing: -0.31,
          lineHeight: 1.0,
          color: AppColors.primary500,
        ),
        leading: CustomBackButton(),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              CustomDropdown<String>(
                title: "Category",
                selectedItem: _selectedMedicineCategory,
                margin: EdgeInsets.symmetric(
                  vertical: ScallingConfig.verticalScale(6),
                ),
                items: medicineCategoryList,
                onChanged: (value) {
                  setState(() {
                    _selectedMedicineCategory = value!;
                  });
                },
              ),
              CustomDropdown<String>(
                title: "Medicine Type",
                selectedItem: _selectedMedicineType,
                margin: EdgeInsets.symmetric(
                  vertical: ScallingConfig.verticalScale(6),
                ),
                items: medicineTypeList,
                onChanged: (value) {
                  setState(() {
                    _selectedMedicineType = value!;
                  });
                },
              ),
              CustomDropdown<String>(
                title: "Brand Manifacturer",
                selectedItem: _selectedBrandManufacturer,
                margin: EdgeInsets.symmetric(
                  vertical: ScallingConfig.verticalScale(6),
                ),
                items: brandManufacturerList,
                onChanged: (value) {
                  setState(() {
                    _selectedBrandManufacturer = value!;
                  });
                },
              ),
              ChooseLocationButton(label: "Near By Store Availability"),
              CustomDropdown<String>(
                title: "Delievery Option",
                margin: EdgeInsets.symmetric(
                  vertical: ScallingConfig.verticalScale(6),
                ),
                selectedItem: _selectedDeliveryOption,
                items: deliveryOptionList,
                onChanged: (value) {
                  setState(() {
                    _selectedDeliveryOption = value!;
                  });
                },
              ),
              CustomDropdown<String>(
                title: "Reviews",
                selectedItem: _selectedReviews,
                margin: EdgeInsets.symmetric(
                  vertical: ScallingConfig.verticalScale(6),
                ),
                items: reviewsList,
                onChanged: (value) {
                  setState(() {
                    _selectedReviews = value!;
                  });
                },
              ),
              SizedBox(height: ScallingConfig.scale(20)),
              CustomButton(
                label: "Search",
                borderRadius: 30,
                width: Utils.windowWidth(context) * 0.9,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        centerTitle: true,
        title: const Text(
          "Filter Pharmacy",
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Pharmacy Filters",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Refine your pharmacy search by category, manufacturer, or location.",
                  style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 40),

                // Filters Grid
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    _buildWebDropdown(
                      "Medicine Category",
                      medicineCategoryList,
                      _selectedMedicineCategory,
                      (val) {
                        setState(() => _selectedMedicineCategory = val);
                      },
                    ),
                    _buildWebDropdown(
                      "Medicine Type",
                      medicineTypeList,
                      _selectedMedicineType,
                      (val) {
                        setState(() => _selectedMedicineType = val);
                      },
                    ),
                    _buildWebDropdown(
                      "Manufacturer",
                      brandManufacturerList,
                      _selectedBrandManufacturer,
                      (val) {
                        setState(() => _selectedBrandManufacturer = val);
                      },
                    ),
                    _buildWebDropdown(
                      "Delivery Method",
                      deliveryOptionList,
                      _selectedDeliveryOption,
                      (val) {
                        setState(() => _selectedDeliveryOption = val);
                      },
                    ),
                    _buildWebDropdown(
                      "Minimum Reviews",
                      reviewsList,
                      _selectedReviews,
                      (val) {
                        setState(() => _selectedReviews = val);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                const Divider(height: 48, color: Color(0xFFF1F5F9)),

                const Text(
                  "Location Prefrences",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ChooseLocationButton(
                    label: "Near By Store Availability",
                  ),
                ),

                const SizedBox(height: 56),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedMedicineCategory = null;
                            _selectedMedicineType = null;
                            _selectedBrandManufacturer = null;
                            _selectedDeliveryOption = null;
                            _selectedReviews = null;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: const Text(
                          "Reset All",
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 10,
                          shadowColor: AppColors.primaryColor.withValues(alpha: 0.4),
                        ),
                        child: const Text(
                          "Find Pharmacies",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebDropdown(
    String title,
    List<String> items,
    String? selected,
    Function(String?) onChanged,
  ) {
    return SizedBox(
      width: 328,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButton<String>(
              value: selected,
              hint: const Text(
                "Select option",
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF94A3B8),
              ),
              items: items.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
