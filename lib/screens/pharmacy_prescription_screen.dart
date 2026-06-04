import 'package:flutter/material.dart';
import 'package:icare/services/pharmacy_service.dart';
import 'package:icare/widgets/back_button.dart';

/// Pharmacy prescription screen — exactly like LabDetails
/// Shows prescribed medicines pre-selected with dosage/quantity details
/// Plus pharmacy's own catalog medicines
class PharmacyPrescriptionScreen extends StatefulWidget {
  final Map<String, dynamic> pharmacy;
  final List<dynamic>? prescribedMedicines; // from doctor's prescription
  final String? medicalRecordId;

  const PharmacyPrescriptionScreen({
    super.key,
    required this.pharmacy,
    this.prescribedMedicines,
    this.medicalRecordId,
  });

  @override
  State<PharmacyPrescriptionScreen> createState() =>
      _PharmacyPrescriptionScreenState();
}

class _PharmacyPrescriptionScreenState
    extends State<PharmacyPrescriptionScreen> {
  final PharmacyService _pharmacyService = PharmacyService();

  // Selected medicines: {name, qty, dosageInfo}
  List<Map<String, dynamic>> _selectedMedicines = [];
  List<dynamic> _catalogMedicines = [];
  bool _isLoading = true;
  bool _isPlacingOrder = false;

  static const Color _primary = Color(0xFF1D4ED8);

  @override
  void initState() {
    super.initState();
    _initPrescribed();
    _loadCatalog();
  }

  /// Pre-select prescribed medicines with calculated quantities
  void _initPrescribed() {
    final meds = widget.prescribedMedicines ?? [];
    _selectedMedicines = meds.map((m) {
      final name = m is Map
          ? (m['name'] ?? m['medicineName'] ?? '').toString()
          : m.toString();
      final day = m is Map ? (m['day'] ?? '').toString() : '';
      final noon = m is Map ? (m['noon'] ?? '').toString() : '';
      final night = m is Map ? (m['night'] ?? '').toString() : '';
      final duration = m is Map ? (m['duration'] ?? '').toString() : '';
      final dosage = m is Map ? (m['dosage'] ?? m['dose'] ?? '').toString() : '';
      final frequency = m is Map ? (m['frequency'] ?? '').toString() : '';
      final formType = m is Map ? (m['formType'] ?? 'tablet').toString() : 'tablet';

      // For liquid, qty defaults to 1 bottle; for tablets/capsules, calculate from schedule
      final isLiquid = formType.toLowerCase() == 'liquid' || formType.toLowerCase() == 'syrup';
      final calculatedQty = isLiquid ? 1 : _calcQty(day, noon, night, duration, frequency: frequency);

      return {
        'name': name,
        'qty': calculatedQty > 0 ? calculatedQty : 1,
        'prescribedQty': calculatedQty > 0 ? calculatedQty : 1,
        'day': day,
        'noon': noon,
        'night': night,
        'duration': duration,
        'dosage': dosage,
        'frequency': frequency,
        'formType': formType,
        'isPrescribed': true,
      };
    }).where((m) => (m['name'] as String).isNotEmpty).toList();
  }

  /// Maps frequency codes used by doctors to times-per-day
  int _freqToPerDay(String freq) {
    switch (freq.toLowerCase().trim()) {
      case 'od': case 'qd': case 'once daily': case 'once a day': case 'nocte': case 'hs': case 'at night': return 1;
      case 'bd': case 'bid': case 'twice daily': case 'twice a day': return 2;
      case 'tds': case 'tid': case 'thrice daily': case 'three times daily': case 'three times a day': return 3;
      case 'qds': case 'qid': case 'four times daily': case 'four times a day': return 4;
      case 'q6h': return 4;
      case 'q8h': return 3;
      case 'q12h': return 2;
      default: return int.tryParse(freq) ?? 1;
    }
  }

  int _calcQty(String day, String noon, String night, String duration, {String frequency = ''}) {
    try {
      final d = int.tryParse(day) ?? 0;
      final n = int.tryParse(noon) ?? 0;
      final ni = int.tryParse(night) ?? 0;
      int perDay = d + n + ni;

      // If no day/noon/night schedule, fall back to frequency code (bd=2, tds=3, etc.)
      if (perDay == 0 && frequency.isNotEmpty) {
        perDay = _freqToPerDay(frequency);
      }

      final durationMatch = RegExp(r'\d+').firstMatch(duration);
      final days = durationMatch != null
          ? int.tryParse(durationMatch.group(0)!) ?? 0
          : 0;
      if (perDay > 0 && days > 0) return perDay * days;
    } catch (_) {}
    return 0;
  }

  Future<void> _loadCatalog() async {
    try {
      final pharmacyId = widget.pharmacy['_id']?.toString() ?? '';
      if (pharmacyId.isNotEmpty) {
        final meds =
            await _pharmacyService.getMedicinesByPharmacyId(pharmacyId);
        if (mounted) {
          setState(() {
            _catalogMedicines = meds;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isPrescribed(String name) =>
      _selectedMedicines.any((m) => m['isPrescribed'] == true && m['name'] == name);

  bool _isSelected(String name) =>
      _selectedMedicines.any((m) => m['name'] == name);

  void _toggleCatalogMed(dynamic med) {
    final name = (med['productName'] ?? med['name'] ?? '').toString();
    if (name.isEmpty) return;
    if (_isPrescribed(name)) return; // can't deselect prescribed
    setState(() {
      if (_isSelected(name)) {
        _selectedMedicines.removeWhere((m) => m['name'] == name);
      } else {
        _selectedMedicines.add({
          'name': name,
          'qty': 1,
          'isPrescribed': false,
          'price': med['price'] ?? 0,
        });
      }
    });
  }

  int get _totalQty =>
      _selectedMedicines.fold(0, (sum, m) => sum + ((m['qty'] as int?) ?? 1));

  Future<void> _placeOrder() async {
    if (_selectedMedicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one medicine')),
      );
      return;
    }
    setState(() => _isPlacingOrder = true);
    try {
      final pharmacyId = widget.pharmacy['_id']?.toString() ?? '';
      await _pharmacyService.createPrescriptionOrder(
        pharmacyId: pharmacyId,
        medicines: _selectedMedicines
            .map((m) => {
                  'name': m['name'],
                  'productName': m['name'],
                  'quantity': m['qty'],
                  'dosage': m['dosage'] ?? '',
                  'frequency': m['frequency'] ?? '',
                  'duration': m['duration'] ?? '',
                })
            .toList(),
        medicalRecordId: widget.medicalRecordId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed! Pharmacy will confirm shortly.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;
    final pharmacyName = widget.pharmacy['pharmacy_name']?.toString() ??
        widget.pharmacy['pharmacyName']?.toString() ??
        widget.pharmacy['name']?.toString() ??
        'Pharmacy';
    final address = widget.pharmacy['address']?.toString() ?? '';
    final city = widget.pharmacy['city']?.toString() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          pharmacyName,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A)),
        ),
      ),
      body: isDesktop
          ? _buildDesktopLayout(pharmacyName, address, city)
          : _buildMobileLayout(pharmacyName, address, city),
      bottomNavigationBar: _buildOrderBar(),
    );
  }

  // ── DESKTOP LAYOUT ────────────────────────────────────────────────────────
  Widget _buildDesktopLayout(
      String pharmacyName, String address, String city) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: pharmacy info
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: _buildPharmacyInfo(pharmacyName, address, city),
          ),
        ),
        // Right: medicine selection
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSelectionHeader(),
                Expanded(child: _buildMedicineList()),
                _buildEstimatedTotal(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── MOBILE LAYOUT ─────────────────────────────────────────────────────────
  Widget _buildMobileLayout(String pharmacyName, String address, String city) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildPharmacyInfo(pharmacyName, address, city),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildSelectionHeader(),
                _buildMedicineList(),
                _buildEstimatedTotal(),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ── PHARMACY INFO ─────────────────────────────────────────────────────────
  Widget _buildPharmacyInfo(
      String pharmacyName, String address, String city) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero card
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_pharmacy_rounded,
                          color: Colors.white, size: 56),
                    ),
                    const SizedBox(height: 12),
                    Text(pharmacyName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Verified Pharmacy',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(pharmacyName,
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        if (address.isNotEmpty)
          Row(children: [
            const Icon(Icons.location_on_rounded,
                size: 16, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Expanded(
                child: Text('$address${city.isNotEmpty ? ', $city' : ''}',
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF64748B)))),
          ]),
        const SizedBox(height: 16),
        Row(children: [
          _infoChip(Icons.verified_rounded, 'Licensed', Colors.green),
          const SizedBox(width: 10),
          if (widget.pharmacy['deliveryAvailable'] == true ||
              widget.pharmacy['delivery_available'] == true)
            _infoChip(Icons.delivery_dining_rounded, 'Delivery', _primary),
        ]),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  // ── SELECTION HEADER ──────────────────────────────────────────────────────
  Widget _buildSelectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Medicines',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          const Text('Prescribed medicines are pre-selected',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
        ],
      ),
    );
  }

  // ── MEDICINE LIST ─────────────────────────────────────────────────────────
  Widget _buildMedicineList() {
    final prescribed = _selectedMedicines
        .where((m) => m['isPrescribed'] == true)
        .toList();
    final catalog = _catalogMedicines
        .where((m) {
          final name =
              (m['productName'] ?? m['name'] ?? '').toString();
          return !_isPrescribed(name);
        })
        .toList();

    return ListView(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Prescribed medicines
        ...prescribed.map((m) => _prescribedMedTile(m)),

        // Divider if both sections exist
        if (prescribed.isNotEmpty && catalog.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Also Available',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600)),
              ),
              Expanded(child: Divider()),
            ]),
          ),
        ],

        // Catalog medicines
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          ...catalog.map((m) => _catalogMedTile(m)),

        const SizedBox(height: 16),
      ],
    );
  }

  // ── PRESCRIBED MEDICINE TILE ──────────────────────────────────────────────
  Widget _prescribedMedTile(Map<String, dynamic> m) {
    final name = m['name'] as String;
    final dosage = (m['dosage'] ?? '').toString();
    final formType = (m['formType'] ?? '').toString().toLowerCase();
    final frequency = (m['frequency'] ?? '').toString().toUpperCase();
    final duration = (m['duration'] ?? '').toString();
    int qty = m['qty'] as int? ?? 1;

    // form label
    final formLabel = formType == 'liquid' || formType == 'syrup'
        ? 'Liquid/Syrup'
        : formType == 'capsule'
            ? 'Capsule'
            : formType == 'drops'
                ? 'Drops'
                : formType == 'injection'
                    ? 'Injection'
                    : formType == 'cream'
                        ? 'Cream'
                        : formType == 'inhaler'
                            ? 'Inhaler'
                            : 'Tablet';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22, height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    // Dosage info line: "500mg • Tablet • BD • 5 Days"
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      if (dosage.isNotEmpty) _chip(dosage, const Color(0xFF64748B)),
                      _chip(formLabel, _primary),
                      if (frequency.isNotEmpty) _chip(frequency, const Color(0xFF10B981)),
                      if (duration.isNotEmpty) _chip('📅 $duration', const Color(0xFF94A3B8)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Quantity row: label + minus + value + plus
          Row(
            children: [
              const Text('Quantity:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  if (qty > 1) {
                    setState(() => m['qty'] = qty - 1);
                  }
                },
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Icon(Icons.remove_rounded, size: 18, color: Color(0xFF475569)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$qty',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _primary)),
              ),
              Builder(builder: (_) {
                final maxQty = (m['prescribedQty'] as int?) ?? qty;
                final atMax = qty >= maxQty;
                return GestureDetector(
                  onTap: atMax ? null : () => setState(() => m['qty'] = qty + 1),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: atMax ? const Color(0xFFCBD5E1) : _primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add_rounded, size: 18,
                        color: atMax ? const Color(0xFF94A3B8) : Colors.white),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  // ── CATALOG MEDICINE TILE ─────────────────────────────────────────────────
  Widget _catalogMedTile(dynamic med) {
    final name =
        (med['productName'] ?? med['name'] ?? '').toString();
    final price = med['price'] ?? 0;
    final selected = _isSelected(name);

    return GestureDetector(
      onTap: () => _toggleCatalogMed(med),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? _primary.withValues(alpha: 0.06)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? _primary.withValues(alpha: 0.3)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: selected ? _primary : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: selected ? _primary : const Color(0xFFCBD5E1),
                  width: 2),
            ),
            child: selected
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF475569))),
          ),
          Text('PKR $price',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? _primary : const Color(0xFF94A3B8))),
        ]),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  String _qtyText(
      String day, String noon, String night, String duration, int total) {
    final parts = <String>[];
    if (day.isNotEmpty && day != '0') parts.add('Day: $day');
    if (noon.isNotEmpty && noon != '0') parts.add('Noon: $noon');
    if (night.isNotEmpty && night != '0') parts.add('Night: $night');
    final perDay = parts.join(' + ');
    if (perDay.isNotEmpty && duration.isNotEmpty) {
      return '($perDay) × $duration = $total tablets';
    }
    return 'Total: $total tablets';
  }

  // ── ESTIMATED TOTAL ───────────────────────────────────────────────────────
  Widget _buildEstimatedTotal() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Selected',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            Text('${_selectedMedicines.length} medicine(s)',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A))),
          ]),
          Text('Total Qty: $_totalQty',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _primary)),
        ],
      ),
    );
  }

  // ── ORDER BAR ─────────────────────────────────────────────────────────────
  Widget _buildOrderBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isPlacingOrder ? null : _placeOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: _isPlacingOrder
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(
            _isPlacingOrder
                ? 'Placing Order...'
                : 'Place Order (${_selectedMedicines.length} medicines)',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}
