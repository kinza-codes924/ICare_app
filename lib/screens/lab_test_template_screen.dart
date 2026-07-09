import 'package:flutter/material.dart';
import 'package:icare/widgets/back_button.dart';

// Full list of common lab tests for search
const List<String> _kAllLabTests = [
  'Complete Blood Count (CBC)',
  'Blood Glucose (Fasting)',
  'Blood Glucose (Random)',
  'HbA1c (Glycated Haemoglobin)',
  'Lipid Profile',
  'Total Cholesterol',
  'HDL Cholesterol',
  'LDL Cholesterol',
  'Triglycerides',
  'Liver Function Tests (LFT)',
  'ALT (SGPT)',
  'AST (SGOT)',
  'Bilirubin Total',
  'Bilirubin Direct',
  'Alkaline Phosphatase (ALP)',
  'GGT (Gamma GT)',
  'Albumin',
  'Total Protein',
  'Kidney Function Tests (KFT)',
  'Serum Creatinine',
  'Blood Urea Nitrogen (BUN)',
  'Uric Acid',
  'Electrolytes (Na/K/Cl)',
  'Serum Sodium',
  'Serum Potassium',
  'Serum Chloride',
  'Urine Complete Examination (UCE)',
  'Urine Culture & Sensitivity',
  'Urine Microalbumin',
  'Thyroid Function Tests (TFT)',
  'TSH (Thyroid Stimulating Hormone)',
  'T3 (Triiodothyronine)',
  'T4 (Thyroxine)',
  'Free T3',
  'Free T4',
  'Serum Iron',
  'TIBC (Total Iron Binding Capacity)',
  'Serum Ferritin',
  'Vitamin B12',
  'Vitamin D (25-OH)',
  'Folate / Folic Acid',
  'Calcium (Serum)',
  'Phosphorus (Serum)',
  'Magnesium (Serum)',
  'CRP (C-Reactive Protein)',
  'ESR (Erythrocyte Sedimentation Rate)',
  'Procalcitonin',
  'Rheumatoid Factor (RF)',
  'ANA (Antinuclear Antibody)',
  'Anti-dsDNA',
  'ASO Titre',
  'Widal Test',
  'Dengue NS1 Antigen',
  'Dengue IgG / IgM',
  'Malaria Parasite (MP)',
  'Hepatitis B Surface Antigen (HBsAg)',
  'Hepatitis C Antibody (Anti-HCV)',
  'HIV 1 & 2 Antibody',
  'VDRL / RPR (Syphilis)',
  'Blood Culture & Sensitivity',
  'Sputum Culture & Sensitivity',
  'Stool Complete Examination',
  'Stool Culture',
  'Occult Blood (Stool)',
  'Pap Smear',
  'Pregnancy Test (Beta-hCG)',
  'FSH (Follicle Stimulating Hormone)',
  'LH (Luteinizing Hormone)',
  'Prolactin',
  'Testosterone (Total)',
  'Estradiol (E2)',
  'Progesterone',
  'PSA (Prostate Specific Antigen)',
  'CA-125 (Ovarian Marker)',
  'CA 19-9 (Pancreatic Marker)',
  'CEA (Carcinoembryonic Antigen)',
  'AFP (Alpha Fetoprotein)',
  'Troponin I / T',
  'CK-MB (Creatine Kinase)',
  'BNP / NT-proBNP',
  'D-Dimer',
  'PT / INR (Prothrombin Time)',
  'APTT',
  'Fibrinogen',
  'Peripheral Blood Smear',
  'Reticulocyte Count',
  'Bone Marrow Biopsy',
  'Serum Protein Electrophoresis',
  'Cortisol (Morning)',
  'ACTH',
  'Insulin (Fasting)',
  'C-Peptide',
  'Amylase',
  'Lipase',
  'LDH (Lactate Dehydrogenase)',
  'Chest X-Ray',
  'ECG (Electrocardiogram)',
  'Echocardiogram',
  'Ultrasound Abdomen',
  'Ultrasound Pelvis',
  'CT Scan',
  'MRI Brain',
  'Spirometry (PFT)',
  'Audiometry',
  'Vision Test',
];

class LabTestTemplateScreen extends StatefulWidget {
  final bool selectionMode;
  final Function(Map<String, dynamic>)? onTemplateSelected;

