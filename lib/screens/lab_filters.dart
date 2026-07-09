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

class LabFilters extends StatefulWidget {
  const LabFilters({super.key});

  @override
  State<LabFilters> createState() => _LabFiltersState();
}

class _LabFiltersState extends State<LabFilters> {
  String? _selectedSortByOption;

  final List<String> sortByOptions = [
    "distance",
    "newest",
    "oldest",
    "price_low_to_high",
    "price_high_to_low",
    "rating",
  ];

  List<String> reviewOptions = [
    'All Reviews',
    '5 Stars',
    '4 Stars',
    '3 Stars',
    '2 Stars',
    '1 Star',
    'With Comments',
    'With Photos',
    'Most Recent',
    'Oldest',
  ];
  String? _review;
  var _isHomeSample = false;

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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChooseLocationButton(),
                  CustomDropdown<String>(
                    title: "Reviews",
                    selectedItem: _review,
                    margin: EdgeInsets.symmetric(
                      vertical: ScallingConfig.verticalScale(6),
                    ),
                    items: reviewOptions,
                    onChanged: (value) {
                      setState(() {
                        _review = value!;
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
                  ToggleSwitchButtonWithPlaceholder(
                    title: "Home Sample",
                    value: _isHomeSample,
                    onToggle: (value) {
                      setState(() {
                        _isHomeSample = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: ScallingConfig.verticalScale(40)),
            child: CustomButton(
              label: "Search",
              borderRadius: 30,
              width: Utils.windowWidth(context) * 0.9,
            ),
          ),
        ],
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
          "Filter Laboratories",
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
                  "Lab Search Filters",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Find the best laboratory nearby with specific preferences.",
                  style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 40),

                // Filters Grid
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    _buildWebDropdown(
                      "Minimum Rating / Reviews",
                      reviewOptions,
                      _review,
                      (val) {
                        setState(() => _review = val);
                      },
                    ),
                    _buildWebDropdown(
                      "Sort Order",
                      sortByOptions,
                      _selectedSortByOption,
                      (val) {
                        setState(() => _selectedSortByOption = val);
                      },
                    ),

                    // Toggle for web
                    SizedBox(
                      width: 328,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Special Requirements",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Home Sample Available",
                                  style: TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 14,
                                  ),
                                ),
                                Switch(
                                  value: _isHomeSample,
                                  activeThumbColor: AppColors.primaryColor,
                                  onChanged: (val) {
                                    setState(() => _isHomeSample = val);
                                  },
                                ),
                              ],
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
                SizedBox(width: double.infinity, child: ChooseLocationButton()),

                const SizedBox(height: 56),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _review = null;
                            _selectedSortByOption = null;
                            _isHomeSample = false;
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
                          "Reset Filters",
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
                          "Show Laboratories",
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
