import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/screens/consultation_details_screen.dart';
import 'package:icare/screens/doctors_list.dart';
import 'package:icare/screens/pharmacies.dart';
import 'package:icare/screens/lab_list.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/whatsapp_button.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/widgets/doctor_search_bar.dart';
import 'package:icare/services/doctor_service.dart';
import 'package:icare/services/pharmacy_service.dart';
import 'package:icare/services/laboratory_service.dart';
import 'package:icare/screens/pharmacy_details.dart';
import 'package:icare/screens/book_lab.dart';
import 'package:icare/screens/gamification_screen.dart';

// ── Auth guard — show sign-in/sign-up dialog if not logged in ─────────────────
Future<bool> _requireAuth(BuildContext context) async {
  final token = await SharedPref().getToken();
  if (token != null && token.isNotEmpty) return true; // already logged in
  if (!context.mounted) return false;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [
        Icon(Icons.lock_rounded, color: Color(0xFF0036BC), size: 24),
        SizedBox(width: 10),
        Text('Sign In Required', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ]),
      content: const Text('Please sign in to continue. New here? You can also create an account.', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
      actions: [
        OutlinedButton(
          onPressed: () { Navigator.pop(ctx); ctx.go('/signup'); },
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF0036BC)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0036BC))),
        ),
        ElevatedButton(
          onPressed: () { Navigator.pop(ctx); ctx.go('/login'); },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0036BC), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return false;
}

class PublicHome extends StatelessWidget {
  const PublicHome({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          MediaQuery.removePadding(
            context: context,
            removeLeft: true,
            removeRight: true,
            removeBottom: true,
            child: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            floating: true,
            toolbarHeight: isMobile ? 76 : 88,
            surfaceTintColor: Colors.white,
            shadowColor: const Color(0x1A0036BC),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Padding(
                  padding: EdgeInsets.only(
                    left: isMobile ? 12 : 24,
                    right: isMobile ? 12 : 24,
                    top: isMobile ? MediaQuery.of(context).viewPadding.top + 4 : 14,
                    bottom: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: iCare logo
                      Image.asset(
                        'assets/Asset 1.png',
                        height: isMobile ? 56 : 72,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                      // Right: nav buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isMobile) ...[
                            _NavButton(
                              label: 'Sign In',
                              filled: true,
                              onTap: () => context.go('/login'),
                            ),
                            const SizedBox(width: 6),
                            _NavButton(
                              label: 'Patient Sign Up',
                              filled: false,
                              onTap: () => context.go('/signup'),
                            ),
                            const SizedBox(width: 6),
                            _NavButton(
                              label: 'Work With Us',
                              filled: false,
                              accent: true,
                              onTap: () => context.go('/work-with-us'),
                            ),
                          ] else ...[
                            _NavButton(
                              label: 'Sign In',
                              filled: true,
                              onTap: () => context.go('/login'),
                            ),
                            const SizedBox(width: 6),
                            _NavButton(
                              label: 'Sign Up',
                              filled: false,
                              onTap: () => context.go('/signup'),
                            ),
                            const SizedBox(width: 6),
                            _NavButton(
                              label: 'Work With Us',
                              filled: false,
                              accent: true,
                              onTap: () => context.go('/work-with-us'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Banner(),
                const SizedBox(height: 40),

                // 1. Connect to a Doctor Section
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: _CenteredSection(
                    child: Column(
                      children: [
                        _SectionHeader(
                          title: 'Consult Available Doctors Now',
                          subtitle: 'Talk to a verified doctor within minutes from the comfort of your home',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (ctx) => const DoctorsList()),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (ctx) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: DoctorSearchBar(isMobile: MediaQuery.of(ctx).size.width < 700),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _DoctorsSlider(),
                        const SizedBox(height: 40),
                        // Browse by Specialty
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Browse by Specialty',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7C3AED),
                              fontFamily: 'Gilroy-Bold',
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Find the right specialist for your health needs',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SpecialtySearchBar(),
                        const SizedBox(height: 14),
                        _SpecialtyGrid(),
                        const SizedBox(height: 16),
                        Center(
                          child: _GlowingViewAllButton(
                            label: 'See All Speciality',
                            color: const Color(0xFF7C3AED),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const DoctorsList(initialSearchMode: 'specialty')),
                            ),
                          ),
                        ),
                        const SizedBox(height: 60),
                        // Browse by Condition
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Browse by Condition',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0891B2),
                              fontFamily: 'Gilroy-Bold',
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Search by your symptoms or medical condition',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ConditionOnlySearchBar(),
                        const SizedBox(height: 14),
                        _ConditionGrid(),
                        const SizedBox(height: 16),
                        // View All Conditions button
                        Center(
                          child: _GlowingViewAllButton(
                            label: 'View All Conditions',
                            color: const Color(0xFF0891B2),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const DoctorsList(initialSearchMode: 'condition')),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // 3. Order Medicines Section (renamed from Pharmacies)
                _CenteredSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _SectionHeader(
                        title: 'Order Medicines',
                        subtitle: 'Order medicines from trusted pharmacies near you',
                        titleColor: const Color(0xFF95BF47),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (ctx) => const PharmaciesScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _MedicineSearchBar(),
                      const SizedBox(height: 24),
                      _PharmaciesGrid(),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                // 4. Book a Lab Test Section (renamed from Laboratories)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.only(top: 60, bottom: 32),
                  child: _CenteredSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _SectionHeader(
                          title: 'Book a Lab Test',
                          subtitle: 'Book lab tests and get results delivered at home',
                          titleColor: const Color(0xFFFF4D00),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (ctx) => LabsListScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _LabSearchBar(),
                        const SizedBox(height: 24),
                        _LaboratoriesGrid(),
                        const SizedBox(height: 20),
                        Center(child: _FlashingBookLabButton()),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 5. Courses Section (new — above How iCare Works)
                _CoursesSection(),

                const SizedBox(height: 24),

                // 6. How iCare Works Section
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.only(top: 36, bottom: 60),
                  child: _CenteredSection(
                    child: Column(
                      children: [
                        _SectionHeader(
                          title: 'How iCare Works',
                          subtitle: 'Get quality healthcare in 5 simple steps',
                        ),
                        const SizedBox(height: 40),
                        _HowItWorksSteps(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // App Download Section
                _AppDownloadBanner(),

                // Footer (no gap)
                _Footer(),
              ],
            ),
          ),
        ],
        ),
          ),
          const WhatsAppFloatingButton(),
        ],
      ),
    );
  }
}



// ── Browse Search Field (Specialty / Condition) ──────────────────────────────
class _BrowseSearchField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final VoidCallback onSearch;
  const _BrowseSearchField({required this.hint, required this.icon, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF5), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: const Color(0xFF0036BC), size: 20),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0036BC), size: 20),
            onPressed: onSearch,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
        onSubmitted: (_) => onSearch(),
      ),
    );
  }
}

// ── Specialty Search Bar ──────────────────────────────────────────────────────
class _SpecialtySearchBar extends StatefulWidget {
  @override
  State<_SpecialtySearchBar> createState() => _SpecialtySearchBarState();
}

