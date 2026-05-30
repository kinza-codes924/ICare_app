import 'package:flutter/material.dart';
import 'package:icare/models/lab.dart';
import 'package:icare/screens/book_lab.dart';
import 'package:icare/services/laboratory_service.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';

// Common lab tests list (static — backend will add more later)
const List<Map<String, dynamic>> _allTests = [
  {'name': 'Complete Blood Count (CBC)', 'price': 500.0, 'category': 'Blood'},
  {'name': 'Blood Sugar (Fasting)', 'price': 200.0, 'category': 'Blood'},
  {'name': 'Blood Sugar (Random)', 'price': 200.0, 'category': 'Blood'},
  {'name': 'HbA1c', 'price': 800.0, 'category': 'Blood'},
  {'name': 'Lipid Profile', 'price': 1200.0, 'category': 'Blood'},
  {'name': 'Liver Function Test (LFT)', 'price': 1500.0, 'category': 'Blood'},
  {'name': 'Kidney Function Test (KFT)', 'price': 1500.0, 'category': 'Blood'},
  {'name': 'Thyroid Profile (T3/T4/TSH)', 'price': 1800.0, 'category': 'Hormones'},
  {'name': 'Urine Complete Examination (UCE)', 'price': 300.0, 'category': 'Urine'},
  {'name': 'Urine Culture & Sensitivity', 'price': 700.0, 'category': 'Urine'},
  {'name': 'Blood Urea Nitrogen (BUN)', 'price': 400.0, 'category': 'Blood'},
  {'name': 'Serum Creatinine', 'price': 350.0, 'category': 'Blood'},
  {'name': 'Hepatitis B Surface Antigen (HBsAg)', 'price': 600.0, 'category': 'Hepatitis'},
  {'name': 'Hepatitis C Antibody (Anti-HCV)', 'price': 600.0, 'category': 'Hepatitis'},
  {'name': 'COVID-19 PCR', 'price': 3500.0, 'category': 'Viral'},
  {'name': 'Dengue NS1 Antigen', 'price': 1200.0, 'category': 'Viral'},
  {'name': 'ECG (Electrocardiogram)', 'price': 500.0, 'category': 'Heart'},
  {'name': 'Vitamin D3', 'price': 2000.0, 'category': 'Vitamins'},
  {'name': 'Vitamin B12', 'price': 1800.0, 'category': 'Vitamins'},
  {'name': 'Iron Studies', 'price': 1400.0, 'category': 'Blood'},
  {'name': 'Stool Examination (R/E)', 'price': 250.0, 'category': 'Stool'},
  {'name': 'Blood Group & Rh Typing', 'price': 200.0, 'category': 'Blood'},
  {'name': 'Pregnancy Test (Beta-HCG)', 'price': 500.0, 'category': 'Hormones'},
  {'name': 'PSA (Prostate Specific Antigen)', 'price': 1500.0, 'category': 'Cancer Markers'},
  {'name': 'Chest X-Ray', 'price': 800.0, 'category': 'Radiology'},
];

class PatientBookLabFlow extends StatefulWidget {
  const PatientBookLabFlow({super.key});

  @override
  State<PatientBookLabFlow> createState() => _PatientBookLabFlowState();
}

class _PatientBookLabFlowState extends State<PatientBookLabFlow> {
  int _step = 0; // 0 = Sample Type, 1 = Select Tests, 2 = Select Lab

  // Step 1
  String? _sampleType; // 'home' or 'lab'

  // Step 2
  final TextEditingController _testSearch = TextEditingController();
  final Set<String> _selectedTests = {};
  String _searchQuery = '';

  // Step 3
  final LaboratoryService _labService = LaboratoryService();
  List<Lab> _labs = [];
  bool _loadingLabs = false;
  String _selectedRadius = '10 km';

  @override
  void initState() {
    super.initState();
    _testSearch.addListener(() => setState(() => _searchQuery = _testSearch.text.toLowerCase()));
  }

