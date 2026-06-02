import 'package:flutter/material.dart';
import 'package:icare/models/lab_test.dart';
import 'package:icare/screens/confirm_booking.dart';
import 'package:icare/services/laboratory_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';

class SelectTest extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  const SelectTest({super.key, required this.bookingData});

  @override
  State<SelectTest> createState() => _SelectTestState();
}

class _SelectTestState extends State<SelectTest> {
  final LaboratoryService _labService = LaboratoryService();
  final List<LabTest> _selectedTests = [];
  List<LabTest> _allTests = [];
  List<LabTest> _filteredTests = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchLabTests();
  }

  Future<void> _fetchLabTests() async {
    try {
      // Use profileId for fetching lab details (availableTests),
      // labId (user._id) is only used for booking creation routes
      final labId = widget.bookingData['labProfileId'] ?? widget.bookingData['labId'];
      if (labId == null) throw 'Lab ID is missing';

      final lab = await _labService.getLabById(labId);
      final List<dynamic> testsData = lab['availableTests'] ?? [];

      final List<LabTest> loadedTests = testsData.map((t) {
        return LabTest(
          id: t['_id'] ?? t['name'] ?? DateTime.now().toString(),
          name: t['name']?.toString() ?? 'Unnamed Test',
          price: (t['price'] ?? 0).toDouble(),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _allTests = loadedTests;
          _filteredTests = loadedTests;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching lab tests: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _filteredTests = _allTests
          .where((t) => t.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  double get _totalPrice =>
      _selectedTests.fold(0, (sum, item) => sum + item.price);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              _buildSearchBar(),
              _isLoading
                  ? _buildLoadingState()
                  : _allTests.isEmpty
                  ? _buildEmptyState()
                  : _buildTestsList(),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          if (_selectedTests.isNotEmpty) _buildStickySummaryFooter(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: AppColors.primaryColor,
      leading: const CustomBackButton(),
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryColor, Color(0xFF1E40AF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'STEP 2 OF 3',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                CustomText(
                  text: 'Select Lab Tests',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontFamily: 'Gilroy-Bold',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            onChanged: _onSearch,
            decoration: const InputDecoration(
              hintText: "Search for tests (e.g. CBC, Liver...)",
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppColors.primaryColor,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const SliverFillRemaining(
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.biotech_rounded, size: 80, color: Colors.grey[200]),
            const SizedBox(height: 20),
            const Text(
              "No tests available for this laboratory",
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Go Back and Select Another Lab"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestsList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((ctx, i) {
          final test = _filteredTests[i];
          final bool isSelected = _selectedTests.any((t) => t.id == test.id);
          return _buildTestCard(test, isSelected);
        }, childCount: _filteredTests.length),
      ),
    );
  }

  Widget _buildTestCard(LabTest test, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedTests.removeWhere((t) => t.id == test.id);
            } else {
              _selectedTests.add(test);
            }
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryColor.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryColor
                  : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryColor.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryColor
                        : const Color(0xFFCBD5E1),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  color: isSelected
                      ? AppColors.primaryColor
                      : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      test.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? AppColors.primaryColor
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "PKR ${test.price.toInt()}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppColors.primaryColor.withValues(alpha: 0.7)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickySummaryFooter() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${_selectedTests.length} tests selected",
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    "Total: PKR ${_totalPrice.toInt()}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => ConfirmBookingScreen(
                      bookingData: widget.bookingData,
                      selectedTests: _selectedTests,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Row(
                children: [
                  Text("Review", style: TextStyle(fontWeight: FontWeight.w900)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