class _SpecialtySearchBarState extends State<_SpecialtySearchBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _scrollCtrl = ScrollController();
  bool _showDropdown = false;
  List<String> _filtered = [];
  int _highlightIndex = -1;

  static const _accentColor = Color(0xFF7C3AED);

  static const _all = [
    'Cardiologist','Dermatologist','Neurologist','Orthopedic','Gynecologist',
    'Pediatrician','Psychiatrist','Ophthalmologist','ENT Specialist','Urologist',
    'Gastroenterologist','Endocrinologist','Pulmonologist','Oncologist','Nephrologist',
    'Rheumatologist','Diabetologist','General Physician','Dentist','Nutritionist',
  ];

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() { _showDropdown = false; _highlightIndex = -1; });
        });
      }
    });
    _focus.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (!_showDropdown || _filtered.isEmpty) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() { _highlightIndex = (_highlightIndex + 1) % _filtered.length; });
        _scrollToHighlight();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() { _highlightIndex = (_highlightIndex - 1 + _filtered.length) % _filtered.length; });
        _scrollToHighlight();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter && _highlightIndex >= 0) {
        _ctrl.text = _filtered[_highlightIndex];
        _select(_filtered[_highlightIndex]);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() { _showDropdown = false; _highlightIndex = -1; });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  void _scrollToHighlight() {
    if (!_scrollCtrl.hasClients || _highlightIndex < 0) return;
    const itemH = 44.0;
    final offset = (_highlightIndex * itemH).clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.animateTo(offset, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  void _onChanged(String v) {
    setState(() {
      _highlightIndex = -1;
      _filtered = v.isEmpty ? _all : _all.where((s) => s.toLowerCase().contains(v.toLowerCase())).toList();
      _showDropdown = v.isNotEmpty || _focus.hasFocus;
    });
  }

  void _select(String s) {
    _ctrl.text = s;
    setState(() { _showDropdown = false; _highlightIndex = -1; });
    _focus.unfocus();
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => DoctorsList(initialSpecialty: s)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accentColor.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [BoxShadow(color: _accentColor.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              decoration: InputDecoration(
                hintText: 'Search by specialty (e.g. Cardiologist...)',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search_rounded, color: _accentColor, size: 20),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18, color: _accentColor), onPressed: () { _ctrl.clear(); setState(() { _showDropdown = false; _highlightIndex = -1; }); })
                    : const Icon(Icons.keyboard_arrow_down_rounded, color: _accentColor, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onChanged: _onChanged,
              onTap: () => _onChanged(_ctrl.text),
              onSubmitted: (v) { if (v.trim().isNotEmpty) _select(v.trim()); },
            ),
          ),
          if (_showDropdown && _filtered.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)],
              ),
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final highlighted = i == _highlightIndex;
                  return Container(
                    color: highlighted ? _accentColor.withValues(alpha: 0.08) : null,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.medical_services_outlined, size: 16, color: highlighted ? _accentColor : _accentColor.withValues(alpha: 0.7)),
                      title: Text(_filtered[i], style: TextStyle(fontSize: 13, fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal, color: highlighted ? _accentColor : const Color(0xFF0F172A))),
                      onTap: () => _select(_filtered[i]),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Condition Only Search Bar ─────────────────────────────────────────────────
class _ConditionOnlySearchBar extends StatefulWidget {
  @override
  State<_ConditionOnlySearchBar> createState() => _ConditionOnlySearchBarState();
}

class _ConditionOnlySearchBarState extends State<_ConditionOnlySearchBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _scrollCtrl = ScrollController();
  bool _showDropdown = false;
  List<String> _filtered = [];
  int _highlightIndex = -1;

  static const _accentColor = Color(0xFF0891B2);

  static const _all = [
    'Diabetes','Hypertension','Fever','Heart Disease','Asthma','Back Pain',
    'Arthritis','Anxiety','Depression','Migraine','Obesity','Thyroid',
    'Kidney Disease','Liver Disease','Cancer','Skin Problem','Eye Problem',
    'Ear Infection','Stomach Pain','Chest Pain','Shortness of Breath',
    'Joint Pain','Allergies','Insomnia','PCOS','Hepatitis','Dengue',
    'Typhoid','Anemia','Vitamin Deficiency',
  ];

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() { _showDropdown = false; _highlightIndex = -1; });
        });
      }
    });
    _focus.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (!_showDropdown || _filtered.isEmpty) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() { _highlightIndex = (_highlightIndex + 1) % _filtered.length; });
        _scrollToHighlight();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() { _highlightIndex = (_highlightIndex - 1 + _filtered.length) % _filtered.length; });
        _scrollToHighlight();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter && _highlightIndex >= 0) {
        _ctrl.text = _filtered[_highlightIndex];
        _select(_filtered[_highlightIndex]);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() { _showDropdown = false; _highlightIndex = -1; });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  void _scrollToHighlight() {
    if (!_scrollCtrl.hasClients || _highlightIndex < 0) return;
    const itemH = 44.0;
    final offset = (_highlightIndex * itemH).clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.animateTo(offset, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  void _onChanged(String v) {
    setState(() {
      _highlightIndex = -1;
      _filtered = v.isEmpty ? _all : _all.where((c) => c.toLowerCase().contains(v.toLowerCase())).toList();
      _showDropdown = v.isNotEmpty || _focus.hasFocus;
    });
  }

  void _select(String c) {
    _ctrl.text = c;
    setState(() { _showDropdown = false; _highlightIndex = -1; });
    _focus.unfocus();
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => DoctorsList(initialCondition: c)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accentColor.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [BoxShadow(color: _accentColor.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              decoration: InputDecoration(
                hintText: 'Search by condition (e.g. Diabetes, Fever...)',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search_rounded, color: _accentColor, size: 20),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18, color: _accentColor), onPressed: () { _ctrl.clear(); setState(() { _showDropdown = false; _highlightIndex = -1; }); })
                    : const Icon(Icons.keyboard_arrow_down_rounded, color: _accentColor, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onChanged: _onChanged,
              onTap: () => _onChanged(_ctrl.text),
              onSubmitted: (v) { if (v.trim().isNotEmpty) _select(v.trim()); },
            ),
          ),
          if (_showDropdown && _filtered.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)],
              ),
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final highlighted = i == _highlightIndex;
                  return Container(
                    color: highlighted ? _accentColor.withValues(alpha: 0.08) : null,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.healing_outlined, size: 16, color: highlighted ? _accentColor : _accentColor.withValues(alpha: 0.7)),
                      title: Text(_filtered[i], style: TextStyle(fontSize: 13, fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal, color: highlighted ? _accentColor : const Color(0xFF0F172A))),
                      onTap: () => _select(_filtered[i]),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Flashing Book Lab Button ──────────────────────────────────────────────────
// ── Glowing View All Button ───────────────────────────────────────────────────
class _GlowingViewAllButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _GlowingViewAllButton({required this.label, required this.color, required this.onTap});
  @override
  State<_GlowingViewAllButton> createState() => _GlowingViewAllButtonState();
}

class _GlowingViewAllButtonState extends State<_GlowingViewAllButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _glow = Tween<double>(begin: 4.0, end: 16.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, _) => GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [widget.color, widget.color.withValues(alpha: 0.8)]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.4), blurRadius: _glow.value, spreadRadius: 1)],
          ),
          child: Text(widget.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        ),
      ),
    );
  }
}

class _FlashingBookLabButton extends StatefulWidget {
  @override
  State<_FlashingBookLabButton> createState() => _FlashingBookLabButtonState();
}

class _FlashingBookLabButtonState extends State<_FlashingBookLabButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacityAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnim,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnim.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LabsListScreen())),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF4D00),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D00).withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Text(
            'Book Lab Test',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              fontFamily: 'Gilroy-Bold',
            ),
          ),
        ),
      ),
    );
  }
}

// ── Search Bars ───────────────────────────────────────────────────────────────
class _ConditionSearchBar extends StatefulWidget {
  @override
  State<_ConditionSearchBar> createState() => _ConditionSearchBarState();
}

class _ConditionSearchBarState extends State<_ConditionSearchBar> {
  String _filter = 'specialty';

  @override
  Widget build(BuildContext context) {
    final hintMap = {
      'specialty': 'Search by specialty (e.g. Cardiologist...)',
      'condition': 'Search by condition (e.g. Diabetes, Fever...)',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8ECF5), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Color(0xFFE8ECF5), width: 1.5)),
              ),
              child: DropdownButton<String>(
                value: _filter,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                style: const TextStyle(fontSize: 12, color: Color(0xFF0036BC), fontWeight: FontWeight.w600),
                items: const [
                  DropdownMenuItem(value: 'specialty', child: Text('Specialty')),
                  DropdownMenuItem(value: 'condition', child: Text('Condition')),
                ],
                onChanged: (v) => setState(() => _filter = v!),
              ),
            ),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: hintMap[_filter],
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0036BC), size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => _filter == 'specialty'
                            ? DoctorsList(initialSpecialty: value.trim())
                            : DoctorsList(initialCondition: value.trim()),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicineSearchBar extends StatefulWidget {
  @override
  State<_MedicineSearchBar> createState() => _MedicineSearchBarState();
}

