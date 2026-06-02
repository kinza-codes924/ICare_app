import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/fill_lab_form.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/svg_wrapper.dart';

class LabDetails extends StatefulWidget {
  const LabDetails({super.key, this.labData, this.prescribedTests, this.prescriptionId});
  final Map<String, dynamic>? labData;
  final List<String>? prescribedTests; // pre-select from prescription
  final String? prescriptionId;

  @override
  State<LabDetails> createState() => _LabDetailsState();
}

class _LabDetailsState extends State<LabDetails> {
  late List<String> _selectedTests;

  @override
  void initState() {
    super.initState();
    // Pre-select prescribed tests if coming from prescription flow
    _selectedTests = List<String>.from(widget.prescribedTests ?? []);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = ResponsiveHelper.isDesktop(context);
    final labData = widget.labData;

    final String name = (labData?['labName'] is String)
        ? (labData?['labName'] as String)
        : ((labData?['name'] is String)
              ? (labData?['name'] as String)
              : "Quantum Spar Lab");
    final String address = (labData?['address'] is String)
        ? (labData?['address'] as String)
        : ((labData?['location'] is String)
              ? (labData?['location'] as String)
              : "4915 Muller Radial, 84904, USA");
    final String open = (labData?['open'] is String)
        ? (labData?['open'] as String)
        : "Open at 9:00am";
    final String desc = (labData?['description'] is String)
        ? (labData?['description'] as String)
        : ((labData?['desc'] is String)
              ? (labData?['desc'] as String)
              : "Our laboratory combines advanced diagnostic technology with the expertise of highly qualified professionals, ensuring every test is conducted with precision, accuracy, and reliability to support better healthcare outcomes.");
    final String image = (labData?['image'] is String)
        ? (labData?['image'] as String)
        : '';

    // Rich test catalog from lab's Test Catalog management
    final List<Map<String, dynamic>> availableTestsRich = (labData?['availableTests'] is List)
        ? (labData!['availableTests'] as List)
            .whereType<Map>()
            .map((t) => Map<String, dynamic>.from(t))
            .toList()
        : [];

    // Names list: prefer rich catalog, fall back to string list, then defaults
    final List<String> labTests = availableTestsRich.isNotEmpty
        ? availableTestsRich
            .map((t) => (t['name'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toList()
        : (labData?['tests'] is List)
            ? (labData!['tests'] as List).map((t) {
                if (t is String) return t;
                if (t is Map) return (t['name'] ?? t['testName'] ?? t['test_name'] ?? '').toString();
                return t.toString();
              }).where((s) => s.isNotEmpty).toList()
            : [
                "Complete Blood Count (CBC)",
                "Blood Sugar (Fasting / Random)",
                "Liver Function Test (LFT)",
                "Kidney Profile (KFT)",
              ];

    // Merge prescribed tests with lab's available tests
    final List<String> prescribedList = widget.prescribedTests ?? [];
    final Set<String> allTestsSet = <String>{};
    allTestsSet.addAll(prescribedList);
    allTestsSet.addAll(labTests);
    final List<String> availableTests = allTestsSet.toList();

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              leading: const CustomBackButton(),
              title: const CustomText(text: "Lab Details"),
            ),
      body: isDesktop
          ? _buildWebLayout(
              context, name, address, open, desc, image,
              availableTests, availableTestsRich,
            )
          : _buildMobileLayout(
              context, name, address, open, desc, image,
              availableTests, availableTestsRich,
            ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    String name,
    String address,
    String open,
    String desc,
    String image,
    List<String> availableTests,
    List<Map<String, dynamic>> availableTestsRich,
  ) {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          children: [
            ClipRRect(
              clipBehavior: Clip.hardEdge,
              borderRadius: BorderRadius.circular(20),
              child: image.isEmpty
                  ? Container(
                      width: Utils.windowWidth(context) * 0.9,
                      height: Utils.windowWidth(context) * 0.5,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
                        ),
                      ),
                      child: const Icon(Icons.science_rounded, color: Colors.white, size: 60),
                    )
                  : image.startsWith('assets')
                      ? Image.asset(
                          image,
                          fit: BoxFit.cover,
                          width: Utils.windowWidth(context) * 0.9,
                          height: Utils.windowWidth(context) * 0.5,
                          errorBuilder: (_, _, _) => Container(
                            width: Utils.windowWidth(context) * 0.9,
                            height: Utils.windowWidth(context) * 0.5,
                            color: const Color(0xFF1D4ED8),
                            child: const Icon(Icons.science_rounded, color: Colors.white, size: 60),
                          ),
                        )
                      : Image.network(
                          image,
                          fit: BoxFit.cover,
                          width: Utils.windowWidth(context) * 0.9,
                          height: Utils.windowWidth(context) * 0.5,
                          errorBuilder: (_, _, _) => Container(
                            width: Utils.windowWidth(context) * 0.9,
                            height: Utils.windowWidth(context) * 0.5,
                            color: const Color(0xFF1D4ED8),
                            child: const Icon(Icons.science_rounded, color: Colors.white, size: 60),
                          ),
                        ),
            ),
            SizedBox(height: ScallingConfig.scale(20)),
            CustomText(
              width: Utils.windowWidth(context) * 0.9,
              text: name,
              fontFamily: 'Gilroy-Bold',
              fontSize: 14.78,
              color: AppColors.themeDarkGrey,
            ),
            SizedBox(height: ScallingConfig.scale(10)),
            CustomText(
              width: Utils.windowWidth(context) * 0.9,
              text: desc,
              fontFamily: 'Gilroy-SemiBold',
              maxLines: 10,
              fontSize: 10.88,
              color: AppColors.grayColor,
            ),
            SizedBox(height: ScallingConfig.scale(15)),
            SizedBox(
              width: Utils.windowWidth(context) * 0.9,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SvgWrapper(
                    assetPath: ImagePaths.home_edit,
                    width: ScallingConfig.scale(15),
                    height: ScallingConfig.scale(15),
                  ),
                  SizedBox(width: ScallingConfig.scale(8)),
                  const CustomText(
                    text: "Home Sample Available",
                    fontFamily: "Gilroy-SemiBold",
                    fontSize: 14,
                    color: AppColors.tertiaryColor,
                  ),
                ],
              ),
            ),
            SizedBox(height: ScallingConfig.scale(15)),
            SizedBox(
              width: Utils.windowWidth(context) * 0.9,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SvgWrapper(
                    assetPath: ImagePaths.marker2,
                    width: ScallingConfig.scale(15),
                    height: ScallingConfig.scale(15),
                  ),
                  SizedBox(width: ScallingConfig.scale(8)),
                  CustomText(
                    text: address,
                    fontFamily: "Gilroy-SemiBold",
                    fontSize: 14,
                    color: AppColors.tertiaryColor,
                  ),
                ],
              ),
            ),
            SizedBox(height: ScallingConfig.scale(15)),
            SizedBox(
              width: Utils.windowWidth(context) * 0.9,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SvgWrapper(
                    assetPath: ImagePaths.clock,
                    width: ScallingConfig.scale(15),
                    height: ScallingConfig.scale(15),
                  ),
                  SizedBox(width: ScallingConfig.scale(8)),
                  CustomText(
                    text: open,
                    fontFamily: "Gilroy-SemiBold",
                    fontSize: 14,
                    color: AppColors.tertiaryColor,
                  ),
                ],
              ),
            ),
            SizedBox(height: ScallingConfig.scale(15)),
            CustomText(
              width: Utils.windowWidth(context) * 0.9,
              text: "Test Available",
              fontFamily: "Gilroy-Bold",
              fontSize: 14,
              color: AppColors.themeDarkGrey,
            ),
            ...availableTests.asMap().entries.map((entry) {
              final i = entry.key;
              final testName = entry.value;
              final rich = availableTestsRich.where((t) => t['name'] == testName).isNotEmpty
                  ? availableTestsRich.firstWhere((t) => t['name'] == testName)
                  : null;
              final price = rich != null ? (rich['price'] as num?)?.toDouble() ?? 0.0 : 0.0;
              final turnaround = rich?['turnaroundTime']?.toString() ?? '';
              final isPrescribed = (widget.prescribedTests ?? []).contains(testName);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: Utils.windowWidth(context) * 0.03),
                    Checkbox(
                      value: _selectedTests.contains(testName),
                      onChanged: (val) {
                        if (isPrescribed && val == false) return;
                        setState(() {
                          if (val == true) {
                            _selectedTests.add(testName);
                          } else {
                            _selectedTests.remove(testName);
                          }
                        });
                      },
                      activeColor: AppColors.primaryColor,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: CustomText(
                                  text: "${i + 1}. $testName",
                                  fontSize: 13,
                                  color: AppColors.themeDarkGrey,
                                ),
                              ),
                              if (price > 0)
                                Text(
                                  'PKR ${price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                            ],
                          ),
                          if (turnaround.isNotEmpty)
                            Text(
                              turnaround,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: Utils.windowWidth(context) * 0.03),
                  ],
                ),
              );
            }),
            SizedBox(height: ScallingConfig.scale(12)),
            CustomButton(
              width: Utils.windowWidth(context) * 0.9,
              borderRadius: 70,
              label: "Schedule Now",
              onPressed: () {
                if (_selectedTests.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please select at least one test"),
                    ),
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => FillLabForm(
                      labData: widget.labData,
                      selectedTests: _selectedTests,
                      prescriptionId: widget.prescriptionId,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWebLayout(
    BuildContext context,
    String name,
    String address,
    String open,
    String desc,
    String image,
    List<String> availableTests,
    List<Map<String, dynamic>> availableTestsRich,
  ) {
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
                  text: "Laboratory Profile",
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Gilroy-Bold",
                ),
                const Spacer(),
                _buildBreadcrumbs(),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Hero & Info
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Gallery/Hero Section
                            Container(
                              height: 450,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(32),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF1D4ED8),
                                    Color(0xFF0EA5E9),
                                  ],
                                ),
                                image: image.isNotEmpty
                                    ? DecorationImage(
                                        image: image.startsWith('assets')
                                            ? AssetImage(image) as ImageProvider
                                            : NetworkImage(image),
                                        fit: BoxFit.cover,
                                        onError: (_, _) {},
                                      )
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 30,
                                    offset: const Offset(0, 15),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // Show lab icon/content when no image
                                  if (image.isEmpty)
                                    Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(24),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.science_rounded,
                                              color: Colors.white,
                                              size: 80,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 28,
                                              fontWeight: FontWeight.w900,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: const Text(
                                              'Certified Diagnostic Laboratory',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Positioned(
                                    top: 20,
                                    right: 20,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            color: Colors.amber,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 4),
                                          Builder(builder: (_) {
                                            final r = widget.labData?['rating'];
                                            final rStr = (r == null || r == 0) ? 'New' : (r is num ? r.toStringAsFixed(1) : r.toString());
                                            return CustomText(text: rStr, fontWeight: FontWeight.bold);
                                          }),
                                          const SizedBox(width: 4),
                                          Builder(builder: (_) {
                                            final count = widget.labData?['total_reviews'] as int? ?? 0;
                                            return CustomText(
                                              text: count > 0 ? "($count Reviews)" : "(No Reviews Yet)",
                                              color: Colors.grey,
                                              fontSize: 12,
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Lab Info Task
                            CustomText(
                              text: name,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              fontFamily: "Gilroy-Bold",
                            ),
                            const SizedBox(height: 16),
                            CustomText(
                              text: desc,
                              fontSize: 16,
                              color: const Color(0xFF64748B),
                              maxLines: 5,
                            ),
                            const SizedBox(height: 32),

                            // Info Grid
                            Row(
                              children: [
                                _buildInfoCard(
                                  Icons.location_on_rounded,
                                  "Address",
                                  address,
                                  Colors.blue,
                                ),
                                const SizedBox(width: 20),
                                _buildInfoCard(
                                  Icons.access_time_filled_rounded,
                                  "Working Hours",
                                  open,
                                  Colors.orange,
                                ),
                                const SizedBox(width: 20),
                                _buildInfoCard(
                                  Icons.home_work_rounded,
                                  "Service",
                                  "Home Sample Available",
                                  Colors.green,
                                ),
                              ],
                            ),
                            if (availableTestsRich.isNotEmpty) ...[
                              const SizedBox(height: 40),
                              const Text(
                                'Test Catalog',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'All prices in PKR. Turnaround time from sample collection.',
                                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF0B2D6E),
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(15),
                                          topRight: Radius.circular(15),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Expanded(flex: 5, child: Text('TEST NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.0))),
                                          Expanded(flex: 2, child: Text('PRICE (PKR)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.0), textAlign: TextAlign.center)),
                                          Expanded(flex: 2, child: Text('TURNAROUND', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.0), textAlign: TextAlign.center)),
                                          Expanded(flex: 2, child: Text('SAMPLE TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.0), textAlign: TextAlign.center)),
                                        ],
                                      ),
                                    ),
                                    ...availableTestsRich.asMap().entries.map((e) {
                                      final idx = e.key;
                                      final t = e.value;
                                      final price = (t['price'] as num?)?.toDouble() ?? 0.0;
                                      final turnaround = t['turnaroundTime']?.toString() ?? t['turnaround']?.toString() ?? '—';
                                      final sampleType = t['sampleType']?.toString() ?? t['collectionType']?.toString() ?? '—';
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: idx.isEven ? Colors.white : const Color(0xFFF8FAFC),
                                          border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 5,
                                              child: Text(
                                                t['name']?.toString() ?? '',
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                price > 0 ? 'PKR ${price.toStringAsFixed(0)}' : '—',
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0B2D6E)),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                turnaround,
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                sampleType,
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 40),

                      // Right Column: Booking Card
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 40,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CustomText(
                                text: "Select Tests",
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                              const SizedBox(height: 8),
                              const CustomText(
                                text: "Select the tests you want to schedule",
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 24),
                              ...availableTests.map((t) {
                                final rich = availableTestsRich.where((r) => r['name'] == t).isNotEmpty
                                    ? availableTestsRich.firstWhere((r) => r['name'] == t)
                                    : {'name': t};
                                return _buildWebCheckbox(rich);
                              }),
                              const SizedBox(height: 32),

                              const Divider(
                                height: 1,
                                color: Color(0xFFF1F5F9),
                              ),
                              const SizedBox(height: 32),

                              Builder(builder: (_) {
                                double total = 0;
                                for (final name in _selectedTests) {
                                  final rich = availableTestsRich.where((r) => r['name'] == name).isNotEmpty
                                      ? availableTestsRich.firstWhere((r) => r['name'] == name)
                                      : null;
                                  final price = rich != null ? (rich['price'] as num?)?.toDouble() ?? 0.0 : 0.0;
                                  total += price > 0 ? price : 3000;
                                }
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const CustomText(
                                      text: "Estimated Total",
                                      color: Color(0xFF64748B),
                                    ),
                                    CustomText(
                                      text: "PKR ${total.toStringAsFixed(0)}",
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryColor,
                                    ),
                                  ],
                                );
                              }),
                              const SizedBox(height: 24),

                              CustomButton(
                                height: 56,
                                borderRadius: 16,
                                label: "Schedule Appointment",
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primaryColor,
                                    Color(0xFF1E40AF),
                                  ],
                                ),
                                onPressed: () {
                                  if (_selectedTests.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Please select at least one test",
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (ctx) => FillLabForm(
                                        labData: widget.labData,
                                        selectedTests: _selectedTests,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              const Center(
                                child: CustomText(
                                  text: "Secure 256-bit SSL encrypted booking",
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildBreadcrumbs() {
    return Row(
      children: [
        Text("Home", style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
        Text(
          "Laboratories",
          style: TextStyle(color: Colors.grey[400], fontSize: 13),
        ),
        const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
        const Text(
          "Details",
          style: TextStyle(
            color: AppColors.primaryColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            CustomText(text: title, fontSize: 12, color: Colors.grey),
            const SizedBox(height: 4),
            CustomText(
              text: value,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebCheckbox(Map<String, dynamic> testData) {
    final String label = testData['name']?.toString() ?? '';
    final double price = (testData['price'] as num?)?.toDouble() ?? 0.0;
    final String turnaround = testData['turnaroundTime']?.toString() ?? '';
    final bool isSelected = _selectedTests.contains(label);
    final bool isPrescribed = (widget.prescribedTests ?? []).contains(label);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            if (!isPrescribed) _selectedTests.remove(label);
          } else {
            _selectedTests.add(label);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryColor.withValues(alpha: 0.05)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrescribed
                ? const Color(0xFF8B5CF6)
                : isSelected
                    ? AppColors.primaryColor
                    : const Color(0xFFF1F5F9),
            width: isPrescribed || isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryColor
                      : const Color(0xFFCBD5E1),
                  width: 2,
                ),
                color: isSelected ? AppColors.primaryColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isPrescribed) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'Prescribed',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (turnaround.isNotEmpty)
                    Text(
                      turnaround,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              price > 0 ? 'PKR ${price.toStringAsFixed(0)}' : '—',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
