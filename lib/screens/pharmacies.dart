import 'dart:async';
import 'dart:math' as math;
import '../utils/js_stub.dart'
    if (dart.library.html) 'dart:js' as js;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/services/pharmacy_service.dart';
import 'package:icare/screens/pharmacy_details.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/custom_text_input.dart';

class PharmaciesScreen extends StatefulWidget {
  final List<dynamic>? prescribedMedicines;
  final String? initialSearch;
  const PharmaciesScreen({super.key, this.prescribedMedicines, this.initialSearch});

  @override
  State<PharmaciesScreen> createState() => _PharmaciesScreenState();
}

class _PharmaciesScreenState extends State<PharmaciesScreen> {
  final PharmacyService _pharmacyService = PharmacyService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  List<dynamic> _pharmacies = [];
  List<dynamic> _filteredPharmacies = [];
  bool _isLoading = true;
  final FocusNode _searchFocus = FocusNode();
  List<Map<String, dynamic>> _pharmacySuggestions = [];
  bool _showPharmacySuggestions = false;

  // View mode: 'all', 'nearest', 'search_location'
  String _viewMode = 'all';
  bool _detectingLocation = false;
  String? _locationStatus;
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      _searchController.text = widget.initialSearch!;
    }
    _fetchPharmacies();
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showPharmacySuggestions = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _locationController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchPharmacies() async {
    try {
      final data = await _pharmacyService.getAllPharmacies();
      if (mounted) {
        setState(() {
          _pharmacies = data;
          _filteredPharmacies = data;
          _isLoading = false;
        });
        if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
          _filterPharmacies(widget.initialSearch!);
        }
      }
    } catch (e) {
      debugPrint('Error fetching pharmacies: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterPharmacies(String query) {
    if (query.isEmpty) {
      setState(() => _filteredPharmacies = _pharmacies);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _filteredPharmacies = _pharmacies.where((p) {
        final name = (p['pharmacyName'] ?? p['pharmacy_name'] ?? p['name'] ?? '').toString().toLowerCase();
        final address = (p['address'] ?? p['location'] ?? '').toString().toLowerCase();
        final city = (p['city'] ?? '').toString().toLowerCase();
        final area = (p['area'] ?? '').toString().toLowerCase();
        final owner = (p['ownerName'] ?? p['owner_name'] ?? p['contactPerson'] ?? '').toString().toLowerCase();
        return name.contains(q) || address.contains(q) || city.contains(q) || area.contains(q) || owner.contains(q);
      }).toList();
    });
  }

  void _filterByLocation(String query) {
    if (query.isEmpty) {
      setState(() => _filteredPharmacies = _pharmacies);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _filteredPharmacies = _pharmacies.where((p) {
        final address = (p['address'] ?? p['location'] ?? '').toString().toLowerCase();
        final city = (p['city'] ?? '').toString().toLowerCase();
        final area = (p['area'] ?? '').toString().toLowerCase();
        final name = (p['pharmacy_name'] ?? p['pharmacyName'] ?? p['name'] ?? '').toString().toLowerCase();
        return address.contains(q) || city.contains(q) || area.contains(q) || name.contains(q);
      }).toList();
    });
  }

  void _updatePharmacySuggestions(String query) {
    if (query.isEmpty) {
      setState(() { _pharmacySuggestions = []; _showPharmacySuggestions = false; });
      return;
    }
    final q = query.toLowerCase();
    final suggestions = _pharmacies.where((p) {
      final name = (p['pharmacyName'] ?? p['pharmacy_name'] ?? p['name'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).cast<Map<String, dynamic>>().take(6).toList();
    setState(() {
      _pharmacySuggestions = suggestions;
      _showPharmacySuggestions = suggestions.isNotEmpty;
    });
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Future<void> _detectAndSortNearest() async {
    setState(() {
      _detectingLocation = true;
      _locationStatus = 'Detecting your location...';
    });

    final completer = Completer<List<double>?>();
    try {
      js.context['navigator']['geolocation'].callMethod('getCurrentPosition', [
        js.allowInterop((pos) {
          final coords = pos['coords'];
          completer.complete([
            (coords['latitude'] as num).toDouble(),
            (coords['longitude'] as num).toDouble(),
          ]);
        }),
        js.allowInterop((err) => completer.complete(null)),
      ]);
    } catch (e) {
      completer.complete(null);
    }

    final result = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );

    if (!mounted) return;

    if (result != null) {
      _userLat = result[0];
      _userLng = result[1];

      final sorted = List<dynamic>.from(_pharmacies);
      sorted.sort((a, b) {
        final latA = (a['latitude'] ?? a['lat'] as num?)?.toDouble();
        final lngA = (a['longitude'] ?? a['lng'] as num?)?.toDouble();
        final latB = (b['latitude'] ?? b['lat'] as num?)?.toDouble();
        final lngB = (b['longitude'] ?? b['lng'] as num?)?.toDouble();
        final distA = (latA != null && lngA != null)
            ? _haversineDistance(_userLat!, _userLng!, latA, lngA)
            : double.infinity;
        final distB = (latB != null && lngB != null)
            ? _haversineDistance(_userLat!, _userLng!, latB, lngB)
            : double.infinity;
        return distA.compareTo(distB);
      });

      setState(() {
        _filteredPharmacies = sorted;
        _detectingLocation = false;
        _locationStatus = 'Showing nearest pharmacies';
      });
    } else {
      setState(() {
        _detectingLocation = false;
        _locationStatus = 'Could not detect location — showing all';
        _filteredPharmacies = _pharmacies;
      });
    }
  }

  void _setMode(String mode) {
    setState(() {
      _viewMode = mode;
      _searchController.clear();
      _locationController.clear();
      _locationStatus = null;
      _userLat = null;
      _userLng = null;
      _pharmacySuggestions = [];
      _showPharmacySuggestions = false;
    });

    if (mode == 'all') {
      setState(() => _filteredPharmacies = _pharmacies);
    } else if (mode == 'nearest') {
      _detectAndSortNearest();
    } else {
      setState(() => _filteredPharmacies = _pharmacies);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: CustomText(
          text: "Pharmacies".tr(),
          fontFamily: "Gilroy-Bold",
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF0F172A),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 1200 : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Header: mode chips + search field ──────────────────
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 40 : 20,
                        20,
                        isDesktop ? 40 : 20,
                        16,
                      ),
                      color: Colors.white,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 700 : double.infinity,
                          ),
                          child: Column(
                            children: [
                              // Mode toggle chips
                              Row(
                                children: [
                                  _modeChip('all', Icons.list_rounded, 'All'.tr()),
                                  const SizedBox(width: 8),
                                  _modeChip('nearest', Icons.near_me_rounded, 'Nearest'.tr()),
                                  const SizedBox(width: 8),
                                  _modeChip(
                                    'search_location',
                                    Icons.location_searching_rounded,
                                    'Search by Location'.tr(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Contextual search field
                              if (_viewMode == 'all') ...[
                                CustomInputField(
                                  width: double.infinity,
                                  hintText: "Search pharmacies or medicines...".tr(),
                                  controller: _searchController,
                                  focusNode: _searchFocus,
                                  onChanged: (v) {
                                    _filterPharmacies(v);
                                    _updatePharmacySuggestions(v);
                                  },
                                  leadingIcon: const Icon(
                                    Icons.search_rounded,
                                    color: Color(0xFF94A3B8),
                                    size: 22,
                                  ),
                                ),
                                if (_showPharmacySuggestions && _pharmacySuggestions.isNotEmpty)
                                  _buildPharmacySuggestions(),
                              ],
                              if (_viewMode == 'search_location')
                                CustomInputField(
                                  width: double.infinity,
                                  hintText: "Enter area, city or address...".tr(),
                                  controller: _locationController,
                                  onChanged: _filterByLocation,
                                  leadingIcon: const Icon(
                                    Icons.location_on_rounded,
                                    color: Color(0xFF94A3B8),
                                    size: 22,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Location status banner ──────────────────────────────
                    if (_locationStatus != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        color: _detectingLocation
                            ? const Color(0xFFFFF8E1)
                            : (_userLat != null
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFF3E0)),
                        child: Row(
                          children: [
                            if (_detectingLocation)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              Icon(
                                _userLat != null
                                    ? Icons.location_on_rounded
                                    : Icons.location_off_rounded,
                                size: 16,
                                color: _userLat != null
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                              ),
                            const SizedBox(width: 8),
                            Text(
                              _locationStatus!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _userLat != null
                                    ? Colors.green[800]
                                    : Colors.orange[800],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Pharmacy list ───────────────────────────────────────
                    Expanded(
                      child: _filteredPharmacies.isEmpty
                          ? _buildEmptyState()
                          : SingleChildScrollView(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isDesktop ? 40 : 20,
                                  vertical: 24,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_viewMode == 'all') ...[
                                      _buildCategories(isDesktop),
                                      const SizedBox(height: 28),
                                    ],
                                    CustomText(
                                      text:
                                          "${'Available Pharmacies'.tr()} (${_filteredPharmacies.length})",
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                    ),
                                    const SizedBox(height: 20),
                                    isDesktop
                                        ? _buildPharmacyGrid()
                                        : _buildPharmacyList(),
                                    const SizedBox(height: 40),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _modeChip(String mode, IconData icon, String label) {
    final isSelected = _viewMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryColor : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPharmacySuggestions() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _pharmacySuggestions.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final name = (p['pharmacyName'] ?? p['pharmacy_name'] ?? p['name'] ?? 'Pharmacy').toString();
            final address = (p['address'] ?? p['city'] ?? '').toString();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                InkWell(
                  onTap: () {
                    setState(() {
                      _searchController.text = name;
                      _showPharmacySuggestions = false;
                    });
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (ctx) => PharmacyDetailsScreen(
                        pharmacy: p,
                        prescribedMedicines: widget.prescribedMedicines,
                      ),
                    ));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.local_pharmacy_outlined, size: 16, color: AppColors.primaryColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                              if (address.isNotEmpty)
                                Text(address, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFCBD5E1)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_pharmacy_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No pharmacies found".tr(),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_viewMode == 'search_location') ...[
            const SizedBox(height: 8),
            Text(
              "Try a different area or city name".tr(),
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategories(bool isDesktop) {
    final categories = [
      {"name": "Baby Care".tr(), "icon": Icons.child_care_rounded, "color": const Color(0xFFF472B6)},
      {"name": "Skin Care".tr(), "icon": Icons.face_rounded, "color": const Color(0xFF60A5FA)},
      {"name": "Vitamins".tr(), "icon": Icons.auto_awesome_rounded, "color": const Color(0xFFFBBF24)},
      {"name": "Pain Relief".tr(), "icon": Icons.healing_rounded, "color": const Color(0xFF34D399)},
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: categories.map((cat) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: (cat["color"] as Color).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cat["icon"] as IconData, color: cat["color"] as Color, size: 18),
            const SizedBox(width: 10),
            CustomText(
              text: cat["name"] as String,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildPharmacyGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredPharmacies.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 320,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemBuilder: (ctx, i) => PharmacyWidget(
        pharmacy: _filteredPharmacies[i],
        prescribedMedicines: widget.prescribedMedicines,
      ),
    );
  }

  Widget _buildPharmacyList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredPharmacies.length,
      itemBuilder: (ctx, i) => PharmacyWidget(
        pharmacy: _filteredPharmacies[i],
        prescribedMedicines: widget.prescribedMedicines,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Pharmacy Card Widget
// ═══════════════════════════════════════════════════════════════════════════
class PharmacyWidget extends StatelessWidget {
  final Map<String, dynamic> pharmacy;
  final List<dynamic>? prescribedMedicines;

  const PharmacyWidget({
    super.key,
    required this.pharmacy,
    this.prescribedMedicines,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => PharmacyDetailsScreen(
              pharmacy: pharmacy,
              prescribedMedicines: prescribedMedicines,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF8FAFC)],
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Left accent bar
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(
                width: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primaryColor,
                      AppColors.primaryColor.withValues(alpha: 0.5),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryColor.withValues(alpha: 0.12),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                ImagePaths.pharmacyLogo,
                                fit: BoxFit.cover,
                                width: 75,
                                height: 75,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -2, right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                                child: const Icon(Icons.check_rounded, color: Colors.white, size: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: CustomText(
                                    text: pharmacy['pharmacy_name']?.toString()
                                        ?? pharmacy['pharmacyName']?.toString()
                                        ?? pharmacy['user']?['name']?.toString()
                                        ?? pharmacy['name']?.toString()
                                        ?? 'Pharmacy',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: "Gilroy-Bold",
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                if (pharmacy['isApproved'] == true)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFFEF3C7)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.verified_rounded, size: 14, color: Color(0xFFD97706)),
                                        const SizedBox(width: 4),
                                        CustomText(text: "Verified", fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF92400E)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: CustomText(
                                    text: pharmacy['address'] ?? 'Address not available',
                                    color: const Color(0xFF64748B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                // Star rating
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFEF3C7)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded, size: 13, color: Color(0xFFD97706)),
                                      const SizedBox(width: 3),
                                      Text(
                                        () {
                                          final r = pharmacy['rating'];
                                          if (r == null || r == 0) return 'New';
                                          return (r is num) ? r.toStringAsFixed(1) : r.toString();
                                        }(),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (pharmacy['deliveryAvailable'] == true)
                                  _buildStatusTag("Free Delivery", const Color(0xFF0EA5E9)),
                                if (pharmacy['deliveryAvailable'] == true) const SizedBox(width: 8),
                                if (pharmacy['openHours'] != null)
                                  _buildStatusTag(
                                    "${pharmacy['openHours']['from'] ?? ''}-${pharmacy['openHours']['to'] ?? ''}",
                                    const Color(0xFF6366F1),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText(
                            text: pharmacy['city'] != null ? "Location" : "Pickup Type",
                            color: const Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                pharmacy['city'] != null ? Icons.location_city_rounded : Icons.access_time_filled_rounded,
                                size: 12,
                                color: const Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 4),
                              CustomText(
                                text: pharmacy['city'] ?? "15-20 Mins",
                                color: const Color(0xFF0F172A),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ],
                          ),
                        ],
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: CustomButton(
                            label: "Visit Pharmacy",
                            height: 44,
                            borderRadius: 14,
                            labelSize: 12,
                            labelWeight: FontWeight.w900,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF334155)],
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => PharmacyDetailsScreen(
                                    pharmacy: pharmacy,
                                    prescribedMedicines: prescribedMedicines,
                                  ),
                                ),
                              );
                            },
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

  Widget _buildStatusTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomText(text: label, color: color, fontSize: 10, fontWeight: FontWeight.w800),
    );
  }
}