class _MedicineSearchBarState extends State<_MedicineSearchBar> {
  String _filter = 'name';
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  int _highlightIndex = -1;
  List<dynamic> _allPharmacies = [];

  static const _accentColor = Color(0xFF95BF47);

  @override
  void initState() {
    super.initState();
    PharmacyService().getAllPharmacies().then((data) {
      if (mounted) setState(() => _allPharmacies = data);
    });
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() { _showSuggestions = false; _highlightIndex = -1; });
        });
      }
    });
    _focusNode.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (!_showSuggestions || _suggestions.isEmpty) return KeyEventResult.ignored;
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
        _activateSuggestion(_suggestions[_highlightIndex]);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() { _showSuggestions = false; _highlightIndex = -1; });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  void _scrollToHighlight() {
    if (!_scrollCtrl.hasClients || _highlightIndex < 0) return;
    const itemH = 55.0;
    final offset = (_highlightIndex * itemH).clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.animateTo(offset, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
  }

  void _activateSuggestion(Map<String, dynamic> p) {
    final isStatic = p.containsKey('_staticType');
    final name = (p['pharmacyName'] ?? p['pharmacy_name'] ?? p['name'] ?? 'Pharmacy').toString();
    final label = isStatic ? (p['_label'] as String) : name;
    setState(() { _controller.text = label; _showSuggestions = false; _highlightIndex = -1; });
    if (isStatic) {
      Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => PharmaciesScreen(initialSearch: label)));
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => PharmacyDetailsScreen(pharmacy: p)));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  static const _medicineCategories = [
    'Antibiotic', 'Painkiller / Analgesic', 'Antacid', 'Antifungal',
    'Antihistamine', 'Vitamin & Supplement', 'Blood Pressure Medicine',
    'Diabetes Medicine', 'Antiseptic', 'Cough Syrup', 'Eye Drops',
    'Skin Cream / Ointment', 'Injection', 'Antiviral',
  ];
  static const _medicineConditions = [
    'Fever', 'Cold & Flu', 'Cough', 'Headache', 'Diabetes', 'Hypertension',
    'Stomach Pain', 'Allergy', 'Skin Problem', 'Eye Infection',
    'Ear Infection', 'Anxiety / Depression', 'Asthma', 'Back Pain',
  ];

  void _updateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() { _suggestions = []; _showSuggestions = false; });
      return;
    }
    final q = query.toLowerCase();
    List<Map<String, dynamic>> results = [];

    if (_filter == 'name') {
      results = _allPharmacies.where((p) {
        final name = (p['pharmacyName'] ?? p['pharmacy_name'] ?? p['name'] ?? '').toString().toLowerCase();
        final city = (p['city'] ?? '').toString().toLowerCase();
        final area = (p['area'] ?? '').toString().toLowerCase();
        return name.contains(q) || city.contains(q) || area.contains(q);
      }).cast<Map<String, dynamic>>().take(6).toList();
    } else if (_filter == 'category') {
      results = _medicineCategories
          .where((c) => c.toLowerCase().contains(q))
          .take(6)
          .map((c) => {'_staticType': 'category', '_label': c})
          .toList();
    } else if (_filter == 'condition') {
      results = _medicineConditions
          .where((c) => c.toLowerCase().contains(q))
          .take(6)
          .map((c) => {'_staticType': 'condition', '_label': c})
          .toList();
    }
    setState(() { _highlightIndex = -1; _suggestions = results; _showSuggestions = results.isNotEmpty; });
  }

  @override
  Widget build(BuildContext context) {
    final hintMap = {
      'name': 'Search by medicine name or pharmacy...',
      'category': 'Search by category (e.g. Antibiotic...)',
      'condition': 'Search by condition (e.g. Fever, Pain...)',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8ECF5), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE8ECF5), width: 1.5)),
                  ),
                  child: DropdownButton<String>(
                    value: _filter,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                    style: const TextStyle(fontSize: 12, color: _accentColor, fontWeight: FontWeight.w600),
                    items: const [
                      DropdownMenuItem(value: 'name', child: Text('Medicine Name')),
                      DropdownMenuItem(value: 'category', child: Text('Category')),
                      DropdownMenuItem(value: 'condition', child: Text('Condition')),
                    ],
                    onChanged: (v) => setState(() { _filter = v!; _suggestions = []; _showSuggestions = false; _highlightIndex = -1; }),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: hintMap[_filter],
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      prefixIcon: const Icon(Icons.local_pharmacy_rounded, color: _accentColor, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onChanged: _updateSuggestions,
                    onSubmitted: (value) {
                      setState(() { _showSuggestions = false; _highlightIndex = -1; });
                      if (value.trim().isNotEmpty) {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (ctx) => PharmaciesScreen(initialSearch: value.trim()),
                        ));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_showSuggestions && _suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8ECF5), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (_, i) {
                    final p = _suggestions[i];
                    final highlighted = i == _highlightIndex;
                    final name = (p['pharmacyName'] ?? p['pharmacy_name'] ?? p['name'] ?? 'Pharmacy').toString();
                    final address = (p['address'] ?? p['city'] ?? '').toString();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        InkWell(
                          onTap: () => _activateSuggestion(p),
                          child: Container(
                            color: highlighted ? _accentColor.withValues(alpha: 0.07) : null,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: _accentColor.withValues(alpha: highlighted ? 0.18 : 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    p.containsKey('_staticType')
                                        ? (p['_staticType'] == 'condition' ? Icons.medical_services_outlined : Icons.category_outlined)
                                        : Icons.local_pharmacy_rounded,
                                    size: 15, color: _accentColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.containsKey('_staticType') ? (p['_label'] as String) : name,
                                        style: TextStyle(fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600, fontSize: 13, color: highlighted ? _accentColor : const Color(0xFF0F172A)),
                                      ),
                                      if (!p.containsKey('_staticType') && address.isNotEmpty)
                                        Text(address, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFFCBD5E1)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LabSearchBar extends StatefulWidget {
  @override
  State<_LabSearchBar> createState() => _LabSearchBarState();
}

class _LabSearchBarState extends State<_LabSearchBar> {
  String _filter = 'test';
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();
  List<_HomeSuggestion> _suggestions = [];
  bool _showSuggestions = false;
  int _highlightIndex = -1;
  List<Map<String, dynamic>> _allLabs = [];

  static const _accentColor = Color(0xFFFF4D00);

  @override
  void initState() {
    super.initState();
    LaboratoryService().getAllLaboratories().then((data) {
      if (mounted) setState(() => _allLabs = data.cast<Map<String, dynamic>>());
    });
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() { _showSuggestions = false; _highlightIndex = -1; });
        });
      }
    });
    _focusNode.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (!_showSuggestions || _suggestions.isEmpty) return KeyEventResult.ignored;
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
        _activateSuggestion(_suggestions[_highlightIndex]);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() { _showSuggestions = false; _highlightIndex = -1; });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  void _scrollToHighlight() {
    if (!_scrollCtrl.hasClients || _highlightIndex < 0) return;
    const itemH = 55.0;
    final offset = (_highlightIndex * itemH).clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.animateTo(offset, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
  }

  void _activateSuggestion(_HomeSuggestion s) {
    setState(() { _controller.text = s.label; _showSuggestions = false; _highlightIndex = -1; });
    final hasId = s.raw.containsKey('_id');
    if (hasId) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (ctx) => BookLabScreen(
          labId: s.raw['_id']?.toString() ?? '',
          labTitle: (s.raw['labName'] ?? s.raw['name'] ?? '').toString(),
          labProfileId: s.raw['profileId']?.toString(),
        ),
      ));
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (ctx) => LabsListScreen(initialSearch: s.label),
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  static const _labCategories = [
    'Blood Tests', 'Urine Analysis', 'X-Ray / Imaging', 'MRI / CT Scan',
    'Pathology', 'Microbiology', 'Serology', 'Hormone Tests',
    'Lipid Profile', 'Liver Function Tests', 'Kidney Function Tests',
    'Cardiac Tests', 'Thyroid Tests', 'Diabetes Tests', 'Allergy Tests',
  ];
  static const _commonTests = [
    'CBC (Complete Blood Count)', 'HbA1c', 'Blood Sugar (Fasting)',
    'Lipid Profile', 'Thyroid Panel (TSH/T3/T4)', 'Liver Function Test (LFT)',
    'Kidney Function Test (KFT)', 'Urine Complete Examination', 'ECG',
    'Chest X-Ray', 'Ultrasound Abdomen', 'COVID-19 PCR',
    'Hepatitis B (HBsAg)', 'Hepatitis C (HCV)',
  ];

  void _updateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() { _suggestions = []; _showSuggestions = false; });
      return;
    }
    final q = query.toLowerCase();
    final results = <_HomeSuggestion>[];

    if (_filter == 'lab') {
      for (final lab in _allLabs) {
        if (results.length >= 6) break;
        final name = (lab['labName'] ?? lab['name'] ?? '').toString();
        final address = (lab['address'] ?? lab['city'] ?? '').toString();
        if (name.toLowerCase().contains(q)) {
          results.add(_HomeSuggestion(label: name, sublabel: address, isTest: false, raw: lab));
        }
      }
    } else if (_filter == 'test') {
      for (final lab in _allLabs) {
        if (results.length >= 6) break;
        final tests = lab['availableTests'] as List? ?? [];
        for (final t in tests) {
          final tName = (t['name'] ?? t.toString()).toString();
          if (tName.toLowerCase().contains(q)) {
            final labName = (lab['labName'] ?? lab['name'] ?? '').toString();
            results.add(_HomeSuggestion(label: tName, sublabel: 'At: $labName', isTest: true, raw: lab));
            break;
          }
        }
      }
      if (results.length < 3) {
        for (final t in _commonTests) {
          if (t.toLowerCase().contains(q) && !results.any((r) => r.label.toLowerCase() == t.toLowerCase())) {
            results.add(_HomeSuggestion(label: t, sublabel: 'Search all labs', isTest: true, raw: {}));
          }
          if (results.length >= 6) break;
        }
      }
    } else if (_filter == 'category') {
      for (final cat in _labCategories) {
        if (cat.toLowerCase().contains(q)) {
          results.add(_HomeSuggestion(label: cat, sublabel: 'Browse labs by category', isTest: false, raw: {}));
        }
        if (results.length >= 6) break;
      }
    }
    setState(() { _highlightIndex = -1; _suggestions = results; _showSuggestions = results.isNotEmpty; });
  }

  @override
  Widget build(BuildContext context) {
    final hintMap = {
      'test': 'Search test name (e.g. CBC, HbA1c...)',
      'category': 'Search by category (e.g. Blood Test...)',
      'lab': 'Search by lab name (e.g. Chughtai...)',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8ECF5), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE8ECF5), width: 1.5)),
                  ),
                  child: DropdownButton<String>(
                    value: _filter,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                    style: const TextStyle(fontSize: 12, color: _accentColor, fontWeight: FontWeight.w600),
                    items: const [
                      DropdownMenuItem(value: 'test', child: Text('Test Name')),
                      DropdownMenuItem(value: 'category', child: Text('Category')),
                      DropdownMenuItem(value: 'lab', child: Text('Lab Name')),
                    ],
                    onChanged: (v) => setState(() { _filter = v!; _suggestions = []; _showSuggestions = false; _highlightIndex = -1; }),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: hintMap[_filter],
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      prefixIcon: const Icon(Icons.biotech_rounded, color: _accentColor, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onChanged: _updateSuggestions,
                    onSubmitted: (value) {
                      setState(() { _showSuggestions = false; _highlightIndex = -1; });
                      if (value.trim().isNotEmpty) {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (ctx) => LabsListScreen(initialSearch: value.trim()),
                        ));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_showSuggestions && _suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8ECF5), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (_, i) {
                    final s = _suggestions[i];
                    final highlighted = i == _highlightIndex;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        InkWell(
                          onTap: () => _activateSuggestion(s),
                          child: Container(
                            color: highlighted ? _accentColor.withValues(alpha: 0.07) : null,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: _accentColor.withValues(alpha: highlighted ? 0.15 : 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    s.isTest ? Icons.biotech_outlined : Icons.science_outlined,
                                    size: 15, color: _accentColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.label, style: TextStyle(fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600, fontSize: 13, color: highlighted ? _accentColor : const Color(0xFF0F172A))),
                                      if (s.sublabel.isNotEmpty)
                                        Text(s.sublabel, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFFCBD5E1)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeSuggestion {
  final String label;
  final String sublabel;
  final bool isTest;
  final Map<String, dynamic> raw;
  const _HomeSuggestion({required this.label, required this.sublabel, required this.isTest, required this.raw});
}

// ── Courses Section ───────────────────────────────────────────────────────────
class _CoursesSection extends StatelessWidget {
  static const _courses = [
    {'title': 'Diet Plan & Health Courses', 'desc': 'For Patients — Learn to manage your health', 'icon': Icons.restaurant_menu_rounded, 'color': 0xFF10B981, 'audience': 'patient'},
    {'title': 'Training Programs and Courses', 'desc': 'For Healthcare Professionals', 'icon': Icons.school_rounded, 'color': 0xFFF59E0B, 'audience': 'doctor'},
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: _CenteredSection(
        child: Column(
          children: [
            _SectionHeader(
              title: "Join Pakistan's First 360° Health Care Platform",
              subtitle: 'Open for Everyone • Live Skill Academy for Everyone',
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: isMobile
                  ? Column(
                      children: _courses.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CourseCard(course: c),
                      )).toList(),
                    )
                  : GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 2.8,
                      children: _courses.map((c) => _CourseCard(course: c)).toList(),
                    ),
            ),
            const SizedBox(height: 32),
            // Explore All Courses Button
            ElevatedButton.icon(
              onPressed: () {
                context.go('/lms/catalog');
              },
              icon: const Icon(Icons.school_rounded, size: 20),
              label: const Text('Explore All Courses'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatefulWidget {
  final Map<String, Object> course;
  const _CourseCard({required this.course});

  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  @override
  Widget build(BuildContext context) {
    final color = Color(widget.course['color'] as int);
    return GestureDetector(
        onTap: () {
          final audience = widget.course['audience'] as String? ?? 'patient';
          context.push('/lms/catalog', extra: {'audienceFilter': audience});
        },
        child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F3F3), width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.course['icon'] as IconData, color: color, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.course['title'] as String,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                  fontFamily: 'Gilroy-Bold',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.course['desc'] as String,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
}

// ── Card Data Model ───────────────────────────────────────────────────────────
class _CardData {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final IconData icon;
  final Color iconColor;
  final Color? iconBg;

  const _CardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  }) : imageUrl = null, iconBg = null;
}

// ── Navbar Button ─────────────────────────────────────────────────────────────
class _NavButton extends StatefulWidget {
  final String label;
  final bool filled;
  final bool accent;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.accent = false,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile && widget.label == 'Work With Us') {
      return GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF10B981), width: 1.5),
          ),
          child: const Icon(Icons.work_outline_rounded, color: Color(0xFF10B981), size: 18),
        ),
      );
    }

    final bgColor = widget.filled
        ? (_hovered ? AppColors.primaryColor.withValues(alpha: 0.85) : AppColors.primaryColor)
        : widget.accent
            ? (_hovered ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFF10B981).withValues(alpha: 0.08))
            : (_hovered ? AppColors.primaryColor.withValues(alpha: 0.06) : Colors.transparent);

    final textColor = widget.filled
        ? Colors.white
        : widget.accent
            ? const Color(0xFF10B981)
            : AppColors.primaryColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 20,
            vertical: isMobile ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.filled
                  ? AppColors.primaryColor
                  : widget.accent
                      ? const Color(0xFF10B981)
                      : AppColors.primaryColor,
              width: 1.5,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: isMobile ? 12 : 14,
              fontFamily: 'Gilroy-Bold',
            ),
          ),
        ),
      ),
    );
  }
}

