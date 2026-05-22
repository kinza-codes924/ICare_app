import 'package:flutter/material.dart';
import '../data/lab_tests_data.dart';
import '../utils/theme.dart';

class LabTestsDirectoryScreen extends StatefulWidget {
  const LabTestsDirectoryScreen({super.key});

  @override
  State<LabTestsDirectoryScreen> createState() => _LabTestsDirectoryScreenState();
}

class _LabTestsDirectoryScreenState extends State<LabTestsDirectoryScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String _selectedDept = 'All';
  String _selectedLetter = 'All';
  String _query = '';

  static const _departments = [
    'All', 'BIOCHEMISTRY', 'HAEMATOLOGY', 'MICROBIOLOGY',
    'HISTOPATHOLOGY', 'BLOOD BANK', 'MOLECULAR PATHOLOGY',
  ];

  static const _deptColors = {
    'BIOCHEMISTRY': Color(0xFF6366F1),
    'HAEMATOLOGY': Color(0xFFEF4444),
    'MICROBIOLOGY': Color(0xFF10B981),
    'HISTOPATHOLOGY': Color(0xFFF59E0B),
    'BLOOD BANK': Color(0xFFEC4899),
    'MOLECULAR PATHOLOGY': Color(0xFF8B5CF6),
  };

  static const _alphabet = [
    'All', '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K',
    'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  List<LabTest> get _filtered {
    return kLabTests.where((t) {
      final matchDept = _selectedDept == 'All' || t.department == _selectedDept;
      final matchLetter = _selectedLetter == 'All'
          ? true
          : _selectedLetter == '#'
              ? !RegExp(r'^[A-Z]').hasMatch(t.name)
              : t.name.startsWith(_selectedLetter);
      final matchQuery = _query.isEmpty ||
          t.name.toLowerCase().contains(_query.toLowerCase()) ||
          t.department.toLowerCase().contains(_query.toLowerCase());
      return matchDept && matchLetter && matchQuery;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Color _deptColor(String dept) => _deptColors[dept] ?? AppColors.primaryColor;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Lab Test Directory',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE8ECF5)),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildDeptChips(),
          _buildAlphabetBar(),
          Expanded(child: _buildList(results)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v.trim()),
        style: const TextStyle(fontSize: 14, fontFamily: 'Gilroy-Bold'),
        decoration: InputDecoration(
          hintText: 'Search tests (e.g. CBC, Thyroid, Liver)...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildDeptChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _departments.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final dept = _departments[i];
            final selected = _selectedDept == dept;
            final color = dept == 'All' ? AppColors.primaryColor : _deptColor(dept);
            return GestureDetector(
              onTap: () => setState(() => _selectedDept = dept),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? color : color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? color : color.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  dept == 'MOLECULAR PATHOLOGY' ? 'MOLECULAR' : dept,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Gilroy-Bold',
                    color: selected ? Colors.white : color,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAlphabetBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _alphabet.length,
          separatorBuilder: (_, _) => const SizedBox(width: 4),
          itemBuilder: (_, i) {
            final letter = _alphabet[i];
            final selected = _selectedLetter == letter;
            return GestureDetector(
              onTap: () => setState(() => _selectedLetter = letter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: letter == 'All' ? 40 : 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryColor
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: letter == 'All' ? 10 : 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Gilroy-Bold',
                    color: selected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(List<LabTest> tests) {
    if (tests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.science_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'No tests found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
                fontFamily: 'Gilroy-Bold',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try a different search or filter',
              style: TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: tests.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${tests.length} test${tests.length == 1 ? '' : 's'} found',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
                fontFamily: 'Gilroy-Bold',
              ),
            ),
          );
        }
        final test = tests[i - 1];
        return _buildTestCard(test);
      },
    );
  }

  Widget _buildTestCard(LabTest test) {
    final color = _deptColor(test.department);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.biotech_outlined, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    test.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Gilroy-Bold',
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      test.department,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Gilroy-Bold',
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          test.sampleInstructions,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontFamily: 'Gilroy-Bold',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