  const LabTestTemplateScreen({
    super.key,
    this.selectionMode = false,
    this.onTemplateSelected,
  });

  @override
  State<LabTestTemplateScreen> createState() => _LabTestTemplateScreenState();
}

class _LabTestTemplateScreenState extends State<LabTestTemplateScreen> {
  static final List<Map<String, dynamic>> _templates = [
    {
      'id': 'default_1',
      'name': 'Basic Blood Panel',
      'tests': [
        {'name': 'Complete Blood Count (CBC)', 'notes': ''},
        {'name': 'Blood Glucose (Fasting)', 'notes': ''},
        {'name': 'Lipid Profile', 'notes': ''},
      ],
    },
    {
      'id': 'default_2',
      'name': 'Liver Function Tests',
      'tests': [
        {'name': 'ALT (SGPT)', 'notes': ''},
        {'name': 'AST (SGOT)', 'notes': ''},
        {'name': 'Bilirubin Total', 'notes': ''},
        {'name': 'Alkaline Phosphatase (ALP)', 'notes': ''},
      ],
    },
    {
      'id': 'default_3',
      'name': 'Kidney Function Tests',
      'tests': [
        {'name': 'Serum Creatinine', 'notes': ''},
        {'name': 'Blood Urea Nitrogen (BUN)', 'notes': ''},
        {'name': 'Uric Acid', 'notes': ''},
        {'name': 'Urine Complete Examination (UCE)', 'notes': ''},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Text(
          widget.selectionMode ? 'Suggest Lab Tests' : 'Lab Test Templates',
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900),
        ),
      ),
      floatingActionButton: widget.selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openBuildScreen(context),
              backgroundColor: const Color(0xFF8B5CF6),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('New Template',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
      body: Column(
        children: [
          if (widget.selectionMode) ...[
            // Quick "Build Custom" button at top in selection mode
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openBuildScreen(context, isQuickSuggest: true),
                  icon: const Icon(Icons.search_rounded, size: 20),
                  label: const Text('Search & Select Tests Manually',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B5CF6),
                    side: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or use a template',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                ),
                Expanded(child: Divider()),
              ]),
            ),
          ],
          Expanded(
            child: _templates.isEmpty
                ? _buildEmptyState()
                : _buildTemplatesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.biotech_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No templates yet.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Tap + to create your first template.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTemplatesList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _templates.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final template = _templates[index];
        final tests = (template['tests'] ?? []) as List<dynamic>;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.biotech_rounded,
                        color: Color(0xFF8B5CF6), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(template['name'] ?? '',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A))),
                  ),
                  if (!widget.selectionMode)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _openBuildScreen(context, editIndex: index),
                          icon: const Icon(Icons.edit_rounded,
                              color: Color(0xFF8B5CF6), size: 20),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          onPressed: () => _confirmDelete(index),
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.red, size: 20),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: tests.map((t) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                    ),
                    child: Text(t['name'] ?? '',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6D28D9),
                            fontWeight: FontWeight.w600)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              if (widget.selectionMode)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      widget.onTemplateSelected?.call(template);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Use This Template'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Opens the full-screen test builder
  void _openBuildScreen(BuildContext context,
      {int? editIndex, bool isQuickSuggest = false}) {
    final existing = editIndex != null ? _templates[editIndex] : null;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LabTestBuilderScreen(
          initialName: existing?['name'] ?? '',
          initialTests: existing != null
              ? List<Map<String, String>>.from(
                  (existing['tests'] as List)
                      .map((t) => Map<String, String>.from(t)))
              : [],
          isQuickSuggest: isQuickSuggest,
          onSave: (name, tests) {
            if (isQuickSuggest) {
              // Return directly as a suggestion without saving as template
              widget.onTemplateSelected?.call({
                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                'name': name.isNotEmpty ? name : 'Custom Lab Tests',
                'tests': tests,
              });
              Navigator.pop(context);
            } else if (editIndex != null) {
              setState(() {
                _templates[editIndex] = {
                  ..._templates[editIndex],
                  'name': name,
                  'tests': tests,
                };
              });
            } else {
              setState(() {
                _templates.add({
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'name': name,
                  'tests': tests,
                });
              });
            }
          },
        ),
      ),
    );
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Delete "${_templates[index]['name']}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() => _templates.removeAt(index));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Full-screen Lab Test Builder ────────────────────────────────────────────
class _LabTestBuilderScreen extends StatefulWidget {
  final String initialName;
  final List<Map<String, String>> initialTests;
  final bool isQuickSuggest;
  final Function(String name, List<Map<String, String>> tests) onSave;