// ── Banner ────────────────────────────────────────────────────────────────────
class _Banner extends StatefulWidget {
  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 700;
    final h = isMobile ? 400.0 : (w < 900 ? 450.0 : 500.0);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 30,
        vertical: isMobile ? 12 : 10,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isMobile ? 20 : 28),
        child: SizedBox(
          width: double.infinity,
          height: h,
          child: Stack(
            fit: StackFit.expand,
            children: [
          // 1. Background — mobile: gradient only, desktop: banner image
          if (!isMobile)
            Image.asset(
              'assets/newban.png',
              fit: BoxFit.cover,
              alignment: const Alignment(1.0, -0.85),
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0026A0), Color(0xFF0036BC), Color(0xFF1565C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          // Mobile: pure gradient background
          if (isMobile)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0026A0),
                    Color(0xFF0036BC),
                    Color(0xFF1565C0),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          // 2. Text + buttons — left side
          Padding(
            padding: EdgeInsets.only(
              left: isMobile ? 20 : 52,
              right: isMobile ? w * 0.10 : w * 0.42,
              top: isMobile ? 24 : 44,
              bottom: isMobile ? 24 : 44,
            ),
            child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Consult a Doctor',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: isMobile ? 24 : 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFamily: 'Gilroy-Bold',
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: isMobile ? 10 : 14),
                    Text(
                      'Consult trusted doctors, book appointments\nand access healthcare from home 24/7.',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 15,
                        color: Colors.white.withValues(alpha: 0.90),
                        height: 1.55,
                      ),
                    ),
                    SizedBox(height: isMobile ? 22 : 30),
                    Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        // Connect button (white filled)
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            final g = (_pulseAnimation.value - 1.0) / 0.06;
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.4 * g),
                                    blurRadius: 18,
                                    spreadRadius: 3 * g,
                                  ),
                                ],
                              ),
                              child: child,
                            );
                          },
                          child: ElevatedButton(
                            onPressed: () async {
                              if (await _requireAuth(context)) {
                                if (context.mounted) {
                                  Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const ConsultationDetailsScreen()),
                                );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0036BC),
                              minimumSize: Size(isMobile ? 145 : 185, isMobile ? 46 : 52),
                              padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 28),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: Text(
                              'Connect to a Doctor Now',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: isMobile ? 12 : 14,
                                fontFamily: 'Gilroy-Bold',
                              ),
                            ),
                          ),
                        ),
                        // Book Appointment button (outlined)
                        OutlinedButton(
                          onPressed: () async {
                            if (await _requireAuth(context)) {
                              if (context.mounted) {
                                Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const DoctorsList()),
                              );
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white, width: 2),
                            minimumSize: Size(isMobile ? 145 : 185, isMobile ? 46 : 52),
                            padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 28),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Book Appointment',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: isMobile ? 12 : 14,
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
      ),
    );
  }
}

