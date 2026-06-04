import 'dart:async';
import 'dart:math' as math;
import '../utils/js_stub.dart'
    if (dart.library.html) 'dart:js' as js;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/pharmacy_filter.dart';
import 'package:icare/services/pharmacy_service.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/custom_text_input.dart';
import 'package:icare/widgets/pharmcy_categories.dart';
import 'package:icare/widgets/seller_products.dart';
import 'package:icare/widgets/svg_wrapper.dart';

class PharmacyHome extends StatefulWidget {
  const PharmacyHome({super.key});

  @override
  State<PharmacyHome> createState() => _PharmacyHomeState();
}

class _PharmacyHomeState extends State<PharmacyHome> {
  final PharmacyService _pharmacyService = PharmacyService();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String selectedCategory = "";
  String _viewMode = 'all'; // 'all', 'nearest', 'search_location'
  bool _detectingLocation = false;
  String? _locationStatus;
  double? _userLat;
  double? _userLng;
  List<Map<String, dynamic>> _pharmacies = [];
  List<Map<String, dynamic>> _filteredPharmacies = [];
  bool _pharmaciesLoaded = false;

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

  Future<void> _loadPharmacies() async {
    if (_pharmaciesLoaded) return;
    try {
      final data = await _pharmacyService.getAllPharmacies();
      _pharmacies = data.cast<Map<String, dynamic>>();
      _filteredPharmacies = List.from(_pharmacies);
      _pharmaciesLoaded = true;
    } catch (e) {
      debugPrint('Error loading pharmacies: $e');
    }
  }

  Future<void> _detectAndSortNearest() async {
    setState(() {
      _detectingLocation = true;
      _locationStatus = 'Detecting your location...'.tr();
    });

    await _loadPharmacies();

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

      final sorted = List<Map<String, dynamic>>.from(_pharmacies);
      sorted.sort((a, b) {
        final latA = (a['lat'] as num?)?.toDouble() ?? 31.5204;
        final lngA = (a['lng'] as num?)?.toDouble() ?? 74.3587;
        final latB = (b['lat'] as num?)?.toDouble() ?? 31.5204;
        final lngB = (b['lng'] as num?)?.toDouble() ?? 74.3587;
        final distA = _haversineDistance(_userLat!, _userLng!, latA, lngA);
        final distB = _haversineDistance(_userLat!, _userLng!, latB, lngB);
        return distA.compareTo(distB);
      });

      setState(() {
        _filteredPharmacies = sorted;
        _detectingLocation = false;
        _locationStatus = 'Showing nearest pharmacies first'.tr();
      });
    } else {
      setState(() {
        _detectingLocation = false;
        _locationStatus = 'Could not detect location'.tr();
        _filteredPharmacies = List.from(_pharmacies);
      });
    }
  }

  void _filterByLocation(String query) {
    if (query.isEmpty) {
      setState(() => _filteredPharmacies = _pharmacies);
      return;
    }
    setState(() {
      _filteredPharmacies = _pharmacies.where((p) {
        final address = (p['address'] ?? p['location'] ?? '').toString().toLowerCase();
        final name = (p['name'] ?? p['pharmacyName'] ?? '').toString().toLowerCase();
        return address.contains(query.toLowerCase()) || name.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _setMode(String mode) {
    setState(() {
      _viewMode = mode;
      _locationController.clear();
      _searchController.clear();
      _locationStatus = null;
    });

    if (mode == 'nearest') {
      _detectAndSortNearest();
    } else if (mode == 'search_location') {
      _loadPharmacies().then((_) => setState(() {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode toggle chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              _modeChip('all', Icons.local_pharmacy_rounded, 'All'.tr()),
              const SizedBox(width: 8),
              _modeChip('nearest', Icons.near_me_rounded, 'Nearest'.tr()),
              const SizedBox(width: 8),
              _modeChip('search_location', Icons.location_searching_rounded, 'Search by Location'.tr()),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Location status banner
        if (_locationStatus != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _detectingLocation
                ? const Color(0xFFFFF8E1)
                : (_userLat != null ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0)),
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
                    _userLat != null ? Icons.location_on_rounded : Icons.location_off_rounded,
                    size: 16,
                    color: _userLat != null ? Colors.green[700] : Colors.orange[700],
                  ),
                const SizedBox(width: 8),
                Text(
                  _locationStatus!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _userLat != null ? Colors.green[800] : Colors.orange[800],
                  ),
                ),
              ],
            ),
          ),

        // Search / Location fields
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _viewMode == 'search_location'
              ? CustomInputField(
                  width: Utils.windowWidth(context) * 0.9,
                  hintText: 'Enter area, city or address...'.tr(),
                  controller: _locationController,
                  onChanged: _filterByLocation,
                  leadingIcon: const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFF94A3B8),
                    size: 22,
                  ),
                )
              : CustomInputField(
                  width: Utils.windowWidth(context) * 0.9,
                  hintText: 'Search'.tr(),
                  controller: _searchController,
                  trailingIcon: SvgWrapper(
                    assetPath: ImagePaths.filters,
                    onPress: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (ctx) => PharmacyFilterScreen()),
                      );
                    },
                  ),
                  leadingIcon: SvgWrapper(assetPath: ImagePaths.search),
                ),
        ),

        SizedBox(height: ScallingConfig.scale(20)),
        PharmcyCategories(
          selectedCategory: selectedCategory,
          onCategorySelect: (value) {
            setState(() {
              selectedCategory = value;
            });
            debugPrint("Selected Category: $value");
          },
          categories: [
            {"id": "1", "name": "Pain".tr(), "icon": ImagePaths.pain},
            {"id": "2", "name": "Vitamins".tr(), "icon": ImagePaths.vitamins},
            {"id": "3", "name": "Skincare".tr(), "icon": ImagePaths.skin_care},
            {"id": "4", "name": "Babycare".tr(), "icon": ImagePaths.baby_care},
          ],
        ),
        SizedBox(height: ScallingConfig.scale(20)),
        _buildVaccineBanner(context),
        SizedBox(height: ScallingConfig.scale(20)),
        SellerProducts(),
      ],
    );
  }

  Widget _buildVaccineBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0036BC), Color(0xFF0EA5E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Get Vaccines at Your Doorstep',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Consult our doctor first, then get your vaccine safely delivered home.',
                    style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0036BC),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Book Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.vaccines_rounded, size: 52, color: Colors.white54),
          ],
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
              Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF64748B)),
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
}
