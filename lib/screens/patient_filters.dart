import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/choose_location_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_drop_down.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/toggle_switch_button_with_placeHolder.dart';

class PatientFiltersScreen extends StatefulWidget {
  const PatientFiltersScreen({super.key});

  @override
  State<PatientFiltersScreen> createState() => _PatientFiltersScreenState();
}

class _PatientFiltersScreenState extends State<PatientFiltersScreen> {
  var specialityArray = [
    "Cardiologist",
    "Dermatologist",
    "Neurologist",
    "Orthopedic",
    "Pediatrician",
    "Psychiatrist",
    "Dentist",
  ];
  final List<String> reviewsList = [
    '1+ Stars',
    '2+ Stars',
    '3+ Stars',
    '4+ Stars',
    '5 Stars',
  ];

  final List<String> sortByOptions = [
    "distance",
    "newest",
    "oldest",
    "price_low-to-high",
    "price_high-to-low",
    "rating",
  ];
  final List<String> pharmacyTypeList = [
    "24/7",
    "Retail",
    "Hospital",
    "Community",
    "Clinical",
    "Online",
    "Compounding",
    "Specialty",
    "Home Care",
    "Wholesale",
    "Veterinary",
  ];

  final List<String> spokenLanguagesList = [
    'Urdu',
    'Punjabi',
    'Pashto',
    'Sindhi',
    'Balochi',
    'English',
  ];

  String? _selectedSpeciality;
  String? _selectedReviews;
  String? _selectedSortByOption;
  String? _selectedPharmacyType;
  String? _selectedSpokenLanguage;
  bool _medicineAvailablity = false;
  bool _homeAvailablity = false;

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
              ChooseLocationButton(label: "Choose Location"),
              CustomDropdown<String>(
                title: "Doctor's Speciality",
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
              CustomDropdown<String>(
                title: "Sort By",
                selectedItem: _selectedSortByOption,
                margin: EdgeInsets.symmetric(
                  vertical: ScallingConfig.verticalScale(6),
                ),
                items: sortByOptions,
                onChanged: (value) {
                  setState(() {
                    _selectedSortByOption = value!;
                  });
                },
              ),
              CustomDropdown<String>(
                title: "Spoken Language",
                selectedItem: _selectedSpokenLanguage,
                margin: EdgeInsets.symmetric(
                  vertical: ScallingConfig.verticalScale(6),
                ),
                items: spokenLanguagesList,
                onChanged: (value) {
                  setState(() {
                    _selectedSpokenLanguage = value!;
                  });
                },
              ),
              CustomDropdown<String>(
                title: "Pharmcy Type (Optional)",
                selectedItem: _selectedPharmacyType,
                margin: EdgeInsets.symmetric(
                  vertical: ScallingConfig.verticalScale(6),
                ),
                items: pharmacyTypeList,
                onChanged: (value) {
                  setState(() {
                    _selectedPharmacyType = value!;
                  });
                },
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ScallingConfig.scale(5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ToggleSwitchButtonWithPlaceholder(
                      value: _medicineAvailablity,
                      onToggle: (value) {
                        setState(() {
                          _medicineAvailablity = value;
                        });
                      },
                      title: "Medicine Availability",
                      width: Utils.windowWidth(context) * 0.42,
                    ),
                    SizedBox(width: ScallingConfig.scale(18)),
                    ToggleSwitchButtonWithPlaceholder(
                      title: "Home Availability",
                      value: _homeAvailablity,
                      onToggle: (value) {
                        setState(() {
                          _homeAvailablity = value;
                        });
                      },
                      width: Utils.windowWidth(context) * 0.42,
                    ),
                  ],
                ),
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
          "Filter Results",
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
                  "Patient Preferences",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Customize your search to find the perfect medical service.",
                  style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 40),

                // Filters Grid
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    _buildWebDropdown(
                      "Doctor's Speciality",
                      specialityArray,
                      _selectedSpeciality,
                      (val) {
                        setState(() => _selectedSpeciality = val);
                      },
                    ),
                    _buildWebDropdown(
                      "Minimum Rating",
                      reviewsList,
                      _selectedReviews,
                      (val) {
                        setState(() => _selectedReviews = val);
                      },
                    ),
                    _buildWebDropdown(
                      "Sort By",
                      sortByOptions,
                      _selectedSortByOption,
                      (val) {
                        setState(() => _selectedSortByOption = val);
                      },
                    ),
                    _buildWebDropdown(
                      "Spoken Language",
                      spokenLanguagesList,
                      _selectedSpokenLanguage,
                      (val) {
                        setState(() => _selectedSpokenLanguage = val);
                      },
                    ),
                    _buildWebDropdown(
                      "Pharmacy Type (Optional)",
                      pharmacyTypeList,
                      _selectedPharmacyType,
                      (val) {
                        setState(() => _selectedPharmacyType = val);
                      },
                    ),

                    // Toggle Area
                    SizedBox(
                      width: double.infinity,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildWebToggle(
                              "Medicine Availability",
                              _medicineAvailablity,
                              (val) {
                                setState(() => _medicineAvailablity = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildWebToggle(
                              "Home Availability",
                              _homeAvailablity,
                              (val) {
                                setState(() => _homeAvailablity = val);
                              },
                            ),
                          ),
                        ],
                      ),
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
                    label: "Set Your Current Location",
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
                            _selectedSpeciality = null;
                            _selectedReviews = null;
                            _selectedSortByOption = null;
                            _selectedPharmacyType = null;
                            _selectedSpokenLanguage = null;
                            _medicineAvailablity = false;
                            _homeAvailablity = false;
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
                          "Search results",
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

  Widget _buildWebToggle(String title, bool value, Function(bool) onChanged) {
    return Column(
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Enabled",
                style: TextStyle(color: Color(0xFF1E293B), fontSize: 14),
              ),
              Switch(
                value: value,
                activeThumbColor: AppColors.primaryColor,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