// ── Centered Section Wrapper ──────────────────────────────────────────────────
class _CenteredSection extends StatelessWidget {
  final Widget child;
  const _CenteredSection({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: child,
      ),
    );
  }
}

// ── Doctors Slider ───────────────────────────────────────────────────────────
class _DoctorsSlider extends StatefulWidget {
  @override
  State<_DoctorsSlider> createState() => _DoctorsSliderState();
}

class _DoctorsSliderState extends State<_DoctorsSlider> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoPlayTimer;
  List<Map<String, dynamic>> _doctors = [];
  bool _loading = true;
  bool _isMobile = false;

  static const List<Map<String, dynamic>> _fallbackDoctors = [
    {'name': 'Dr. Ahmed Khan', 'spec': 'Cardiologist', 'exp': '15 years experience', 'rating': '4.9', 'reviews': '342', 'img': 'assets/images/user5.png', 'isOnline': true},
    {'name': 'Dr. Sara Malik', 'spec': 'Gynecologist', 'exp': '12 years experience', 'rating': '4.8', 'reviews': '289', 'img': 'assets/images/user1.png', 'isOnline': true},
    {'name': 'Dr. Bilal Ahmed', 'spec': 'Neurologist', 'exp': '10 years experience', 'rating': '4.7', 'reviews': '198', 'img': 'assets/images/user7.png', 'isOnline': true},
    {'name': 'Dr. Hina Raza', 'spec': 'Dermatologist', 'exp': '8 years experience', 'rating': '4.9', 'reviews': '412', 'img': 'assets/images/user10.png', 'isOnline': true},
    {'name': 'Dr. Usman Ali', 'spec': 'Pediatrician', 'exp': '14 years experience', 'rating': '4.8', 'reviews': '320', 'img': 'assets/images/user11.png', 'isOnline': true},
    {'name': 'Dr. Ayesha Noor', 'spec': 'Psychiatrist', 'exp': '11 years experience', 'rating': '4.6', 'reviews': '175', 'img': 'assets/images/user12.png', 'isOnline': true},
    {'name': 'Dr. Kamran Baig', 'spec': 'Orthopedic Surgeon', 'exp': '18 years experience', 'rating': '4.9', 'reviews': '511', 'img': 'assets/images/user5.png', 'isOnline': true},
    {'name': 'Dr. Zara Sheikh', 'spec': 'ENT Specialist', 'exp': '9 years experience', 'rating': '4.8', 'reviews': '230', 'img': 'assets/images/user13.png', 'isOnline': true},
  ];

  int get _totalPages {
    if (_doctors.isEmpty) return 1;
    return _isMobile ? _doctors.length : (_doctors.length / 4).ceil();
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchOnlineDoctors();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchOnlineDoctors() async {
    try {
      final result = await DoctorService().getAllDoctors();
      if (result['success'] == true) {
        final all = (result['doctors'] as List? ?? []).cast<Map<String, dynamic>>();
        final online = all.where((d) => d['isOnline'] == true).toList();
        if (mounted) {
          setState(() {
            _doctors = online;
            _loading = false;
          });
          if (online.isNotEmpty) _startAutoPlay();
        }
      } else {
        _useEmpty();
      }
    } catch (_) {
      _useEmpty();
    }
  }

  void _useEmpty() {
    if (mounted) setState(() { _doctors = []; _loading = false; });
  }

  void _useFallback() {
    if (mounted) {
      setState(() {
        _doctors = List<Map<String, dynamic>>.from(_fallbackDoctors);
        _loading = false;
      });
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _doctors.isEmpty) return;
      final next = (_currentPage + 1) % _totalPages;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    _isMobile = screenWidth < 700;

    if (_loading) {
      return SizedBox(
        height: 280,
        child: Center(
          child: CircularProgressIndicator(
            color: const Color(0xFF0036BC),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_doctors.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.watch_later_outlined, color: Color(0xFF0284C7), size: 24),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'No doctors are available right now. Please check back soon.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF0369A1), fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    if (_isMobile) {
      return Column(
        children: [
          SizedBox(
            height: 290,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (p) => setState(() => _currentPage = p),
              itemCount: _doctors.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _DoctorCard(doctor: _doctors[i]),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SliderDots(
            total: _doctors.length,
            current: _currentPage,
            onTap: _goTo,
          ),
        ],
      );
    }

    // Desktop: 4 cards per page
    final totalPages = (_doctors.length / 4).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: SizedBox(
                  height: 295,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (p) => setState(() => _currentPage = p),
                    itemCount: totalPages,
                    itemBuilder: (_, pageIndex) {
                      final start = pageIndex * 4;
                      final pageDoctors = _doctors.skip(start).take(4).toList();
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: pageDoctors.map((doctor) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          child: _DoctorCard(doctor: doctor),
                        )).toList(),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                left: 0,
                child: _SliderButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => _goTo(_currentPage - 1),
                  enabled: _currentPage > 0,
                ),
              ),
              Positioned(
                right: 0,
                child: _SliderButton(
                  icon: Icons.arrow_forward_rounded,
                  onTap: () => _goTo(_currentPage + 1),
                  enabled: _currentPage < totalPages - 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SliderDots(
            total: totalPages,
            current: _currentPage,
            onTap: _goTo,
          ),
        ],
      ),
    );
  }
}

class _SliderButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _SliderButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  @override
  State<_SliderButton> createState() => _SliderButtonState();
}

