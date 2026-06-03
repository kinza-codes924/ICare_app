import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icare/screens/doctors_list.dart';
import 'package:icare/services/doctor_service.dart';

class DoctorSearchBar extends StatefulWidget {
  final bool isMobile;
  const DoctorSearchBar({super.key, required this.isMobile});

  @override
  State<DoctorSearchBar> createState() => _DoctorSearchBarState();
}

class _DoctorSearchBarState extends State<DoctorSearchBar> {
  String _mode = 'name';
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _scrollCtrl = ScrollController();
  bool _showDrop = false;
  List<String> _suggestions = [];
  int _highlightIndex = -1;
  List<String> _doctorNames = [];
  bool _loadingDoctors = false;
  Timer? _debounce;

  static const _specialties = [
    'Cardiologist','Dermatologist','Neurologist','Orthopedic','Gynecologist',
    'Pediatrician','Psychiatrist','Ophthalmologist','ENT Specialist','Urologist',
    'Gastroenterologist','Endocrinologist','General Physician','Dentist','Nutritionist',
    'Pulmonologist','Nephrologist','Rheumatologist','Oncologist','Diabetologist',
  ];

  static const _conditions = [
    'Diabetes','Hypertension','Fever','Heart Disease','Asthma','Back Pain',
    'Arthritis','Anxiety','Depression','Migraine','Obesity','Thyroid',
    'Kidney Disease','Skin Problem','Eye Problem','Ear Infection','Stomach Pain',
    'Chest Pain','Joint Pain','Allergies','PCOS','Hepatitis','Dengue','Anemia',
  ];

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() { _showDrop = false; _highlightIndex = -1; });
        });
      }
    });
    _focus.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (!_showDrop || _suggestions.isEmpty) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() { _highlightIndex = (_highlightIndex + 1) % _suggestions.length; });
        _scrollToHighlight();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() { _highlightIndex = (_highlightIndex - 1 + _suggestions.length) % _suggestions.length; });
        _scrollToHighlight();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter && _highlightIndex >= 0) {
        final sel = _suggestions[_highlightIndex];
        _ctrl.text = sel;
        _navigate(sel);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() { _showDrop = false; _highlightIndex = -1; });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    _loadDoctorNames();
  }

  void _scrollToHighlight() {
    if (!_scrollCtrl.hasClients || _highlightIndex < 0) return;
    const itemH = 44.0;
    final offset = (_highlightIndex * itemH).clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.animateTo(offset, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
  }

  Future<void> _loadDoctorNames() async {
    if (_loadingDoctors) return;
    setState(() => _loadingDoctors = true);
    try {
      final result = await DoctorService().getAllDoctors();
      if (result['success'] == true) {
        final doctors = result['doctors'] as List? ?? [];
        _doctorNames = doctors
            .map((d) => (d['name'] ?? d['username'] ?? '').toString().trim())
            .where((n) => n.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingDoctors = false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      if (_mode == 'name') {
        setState(() {
          _highlightIndex = -1;
          _suggestions = v.isEmpty
              ? []
              : _doctorNames.where((n) => n.toLowerCase().contains(v.toLowerCase())).toList();
          _showDrop = _focus.hasFocus && _suggestions.isNotEmpty;
        });
      } else {
        final list = _mode == 'speciality' ? _specialties : _conditions;
        setState(() {
          _highlightIndex = -1;
          _suggestions = v.isEmpty
              ? list
              : list.where((s) => s.toLowerCase().contains(v.toLowerCase())).toList();
          _showDrop = _focus.hasFocus;
        });
      }
    });
  }

  void _navigate(String query) {
    if (query.trim().isEmpty) return;
    setState(() { _showDrop = false; _highlightIndex = -1; });
    _focus.unfocus();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _mode == 'speciality'
          ? DoctorsList(initialSpecialty: query)
          : _mode == 'condition'
              ? DoctorsList(initialCondition: query)
              : DoctorsList(initialName: query),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF0036BC);
    return Column(
      children: [
        Container(
          height: widget.isMobile ? 46 : 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!, width: 1))),
                child: DropdownButton<String>(
                  value: _mode,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  style: TextStyle(fontSize: widget.isMobile ? 11 : 12, color: accentColor, fontWeight: FontWeight.w600),
                  items: const [
                    DropdownMenuItem(value: 'name', child: Text('Doctor Name')),
                    DropdownMenuItem(value: 'speciality', child: Text('Speciality')),
                    DropdownMenuItem(value: 'condition', child: Text('Condition')),
                  ],
                  onChanged: (v) {
                    setState(() { _mode = v!; _ctrl.clear(); _showDrop = false; _suggestions = []; _highlightIndex = -1; });
                  },
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  decoration: InputDecoration(
                    hintText: _mode == 'name'
                        ? 'Search doctor by name...'
                        : _mode == 'speciality'
                            ? 'Search by speciality...'
                            : 'Search by condition...',
                    hintStyle: TextStyle(fontSize: widget.isMobile ? 12 : 13, color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search_rounded, color: accentColor, size: widget.isMobile ? 20 : 22),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: widget.isMobile ? 14 : 16),
                  ),
                  onChanged: _onTextChanged,
                  onTap: () {
                    if (_mode != 'name') _onTextChanged(_ctrl.text);
                  },
                  onSubmitted: _navigate,
                ),
              ),
              GestureDetector(
                onTap: () => _navigate(_ctrl.text),
                child: Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(8)),
                  child: const Center(child: Icon(Icons.search, color: Colors.white, size: 20)),
                ),
              ),
            ],
          ),
        ),
        if (_showDrop && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12)],
            ),
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (_, i) {
                final highlighted = i == _highlightIndex;
                return Container(
                  color: highlighted ? accentColor.withValues(alpha: 0.08) : null,
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      _mode == 'name' ? Icons.person_outlined
                          : _mode == 'speciality' ? Icons.medical_services_outlined
                          : Icons.healing_outlined,
                      size: 16,
                      color: highlighted ? accentColor : accentColor.withValues(alpha: 0.7),
                    ),
                    title: Text(
                      _suggestions[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
                        color: highlighted ? accentColor : const Color(0xFF0F172A),
                      ),
                    ),
                    onTap: () { _ctrl.text = _suggestions[i]; _navigate(_suggestions[i]); },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
