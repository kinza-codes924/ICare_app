import 'dart:async';
import 'dart:math' as math;
import '../utils/js_stub.dart'
    if (dart.library.html) 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:icare/models/lab.dart';
import 'package:icare/screens/book_lab.dart';
import 'package:icare/screens/filters.dart';
import 'package:icare/screens/lab_reports_screen.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/custom_text_input.dart';
import 'package:icare/widgets/lab_widget.dart';
import 'package:icare/widgets/svg_wrapper.dart';
import 'package:icare/services/laboratory_service.dart';

class LabsListScreen extends StatefulWidget {
  final List<dynamic>? recommendedTests;
  final String? initialSearch;
  const LabsListScreen({super.key, this.recommendedTests, this.initialSearch});

  @override
  State<LabsListScreen> createState() => _LabsListScreenState();
}

class _LabsListScreenState extends State<LabsListScreen> {
  final LaboratoryService _labService = LaboratoryService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  List<Lab> _labs = [];
  List<Lab> _filteredLabs = [];
  List<Map<String, dynamic>> _rawLabsData = [];
  bool _isLoading = true;
  final FocusNode _searchFocus = FocusNode();
  List<_LabSuggestionItem> _labSuggestions = [];
  bool _showLabSuggestions = false;

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
    _fetchLabs();
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showLabSuggestions = false);
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

  Future<void> _fetchLabs() async {
    try {
      final labsData = await _labService.getAllLaboratories();
      _rawLabsData = labsData.cast<Map<String, dynamic>>();
      final List<Lab> loadedLabs = labsData.map((json) {
        return Lab(
          id: json['_id'] ?? '',
          profileId: json['profileId']?.toString(),
          title: json['labName'] ?? json['name'] ?? 'Laboratory',
          photo: json['image'] ?? ImagePaths.lab1,
          delivery: json['homeSample'] == true
              ? "Home Sample Available"
              : "Walk-in Only",
          address:
              json['address'] ?? json['location'] ?? 'Location not available',
          rating: (json['rating'] ?? 4.5).toString(),
          tests:
              (json['availableTests'] as List?)
                  ?.map((t) => t['name'].toString())
                  .toList() ??
              [],
        );
      }).toList();

      if (mounted) {
        setState(() {
          _labs = loadedLabs;
          _filteredLabs = loadedLabs;
          _isLoading = false;
        });
        if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
          _filterLabs(widget.initialSearch!);
        }
      }
    } catch (e) {
      debugPrint('Error fetching labs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterLabs(String query) {
    if (query.isEmpty) {
      setState(() => _filteredLabs = _labs);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _filteredLabs = _labs.where((lab) {
        // Match lab name
        if ((lab.title?.toLowerCase() ?? '').contains(q)) return true;
        // Match address
        if ((lab.address?.toLowerCase() ?? '').contains(q)) return true;
        // Match test names
        if ((lab.tests ?? []).any((t) => t.toLowerCase().contains(q))) return true;
        // Match any raw field (city, area, labName variants, etc.)
        final idx = _labs.indexOf(lab);
        if (idx >= 0 && idx < _rawLabsData.length) {
          final raw = _rawLabsData[idx];
          for (final val in raw.values) {
            if (val is String && val.toLowerCase().contains(q)) return true;
          }
        }
        return false;
      }).toList();
    });
  }

  void _filterByLocation(String query) {
    if (query.isEmpty) {
      setState(() => _filteredLabs = _labs);
      return;
    }
    setState(() {
      _filteredLabs = _labs.where((lab) {
        final address = lab.address?.toLowerCase() ?? "";
        final title = lab.title?.toLowerCase() ?? "";
        final q = query.toLowerCase();
        // Also check raw data for city/area fields not in the Lab model
        final rawIdx = _labs.indexOf(lab);
        final raw = rawIdx >= 0 && rawIdx < _rawLabsData.length
            ? _rawLabsData[rawIdx]
            : <String, dynamic>{};
        final city = (raw['city'] ?? '').toString().toLowerCase();
        final area = (raw['area'] ?? '').toString().toLowerCase();
        return address.contains(q) || title.contains(q) || city.contains(q) || area.contains(q);
      }).toList();
    });
  }

  void _updateLabSuggestions(String query) {
    if (query.isEmpty) {
      setState(() { _labSuggestions = []; _showLabSuggestions = false; });
      return;
    }
    final q = query.toLowerCase();
    final items = <_LabSuggestionItem>[];
    for (final lab in _labs) {
      if (items.length >= 6) break;
      if ((lab.title?.toLowerCase() ?? '').contains(q)) {
        items.add(_LabSuggestionItem(label: lab.title ?? 'Laboratory', sublabel: lab.address ?? '', isTest: false, lab: lab));
      } else {
        for (final test in (lab.tests ?? [])) {
          if (test.toLowerCase().contains(q)) {
            items.add(_LabSuggestionItem(label: test, sublabel: lab.title ?? 'Laboratory', isTest: true, lab: lab));
            break;
          }
        }
      }
    }
    setState(() { _labSuggestions = items; _showLabSuggestions = items.isNotEmpty; });
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

      // Build a paired list so Lab objects stay aligned with their raw coords
      final paired = List.generate(_labs.length, (i) {
        final raw = i < _rawLabsData.length ? _rawLabsData[i] : <String, dynamic>{};
        final lat = (raw['latitude'] ?? raw['lat'] as num?)?.toDouble();
        final lng = (raw['longitude'] ?? raw['lng'] as num?)?.toDouble();
        final dist = (lat != null && lng != null)
            ? _haversineDistance(_userLat!, _userLng!, lat, lng)
            : double.infinity; // push labs with no coords to the end
        return _LabWithDist(lab: _labs[i], dist: dist);
      });
      paired.sort((a, b) => a.dist.compareTo(b.dist));

      setState(() {
        _filteredLabs = paired.map((e) => e.lab).toList();
        _detectingLocation = false;
        _locationStatus = 'Showing nearest laboratories';
      });
    } else {
      setState(() {
        _detectingLocation = false;
        _locationStatus = 'Could not detect location — showing all';
        _filteredLabs = _labs;
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
      _labSuggestions = [];
      _showLabSuggestions = false;
    });

    if (mode == 'all') {
      setState(() => _filteredLabs = _labs);
    } else if (mode == 'nearest') {
      _detectAndSortNearest();
    } else {
      setState(() => _filteredLabs = _labs);
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
          text: "Book a Lab",
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
                    // Header with search and mode buttons
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
                          constraints: BoxConstraints(maxWidth: isDesktop ? 700 : double.infinity),
                          child: Column(
                            children: [
                              // Mode toggle buttons
                              Row(
                                children: [
                                  _modeChip('all', Icons.list_rounded, 'All'),
                                  const SizedBox(width: 8),
                                  _modeChip('nearest', Icons.near_me_rounded, 'Nearest'),
                                  const SizedBox(width: 8),
                                  _modeChip('search_location', Icons.location_searching_rounded, 'Search by Location'),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Search field (for All and Search by Location modes)
                              if (_viewMode == 'all') ...[
                                CustomInputField(
                                  width: double.infinity,
                                  hintText: "Search laboratories or clinics...",
                                  controller: _searchController,
                                  focusNode: _searchFocus,
                                  onChanged: (v) {
                                    _filterLabs(v);
                                    _updateLabSuggestions(v);
                                  },
                                  trailingIcon: SvgWrapper(
                                    assetPath: ImagePaths.filters,
                                    onPress: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (ctx) => const FiltersScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  leadingIcon: const Icon(
                                    Icons.search_rounded,
                                    color: Color(0xFF94A3B8),
                                    size: 22,
                                  ),
                                ),
                                if (_showLabSuggestions && _labSuggestions.isNotEmpty)
                                  _buildLabSuggestions(),
                              ],
                              if (_viewMode == 'search_location')
                                CustomInputField(
                                  width: double.infinity,
                                  hintText: "Enter area, city or address...",
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

                    // Location status banner
                    if (_locationStatus != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

                    Expanded(
                      child: _filteredLabs.isEmpty
                          ? _buildEmptyState()
                          : LabsList(labs: _filteredLabs, tab: 'book', recommendedTests: widget.recommendedTests),
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

  Widget _buildLabSuggestions() {
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
          children: _labSuggestions.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                InkWell(
                  onTap: () {
                    setState(() {
                      _searchController.text = s.label;
                      _showLabSuggestions = false;
                    });
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (ctx) => BookLabScreen(
                        labId: s.lab.id,
                        labTitle: s.lab.title,
                        labProfileId: s.lab.profileId,
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
                          child: Icon(
                            s.isTest ? Icons.biotech_outlined : Icons.science_outlined,
                            size: 16,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                              if (s.sublabel.isNotEmpty)
                                Text(
                                  s.isTest ? 'Available at: ${s.sublabel}' : s.sublabel,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
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
          Icon(Icons.science_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No laboratories found",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_viewMode == 'search_location') ...[
            const SizedBox(height: 8),
            Text(
              "Try a different area or city name",
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class LabsList extends StatelessWidget {
  final List<Lab> labs;
  final String tab;
  final List<dynamic>? recommendedTests;
  const LabsList({super.key, required this.labs, this.tab = 'book', this.recommendedTests});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 600;
    final actionText = tab == 'book' ? 'Book a Lab' : 'View Reports';

    return GridView.builder(
      padding: EdgeInsets.all(isDesktop ? 40 : 20),
      itemCount: labs.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 2 : 1,
        mainAxisExtent: isDesktop ? 340 : 340,
        crossAxisSpacing: 30,
        mainAxisSpacing: 20,
      ),
      itemBuilder: (ctx, i) {
        return LabWidget(
          lab: labs[i],
          actionText: actionText,
          onActionBtnPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => tab == 'book'
                    ? BookLabScreen(
                        labId: labs[i].id,
                        labTitle: labs[i].title,
                        labProfileId: labs[i].profileId,
                      )
                    : const LabReportsScreen(),
              ),
            );
          },
        );
      },
    );
  }
}

/// Helper to keep a Lab paired with its computed distance so the sort
/// never goes out of sync with the raw data index.
class _LabWithDist {
  final Lab lab;
  final double dist;
  const _LabWithDist({required this.lab, required this.dist});
}

class _LabSuggestionItem {
  final String label;
  final String sublabel;
  final bool isTest;
  final Lab lab;
  const _LabSuggestionItem({required this.label, required this.sublabel, required this.isTest, required this.lab});
}