class _SliderButtonState extends State<_SliderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: widget.enabled
                ? (_hovered ? const Color(0xFF0024A0) : const Color(0xFF0036BC))
                : Colors.grey[300],
            shape: BoxShape.circle,
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF0036BC).withValues(alpha: _hovered ? 0.45 : 0.25),
                      blurRadius: _hovered ? 22 : 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.icon,
            color: widget.enabled ? Colors.white : Colors.grey[500],
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _SliderDots extends StatelessWidget {
  final int total;
  final int current;
  final void Function(int) onTap;

  const _SliderDots({
    required this.total,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        return GestureDetector(
          onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            width: isActive ? 32 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF0036BC) : const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}

class _DoctorCard extends StatefulWidget {
  final Map<String, dynamic> doctor;

  const _DoctorCard({required this.doctor});

  @override
  State<_DoctorCard> createState() => _DoctorCardState();
}

class _DoctorCardState extends State<_DoctorCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.doctor;
    final name = d['name']?.toString() ?? 'Doctor';
    final spec = d['spec']?.toString() ?? d['specialization']?.toString() ?? 'Specialist';
    final exp = d['exp']?.toString() ??
        (d['experience'] != null ? '${d['experience']} years experience' : 'Experienced');
    final rating = d['rating']?.toString() ?? '4.5';
    final reviews = d['reviews']?.toString() ?? d['totalReviews']?.toString() ?? '0';
    final isOnline = d['isOnline'] == true || d['isOnline'] == 'true';
    final imgAsset = d['img']?.toString();
    final imgUrl = d['profilePicture']?.toString();
    final ratingVal = double.tryParse(rating) ?? 4.5;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 210,
        padding: const EdgeInsets.all(16),
        transform: Matrix4.identity()..translate(0.0, _hovered ? -4.0 : 0.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered ? const Color(0xFF14B1FF) : const Color(0xFFF3F3F3),
            width: 2,
          ),
          boxShadow: [
            if (_hovered)
              BoxShadow(
                color: const Color(0xFF14B1FF).withValues(alpha: 0.15),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isOnline ? Colors.green : const Color(0xFF14B1FF),
                      width: 2.5,
                    ),
                  ),
                  child: ClipOval(
                    child: imgUrl != null && imgUrl.isNotEmpty
                        ? Image.network(
                            imgUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: const Color(0xFF0036BC),
                              child: const Icon(Icons.person, size: 36, color: Colors.white),
                            ),
                          )
                        : imgAsset != null && imgAsset.isNotEmpty
                            ? Image.asset(
                                imgAsset,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: const Color(0xFF0036BC),
                                  child: const Icon(Icons.person, size: 36, color: Colors.white),
                                ),
                              )
                            : Container(
                                color: const Color(0xFF0036BC),
                                child: const Icon(Icons.person, size: 36, color: Colors.white),
                              ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0036BC),
                fontFamily: 'Gilroy-Bold',
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              spec,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              exp,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            if (isOnline)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text('Online', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Color(0xFFF5A623), size: 13),
                const Icon(Icons.star, color: Color(0xFFF5A623), size: 13),
                const Icon(Icons.star, color: Color(0xFFF5A623), size: 13),
                const Icon(Icons.star, color: Color(0xFFF5A623), size: 13),
                Icon(
                  ratingVal >= 4.8 ? Icons.star : Icons.star_border,
                  color: const Color(0xFFF5A623),
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  '$rating ($reviews)',
                  style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const DoctorsList()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0036BC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Consult Now',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Gilroy-Bold',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pharmacies Grid ──────────────────────────────────────────────────────────
class _PharmaciesGrid extends StatelessWidget {
  static const _pharmacies = [
    {'name': 'MedPlus Pharmacy', 'area': 'Gulshan, Karachi', 'rating': '4.8'},
    {'name': 'HealthCare Pharma', 'area': 'DHA, Lahore', 'rating': '4.7'},
    {'name': 'City Pharmacy', 'area': 'F-7, Islamabad', 'rating': '4.6'},
    {'name': 'Al-Shifa Pharmacy', 'area': 'Saddar, Karachi', 'rating': '4.9'},
    {'name': 'Cure Pharmacy', 'area': 'Model Town, Lahore', 'rating': '4.5'},
    {'name': 'Wellness Pharma', 'area': 'G-11, Islamabad', 'rating': '4.7'},
    {'name': 'Shifaa Pharmacy', 'area': 'Clifton, Karachi', 'rating': '4.8'},
    {'name': 'Apollo Pharmacy', 'area': 'Johar Town, Lahore', 'rating': '4.6'},
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: isMobile ? 2 : 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: isMobile ? 1.3 : 1.5,
        children: _pharmacies.map((p) => _ServiceCard(
          name: p['name']!,
          subtitle: p['area']!,
          rating: p['rating']!,
          icon: Icons.local_pharmacy_rounded,
          iconColor: const Color(0xFF95BF47),
          width: double.infinity,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PharmaciesScreen()),
          ),
        )).toList(),
      ),
    );
  }
}

// ── Laboratories Grid ─────────────────────────────────────────────────────────
class _LaboratoriesGrid extends StatelessWidget {
  static const _labs = [
    {'name': 'Chughtai Lab', 'area': 'Lahore', 'rating': '4.9'},
    {'name': 'Essa Lab', 'area': 'Karachi', 'rating': '4.7'},
    {'name': 'Excel Labs', 'area': 'Islamabad', 'rating': '4.8'},
    {'name': 'Shaukat Khanum Lab', 'area': 'Lahore', 'rating': '4.9'},
    {'name': 'Agha Khan Lab', 'area': 'Karachi', 'rating': '4.8'},
    {'name': 'Islamabad Diagnostic', 'area': 'Islamabad', 'rating': '4.6'},
    {'name': 'Doctors Lab', 'area': 'Rawalpindi', 'rating': '4.5'},
    {'name': 'Metropole Lab', 'area': 'Karachi', 'rating': '4.7'},
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: isMobile ? 2 : 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: isMobile ? 1.3 : 1.5,
        children: _labs.map((l) => _ServiceCard(
          name: l['name']!,
          subtitle: l['area']!,
          rating: l['rating']!,
          icon: Icons.biotech_rounded,
          iconColor: const Color(0xFFFF4D00),
          width: double.infinity,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LabsListScreen()),
          ),
        )).toList(),
      ),
    );
  }
}

// ── Service Card (Pharmacy / Lab) ─────────────────────────────────────────────
class _ServiceCard extends StatefulWidget {
  final String name;
  final String subtitle;
  final String rating;
  final IconData icon;
  final Color iconColor;
  final double width;
  final VoidCallback? onTap;