  @override
  void dispose() {
    _testSearch.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_step == 0 && _sampleType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a sample type'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_step == 1 && _selectedTests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one test'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_step < 2) {
      setState(() => _step++);
      if (_step == 2) _loadLabs();
    }
  }

  void _goBack() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _loadLabs() async {
    setState(() => _loadingLabs = true);
    try {
      final data = await _labService.getAllLaboratories();
      final labs = data.map((json) => Lab(
        id: json['_id'] ?? '',
        title: json['labName'] ?? json['name'] ?? 'Laboratory',
        photo: json['image'] ?? ImagePaths.lab1,
        delivery: (json['homeSample'] ?? json['home_sample'] ?? true) == true ? 'Home Sample Available' : 'Walk-in Only',
        address: json['address'] ?? json['location'] ?? 'Location not available',
        rating: (json['rating'] ?? 4.5).toString(),
        tests: (json['availableTests'] as List?)?.map((t) => t['name'].toString()).toList() ?? [],
      )).toList();
      if (mounted) setState(() { _labs = labs; _loadingLabs = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingLabs = false);
    }
  }

  List<Map<String, dynamic>> get _filteredTests {
    if (_searchQuery.isEmpty) return _allTests;
    return _allTests.where((t) =>
      t['name'].toString().toLowerCase().contains(_searchQuery) ||
      t['category'].toString().toLowerCase().contains(_searchQuery)
    ).toList();
  }

  List<Lab> get _filteredLabs {
    if (_sampleType == 'home') {
      return _labs.where((l) => (l.delivery ?? '').contains('Home')).toList();
    }
    return _labs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 20),
          onPressed: _goBack,
        ),
        title: const Text(
          'Book a Lab Test',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _buildStepIndicator(),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _step == 0
            ? _buildStep1(key: const ValueKey(0))
            : _step == 1
                ? _buildStep2(key: const ValueKey(1))
                : _buildStep3(key: const ValueKey(2)),
      ),
      bottomNavigationBar: _step < 2 ? _buildBottomBar() : null,
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Sample Type', 'Select Tests', 'Choose Lab'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i == _step;
          final isDone = i < _step;
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isDone ? AppColors.primaryColor : const Color(0xFFE2E8F0),
                    ),
                  ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? AppColors.primaryColor
                        : isActive
                            ? AppColors.primaryColor
                            : const Color(0xFFE2E8F0),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.white : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: i < _step ? AppColors.primaryColor : const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── STEP 1: Sample Type ────────────────────────────────────────────────────
  Widget _buildStep1({Key? key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How would you like to give your sample?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose the sample collection method that suits you best.',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _buildSampleCard(
                type: 'home',
                icon: Icons.home_rounded,
                title: 'Home Sample',
                subtitle: 'We collect at your doorstep',
                color: AppColors.primaryColor,
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildSampleCard(
                type: 'lab',
                icon: Icons.biotech_rounded,
                title: 'Sample at Lab',
                subtitle: 'Visit the lab yourself',
                color: const Color(0xFF8B5CF6),
              )),
            ],
          ),
          if (_sampleType == 'home') ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primaryColor, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'A lab technician will visit your location. Delivery charges may apply.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSampleCard({
    required String type,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isSelected = _sampleType == type;
    return GestureDetector(
      onTap: () => setState(() => _sampleType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.07) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? color.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isSelected ? color : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            if (isSelected) ...[
              const SizedBox(height: 12),
              Icon(Icons.check_circle_rounded, color: color, size: 22),
            ],
          ],
        ),
      ),
    );
  }

  // ── STEP 2: Select Tests ───────────────────────────────────────────────────
  Widget _buildStep2({Key? key}) {
    return Column(
      key: key,
      children: [
        // Search bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _testSearch,
            decoration: InputDecoration(
              hintText: 'Search by test name or category...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () { _testSearch.clear(); setState(() => _searchQuery = ''); },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryColor),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        // Selected count + total
        if (_selectedTests.isNotEmpty)
          Container(
            color: AppColors.primaryColor.withValues(alpha: 0.05),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.primaryColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_selectedTests.length} test${_selectedTests.length > 1 ? 's' : ''} selected',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryColor),
                ),
                const Spacer(),
              ],
            ),
          ),
        // Tests list
        Expanded(
          child: _filteredTests.isEmpty
              ? const Center(child: Text('No tests found', style: TextStyle(color: Color(0xFF64748B))))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _filteredTests.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, i) {
                    final test = _filteredTests[i];
                    final name = test['name'] as String;
                    final isSelected = _selectedTests.contains(name);
                    return InkWell(
                      onTap: () => setState(() {
                        if (isSelected) {
                          _selectedTests.remove(name);
                        } else {
                          _selectedTests.add(name);
                        }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryColor : const Color(0xFFCBD5E1),
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      test['category'] as String,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                                      ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── STEP 3: Choose Lab ─────────────────────────────────────────────────────
  Widget _buildStep3({Key? key}) {
    return Column(
      key: key,
      children: [
        // Radius filter
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Show labs within:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              Row(
                children: ['5 km', '10 km', '15 km'].map((r) {
                  final isSelected = _selectedRadius == r;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedRadius = r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryColor : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          r,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: Color(0xFF3B82F6), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Select a lab below to book your test.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1D4ED8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Labs list
        Expanded(
          child: _loadingLabs
              ? const Center(child: CircularProgressIndicator())
              : _filteredLabs.isEmpty
                  ? _buildNoLabs()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredLabs.length,
                      itemBuilder: (context, i) => _buildLabCard(_filteredLabs[i]),
                    ),
        ),
      ],
    );
  }

  Widget _buildNoLabs() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.biotech_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No labs available', style: TextStyle(color: Color(0xFF64748B), fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildLabCard(Lab lab) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BookLabScreen(labId: lab.id ?? '', labTitle: lab.title),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.biotech_rounded, color: Color(0xFF3B82F6), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lab.title ?? 'Laboratory',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            lab.address ?? 'Location not available',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          lab.rating ?? '4.5',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _sampleType == 'home'
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _sampleType == 'home' ? 'Home Sample' : 'Walk-in',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _sampleType == 'home'
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom Bar ─────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _goNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _step == 0
                      ? 'Continue to Select Tests'
                      : 'Continue to Choose Lab',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
