import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/models/doctor.dart';
import 'package:icare/models/user.dart';
import 'package:icare/screens/consultation_details_screen.dart';
import 'package:icare/screens/doctor_detail.dart';
import 'package:icare/services/doctor_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';

class DoctorsList extends StatefulWidget {
  final String? initialSpecialty;
  final String? initialCondition;
  final String? initialName;
  final String? initialSearchMode;
  const DoctorsList({super.key, this.initialSpecialty, this.initialCondition, this.initialName, this.initialSearchMode});

  @override
  State<DoctorsList> createState() => _DoctorsListState();
}

class _DoctorsListState extends State<DoctorsList> {
  final DoctorService _doctorService = DoctorService();
  List<Doctor> _doctors = [];
  List<Doctor> _filteredDoctors = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _searchMode = 'name'; // name, specialty, condition
  String? _selectedSpecialization;
  Set<String> _specializations = {};
  String? _availabilityFilter; // online, offline, all
  double? _minFee;
  double? _maxFee;
  double? _minRating;
  String? _genderFilter; // male, female, all
  String? _languageFilter;
  // Mobile only — the dropdowns start collapsed so the results list gets the
  // viewport. See the Filters Row comment in build().
  bool _filtersExpanded = false;

  // Shown on the collapsed Filters button so a filter that's still applied
  // isn't invisible once the panel is closed.
  int get _activeFilterCount => [
        _selectedSpecialization,
        (_availabilityFilter == null || _availabilityFilter == 'all') ? null : _availabilityFilter,
        _minRating,
        _genderFilter,
        _languageFilter,
      ].where((f) => f != null).length;
  Set<String> _languages = {};
  // Static Pakistani languages shown as fallback when API returns none
  static const _defaultLanguages = ['Urdu', 'Punjabi', 'Pashto', 'Sindhi', 'Balochi', 'English'];
  String _sortBy = 'rating'; // rating, experience, fees
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _searchQuery = widget.initialName!;
      _searchMode = 'name';
    } else if (widget.initialSpecialty != null) {
      _searchQuery = widget.initialSpecialty!;
      _searchMode = 'specialty';
    } else if (widget.initialCondition != null) {
      _searchQuery = widget.initialCondition!;
      _searchMode = 'condition';
    } else if (widget.initialSearchMode != null) {
      _searchMode = widget.initialSearchMode!;
    }
    _searchController = TextEditingController(text: _searchQuery);
    _loadDoctors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);

    final result = await _doctorService.getAllDoctors();

    debugPrint('📋 Doctors API Result: $result');

    if (result['success']) {
      final doctorsList = (result['doctors'] as List)
          .map((json) => Doctor.fromJson(json))
          .toList();

      debugPrint('✅ Loaded ${doctorsList.length} doctors');
      for (var doc in doctorsList) {
        debugPrint('  - ${doc.user.name}: ${doc.specialization ?? "NO SPEC"}');
      }

      final specs = doctorsList
          .where(
            (d) => d.specialization != null && d.specialization!.isNotEmpty,
          )
          .map((d) => d.specialization!)
          .toSet();

      final langs = doctorsList
          .where((d) => d.languages.isNotEmpty)
          .expand((d) => d.languages)
          .toSet();

      setState(() {
        _doctors = doctorsList;
        _specializations = specs;
        _languages = langs;
        _isLoading = false;
      });
      _filterDoctors();
    } else {
      debugPrint('❌ Failed to load doctors: ${result['message']}');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to load doctors'),
          ),
        );
      }
    }
  }

  void _filterDoctors() {
    final filtered = _doctors.where((doctor) {
      bool matchesSearch = false;
      if (_searchMode == 'name') {
        matchesSearch = _searchQuery.isEmpty ||
            doctor.user.name.toLowerCase().contains(_searchQuery.toLowerCase());
      } else if (_searchMode == 'specialty') {
        matchesSearch = _searchQuery.isEmpty ||
            (doctor.specialization?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      } else if (_searchMode == 'condition') {
        final q = _searchQuery.toLowerCase();
        matchesSearch = _searchQuery.isEmpty ||
            (doctor.specialization?.toLowerCase().contains(q) ?? false) ||
            doctor.conditionsTreated.any((c) => c.toLowerCase().contains(q)) ||
            doctor.user.name.toLowerCase().contains(q);
      }

      final matchesSpecialization = _selectedSpecialization == null ||
          doctor.specialization == _selectedSpecialization;

      final matchesAvailability = _availabilityFilter == null ||
          _availabilityFilter == 'all' ||
          (_availabilityFilter == 'online' && doctor.isOnline) ||
          (_availabilityFilter == 'offline' && !doctor.isOnline);

      final matchesRating = _minRating == null || doctor.averageRating >= _minRating!;

      final matchesGender = _genderFilter == null ||
          (doctor.user.gender?.toLowerCase() == _genderFilter!.toLowerCase());

      final matchesLanguage = _languageFilter == null ||
          doctor.languages.contains(_languageFilter);

      return matchesSearch && matchesSpecialization && matchesAvailability &&
          matchesRating && matchesGender && matchesLanguage;
    }).toList();

    // Sort in-place — no extra setState
    filtered.sort((a, b) {
      if (_availabilityFilter == null || _availabilityFilter == 'all') {
        final onlineCmp = (b.isOnline ? 1 : 0) - (a.isOnline ? 1 : 0);
        if (onlineCmp != 0) return onlineCmp;
      }
      if (_sortBy == 'rating') return b.averageRating.compareTo(a.averageRating);
      if (_sortBy == 'experience') {
        final aExp = int.tryParse(a.experience?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
        final bExp = int.tryParse(b.experience?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
        return bExp.compareTo(aExp);
      }
      if (_sortBy == 'fees') {
        final aFee = a.consultationFee ?? 0;
        final bFee = b.consultationFee ?? 0;
        return aFee.compareTo(bFee); // low to high
      }
      return 0;
    });

    setState(() => _filteredDoctors = filtered);
  }

  void _sortDoctors() => _filterDoctors();

  bool _isAvailableToday(Doctor doctor) {
    if (doctor.isOnline) return true;
    if (doctor.availableDays.isEmpty) return false;
    final dayName = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday']
        [DateTime.now().weekday - 1];
    return doctor.availableDays.any(
      (d) => d.toLowerCase().startsWith(dayName.substring(0, 3)),
    );
  }

  int get _onlineDoctorsCount {
    return _doctors.where((d) => d.isOnline).length;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: CustomBackButton(),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: CustomText(
          text: "Find Doctors".tr(),
          fontFamily: "Gilroy-Bold",
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF0F172A),
        ),
      ),
      // One scroll view for the whole page. The filter block used to sit as a
      // fixed child above an Expanded list, so it never moved while scrolling
      // and the results were confined to whatever height was left over. As
      // slivers, the filters scroll away and the list owns the full viewport —
      // and there is still only one vertical scrollable, so nothing competes.
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
              children: [
                // Active filter banner
                if (_searchQuery.isNotEmpty && (_searchMode == 'condition' || _searchMode == 'specialty'))
                  Container(
                    color: const Color(0xFF0036BC).withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(children: [
                      Icon(_searchMode == 'condition' ? Icons.healing_outlined : Icons.medical_services_outlined,
                          size: 16, color: const Color(0xFF0036BC)),
                      const SizedBox(width: 8),
                      Text(
                        '${_searchMode == 'condition' ? 'Condition'.tr() : 'Speciality'.tr()}: $_searchQuery  •  ${_filteredDoctors.length} ${'doctor(s) found'.tr()}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF0036BC), fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () { setState(() { _searchQuery = ''; _searchMode = 'name'; _searchController.clear(); _filterDoctors(); }); },
                        child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF0036BC)),
                      ),
                    ]),
                  ),
                // Search and Filter Section
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(isDesktop ? 24 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Online doctors count — tapping it filters the list down
                      // to whoever is online right now. Most patients never
                      // touch the dropdowns, so the one filter they actually
                      // want is reachable in a single tap.
                      InkWell(
                        onTap: () => setState(() {
                          final showingOnline = _availabilityFilter == 'online';
                          _availabilityFilter = showingOnline ? null : 'online';
                          _filterDoctors();
                        }),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: _availabilityFilter == 'online' ? 0.6 : 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$_onlineDoctorsCount ${'doctors online right now'.tr()}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                    Text(
                                      _availabilityFilter == 'online'
                                          ? 'Showing online doctors — tap to show all'
                                          : 'Tap here to explore and connect',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                _availabilityFilter == 'online'
                                    ? Icons.close_rounded
                                    : Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: const Color(0xFF10B981),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Search Mode Tabs
                      Row(
                        children: [
                          _buildSearchModeTab('name', 'By Name'.tr()),
                          const SizedBox(width: 8),
                          _buildSearchModeTab('specialty', 'By Speciality'.tr()),
                          const SizedBox(width: 8),
                          _buildSearchModeTab('condition', 'By Condition'.tr()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          _searchQuery = value;
                          _filterDoctors();
                        },
                        decoration: InputDecoration(
                          hintText: _searchMode == 'name'
                            ? 'Search doctors by name'.tr()
                            : _searchMode == 'specialty'
                            ? 'Search by specialization'.tr()
                            : 'Search by condition (e.g., diabetes)'.tr(),
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primaryColor,
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Filters Row.
                      // On mobile every dropdown is full-width, so the five of
                      // them stack into ~400px of fixed header above the
                      // Expanded list — leaving the results almost no viewport
                      // to scroll in. Collapse them behind a toggle on small
                      // screens (desktop keeps the inline Wrap it always had).
                      if (!isDesktop) ...[
                        InkWell(
                          onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF0036BC)),
                              const SizedBox(width: 8),
                              Text(
                                'Filters'.tr(),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                              if (_activeFilterCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFF0036BC), borderRadius: BorderRadius.circular(10)),
                                  child: Text('$_activeFilterCount',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                                ),
                              ],
                              const Spacer(),
                              Icon(_filtersExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                  size: 20, color: const Color(0xFF64748B)),
                            ]),
                          ),
                        ),
                        if (_filtersExpanded) const SizedBox(height: 12),
                      ],
                      if (isDesktop || _filtersExpanded)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Specialization
                          if (_specializations.isNotEmpty)
                            SizedBox(
                              width: isDesktop ? 200 : double.infinity,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedSpecialization,
                                decoration: InputDecoration(
                                  labelText: 'Speciality'.tr(),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  isDense: true,
                                ),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('All')),
                                  const DropdownMenuItem(value: 'General Practitioner', child: Text('General Practitioner')),
                                  ..._specializations.where((s) => s != 'General Practitioner').map((s) => DropdownMenuItem(value: s, child: Text(s))),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _selectedSpecialization = v;
                                    _filterDoctors();
                                  });
                                },
                              ),
                            ),
                          
                          // Availability
                          SizedBox(
                            width: isDesktop ? 150 : double.infinity,
                            child: DropdownButtonFormField<String>(
                              initialValue: _availabilityFilter,
                              decoration: InputDecoration(
                                labelText: 'Availability'.tr(),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              items: [
                                DropdownMenuItem(value: null, child: Text('All'.tr())),
                                DropdownMenuItem(value: 'online', child: Text('Online'.tr())),
                                DropdownMenuItem(value: 'offline', child: Text('Offline'.tr())),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _availabilityFilter = v;
                                  _filterDoctors();
                                });
                              },
                            ),
                          ),
                          
                          // Rating
                          SizedBox(
                            width: isDesktop ? 150 : double.infinity,
                            child: DropdownButtonFormField<double>(
                              initialValue: _minRating,
                              decoration: InputDecoration(
                                labelText: 'Min Rating'.tr(),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              items: [
                                DropdownMenuItem(value: null, child: Text('All'.tr())),
                                const DropdownMenuItem(value: 4.5, child: Text('4.5+')),
                                DropdownMenuItem(value: 4.0, child: Text('4.0+')),
                                DropdownMenuItem(value: 3.5, child: Text('3.5+')),
                                DropdownMenuItem(value: 3.0, child: Text('3.0+')),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _minRating = v;
                                  _filterDoctors();
                                });
                              },
                            ),
                          ),
                          
                          // Gender
                          SizedBox(
                            width: isDesktop ? 130 : double.infinity,
                            child: DropdownButtonFormField<String>(
                              initialValue: _genderFilter,
                              decoration: InputDecoration(
                                labelText: 'Gender'.tr(),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              items: [
                                DropdownMenuItem(value: null, child: Text('All'.tr())),
                                DropdownMenuItem(value: 'male', child: Text('Male'.tr())),
                                DropdownMenuItem(value: 'female', child: Text('Female'.tr())),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _genderFilter = v;
                                  _filterDoctors();
                                });
                              },
                            ),
                          ),
                          
                          // Language
                          SizedBox(
                            width: isDesktop ? 150 : double.infinity,
                            child: DropdownButtonFormField<String>(
                              initialValue: _languageFilter,
                              decoration: InputDecoration(
                                labelText: 'Language'.tr(),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All')),
                                ...(_languages.isNotEmpty ? _languages : _defaultLanguages.toSet())
                                    .map((l) => DropdownMenuItem(value: l, child: Text(l))),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _languageFilter = v;
                                  _filterDoctors();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Sort Options
                      Row(
                        children: [
                          Text(
                            'Sort by:'.tr(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildSortChip('rating', 'Rating'.tr()),
                          const SizedBox(width: 8),
                          _buildSortChip('experience', 'Experience'.tr()),
                          const SizedBox(width: 8),
                          _buildSortChip('fees', 'Fees'.tr()),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
                  ),
                ),
                // Doctors list
                if (_filteredDoctors.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CustomText(
                        text: 'No doctors found'.tr(),
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 40 : 16,
                      vertical: 16,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => DoctorProfileCard(doctor: _filteredDoctors[i]),
                        childCount: _filteredDoctors.length,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildSearchModeTab(String mode, String label) {
    final isSelected = _searchMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _searchMode = mode;
          _filterDoctors();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(String sort, String label) {
    final isSelected = _sortBy == sort;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = sort;
          _sortDoctors();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

class DoctorsListWithSpecialty extends StatefulWidget {
  final String specialty;
  const DoctorsListWithSpecialty({super.key, required this.specialty});

  @override
  State<DoctorsListWithSpecialty> createState() => _DoctorsListWithSpecialtyState();
}

class _DoctorsListWithSpecialtyState extends State<DoctorsListWithSpecialty> {
  final DoctorService _doctorService = DoctorService();
  List<Doctor> _doctors = [];
  List<Doctor> _filteredDoctors = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);

    final result = await _doctorService.getAllDoctors();

    if (result['success']) {
      final doctorsList = (result['doctors'] as List)
          .map((json) => Doctor.fromJson(json))
          .toList();

      // Filter by specialty immediately
      final filtered = doctorsList
          .where((d) => d.specialization == widget.specialty)
          .toList();

      setState(() {
        _doctors = doctorsList;
        _filteredDoctors = filtered;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to load doctors'),
          ),
        );
      }
    }
  }

  void _filterDoctors() {
    setState(() {
      _filteredDoctors = _doctors.where((doctor) {
        final matchesSearch = _searchQuery.isEmpty ||
            doctor.user.name.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesSpecialty = doctor.specialization == widget.specialty;
        return matchesSearch && matchesSpecialty;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: CustomText(
          text: widget.specialty,
          fontFamily: "Gilroy-Bold",
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF0F172A),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(isDesktop ? 24 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFFF59E0B),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Showing ${widget.specialty} specialists based on your referral',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF92400E),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (value) {
                          _searchQuery = value;
                          _filterDoctors();
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by doctor name',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primaryColor,
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredDoctors.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_search_rounded,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              CustomText(
                                text: 'No ${widget.specialty} specialists found',
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredDoctors.length,
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 40 : 16,
                            vertical: 16,
                          ),
                          itemBuilder: (ctx, i) {
                            return DoctorProfileCard(
                              doctor: _filteredDoctors[i],
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class DoctorProfileCard extends StatelessWidget {
  const DoctorProfileCard({super.key, this.doctor, this.width, this.padding});

  final Doctor? doctor;
  final double? width;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final displayDoctor = doctor ??
        Doctor(
          id: 'dummy',
          user: User(
            id: 'dummy',
            name: 'Dr. John Doe',
            email: 'doctor@example.com',
            phoneNumber: '0300000000',
            role: 'Doctor',
          ),
          specialization: 'General Practitioner',
          ratings: [4.5],
        );

    final averageRating = displayDoctor.averageRating;
    final reviewCount = displayDoctor.reviewCount;
    final fee = displayDoctor.consultationFee;
    final experience = displayDoctor.experience;
    final degrees = displayDoctor.degrees;
    final hasPmdc = displayDoctor.pmdcNumber != null && displayDoctor.pmdcNumber!.isNotEmpty;

    // "Available Today" only if doctor is online OR has today as an available day
    final todayIdx = DateTime.now().weekday - 1; // 0=Mon … 6=Sun
    final todayPrefix = ['mon','tue','wed','thu','fri','sat','sun'][todayIdx];
    final isAvailableToday = displayDoctor.isOnline ||
        displayDoctor.availableDays.any(
          (d) => d.toLowerCase().startsWith(todayPrefix),
        );

    return GestureDetector(
      onTap: () {
        if (doctor != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => DoctorDetailScreen(doctor: displayDoctor),
            ),
          );
        }
      },
      child: Container(
        width: width,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with profile picture
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                    backgroundImage: buildProfileImageProvider(displayDoctor.user.profilePicture),
                    child: buildProfileImageProvider(displayDoctor.user.profilePicture) == null
                        ? Text(
                            displayDoctor.user.name.isNotEmpty
                                ? displayDoctor.user.name.substring(0, 1).toUpperCase()
                                : 'D',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryColor,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + PLATINUM badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayDoctor.user.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            if (averageRating >= 4.5)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.workspace_premium_rounded, size: 12, color: Color(0xFFF59E0B)),
                                    SizedBox(width: 3),
                                    Text('PLATINUM DOCTOR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B))),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // PMDC Verified
                        if (hasPmdc)
                          Row(
                            children: [
                              const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              const Text('PMDC Verified', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                            ],
                          ),

                        const SizedBox(height: 4),

                        // Specialization
                        Text(
                          displayDoctor.specialization ?? 'General Practitioner',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),

                        // Degrees
                        if (degrees.isNotEmpty)
                          Text(
                            degrees.join(', '),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),

                        // Languages
                        if (displayDoctor.languages.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: displayDoctor.languages.take(3).map((lang) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14B1FF).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF14B1FF).withValues(alpha: 0.25)),
                              ),
                              child: Text(lang, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0369A1))),
                            )).toList(),
                          ),
                        ],

                        const SizedBox(height: 8),

                        // Experience + Rating
                        Row(
                          children: [
                            if (experience != null && experience.isNotEmpty) ...[
                              Text(
                                experience,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 4),
                              const Text('Experience', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              const SizedBox(width: 16),
                            ],
                            if (averageRating > 0) ...[
                              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 3),
                              Text(
                                averageRating.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$reviewCount Reviews',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),

              // Bottom row: availability + online status + fee
              Row(
                children: [
                  // Online/Offline dot
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: displayDoctor.isOnline
                          ? const Color(0xFF10B981)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    displayDoctor.isOnline ? 'Online'.tr() : 'Offline'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: displayDoctor.isOnline
                          ? const Color(0xFF10B981)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Available Today badge — only when doctor is actually available today
                  if (isAvailableToday)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Available Today',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                      ),
                    ),
                  const Spacer(),
                  if (fee != null && fee > 0)
                    Text(
                      'PKR ${fee.toInt()}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Action button — Book Appointment only
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (doctor != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => DoctorDetailScreen(doctor: displayDoctor),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Book Appointment'),
                ),
              ),
              // A doctor who is online can be reached right now, so offer that
              // directly instead of making the patient go back out to the
              // separate instant-consultation entry point.
              if (displayDoctor.isOnline) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ConsultationDetailsScreen(
                          targetDoctorId: displayDoctor.user.id,
                        ),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.videocam_rounded, size: 18),
                    label: const Text('Connect for instant consultation'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