  const _ServiceCard({
    required this.name,
    required this.subtitle,
    required this.rating,
    required this.icon,
    required this.iconColor,
    required this.width,
    this.onTap,
  });

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.width,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        transform: Matrix4.identity()..translate(0.0, _hovered ? -3.0 : 0.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovered ? widget.iconColor : const Color(0xFFF3F3F3),
            width: 2,
          ),
          boxShadow: [
            if (_hovered)
              BoxShadow(
                color: widget.iconColor.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: widget.iconColor, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              widget.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
                fontFamily: 'Gilroy-Bold',
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              widget.subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 13),
                const SizedBox(width: 3),
                Text(
                  widget.rating,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

// ── Specialty Grid ────────────────────────────────────────────────────────────
class _SpecialtyGrid extends StatelessWidget {
  static const _specialties = [
    {'name': 'Cardiologist', 'desc': 'Heart & Vascular', 'icon': Icons.favorite},
    {'name': 'Neurologist', 'desc': 'Brain & Nerves', 'icon': Icons.psychology},
    {'name': 'Orthopedic', 'desc': 'Bones & Joints', 'icon': Icons.accessibility_new},
    {'name': 'Pediatrician', 'desc': 'Child Specialist', 'icon': Icons.child_care},
    {'name': 'Dentist', 'desc': 'Oral & Dental', 'icon': Icons.medical_services},
    {'name': 'Eye Specialist', 'desc': 'Ophthalmology', 'icon': Icons.remove_red_eye},
    {'name': 'Pulmonologist', 'desc': 'Lungs & Chest', 'icon': Icons.air},
    {'name': 'Dermatologist', 'desc': 'Skin & Hair', 'icon': Icons.face},
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: isMobile ? 2 : 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: isMobile ? 1.3 : 1.5,
        children: _specialties.map((spec) {
          return _SpecialtyCard(
            name: spec['name'] as String,
            description: spec['desc'] as String,
            icon: spec['icon'] as IconData,
            width: double.infinity,
          );
        }).toList(),
      ),
    );
  }
}

class _SpecialtyCard extends StatefulWidget {
  final String name;
  final String description;
  final IconData icon;
  final double width;

  const _SpecialtyCard({
    required this.name,
    required this.description,
    required this.icon,
    required this.width,
  });

  @override
  State<_SpecialtyCard> createState() => _SpecialtyCardState();
}

class _SpecialtyCardState extends State<_SpecialtyCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DoctorsList(initialSpecialty: widget.name)),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          transform: Matrix4.identity()..translate(0.0, _hovered ? -3.0 : 0.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? const Color(0xFF7C3AED) : const Color(0xFFF3F3F3),
              width: 2,
            ),
            boxShadow: [
              if (_hovered)
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: const Color(0xFF7C3AED), size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                widget.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                  fontFamily: 'Gilroy-Bold',
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                widget.description,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Condition Grid ────────────────────────────────────────────────────────────
class _ConditionGrid extends StatelessWidget {
  static const _conditions = [
    {'name': 'Diabetes', 'desc': 'Blood Sugar Management', 'icon': Icons.bloodtype},
    {'name': 'Fever', 'desc': 'High Temperature & Flu', 'icon': Icons.thermostat},
    {'name': 'Back Pain', 'desc': 'Spine & Muscle Pain', 'icon': Icons.accessibility},
    {'name': 'Hypertension', 'desc': 'High Blood Pressure', 'icon': Icons.monitor_heart},
    {'name': 'Headache', 'desc': 'Migraine & Tension', 'icon': Icons.psychology_alt},
    {'name': 'Asthma', 'desc': 'Breathing & Lungs', 'icon': Icons.air},
    {'name': 'Allergy', 'desc': 'Skin & Respiratory', 'icon': Icons.coronavirus},
    {'name': 'Anxiety', 'desc': 'Mental Health', 'icon': Icons.self_improvement},
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: isMobile ? 2 : 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: isMobile ? 1.3 : 1.5,
        children: _conditions.map((cond) {
          return _ConditionCard(
            name: cond['name'] as String,
            description: cond['desc'] as String,
            icon: cond['icon'] as IconData,
          );
        }).toList(),
      ),
    );
  }
}

class _ConditionCard extends StatefulWidget {
  final String name;
  final String description;
  final IconData icon;

  const _ConditionCard({
    required this.name,
    required this.description,
    required this.icon,
  });

  @override
  State<_ConditionCard> createState() => _ConditionCardState();
}

