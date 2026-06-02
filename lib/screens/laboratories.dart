import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/labb_details.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/laboratory.dart';
import 'package:icare/services/laboratory_service.dart';

class LaboratoriesScreen extends StatefulWidget {
  const LaboratoriesScreen({super.key});

  @override
  State<LaboratoriesScreen> createState() => _LaboratoriesScreenState();
}

class _LaboratoriesScreenState extends State<LaboratoriesScreen> {
  final LaboratoryService _labService = LaboratoryService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _labs = [];
  List<dynamic> _filteredLabs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLabs();
  }

  Future<void> _fetchLabs() async {
    try {
      final labs = await _labService.getAllLaboratories();
      if (mounted) {
        setState(() {
          _labs = labs;
          _filteredLabs = labs;
          _isLoading = false;
        });
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
      setState(() {
        _filteredLabs = _labs;
      });
      return;
    }
    setState(() {
      _filteredLabs = _labs.where((lab) {
        final name = (lab['labName'] ?? lab['name'] ?? "")
            .toString()
            .toLowerCase();
        final address = (lab['address'] ?? lab['location'] ?? "")
            .toString()
            .toLowerCase();
        return name.contains(query.toLowerCase()) ||
            address.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    // ── MOBILE: original layout (untouched) ────────────────────────────────
    if (!isDesktop) {
      return Scaffold(
        appBar: AppBar(
          title: CustomText(
            text: "Laboratories",
            fontFamily: "Gilroy-Bold",
            fontSize: 16.78,
            fontWeight: FontWeight.bold,
            color: AppColors.primary500,
          ),
          automaticallyImplyLeading: false,
          leading: const CustomBackButton(),
          centerTitle: true,
        ),
        body: _filteredLabs.isEmpty
            ? const Center(child: Text("No laboratories found"))
            : ListView.builder(
                itemCount: _filteredLabs.length,
                padding: EdgeInsets.symmetric(
                  horizontal: ScallingConfig.scale(20),
                ),
                itemBuilder: (ctx, i) => Laboratory(
                  labData: _filteredLabs[i],
                  margin: EdgeInsets.only(top: ScallingConfig.scale(10)),
                ),
              ),
      );
    }

    // ── WEB: premium redesigned layout ─────────────────────────────────────
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: CustomScrollView(
        slivers: [
          // Stunning SliverAppBar header
          SliverAppBar(
            expandedHeight: 240,
            floating: true,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: const CustomBackButton(),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryColor.withValues(alpha: 0.05),
                      Colors.white,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(60, 40, 60, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CustomText(
                        text: "DIAGNOSTIC CENTERS",
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryColor,
                        letterSpacing: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              "Nearby Laboratories",
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          // Stats chips
                          Row(
                            children: [
                              _buildStatChip(
                                Icons.science_rounded,
                                "${_labs.length} Labs",
                                const Color(0xFF6366F1),
                              ),
                              const SizedBox(width: 12),
                              Builder(builder: (_) {
                                final ratedLabs = _labs.where((l) => (l['rating'] as num?) != null && (l['rating'] as num) > 0).toList();
                                final avg = ratedLabs.isEmpty ? null : ratedLabs.map((l) => (l['rating'] as num).toDouble()).reduce((a, b) => a + b) / ratedLabs.length;
                                return _buildStatChip(
                                  Icons.star_rounded,
                                  avg != null ? "${avg.toStringAsFixed(1)} Avg Rating" : "Top Rated",
                                  const Color(0xFFF59E0B),
                                );
                              }),
                              const SizedBox(width: 12),
                              _buildStatChip(
                                Icons.check_circle_rounded,
                                "All Verified",
                                const Color(0xFF10B981),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Search and filter bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 28),
              child: Row(
                children: [
                  _buildFilterPill("All Centers", true),
                  const SizedBox(width: 12),
                  _buildFilterPill("Premier", false),
                  const SizedBox(width: 12),
                  _buildFilterPill("Certified", false),
                  const SizedBox(width: 12),
                  _buildFilterPill("Nearest", false),
                  const Spacer(),
                  // Search
                  Container(
                    width: 320,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterLabs,
                      decoration: const InputDecoration(
                        hintText: "Search laboratory...",
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                        hintStyle: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Labs grid
          _labs.isEmpty
              ? const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text("No laboratories found"),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(60, 0, 60, 60),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 480,
                          mainAxisExtent: 340,
                          crossAxisSpacing: 28,
                          mainAxisSpacing: 28,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildLabCard(context, _filteredLabs[i]),
                      childCount: _filteredLabs.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryColor : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isActive ? AppColors.primaryColor : const Color(0xFFE2E8F0),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primaryColor.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : const Color(0xFF64748B),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildLabCard(BuildContext context, Map<String, dynamic> lab) {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (ctx) => LabDetails(labData: lab))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with tag overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: lab['image'] is String
                      ? (lab['image'].toString().startsWith('assets')
                            ? Image.asset(
                                lab['image'] as String,
                                height: 170,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                lab['image'] as String,
                                height: 170,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      height: 170,
                                      width: double.infinity,
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.science_rounded,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                    ),
                              ))
                      : Container(
                          height: 170,
                          width: double.infinity,
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.science_rounded,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                ),
                // Tag badge
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: lab['tagColor'] != null
                          ? (lab['tagColor'] as Color)
                          : Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (lab['tagColor'] != null
                                      ? (lab['tagColor'] as Color)
                                      : Colors.blue)
                                  .withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      lab['tag'] ?? "Premier",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                // Rating badge
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF59E0B),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          () {
                            final r = lab['rating'];
                            if (r == null || r == 0) return 'New';
                            return (r is num) ? r.toStringAsFixed(1) : r.toString();
                          }(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Info section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ((lab['labName'] is String)
                        ? (lab['labName'] as String)
                        : ((lab['name'] is String)
                              ? (lab['name'] as String)
                              : 'Laboratory')),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          (lab['address'] is String)
                              ? (lab['address'] as String)
                              : ((lab['location'] is String)
                                    ? (lab['location'] as String)
                                    : 'Location not available'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        (lab['open'] is String
                            ? lab['open']
                            : 'Open 9:00 AM - 9:00 PM'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "${lab['tests'] ?? 0} Tests",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => LabDetails(labData: lab),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Visit Lab",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
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
