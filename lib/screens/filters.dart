import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_drop_down.dart';
import 'package:icare/widgets/custom_text.dart';

class FiltersScreen extends StatefulWidget {
  const FiltersScreen({super.key});

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  final List<String> specialityArray = [
    "Cardiologist",
    "Dermatologist",
    "Neurologist",
    "Orthopedic",
    "Pediatrician",
    "Psychiatrist",
    "Dentist",
  ];

  final List<String> availabilityArray = [
    "Today",
    "Tomorrow",
    "This Week",
    "Next Week",
  ];

  final List<String> consultationTypeArray = ["Video", "Audio", "In-Person"];

  final List<String> locationArray = [
    "Nearby",
    "Within 5 km",
    "Within 10 km",
    "Citywide",
  ];

  final List<String> reviewsArray = [
    "1+ Stars",
    "2+ Stars",
    "3+ Stars",
    "4+ Stars",
    "5 Stars",
  ];

  final List<String> languageArray = [
    "English",
    "Urdu",
    "Punjabi",
    "Pashto",
    "Sindhi",
    "Balochi",
  ];

  String? _selectedSpeciality;
  String? _selectedAvailablity;
  String? _selectedConsultationType;
  String? _selectedLocation;
  String? _selectedReviews;
  String? _selectedLanguage;

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
                title: "Speciality",
                selectedItem: _selectedSpeciality,
                margin: EdgeInsets.symmetric(
                  vertical: ScallingConfig.verticalScale(6),
                ),
                items: specialityArray,
                onChanged: (value) {
                  setState(() {
                    _selectedSpeciality = value!;
                  });
                },
              ),
              CustomDropdown<String>(
                title: "Availablity",
                selectedItem: _selectedAvailablity,
                margin: EdgeInsets.symmetric(
                  vertical: ScallingConfig.verticalScale(6),
                ),
                items: availabilityArray,
                onChanged: (value) {
                  setState(() {
                    _selectedAvailablity = value!;
                  });
                },
              ),
              CustomDropdown<String>(
                title: "Consultation Type",
                selectedItem: _selectedConsultationType,
                margin: EdgeInsets.symmetric(
                  vertical: ScallingConfig.verticalScale(6),
                ),
                items: consultationTypeArray,
                onChanged: (value) {
                  setState(() {
                    _selectedConsultationType = value!;
                  });
                },
              ),
              CustomDropdown<String>(
                title: "Reviews",
                selectedItem: _selectedReviews,
                margin: EdgeInsets.symmetric(
                  vertical: ScallingConfig.verticalScale(6),
                ),
                items: reviewsArray,
                onChanged: (value) {
                  setState(() {
                    _selectedReviews = value!;
                  });
                },
              ),
              CustomDropdown<String>(
                title: "Location",
                margin: EdgeInsets.symmetric(
                  vertical: ScallingConfig.verticalScale(6),
                ),
                selectedItem: _selectedLocation,
                items: locationArray,
                onChanged: (value) {
                  setState(() {
                    _selectedLocation = value!;
                  });
                },
              ),
              CustomDropdown<String>(
                title: "Language",
                margin: EdgeInsets.symmetric(
                  vertical: ScallingConfig.verticalScale(6),
                ),
                selectedItem: _selectedLanguage,
                items: languageArray,
                onChanged: (value) {
                  setState(() {
                    _selectedLanguage = value!;
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
          "Advanced Search Filters",
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
                  "Refine Your Search",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Choose your preferences to find the best specialists.",
                  style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 40),

                // Filters Grid
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    _buildWebDropdown(
                      "Speciality",
                      specialityArray,
                      _selectedSpeciality,
                      (val) {
                        setState(() => _selectedSpeciality = val);
                      },
                    ),
                    _buildWebDropdown(
                      "Availability",
                      availabilityArray,
                      _selectedAvailablity,
                      (val) {
                        setState(() => _selectedAvailablity = val);
                      },
                    ),
                    _buildWebDropdown(
                      "Consultation Type",
                      consultationTypeArray,
                      _selectedConsultationType,
                      (val) {
                        setState(() => _selectedConsultationType = val);
                      },
                    ),
                    _buildWebDropdown(
                      "Minimum Reviews",
                      reviewsArray,
                      _selectedReviews,
                      (val) {
                        setState(() => _selectedReviews = val);
                      },
                    ),
                    _buildWebDropdown(
                      "Location",
                      locationArray,
                      _selectedLocation,
                      (val) {
                        setState(() => _selectedLocation = val);
                      },
                    ),
                    _buildWebDropdown(
                      "Preferred Language",
                      languageArray,
                      _selectedLanguage,
                      (val) {
                        setState(() => _selectedLanguage = val);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 56),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedSpeciality = null;
                            _selectedAvailablity = null;
                            _selectedConsultationType = null;
                            _selectedLocation = null;
                            _selectedReviews = null;
                            _selectedLanguage = null;
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
                          "Apply Filters",
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
      width: 328, // Fix width for grid-like layout in wrap
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