class _ConditionCardState extends State<_ConditionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DoctorsList(initialCondition: widget.name)),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          transform: Matrix4.identity()..translate(0.0, _hovered ? -3.0 : 0.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? const Color(0xFF0891B2) : const Color(0xFFF3F3F3),
              width: 2,
            ),
            boxShadow: [
              if (_hovered)
                BoxShadow(
                  color: const Color(0xFF0891B2).withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F7FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: const Color(0xFF0891B2), size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                widget.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                  fontFamily: 'Gilroy-Bold',
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                widget.description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── How It Works Steps ──────────────────────────────────────────────────────
class _HowItWorksSteps extends StatelessWidget {
  static const _steps = [
    {'num': '1', 'title': 'Search and Select', 'desc': 'Find the right doctor by specialty, condition, or name'},
    {'num': '2', 'title': 'Book Appointment', 'desc': 'Choose a convenient time slot and confirm your appointment'},
    {'num': '3', 'title': 'Video Consult', 'desc': "Connect via secure HD video call with iCare's trusted doctor"},
    {'num': '4', 'title': 'Get Prescription', 'desc': 'Receive digital prescriptions and follow-up care plans'},
    {'num': '5', 'title': 'Get Medicines and Lab Tests', 'desc': 'Get medicines and lab tests from the comfort of your home'},
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: _steps.map((step) => Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _StepCard(
              number: step['num']!,
              title: step['title']!,
              description: step['desc']!,
            ),
          )).toList(),
        ),
      );
    }

    // Desktop: ALL 5 steps in one horizontal row + fork from step 5
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Steps 1–5 with horizontal connecting line
          Expanded(
            child: Stack(
              children: [
                // Horizontal blue line — goes all the way to right edge (into fork)
                Positioned(
                  top: 28,
                  left: 40,
                  right: 0,
                  child: Container(height: 3, color: const Color(0xFF0036BC)),
                ),
                Row(
                  children: _steps.map((step) => Expanded(
                    child: _StepCard(
                      number: step['num']!,
                      title: step['title']!,
                      description: step['desc']!,
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          // Fork widget — two diagonal lines from step 5 + labels
          SizedBox(
            width: 150,
            height: 130,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Draw the two diagonal blue lines
                CustomPaint(
                  size: const Size(150, 130),
                  painter: _ForkPainter(color: const Color(0xFF0036BC)),
                ),
                // Lab Test label — top right
                Positioned(
                  right: 0,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0036BC), width: 2),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.biotech_rounded, color: Color(0xFFFF4D00), size: 13),
                        SizedBox(width: 4),
                        Text('Lab Test',
                          style: TextStyle(color: Color(0xFF0036BC), fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                // Pharmacy label — bottom right
                Positioned(
                  right: 0,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0036BC), width: 2),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_pharmacy_rounded, color: Color(0xFF10B981), size: 13),
                        SizedBox(width: 4),
                        Text('Pharmacy',
                          style: TextStyle(color: Color(0xFF0036BC), fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
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

class _BranchForkItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;       // line color (blue)
  final Color labelColor;  // badge color (orange/green)
  final bool angleUp;
  const _BranchForkItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.labelColor,
    required this.angleUp,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, angleUp ? -10 : 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Diagonal blue line connected from step 5
          Transform.rotate(
            angle: angleUp ? -0.45 : 0.45,
            child: Container(
              width: 52,
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: labelColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: labelColor.withValues(alpha: 0.45), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: labelColor, size: 13),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchArrow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _BranchArrow({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.arrow_downward_rounded, color: color, size: 20),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _StepCard({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF0036BC),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF14B1FF).withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFamily: 'Gilroy-Bold',
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0036BC),
            fontFamily: 'Gilroy-Bold',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// Fork painter — draws 2 diagonal lines from (0, 28) to top-right and bottom-right
// Starts at y=28 to align perfectly with the horizontal connecting line
class _ForkPainter extends CustomPainter {
  final Color color;
  const _ForkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Start point — same vertical level as horizontal line (top: 28)
    const origin = Offset(0, 28);

    // Upper branch → Lab Test (top-right)
    canvas.drawLine(origin, Offset(size.width * 0.65, size.height * 0.18), paint);

    // Lower branch → Pharmacy (bottom-right)
    canvas.drawLine(origin, Offset(size.width * 0.65, size.height * 0.82), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── App Download Banner ────────────────────────────────────────────────────────
class _AppDownloadBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    const decoration = BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0036BC), Color(0xFF0049E6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );

    if (isMobile) {
      return Container(
        width: double.infinity,
        decoration: decoration,
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        child: Column(
          children: [
            Image.asset(
              'assets/images/mockup.png',
              height: 300,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 200,
                child: Icon(Icons.phone_android, size: 80, color: Colors.white54),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Download the iCare App',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFamily: 'Gilroy-Bold',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Get instant access to 500+ doctors, lab results, prescriptions, and health records — all in one place.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _AppBadges(),
          ],
        ),
      );
    }

    return SizedBox(
      height: 400,
      child: Container(
        width: double.infinity,
        decoration: decoration,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 60),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Download the iCare App',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontFamily: 'Gilroy-Bold',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Get instant access to 500+ doctors, lab results,\nprescriptions, and health records — all in one place.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.95),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _AppBadges(),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 520,
                  child: OverflowBox(
                    maxHeight: 780,
                    alignment: Alignment.center,
                    child: _PhoneMockups(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppBadges extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _StoreBadgeButton(
          onTap: () {},
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.apple, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download on the',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const Text(
                      'App Store',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _StoreBadgeButton(
          onTap: () {},
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GET IT ON',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Text(
                      'Google Play',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StoreBadgeButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _StoreBadgeButton({required this.onTap, required this.child});

  @override
  State<_StoreBadgeButton> createState() => _StoreBadgeButtonState();
}

class _StoreBadgeButtonState extends State<_StoreBadgeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _hovered ? 0.85 : 1.0,
          child: widget.child,
        ),
      ),
    );
  }
}

class _PhoneMockups extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/mockup.png',
      height: 750,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => Container(
        height: 600,
        width: 440,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 3,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.phone_android,
              size: 100,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Mobile Screens',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Header with subtitle ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? titleColor;
  const _SectionHeader({required this.title, this.subtitle, this.onTap, this.titleColor});

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: titleColor ?? const Color(0xFF0036BC),
              fontFamily: 'Gilroy-Bold',
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: content,
        ),
      );
    }
    return content;
  }
}

// ── Footer (white bg + blue theme) ────────────────────────────────────────────
class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ..._buildMobileFooter() else ..._buildDesktopFooter(),
          const SizedBox(height: 32),
          const Divider(color: Color(0xFFE8ECF5), thickness: 1),
          const SizedBox(height: 20),
          _buildFooterBottom(isMobile),
        ],
      ),
    );
  }

  List<Widget> _buildDesktopFooter() {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/Asset 1.png',
                  height: 90,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                const SizedBox(height: 12),
                Text(
                  "Pakistan's leading telehealth platform connecting patients with top specialists for secured online consultations, lab tests and digital prescription.",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
          const Expanded(
            child: _FooterColumn(
              title: 'For Patients',
              items: [
                'Find a Doctor',
                'Book Lab Tests',
                'Order Medicines',
                'Health Records',
                'Teleconsultation',
              ],
            ),
          ),
          const SizedBox(width: 40),
          const Expanded(
            child: _FooterColumn(
              title: 'Company',
              items: [
                'About Us',
                'Careers',
                'Privacy Policy',
                'Terms of Service',
                'Contact Us',
              ],
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildMobileFooter() {
    return [
      Image.asset(
        'assets/Asset 1.png',
        height: 72,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
      const SizedBox(height: 12),
      Text(
        "Pakistan's leading telehealth platform connecting patients with top specialists for secured online consultations, lab tests and digital prescription.",
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          height: 1.6,
        ),
      ),
      const SizedBox(height: 24),
      const _FooterColumn(
        title: 'For Patients',
        items: [
          'Find a Doctor',
          'Book Lab Tests',
          'Order Medicines',
          'Health Records',
          'Teleconsultation',
        ],
      ),
      const SizedBox(height: 20),
      const _FooterColumn(
        title: 'Company',
        items: [
          'About Us',
          'Careers',
          'Privacy Policy',
          'Terms of Service',
          'Contact Us',
        ],
      ),
    ];
  }

  Widget _buildFooterBottom(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          Text(
            '© 2026 iCare. All rights reserved.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '© 2026 iCare. All rights reserved.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<String> items;

  const _FooterColumn({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0036BC),
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            item,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        )),
      ],
    );
  }
}

// ── Achievements & Rewards Banner ────────────────────────────────────────────
class _AchievementsBanner extends StatelessWidget {
  const _AchievementsBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GamificationScreen()),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0036BC), Color(0xFF7C3AED)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0036BC).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Achievements & Rewards',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Gilroy-Bold',
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Earn points, unlock badges, redeem rewards',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// The scrollable body content of the public home page, without the top navbar.
/// Used on the logged-in patient home page so the layout matches the public home.
class PublicHomeBody extends StatelessWidget {
  const PublicHomeBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Banner(),
        const SizedBox(height: 40),
        // 1. Connect to a Doctor
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: _CenteredSection(
            child: Column(
              children: [
                _SectionHeader(
                  title: 'Consult Available Doctors',
                  subtitle: 'Talk to a verified doctor within minutes from the comfort of your home',
                ),
                const SizedBox(height: 24),
                _DoctorsSlider(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        // Achievements & Rewards Banner
        _AchievementsBanner(),
        const SizedBox(height: 60),
        // 2. Browse by Specialty (before pharmacy/labs)
        _CenteredSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _SectionHeader(
                title: 'Browse by Specialty',
                subtitle: 'Find the right specialist for your health needs',
                titleColor: const Color(0xFF7C3AED),
              ),
              const SizedBox(height: 16),
              _ConditionSearchBar(),
              const SizedBox(height: 24),
              _SpecialtyGrid(),
              const SizedBox(height: 24),
              Center(
                child: _GlowingViewAllButton(
                  label: 'See All Speciality',
                  color: const Color(0xFF7C3AED),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DoctorsList(initialSearchMode: 'specialty')),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Search Doctors',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      fontFamily: 'Gilroy-Bold',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Search by doctor name, specialty, or condition',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: DoctorSearchBar(isMobile: MediaQuery.of(ctx).size.width < 700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 60),
        // 3. Order Medicines
        _CenteredSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _SectionHeader(
                title: 'Order Medicines',
                subtitle: 'Order medicines from trusted pharmacies near you',
                titleColor: const Color(0xFF95BF47),
              ),
              const SizedBox(height: 16),
              _MedicineSearchBar(),
              const SizedBox(height: 24),
              _PharmaciesGrid(),
            ],
          ),
        ),
        const SizedBox(height: 60),
        // 4. Book a Lab Test
        Container(
          color: Colors.white,
          padding: const EdgeInsets.only(top: 60, bottom: 32),
          child: _CenteredSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _SectionHeader(
                  title: 'Book a Lab Test',
                  subtitle: 'Book lab tests and get results delivered at home',
                  titleColor: const Color(0xFFFF4D00),
                ),
                const SizedBox(height: 16),
                _LabSearchBar(),
                const SizedBox(height: 24),
                _LaboratoriesGrid(),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LabsListScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFF4D00), width: 1.5),
                      ),
                      child: const Text(
                        'Book Lab',
                        style: TextStyle(
                          color: Color(0xFFFF4D00),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          fontFamily: 'Gilroy-Bold',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 5. Courses Section
        _CoursesSection(),
        const SizedBox(height: 24),
        // 6. How iCare Works
        Container(
          color: Colors.white,
          padding: const EdgeInsets.only(top: 36, bottom: 60),
          child: _CenteredSection(
            child: Column(
              children: [
                _SectionHeader(
                  title: 'How iCare Works',
                  subtitle: 'Get quality healthcare in 5 simple steps',
                ),
                const SizedBox(height: 40),
                _HowItWorksSteps(),
              ],
            ),
          ),
        ),
        // App Download Section (no gap)
        _AppDownloadBanner(),
        // Footer (no gap)
        _Footer(),
      ],
    );
  }
}