  const _LabTestBuilderScreen({
    required this.initialName,
    required this.initialTests,
    required this.isQuickSuggest,
    required this.onSave,
  });

  @override
  State<_LabTestBuilderScreen> createState() => _LabTestBuilderScreenState();
}

class _LabTestBuilderScreenState extends State<_LabTestBuilderScreen> {
  late final TextEditingController _nameController;
  final TextEditingController _searchController = TextEditingController();
  late List<Map<String, String>> _selectedTests;
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _selectedTests = List.from(widget.initialTests);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    final q = query.toLowerCase();
    final results = _kAllLabTests
        .where((t) =>
            t.toLowerCase().contains(q) &&
            !_selectedTests.any((s) => s['name'] == t))
        .take(8)
        .toList();
    setState(() {
      _suggestions = results;
      _showSuggestions = true;
    });
  }

  void _addTest(String name) {
    if (name.trim().isEmpty) return;
    if (_selectedTests.any((t) => t['name'] == name)) return;
    setState(() {
      _selectedTests.add({'name': name.trim(), 'notes': ''});
      _searchController.clear();
      _suggestions = [];
      _showSuggestions = false;
    });
  }

  void _removeTest(int index) {
    setState(() => _selectedTests.removeAt(index));
  }

  void _save() {
    if (widget.isQuickSuggest) {
      if (_selectedTests.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one test')),
        );
        return;
      }
      widget.onSave('Custom Lab Tests', _selectedTests);
      Navigator.pop(context);
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a template name')),
      );
      return;
    }
    if (_selectedTests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one test')),
      );
      return;
    }
    widget.onSave(_nameController.text.trim(), _selectedTests);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Template saved'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Text(
          widget.isQuickSuggest ? 'Select Lab Tests' : 'Build Template',
          style: const TextStyle(
              color: Color(0xFF0F172A), fontWeight: FontWeight.w900),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(
                widget.isQuickSuggest ? 'Suggest' : 'Save',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Template name (only when not quick suggest)
          if (!widget.isQuickSuggest)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Template Name',
                  hintText: 'e.g. Diabetes Monitoring Panel',
                  prefixIcon: const Icon(Icons.label_outline_rounded,
                      color: Color(0xFF8B5CF6)),
                  filled: true,
                  fillColor: const Color(0xFFF5F3FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

          // Search bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
                16, widget.isQuickSuggest ? 16 : 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Search & Add Tests',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search test name...',
                          hintStyle:
                              const TextStyle(color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: Color(0xFF8B5CF6)),
                          filled: true,
                          fillColor: const Color(0xFFF5F3FF),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Add custom (typed) test
                    ElevatedButton(
                      onPressed: () =>
                          _addTest(_searchController.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Add',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),

                // Dropdown suggestions
                if (_showSuggestions && _suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: _suggestions.map((test) {
                        return InkWell(
                          onTap: () => _addTest(test),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.biotech_rounded,
                                    size: 16, color: Color(0xFF8B5CF6)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(test,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF0F172A))),
                                ),
                                const Icon(Icons.add_circle_outline_rounded,
                                    size: 18, color: Color(0xFF8B5CF6)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Selected tests list
          Expanded(
            child: _selectedTests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.science_outlined,
                            size: 56, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        const Text('No tests added yet',
                            style: TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 15)),
                        const SizedBox(height: 6),
                        const Text(
                            'Search above or type a test name and tap Add',
                            style: TextStyle(
                                color: Color(0xFFCBD5E1), fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _selectedTests.length,
                    itemBuilder: (context, index) {
                      final test = _selectedTests[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF8B5CF6)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                test['name'] ?? '',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A)),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeTest(index),
                              icon: const Icon(
                                  Icons.remove_circle_rounded,
                                  color: Colors.red,
                                  size: 22),
                              tooltip: 'Remove',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom count bar
          if (_selectedTests.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_selectedTests.length} test${_selectedTests.length > 1 ? 's' : ''} selected',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8B5CF6)),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      widget.isQuickSuggest ? 'Suggest These Tests' : 'Save Template',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

