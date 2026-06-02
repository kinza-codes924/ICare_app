import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:icare/utils/web_download_helper.dart'
    if (dart.library.html) 'package:icare/utils/web_download_helper_web.dart';
import 'package:file_picker/file_picker.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/services/pharmacy_service.dart';
import 'package:intl/intl.dart';

class PharmacyInventory extends StatefulWidget {
  const PharmacyInventory({super.key});
  @override
  State<PharmacyInventory> createState() => _PharmacyInventoryState();
}

class _PharmacyInventoryState extends State<PharmacyInventory> {
  final PharmacyService _pharmacyService = PharmacyService();
  String _searchQuery = '';
  String _filterCategory = 'All';
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];

  static const _categories = [
    'All', 'Pain Relief', 'Antibiotic', 'Allergy', 'Vitamins',
    'Diabetes', 'Cholesterol', 'Gastric', 'Blood Pressure',
    'Heart', 'Cough & Cold', 'Vaccine',
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      setState(() => _isLoading = true);
      final medicines = await _pharmacyService.getMedicines(
        category: _filterCategory != 'All' ? _filterCategory : null,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      List<Map<String, dynamic>> products = medicines.map<Map<String, dynamic>>((m) => {
        '_id': m['_id'],
        'name': m['productName'] ?? m['name'] ?? m['product_name'] ?? m['medicine_name'] ?? 'Unknown',
        'brand': m['brand'] ?? m['companyName'] ?? '',
        'category': m['category'] ?? 'Other',
        'type': m['medicineType'] ?? 'Tablet',
        'power': m['power'] ?? '',
        'stock': ((m['quantity'] ?? m['stock_quantity'] ?? m['stock'] ?? 0) as num).toInt(),
        'price': (m['price'] ?? 0).toDouble(),
        'amount': m['amount'] ?? '',
        'details': m['details'] ?? '',
        'precautions': m['precautions'] ?? '',
        'manufacturer': m['companyName'] ?? '',
        'expiry': m['expiry'] != null
            ? DateTime.parse(m['expiry'])
            : DateTime.now().add(const Duration(days: 365)),
        'isAvailable': m['isAvailable'] ?? true,
        'isControlled': m['isControlled'] ?? false,
      }).toList();

      // Add dummy data if inventory is empty
      if (products.isEmpty && _filterCategory == 'All' && _searchQuery.isEmpty) {
        products = [
          {
            '_id': 'dummy_1',
            'name': 'Panadol',
            'brand': 'GSK',
            'category': 'Pain Relief',
            'type': 'Tablet',
            'power': '500mg',
            'stock': 150,
            'price': 45.0,
            'amount': '10 tablets',
            'details': 'Paracetamol for fever and pain relief',
            'precautions': 'Do not exceed recommended dose',
            'manufacturer': 'GlaxoSmithKline Pakistan',
            'expiry': DateTime.now().add(const Duration(days: 730)),
            'isAvailable': true,
          },
          {
            '_id': 'dummy_2',
            'name': 'Brufen',
            'brand': 'Abbott',
            'category': 'Pain Relief',
            'type': 'Tablet',
            'power': '400mg',
            'stock': 120,
            'price': 85.0,
            'amount': '20 tablets',
            'details': 'Ibuprofen for pain and inflammation',
            'precautions': 'Take with food to avoid stomach upset',
            'manufacturer': 'Abbott Laboratories Pakistan',
            'expiry': DateTime.now().add(const Duration(days: 700)),
            'isAvailable': true,
          },
          {
            '_id': 'dummy_3',
            'name': 'Augmentin',
            'brand': 'GSK',
            'category': 'Antibiotic',
            'type': 'Tablet',
            'power': '625mg',
            'stock': 80,
            'price': 320.0,
            'amount': '6 tablets',
            'details': 'Amoxicillin + Clavulanic acid antibiotic',
            'precautions': 'Complete full course as prescribed',
            'manufacturer': 'GlaxoSmithKline Pakistan',
            'expiry': DateTime.now().add(const Duration(days: 650)),
            'isAvailable': true,
          },
          {
            '_id': 'dummy_4',
            'name': 'Flagyl',
            'brand': 'Sanofi',
            'category': 'Antibiotic',
            'type': 'Tablet',
            'power': '400mg',
            'stock': 95,
            'price': 180.0,
            'amount': '10 tablets',
            'details': 'Metronidazole for bacterial infections',
            'precautions': 'Avoid alcohol during treatment',
            'manufacturer': 'Sanofi Pakistan',
            'expiry': DateTime.now().add(const Duration(days: 680)),
            'isAvailable': true,
          },
          {
            '_id': 'dummy_5',
            'name': 'Disprin',
            'brand': 'Reckitt Benckiser',
            'category': 'Pain Relief',
            'type': 'Tablet',
            'power': '300mg',
            'stock': 200,
            'price': 35.0,
            'amount': '12 tablets',
            'details': 'Aspirin for pain relief and fever',
            'precautions': 'Not for children under 12',
            'manufacturer': 'Reckitt Benckiser Pakistan',
            'expiry': DateTime.now().add(const Duration(days: 720)),
            'isAvailable': true,
          },
        ];
      }

      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load data. Please try again.')));
      }
    }
  }

  // ── CSV Import / Export ──────────────────────────────────────────────────
  void _showImportExportSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bulk Import / Export',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              'Manage your inventory in bulk using CSV files',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),
            _csvOptionTile(
              Icons.file_download_outlined,
              'Download Template',
              'CSV template with all required fields',
              const Color(0xFF3B82F6),
              () { Navigator.pop(context); _downloadTemplate(); },
            ),
            const SizedBox(height: 12),
            _csvOptionTile(
              Icons.upload_file_outlined,
              'Import CSV',
              'Upload medicines from a filled template',
              const Color(0xFF10B981),
              () { Navigator.pop(context); _importCSV(); },
            ),
            const SizedBox(height: 12),
            _csvOptionTile(
              Icons.download_rounded,
              'Export Inventory',
              'Download your current inventory as CSV',
              const Color(0xFF8B5CF6),
              () { Navigator.pop(context); _exportCSV(); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _csvOptionTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  void _downloadTemplate() {
    const content =
        'Name,Brand,Category,Type,Power,Price (PKR),Stock Quantity,Unit,Details,Precautions,Controlled Medicine (Yes/No),Medicine Permission (OTC/Prescription Only),Delivery Option (both/pickup/delivery)\n'
        'Panadol,GSK,Pain Relief,Tablet,500mg,45,100,tablets,Paracetamol for fever and pain,Do not exceed 8 tablets per day,No,OTC,both\n';
    _triggerDownload(content, 'icare_inventory_template.csv');
  }

  void _exportCSV() {
    final buffer = StringBuffer();
    buffer.writeln('Name,Brand,Category,Type,Power,Price (PKR),Stock Quantity,Unit,Details,Precautions,Controlled Medicine (Yes/No),Medicine Permission (OTC/Prescription Only),Delivery Option (both/pickup/delivery)');
    for (final p in _products) {
      buffer.writeln([
        _esc(p['name'] ?? ''),
        _esc(p['brand'] ?? ''),
        _esc(p['category'] ?? ''),
        _esc(p['type'] ?? ''),
        _esc(p['power'] ?? ''),
        p['price'] ?? 0,
        p['stock'] ?? 0,
        _esc(p['amount'] ?? ''),
        _esc(p['details'] ?? ''),
        _esc(p['precautions'] ?? ''),
        (p['isControlled'] == true) ? 'Yes' : 'No',
        _esc(p['medicinePermission'] ?? 'OTC'),
        _esc(p['deliveryOption'] ?? 'both'),
      ].join(','));
    }
    _triggerDownload(buffer.toString(), 'icare_inventory_export.csv');
  }

  String _esc(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  void _triggerDownload(String content, String filename) {
    if (kIsWeb) {
      triggerWebDownload(content, filename);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV export is available on web only')),
      );
    }
  }

  Future<void> _importCSV() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) return;

      final content = utf8.decode(bytes);
      final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();

      if (lines.length < 2) {
        _showSnack('CSV file has no data rows', isError: true);
        return;
      }

      setState(() => _isLoading = true);
      int success = 0, failed = 0;

      for (int i = 1; i < lines.length; i++) {
        final cols = _parseCsvLine(lines[i]);
        if (cols.isEmpty || (cols[0]).isEmpty) continue;
        try {
          await _pharmacyService.createMedicine({
            'name': cols[0],
            'productName': cols[0],
            'brand': cols.length > 1 ? cols[1] : '',
            'category': cols.length > 2 && cols[2].isNotEmpty ? cols[2] : 'Other',
            'medicineType': cols.length > 3 && cols[3].isNotEmpty ? cols[3] : 'Tablet',
            'power': cols.length > 4 ? cols[4] : '',
            'price': double.tryParse(cols.length > 5 ? cols[5] : '0') ?? 0,
            'quantity': int.tryParse(cols.length > 6 ? cols[6] : '0') ?? 0,
            'amount': cols.length > 7 ? cols[7] : '',
            'details': cols.length > 8 ? cols[8] : '',
            'precautions': cols.length > 9 ? cols[9] : '',
            'isAvailable': true,
          });
          success++;
        } catch (_) {
          failed++;
        }
      }

      await _loadProducts();
      if (mounted) {
        _showSnack(
          'Imported $success medicine${success != 1 ? 's' : ''}${failed > 0 ? ' ($failed failed)' : ''}',
          isError: failed > 0 && success == 0,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Import failed: please check file format', isError: true);
    }
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    bool inQuotes = false;
    final current = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(c);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : const Color(0xFF10B981),
    ));
  }
  // ─────────────────────────────────────────────────────────────────────────

  void _showAddModal() {
    showDialog(
      context: context,
      builder: (_) => _AddMedicineModal(
        onSave: (data) async {
          try {
            await _pharmacyService.createMedicine(data);
            await _loadProducts();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Medicine added successfully'),
                backgroundColor: Color(0xFF10B981),
              ));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text('Inventory',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        actions: [
          IconButton(
            onPressed: _showImportExportSheet,
            icon: const Icon(Icons.upload_file_outlined, color: Color(0xFF0F172A)),
            tooltip: 'Bulk Import / Export',
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _showAddModal,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Medicine'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + filter bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(isDesktop ? 32 : 16, 12, isDesktop ? 32 : 16, 0),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) { setState(() => _searchQuery = v); _loadProducts(); },
                  decoration: InputDecoration(
                    hintText: 'Search medicines...',
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                    filled: true, fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _categories.map((cat) {
                      final sel = _filterCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat, style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : const Color(0xFF64748B),
                          )),
                          selected: sel,
                          selectedColor: AppColors.primaryColor,
                          backgroundColor: const Color(0xFFF1F5F9),
                          onSelected: (_) { setState(() => _filterCategory = cat); _loadProducts(); },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          // Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? _buildEmpty()
                    : GridView.builder(
                        padding: EdgeInsets.all(isDesktop ? 32 : 16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isDesktop ? 4 : 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 182,
                        ),
                        itemCount: _products.length,
                        itemBuilder: (_, i) => _MedicineCard(product: _products[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.medication_outlined, size: 72, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      const Text('No medicines found', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)),
      const SizedBox(height: 12),
      ElevatedButton.icon(
        onPressed: _showAddModal,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add First Medicine'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white),
      ),
    ]),
  );
}

// ── Medicine Card ─────────────────────────────────────────────────────────────
class _MedicineCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _MedicineCard({required this.product});

  Color get _categoryColor {
    switch ((product['category'] as String).toLowerCase()) {
      case 'pain relief': return const Color(0xFFEF4444);
      case 'antibiotic': return const Color(0xFF8B5CF6);
      case 'diabetes': return const Color(0xFF3B82F6);
      case 'vitamins': return const Color(0xFFF59E0B);
      case 'allergy': return const Color(0xFF06B6D4);
      case 'gastric': return const Color(0xFF10B981);
      case 'cholesterol': return const Color(0xFFEC4899);
      case 'blood pressure': return const Color(0xFFEF4444);
      case 'heart': return const Color(0xFFDC2626);
      case 'vaccine': return const Color(0xFF6366F1);
      default: return AppColors.primaryColor;
    }
  }

  IconData get _typeIcon {
    switch ((product['type'] as String).toLowerCase()) {
      case 'syrup': return Icons.local_drink_rounded;
      case 'capsule': return Icons.circle_outlined;
      case 'gel': return Icons.water_drop_rounded;
      case 'injection': return Icons.vaccines_rounded;
      default: return Icons.medication_rounded;
    }
  }

  String get _imageUrl {
    switch ((product['type'] as String).toLowerCase()) {
      case 'syrup': return 'https://img.icons8.com/color/200/cough-syrup.png';
      case 'capsule': return 'https://img.icons8.com/color/200/capsule.png';
      case 'injection': return 'https://img.icons8.com/color/200/syringe.png';
      case 'gel':
      case 'cream': return 'https://img.icons8.com/color/200/ointment.png';
      case 'drops': return 'https://img.icons8.com/color/200/eye-drops.png';
      default: return 'https://img.icons8.com/color/200/pill.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = product['stock'] as int;
    final isLow = stock < 30;
    final isControlled = product['isControlled'] == true;
    final isPrescriptionOnly = (product['medicinePermission'] ?? '').toString() == 'Prescription Only';
    final expiry = product['expiry'] as DateTime;
    final expiringSoon = expiry.difference(DateTime.now()).inDays < 90;
    final color = _categoryColor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isControlled ? const Color(0xFF8B5CF6).withValues(alpha: 0.4) : isLow ? const Color(0xFFEF4444).withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image area — compact
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Image.network(
                    _imageUrl,
                    height: 52,
                    width: 52,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(_typeIcon, size: 38, color: color.withValues(alpha: 0.7)),
                  ),
                ),
                // Category badge
                Positioned(
                  top: 6, left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                    child: Text(product['category'], style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                  ),
                ),
                if (isControlled)
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF8B5CF6), borderRadius: BorderRadius.circular(20)),
                      child: const Text('CTRL', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                    ),
                  )
                else if (isLow)
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(20)),
                      child: const Text('Low', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                    ),
                  ),
                // OTC / Rx badge — bottom right
                Positioned(
                  bottom: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPrescriptionOnly ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isPrescriptionOnly ? 'Rx Only' : 'OTC',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Info — compact, no Spacer
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(product['name'], maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                if ((product['brand'] as String).isNotEmpty)
                  Text(product['brand'], maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                if ((product['power'] as String).isNotEmpty)
                  Text(product['power'],
                      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Rs ${product['price'].toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Qty: $stock',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 10,
                      color: expiringSoon ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8)),
                  const SizedBox(width: 3),
                  Text('Exp: ${DateFormat('MMM yy').format(expiry)}',
                      style: TextStyle(fontSize: 9,
                          color: expiringSoon ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8))),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add Medicine Modal ────────────────────────────────────────────────────────
class _AddMedicineModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const _AddMedicineModal({required this.onSave});
  @override
  State<_AddMedicineModal> createState() => _AddMedicineModalState();
}

class _AddMedicineModalState extends State<_AddMedicineModal> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _power = TextEditingController();
  final _price = TextEditingController();
  final _qty = TextEditingController();
  final _amount = TextEditingController();
  final _details = TextEditingController();
  final _precautions = TextEditingController();
  String _category = 'Pain Relief';
  String _type = 'Tablet';
  String _delivery = 'both';
  String _medicinePermission = 'OTC';
  bool _isControlled = false;
  bool _saving = false;

  static const _categories = ['Pain Relief', 'Antibiotic', 'Allergy', 'Vitamins',
    'Diabetes', 'Cholesterol', 'Gastric', 'Blood Pressure', 'Heart', 'Cough & Cold', 'Vaccine', 'Other'];
  static const _types = ['Tablet', 'Capsule', 'Syrup', 'Gel', 'Injection', 'Drops', 'Cream'];

  @override
  void dispose() {
    for (final c in [_name, _brand, _power, _price, _qty, _amount, _details, _precautions]) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5)),
    filled: true, fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.onSave({
      'name': _name.text.trim(),
      'productName': _name.text.trim(),
      'brand': _brand.text.trim(),
      'power': _power.text.trim(),
      'category': _category,
      'medicineType': _type,
      'price': double.parse(_price.text.trim()),
      'quantity': int.parse(_qty.text.trim()),
      'amount': _amount.text.trim(),
      'details': _details.text.trim(),
      'precautions': _precautions.text.trim(),
      'deliveryOption': _delivery,
      'isControlled': _isControlled,
      'medicinePermission': _medicinePermission,
      'isAvailable': true,
      'expiry': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medication_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Add New Medicine',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(controller: _name, decoration: _dec('Medicine Name *', Icons.medication_rounded),
                          validator: (v) => v!.isEmpty ? 'Required' : null),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: TextFormField(controller: _brand, decoration: _dec('Brand', Icons.business_rounded))),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(controller: _power, decoration: _dec('Strength (e.g. 500mg)', Icons.science_rounded))),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _category,
                            decoration: _dec('Category', Icons.category_rounded),
                            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) => setState(() => _category = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _type,
                            decoration: _dec('Type', Icons.local_pharmacy_rounded),
                            items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) => setState(() => _type = v!),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: TextFormField(controller: _price, decoration: _dec('Price (Rs) *', Icons.attach_money_rounded),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Required' : null)),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(controller: _qty, decoration: _dec('Quantity *', Icons.inventory_rounded),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Required' : null)),
                      ]),
                      const SizedBox(height: 12),
                      TextFormField(controller: _amount, decoration: _dec('Pack Size (e.g. 20 tablets)', Icons.straighten_rounded)),
                      const SizedBox(height: 12),
                      TextFormField(controller: _details, decoration: _dec('Description', Icons.description_rounded), maxLines: 2),
                      const SizedBox(height: 12),
                      TextFormField(controller: _precautions, decoration: _dec('Precautions', Icons.warning_amber_rounded), maxLines: 2),
                      const SizedBox(height: 12),
                      // Medicine Permission
                      const Text('Medicine Permission', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 6),
                      Row(children: [
                        for (final opt in [('OTC', 'OTC (Over-the-Counter)'), ('Prescription Only', 'Prescription Only')])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(opt.$1, style: TextStyle(fontSize: 11,
                                    color: _medicinePermission == opt.$1 ? Colors.white : const Color(0xFF64748B))),
                                selected: _medicinePermission == opt.$1,
                                selectedColor: opt.$1 == 'OTC' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                onSelected: (_) => setState(() => _medicinePermission = opt.$1),
                              ),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 12),
                      // Controlled medicine toggle
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isControlled ? const Color(0xFF8B5CF6).withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isControlled ? const Color(0xFF8B5CF6).withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_rounded, size: 18, color: Color(0xFF8B5CF6)),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Controlled Medicine', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                  Text('Max 30 units per order', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isControlled,
                              onChanged: (v) => setState(() => _isControlled = v),
                              activeThumbColor: const Color(0xFF8B5CF6),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Delivery option
                      const Text('Delivery Option', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 6),
                      Row(children: [
                        for (final opt in [('both', 'Both'), ('pickup', 'Pickup'), ('delivery', 'Delivery')])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(opt.$2, style: TextStyle(fontSize: 12,
                                  color: _delivery == opt.$1 ? Colors.white : const Color(0xFF64748B))),
                              selected: _delivery == opt.$1,
                              selectedColor: AppColors.primaryColor,
                              onSelected: (_) => setState(() => _delivery = opt.$1),
                            ),
                          ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  child: _saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Add Medicine'),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
