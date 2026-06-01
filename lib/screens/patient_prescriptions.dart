import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/services/consultation_service.dart';
import 'package:icare/services/medical_record_service.dart';
import 'package:icare/services/laboratory_service.dart';
import 'package:icare/services/pharmacy_service.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/screens/labb_details.dart';
import 'package:icare/screens/pharmacy_prescription_screen.dart';
import 'package:icare/screens/my_orders.dart';
import 'package:icare/screens/patient_lab_orders.dart';
import 'package:icare/services/order_service.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' as math;
// ignore: avoid_web_libraries_in_flutter
import '../utils/js_stub.dart'
    if (dart.library.html) 'dart:js' as js;

class PatientPrescriptions extends ConsumerStatefulWidget {
  const PatientPrescriptions({super.key});

  @override
  ConsumerState<PatientPrescriptions> createState() =>
      _PatientPrescriptionsState();
}

class _PatientPrescriptionsState extends ConsumerState<PatientPrescriptions> {
  final MedicalRecordService _medicalRecordService = MedicalRecordService();
  final LaboratoryService _labService = LaboratoryService();
  final OrderService _orderService = OrderService();
  List<dynamic> _prescriptions = [];
  List<dynamic> _filtered = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, List<dynamic>> _labBookingsByPrescription = {};
  Map<String, List<dynamic>> _ordersByPrescription = {};
  List<dynamic> _allLabBookings = [];
  List<dynamic> _allPharmacyOrders = [];

  @override
  void initState() {
    super.initState();
    _loadPrescriptions();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _applyFilter();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filtered = List.from(_prescriptions);
      return;
    }
    _filtered = _prescriptions.where((r) {
      final diagnosis = (r['diagnosis'] ?? '').toString().toLowerCase();
      final doctorName = (r['doctor']?['name'] ?? '').toString().toLowerCase();
      final date = r['createdAt'] != null
          ? (() { try { return DateFormat('MMM dd, yyyy').format(DateTime.parse(r['createdAt'].toString().replaceAll('/', '-')).toLocal()).toLowerCase(); } catch (_) { return ''; } })()
          : '';
      final rawId = (r['_id'] ?? r['id'] ?? '').toString();
      final mrNumber = rawId.length >= 6
          ? 'mr-${rawId.substring(rawId.length - 6).toLowerCase()}'
          : '';
      // Also search medicine names
      final meds = (r['prescription']?['medicines'] as List?) ?? [];
      final medNames = meds
          .map((m) => (m is Map ? m['name'] : m).toString().toLowerCase())
          .join(' ');
      // Also search lab test names
      final labs = (r['prescription']?['labTests'] as List?) ??
          (r['labTests'] as List?) ??
          [];
      final labNames = labs
          .map((t) => (t is Map ? (t['name'] ?? t['testName']) : t)
              .toString()
              .toLowerCase())
          .join(' ');

      return diagnosis.contains(_searchQuery) ||
          doctorName.contains(_searchQuery) ||
          date.contains(_searchQuery) ||
          mrNumber.contains(_searchQuery) ||
          medNames.contains(_searchQuery) ||
          labNames.contains(_searchQuery);
    }).toList();
  }

  Future<void> _loadPrescriptions() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authProvider).user;
      final patientId = user?.id ?? '';

      final results = await Future.wait([
        _medicalRecordService.getMyRecords(),
        patientId.isNotEmpty
            ? ConsultationService().getPatientPrescriptions(patientId: patientId)
            : Future.value(<dynamic>[]),
        _labService.getMyBookings().catchError((_) => <dynamic>[]),
        _orderService.getMyOrders().catchError((_) => <dynamic>[]),
      ]);

      final medResult = results[0] as Map<String, dynamic>;
      final rxList = results[1] as List<dynamic>;
      final labBookings = (results[2] as List?) ?? <dynamic>[];
      final pharmacyOrders = (results[3] as List?) ?? <dynamic>[];
      final allPrescriptions = <dynamic>[];

      if (medResult['success'] == true) {
        final records = medResult['records'] as List<dynamic>;
        final filtered = records.where((r) {
          if (r['_source'] == 'enhanced') return true;
          final p = r['prescription'];
          final meds = p is Map ? (p['medicines'] as List?) : null;
          final testsTop = r['labTests'] as List?;
          final testsInP = p is Map ? (p['labTests'] as List?) : null;
          final tests = testsInP ?? testsTop;
          final hasDiagnosis = (r['diagnosis']?.toString() ?? '').isNotEmpty;
          final hasNotes = (r['notes']?.toString() ?? r['doctorNotes']?.toString() ?? '').isNotEmpty;
          return (meds != null && meds.isNotEmpty) || (tests != null && tests.isNotEmpty) || hasDiagnosis || hasNotes;
        }).toList();
        allPrescriptions.addAll(filtered);
      }

      for (final rx in rxList) {
        if (rx['isComplete'] == true) {
          final rxMap = Map<String, dynamic>.from(rx as Map);
          rxMap['_source'] = 'enhanced';
          final rxId = rxMap['_id']?.toString() ?? '';
          final alreadyExists = allPrescriptions.any((r) {
            final eid = (r is Map ? (r['_id'] ?? r['prescription']?['_id'] ?? '') : '').toString();
            return eid == rxId && rxId.isNotEmpty;
          });
          if (!alreadyExists) allPrescriptions.add(rxMap);
        }
      }

      allPrescriptions.sort((a, b) {
        final aDate = (a is Map ? (a['prescribedAt'] ?? a['createdAt'] ?? '') : '').toString();
        final bDate = (b is Map ? (b['prescribedAt'] ?? b['createdAt'] ?? '') : '').toString();
        return bDate.compareTo(aDate);
      });

      // Build lookup maps: prescriptionId → list of lab bookings / pharmacy orders
      final labMap = <String, List<dynamic>>{};
      for (final b in labBookings) {
        final pid = (b['prescriptionId'] ?? b['medicalRecordId'] ?? b['prescription_id'] ?? b['medical_record_id'] ?? b['prescription'])?.toString() ?? '';
        if (pid.isNotEmpty) labMap.putIfAbsent(pid, () => []).add(b);
      }
      final orderMap = <String, List<dynamic>>{};
      for (final o in pharmacyOrders) {
        final pid = (o['prescriptionId'] ?? o['prescription_id'] ?? o['prescription'])?.toString() ?? '';
        if (pid.isNotEmpty) orderMap.putIfAbsent(pid, () => []).add(o);
      }

      if (mounted) {
        setState(() {
          _prescriptions = allPrescriptions;
          _filtered = List.from(allPrescriptions);
          _labBookingsByPrescription = labMap;
          _ordersByPrescription = orderMap;
          _allLabBookings = labBookings;
          _allPharmacyOrders = pharmacyOrders;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading prescriptions: ');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Text(
          'My Prescriptions'.tr(),
          style: const TextStyle(
            fontSize: 18,
            fontFamily: 'Gilroy-Bold',
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // â”€â”€ Search Bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(
                      isDesktop ? 40 : 16, 12, isDesktop ? 40 : 16, 12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          'Search by diagnosis, doctor, medicine, lab testâ€¦',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: Color(0xFF94A3B8), size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Color(0xFF94A3B8), size: 18),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.5),
                            width: 1.5),
                      ),
                    ),
                  ),
                ),
                // â”€â”€ Result count â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                if (_searchQuery.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        isDesktop ? 40 : 16, 8, isDesktop ? 40 : 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _filtered.isEmpty
                            ? 'No results for "$_searchQuery"'
                            : '${_filtered.length} result${_filtered.length == 1 ? '' : 's'} for "$_searchQuery"',
                        style: TextStyle(
                          fontSize: 12,
                          color: _filtered.isEmpty
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                // â”€â”€ List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Expanded(
                  child: _filtered.isEmpty && _searchQuery.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded,
                                  size: 56,
                                  color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                'No prescriptions match\n"$_searchQuery"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        )
                      : _prescriptions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.medication_outlined,
                                      size: 64,
                                      color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                                  Text('No prescriptions yet'.tr(),
                                      style: const TextStyle(
                                          fontSize: 15,
                                          color: Color(0xFF64748B))),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadPrescriptions,
                              child: ListView.builder(
                                padding: EdgeInsets.all(isDesktop ? 40 : 20),
                                itemCount: _filtered.length,
                                itemBuilder: (context, index) =>
                                    _buildPrescriptionCard(_filtered[index]),
                              ),
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildPrescriptionCard(dynamic record) {
    final medicines = (record['prescription']?['medicines'] as List?) ?? [];
    final labTests = (record['prescription']?['labTests'] as List?)
        ?? (record['labTests'] as List?) ?? [];

    // 30-day check: only allow ordering within 30 days of prescription
    bool isWithin30Days = false;
    try {
      final dateStr = record['prescribedAt']?.toString() ?? record['createdAt']?.toString() ?? '';
      final createdAt = DateTime.parse(dateStr).toLocal();
      final daysDiff = DateTime.now().difference(createdAt).inDays;
      isWithin30Days = daysDiff <= 30;
    } catch (_) {
      isWithin30Days = false;
    }

    final recordId = (record['_id'] ?? record['id'] ?? '').toString();
    List<dynamic> linkedBookings = _labBookingsByPrescription[recordId] ?? [];
    List<dynamic> linkedOrders = _ordersByPrescription[recordId] ?? [];

    // Date-based fallback: old bookings/orders have no prescriptionId in backend
    if (linkedBookings.isEmpty && linkedOrders.isEmpty) {
      final prescriptionDate = _parseDateFromRecord(record);
      if (prescriptionDate != null) {
        final idx = _prescriptions.indexWhere((r) =>
            (r is Map ? (r['_id'] ?? r['id'] ?? '') : '').toString() == recordId);
        // Prescriptions sorted newest-first: idx-1 is more recent, so its date is the upper cutoff
        DateTime cutoff;
        if (idx > 0) {
          cutoff = _parseDateFromRecord(_prescriptions[idx - 1]) ??
              DateTime.now().add(const Duration(days: 1));
        } else {
          cutoff = DateTime.now().add(const Duration(days: 1));
        }
        linkedBookings = _allLabBookings.where((b) {
          final d = _parseDateFromData(b);
          return d != null && !d.isBefore(prescriptionDate) && d.isBefore(cutoff);
        }).toList();
        linkedOrders = _allPharmacyOrders.where((o) {
          final d = _parseDateFromData(o);
          return d != null && !d.isBefore(prescriptionDate) && d.isBefore(cutoff);
        }).toList();
      }
    }

    return _PrescriptionPage(
      record: record,
      medicines: medicines,
      labTests: labTests,
      isWithin30Days: isWithin30Days,
      linkedLabBookings: linkedBookings,
      linkedPharmacyOrders: linkedOrders,
      onFindPharmacies: isWithin30Days ? () => _showFindPharmacies(context, medicines, prescriptionId: recordId) : null,
      onFindLabs: isWithin30Days ? () => _showFindLabs(context, labTests, prescriptionId: recordId) : null,
    );
  }

  // â”€â”€ CLICKABLE TILE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _clickableTile({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String title,
    required String subtitle,
    required Color arrowColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: arrowColor, size: 16),
          ],
        ),
      ),
    );
  }

  // â”€â”€ MEDICINES DETAIL SHEET â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showMedicinesDetail(BuildContext context, List<dynamic> medicines) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.medication_rounded,
                          color: Color(0xFF3B82F6), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Prescribed Medicines'.tr(),
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A))),
                          Text('Tap "Find Pharmacies" to order'.tr(),
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              // Medicines list
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: medicines.length,
                  itemBuilder: (_, i) => _buildMedicineItem(medicines[i]),
                ),
              ),
              // Find Pharmacies button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showFindPharmacies(context, medicines);
                    },
                    icon: const Icon(Icons.local_pharmacy_rounded),
                    label: Text('Find Pharmacies'.tr(),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
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

  // â”€â”€ LAB TESTS DETAIL SHEET â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showLabTestsDetail(BuildContext context, List<dynamic> labTests) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.biotech_rounded,
                          color: Color(0xFF8B5CF6), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ordered Lab Tests'.tr(),
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A))),
                          Text('Tap "Find Labs" to book'.tr(),
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: labTests.length,
                  itemBuilder: (_, i) => _buildLabTestItem(labTests[i]),
                ),
              ),
              // Find Labs button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showFindLabs(context, labTests);
                    },
                    icon: const Icon(Icons.science_rounded),
                    label: Text('Find Labs'.tr(),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
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

  Widget _sectionHeader(
      IconData icon, Color color, String title, String? subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A))),
            if (subtitle != null)
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildMedicineItem(dynamic medicine) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medication_rounded,
                  color: Color(0xFF3B82F6), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  medicine['name'] ?? 'Medicine',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if ((medicine['dosage'] ?? '').toString().isNotEmpty)
                  _pill('Dosage', medicine['dosage']),
                if ((medicine['frequency'] ?? '').toString().isNotEmpty)
                  _pill('Frequency', medicine['frequency']),
                if ((medicine['duration'] ?? '').toString().isNotEmpty)
                  _pill('Duration', medicine['duration']),
              ],
            ),
          ),
          if ((medicine['instructions'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                'ðŸ“ ${medicine['instructions']}',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLabTestItem(dynamic test) {
    // Handle both String (legacy) and Map format
    final testName = test is Map
        ? (test['name'] ?? test['testName'] ?? 'Lab Test').toString()
        : test.toString();
    final urgency = test is Map
        ? (test['urgency'] ?? 'Routine').toString().toLowerCase()
        : 'routine';
    final testNotes = test is Map ? (test['notes'] ?? '').toString() : '';
    // Only show badge for STAT / Urgent — not Routine
    final Color? urgencyColor = urgency == 'stat'
        ? const Color(0xFFEF4444)
        : urgency == 'urgent'
            ? const Color(0xFFF59E0B)
            : null;
    final String? urgencyLabel = urgency == 'stat'
        ? 'STAT'
        : urgency == 'urgent'
            ? 'Urgent'
            : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.biotech_rounded,
              color: Color(0xFF8B5CF6), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  testName,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A)),
                ),
                if (testNotes.isNotEmpty)
                  Text(testNotes,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
          if (urgencyLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: urgencyColor!.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: urgencyColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                urgencyLabel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: urgencyColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(String label, dynamic value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600)),
        Text(value?.toString() ?? '',
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  DateTime? _parseDateFromRecord(dynamic record) {
    final s = (record is Map
            ? (record['prescribedAt'] ?? record['createdAt'])
            : null)
        ?.toString() ??
        '';
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDateFromData(dynamic data) {
    // createdAt first (booking/order creation time), then appointment/scheduled date as fallback
    final s = (data is Map
            ? (data['createdAt'] ?? data['bookingDate'] ?? data['orderDate'] ??
               data['appointmentDate'] ?? data['date'])
            : null)
        ?.toString() ??
        '';
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  // â”€â”€ FIND LABS BOTTOM SHEET â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showFindLabs(BuildContext context, List<dynamic> tests, {String? prescriptionId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FindLabsSheet(tests: tests, prescriptionId: prescriptionId),
    );
  }

  // â”€â”€ FIND PHARMACIES BOTTOM SHEET â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showFindPharmacies(BuildContext context, List<dynamic> medicines, {String? prescriptionId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FindPharmaciesSheet(medicines: medicines, prescriptionId: prescriptionId),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// FIND LABS SHEET
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

// ─────────────────────────────────────────────────────────────────────────────
// INLINE PRESCRIPTION PAGE
// Full prescription visible directly in the list — no click needed
// ─────────────────────────────────────────────────────────────────────────────
class _PrescriptionPage extends StatelessWidget {
  final dynamic record;
  final List<dynamic> medicines;
  final List<dynamic> labTests;
  final VoidCallback? onFindPharmacies;
  final VoidCallback? onFindLabs;
  final bool isWithin30Days;
  final List<dynamic> linkedLabBookings;
  final List<dynamic> linkedPharmacyOrders;

  const _PrescriptionPage({
    required this.record,
    required this.medicines,
    required this.labTests,
    required this.isWithin30Days,
    this.onFindPharmacies,
    this.onFindLabs,
    this.linkedLabBookings = const [],
    this.linkedPharmacyOrders = const [],
  });

  String get _patientName {
    final p = record['patient'] ?? record['patientId'] ?? {};
    if (p is Map) return p['name']?.toString() ?? p['username']?.toString() ?? 'Patient';
    return 'Patient';
  }
  String get _patientAge {
    final p = record['patient'] ?? record['patientId'] ?? {};
    if (p is Map && p['age'] != null) return '${p['age']} yrs';
    return '';
  }
  String get _patientGender {
    final p = record['patient'] ?? record['patientId'] ?? {};
    if (p is Map) { final g = p['gender']?.toString() ?? ''; return g.isEmpty ? '' : '${g[0].toUpperCase()}${g.substring(1)}'; }
    return '';
  }
  String get _mrNumber {
    final p = record['patient'] ?? record['patientId'] ?? {};
    if (p is Map) {
      final mr = p['mrNumber'] ?? p['MRNumber'];
      if (mr != null) return mr.toString();
      final id = p['_id']?.toString() ?? '';
      if (id.length >= 6) return 'MR-${id.substring(id.length - 6).toUpperCase()}';
    }
    final rawId = (record['_id'] ?? record['id'] ?? '').toString();
    return rawId.length >= 6 ? 'MR-${rawId.substring(rawId.length - 6).toUpperCase()}' : '';
  }
  String get _doctorName {
    final d = record['doctor'] ?? record['doctorId'] ?? {};
    if (d is Map) return d['name']?.toString() ?? d['username']?.toString() ?? 'Doctor';
    return 'Doctor';
  }
  String get _doctorPmdc {
    final d = record['doctor'] ?? record['doctorId'] ?? {};
    if (d is Map) return d['pmdcLicense']?.toString() ?? d['pmdc']?.toString() ?? '';
    return '';
  }
  String get _doctorPhone {
    final d = record['doctor'] ?? record['doctorId'] ?? {};
    if (d is Map) return d['phone']?.toString() ?? d['phoneNumber']?.toString() ?? '';
    return '';
  }
  String get _diagnosis => record['diagnosis']?.toString() ?? 'General Prescription';
  List<dynamic> get _diagnoses => (record['diagnoses'] as List?) ?? (record['diagnosis'] is List ? record['diagnosis'] as List : []);
  String get _doctorNotes => record['doctorNotes']?.toString() ?? record['notes']?.toString() ?? '';
  String get _prescriptionDate {
    final s = record['prescribedAt']?.toString() ?? record['createdAt']?.toString() ?? '';
    if (s.isNotEmpty) {
      try { return DateFormat('MMMM dd, yyyy').format(DateTime.parse(s).toLocal()); } catch (_) {}
    }
    return DateFormat('MMMM dd, yyyy').format(DateTime.now());
  }
  String get _prescriptionTime {
    final s = record['prescribedAt']?.toString() ?? record['createdAt']?.toString() ?? '';
    if (s.isNotEmpty) {
      try { return DateFormat('hh:mm a').format(DateTime.parse(s).toLocal()); } catch (_) {}
    }
    return '';
  }
  String _followUpLabel() {
    final days = record['followUpDays'];
    final months = record['followUpMonths'];
    final dateStr = record['followUpDate']?.toString() ?? '';
    if (dateStr.isNotEmpty) { try { return 'Follow up: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(dateStr))}'; } catch (_) {} }
    if (days != null && days != 0) return 'Follow up in $days days';
    if (months != null && months != 0) return 'Follow up in $months months';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final followUp = _followUpLabel();
    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0036BC), Color(0xFF1E40AF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Image.asset('assets/Asset 1.png', height: 28, fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(Icons.local_hospital_rounded, color: Color(0xFF0036BC), size: 24)),
                ),
                const SizedBox(width: 10),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('iCare Telemedicine Platform', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  Text('RM Health Solutions (Private) Limited', style: TextStyle(color: Colors.white70, fontSize: 10)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_prescriptionDate, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  if (_prescriptionTime.isNotEmpty) Text(_prescriptionTime, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ]),
              ]),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _hdrInfo('PATIENT', _patientName, [
                  if (_patientAge.isNotEmpty || _patientGender.isNotEmpty) '$_patientAge${_patientAge.isNotEmpty && _patientGender.isNotEmpty ? "  •  " : ""}$_patientGender',
                  _mrNumber,
                ])),
                Container(width: 1, height: 55, color: Colors.white.withValues(alpha: 0.25), margin: const EdgeInsets.symmetric(horizontal: 12)),
                Expanded(child: _hdrInfo('DOCTOR', 'Dr. $_doctorName', [
                  if (_doctorPmdc.isNotEmpty) 'PMDC: $_doctorPmdc',
                  if (_doctorPhone.isNotEmpty) _doctorPhone,
                ])),
              ]),
            ]),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sec('DIAGNOSIS', Icons.local_hospital_rounded, const Color(0xFFEF4444)),
              const SizedBox(height: 8),
              if (_diagnoses.isNotEmpty)
                Wrap(spacing: 8, runSpacing: 6, children: _diagnoses.map((d) {
                  final text = d is Map ? (d['description'] ?? d['diagnosis'] ?? d['name'] ?? d.toString()) : d.toString();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFCA5A5))),
                    child: Text(text.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  );
                }).toList())
              else
                Text(_diagnosis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),

              if (medicines.isNotEmpty) ...[
                const SizedBox(height: 16), _div(), const SizedBox(height: 14),
                _sec('Rx  MEDICATIONS', Icons.medication_rounded, const Color(0xFF0036BC)),
                const SizedBox(height: 10),
                ...medicines.asMap().entries.map((e) => _medRow(e.key, e.value)),
              ],

              if (labTests.isNotEmpty) ...[
                const SizedBox(height: 16), _div(), const SizedBox(height: 14),
                _sec('LAB TESTS', Icons.biotech_rounded, const Color(0xFF8B5CF6)),
                const SizedBox(height: 10),
                ...labTests.map((t) {
                  final name = t is Map ? (t['name'] ?? t['testName'] ?? 'Lab Test').toString() : t.toString();
                  final urgency = t is Map ? (t['urgency'] ?? '').toString().toLowerCase() : '';
                  final Color? uc = urgency == 'stat' ? const Color(0xFFEF4444) : urgency == 'urgent' ? const Color(0xFFF59E0B) : null;
                  final String? ul = urgency == 'stat' ? 'STAT' : urgency == 'urgent' ? 'Urgent' : null;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFDDD6FE))),
                    child: Row(children: [
                      const Icon(Icons.biotech_rounded, color: Color(0xFF8B5CF6), size: 15),
                      const SizedBox(width: 8),
                      Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                      if (ul != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: uc!.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: uc.withValues(alpha: 0.4))),
                          child: Text(ul, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: uc)),
                        ),
                    ]),
                  );
                }),
              ],

              if (_doctorNotes.isNotEmpty) ...[
                const SizedBox(height: 16), _div(), const SizedBox(height: 14),
                _sec("DOCTOR'S NOTES", Icons.notes_rounded, const Color(0xFF10B981)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFA7F3D0))),
                  child: Text(_doctorNotes, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5)),
                ),
              ],

              if (followUp.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBAE6FD))),
                  child: Row(children: [
                    const Icon(Icons.event_repeat_rounded, color: Color(0xFF0EA5E9), size: 15),
                    const SizedBox(width: 8),
                    Text(followUp, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  ]),
                ),
              ],

              // Journey Status
              if (linkedLabBookings.isNotEmpty || linkedPharmacyOrders.isNotEmpty)
                _buildJourneySection(context),

              // Signature
              const SizedBox(height: 18), _div(), const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0036BC), width: 1.5), color: const Color(0xFFEFF6FF)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Image.asset('assets/Asset 1.png', height: 24, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.local_hospital_rounded, color: Color(0xFF0036BC), size: 20)),
                    const Text('iCare', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Color(0xFF0036BC))),
                  ]),
                ),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Text('Dr. $_doctorName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0036BC), fontStyle: FontStyle.italic)),
                  Container(width: 150, height: 1, color: const Color(0xFF374151)),
                  const SizedBox(height: 4),
                  Text('Dr. $_doctorName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  if (_doctorPmdc.isNotEmpty) Text('PMDC: $_doctorPmdc', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  const Text('Authorized Signature', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                ]),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: const Row(children: [
                  Icon(Icons.verified_rounded, size: 12, color: Color(0xFF0EA5E9)),
                  SizedBox(width: 6),
                  Expanded(child: Text('Electronically generated & authenticated via iCare — RM Health Solutions (Private) Limited.', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.4))),
                ]),
              ),
            ]),
          ),

          // Bottom actions
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(children: [
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _printPrescription(context),
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: Text('Print / Download'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0036BC), side: const BorderSide(color: Color(0xFF0036BC)), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                )),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _shareText(context),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: Text('Share'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF10B981), side: const BorderSide(color: Color(0xFF10B981)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ]),
              if (medicines.isNotEmpty || labTests.isNotEmpty) ...[
                const SizedBox(height: 8),
                // 30-day validity indicator
                if (!isWithin30Days)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_clock_rounded, color: Color(0xFFF59E0B), size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Prescription expired (30+ days) — View only. Cannot order.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(children: [
                  if (medicines.isNotEmpty) Expanded(child: ElevatedButton.icon(
                    onPressed: isWithin30Days ? onFindPharmacies : null,
                    icon: const Icon(Icons.local_pharmacy_rounded, size: 15),
                    label: Text('Order Medicines'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0036BC),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  )),
                  if (medicines.isNotEmpty && labTests.isNotEmpty) const SizedBox(width: 8),
                  if (labTests.isNotEmpty) Expanded(child: ElevatedButton.icon(
                    onPressed: isWithin30Days ? onFindLabs : null,
                    icon: const Icon(Icons.science_rounded, size: 15),
                    label: Text('Order Lab Tests'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  )),
                ]),
              ],
            ]),
          ),
        ],
      ),
    );
  }


  Future<void> _printPrescription(BuildContext context) async {
    try {
      // Load iCare logo for PDF
      pw.ImageProvider? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/Asset 1.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {}

      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Row(children: [
              if (logoImage != null) ...[
                pw.Container(
                  width: 60, height: 60,
                  decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 10),
              ] else ...[
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('iCare', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.Text('RM Health Solutions (Private) Limited', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                ]),
                pw.SizedBox(width: 10),
              ],
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(_prescriptionDate, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              if (_prescriptionTime.isNotEmpty) pw.Text(_prescriptionTime, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ]),
          ]),
          pw.Divider(color: PdfColors.blue800, thickness: 2),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('PATIENT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey)),
              pw.Text(_patientName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              if (_patientAge.isNotEmpty) pw.Text('$_patientAge  •  $_patientGender', style: const pw.TextStyle(fontSize: 10)),
              if (_mrNumber.isNotEmpty) pw.Text(_mrNumber, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ])),
            pw.SizedBox(width: 20),
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('DOCTOR', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey)),
              pw.Text('Dr. $_doctorName', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              if (_doctorPmdc.isNotEmpty) pw.Text('PMDC: $_doctorPmdc', style: const pw.TextStyle(fontSize: 10)),
              if (_doctorPhone.isNotEmpty) pw.Text(_doctorPhone, style: const pw.TextStyle(fontSize: 10)),
            ])),
          ]),
          pw.SizedBox(height: 12),
          if (_diagnoses.isNotEmpty || _diagnosis.isNotEmpty) ...[
            pw.Text('DIAGNOSIS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 4),
            pw.Text(_diagnoses.isNotEmpty
                ? _diagnoses.map((d) => d is Map ? (d['description'] ?? d['diagnosis'] ?? d['name'] ?? d.toString()) : d.toString()).join(', ')
                : _diagnosis,
                style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 10),
          ],
          if (medicines.isNotEmpty) ...[
            pw.Text('Rx  MEDICATIONS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 4),
            ...medicines.asMap().entries.map((e) {
              final m = e.value;
              final name = m is Map ? (m['name']?.toString() ?? 'Medicine') : m.toString();
              final dose = m is Map ? (m['dosage']?.toString() ?? m['dose']?.toString() ?? '') : '';
              final freq = m is Map ? (m['frequency']?.toString() ?? '') : '';
              final dur = m is Map ? (m['duration']?.toString() ?? '') : '';
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('${e.key + 1}. $name', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    if (dose.isNotEmpty || freq.isNotEmpty || dur.isNotEmpty)
                      pw.Text('${dose.isNotEmpty ? "Dose: $dose  " : ""}${freq.isNotEmpty ? "Freq: $freq  " : ""}${dur.isNotEmpty ? "Duration: $dur" : ""}',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ]),
                ),
              );
            }),
            pw.SizedBox(height: 8),
          ],
          if (labTests.isNotEmpty) ...[
            pw.Text('LAB TESTS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 4),
            ...labTests.map((t) => pw.Bullet(
                text: (t is Map ? (t['name'] ?? t['testName'] ?? 'Test') : t).toString(),
                style: const pw.TextStyle(fontSize: 11))),
            pw.SizedBox(height: 8),
          ],
          if (_doctorNotes.isNotEmpty) ...[
            pw.Text("DOCTOR'S NOTES", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 4),
            pw.Text(_doctorNotes, style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 8),
          ],
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Container(width: 150, height: 1, color: PdfColors.black),
              pw.SizedBox(height: 4),
              pw.Text('Dr. $_doctorName', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              if (_doctorPmdc.isNotEmpty) pw.Text('PMDC: $_doctorPmdc', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
              pw.Text('Authorized Signature', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
            ]),
          ]),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text('Electronically generated & authenticated via iCare — RM Health Solutions (Private) Limited.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ),
        ],
      ));
      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'iCare_Rx_${_patientName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print failed: $e')));
      }
    }
  }

  void _shareText(BuildContext context) {
    final buf = StringBuffer();
    buf.writeln('=== iCare PRESCRIPTION ===');
    buf.writeln('Date: $_prescriptionDate');
    buf.writeln('Patient: $_patientName');
    if (_patientAge.isNotEmpty) buf.writeln('Age: $_patientAge  Gender: $_patientGender');
    if (_mrNumber.isNotEmpty) buf.writeln('MR#: $_mrNumber');
    buf.writeln('\nDoctor: Dr. $_doctorName');
    if (_doctorPmdc.isNotEmpty) buf.writeln('PMDC: $_doctorPmdc');
    buf.writeln('\nDIAGNOSIS: $_diagnosis');
    if (medicines.isNotEmpty) {
      buf.writeln('\nMEDICINES:');
      for (int i = 0; i < medicines.length; i++) {
        final m = medicines[i];
        final name = m is Map ? (m['name']?.toString() ?? 'Medicine') : m.toString();
        final dose = m is Map ? (m['dosage']?.toString() ?? m['dose']?.toString() ?? '') : '';
        final freq = m is Map ? (m['frequency']?.toString() ?? '') : '';
        final dur = m is Map ? (m['duration']?.toString() ?? '') : '';
        buf.writeln('${i+1}. $name${dose.isNotEmpty ? " | $dose" : ""}${freq.isNotEmpty ? " | $freq" : ""}${dur.isNotEmpty ? " | $dur" : ""}');
      }
    }
    if (labTests.isNotEmpty) {
      buf.writeln('\nLAB TESTS:');
      for (final t in labTests) { buf.writeln('• ${t is Map ? (t['name'] ?? t['testName'] ?? t.toString()) : t}'); }
    }
    if (_doctorNotes.isNotEmpty) buf.writeln('\nNOTES: $_doctorNotes');
    buf.writeln('\n--- Electronically generated via iCare ---');
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prescription copied! Paste in WhatsApp or any app to share.')),
    );
  }
  Widget _buildJourneySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _div(),
        const SizedBox(height: 14),
        _sec('TREATMENT STATUS', Icons.timeline_rounded, const Color(0xFF0EA5E9)),
        const SizedBox(height: 10),
        ...linkedLabBookings.take(3).map((b) => _bookingStatusTile(context, b)),
        ...linkedPharmacyOrders.take(3).map((o) => _orderStatusTile(context, o)),
      ],
    );
  }

  Widget _bookingStatusTile(BuildContext context, dynamic booking) {
    // lab booking uses 'laboratory' field (not 'laboratoryId') from API response
    final rawLab = booking['laboratory'] ?? booking['laboratoryId'];
    final labName = (rawLab is Map
        ? (rawLab['labName'] ?? rawLab['lab_name'] ?? rawLab['name'] ?? 'Lab')
        : (booking['labName'] ?? booking['lab_name'] ?? 'Laboratory')).toString();
    final status = (booking['status'] ?? 'pending').toString().toLowerCase();
    final statusLabel = _labStatusLabel(status);
    final statusColor = _labStatusColor(status);
    // lab bookings are one-per-test; testName is a single string
    final testName = booking['testName']?.toString() ?? '';
    final testCount = (booking['tests'] as List?)?.length ?? (booking['testNames'] as List?)?.length ?? 0;
    final testSubtitle = testName.isNotEmpty ? testName : (testCount > 0 ? '$testCount test${testCount == 1 ? "" : "s"} booked' : 'Lab Booking');

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientLabOrdersScreen())),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDDD6FE)),
        ),
        child: Row(
          children: [
            const Icon(Icons.biotech_rounded, color: Color(0xFF8B5CF6), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(labName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  Text(testSubtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
                ),
                const SizedBox(height: 2),
                Text('View →', style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderStatusTile(BuildContext context, dynamic order) {
    // pharmacy orders use 'pharmacyId' (may be populated object) or top-level fields
    final rawPharmacy = order['pharmacyId'] ?? order['pharmacy'];
    final pharmacyName = (rawPharmacy is Map
        ? (rawPharmacy['pharmacy_name'] ?? rawPharmacy['pharmacyName'] ?? rawPharmacy['name'] ?? 'Pharmacy')
        : (order['pharmacyName'] ?? 'Pharmacy')).toString();
    final status = (order['status'] ?? 'pending').toString().toLowerCase();
    final statusLabel = _orderStatusLabel(status);
    final statusColor = _orderStatusColor(status);
    final itemCount = (order['items'] as List?)?.length ?? (order['medicines'] as List?)?.length ?? 0;

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyOrdersScreen())),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_pharmacy_rounded, color: Color(0xFF3B82F6), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pharmacyName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  Text(itemCount > 0 ? '$itemCount item${itemCount == 1 ? "" : "s"} ordered' : 'Pharmacy Order',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
                ),
                const SizedBox(height: 2),
                Text('Track →', style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _labStatusLabel(String s) {
    switch (s) {
      case 'pending': return 'Pending';
      case 'confirmed': return 'Confirmed';
      case 'sample_collected': return 'Sample Collected';
      case 'processing': return 'Processing';
      case 'completed': return 'Completed ✓';
      case 'cancelled': return 'Cancelled';
      default: return s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : 'Pending';
    }
  }

  Color _labStatusColor(String s) {
    switch (s) {
      case 'completed': return const Color(0xFF10B981);
      case 'cancelled': return const Color(0xFFEF4444);
      case 'confirmed': case 'sample_collected': case 'processing': return const Color(0xFF3B82F6);
      default: return const Color(0xFFF59E0B);
    }
  }

  String _orderStatusLabel(String s) {
    switch (s) {
      case 'pending': return 'Pending';
      case 'confirmed': return 'Confirmed';
      case 'preparing': return 'Preparing';
      case 'out-for-delivery': case 'out_for_delivery': return 'Out for Delivery';
      case 'delivered': case 'completed': return 'Delivered ✓';
      case 'cancelled': case 'rejected': return 'Cancelled';
      default: return s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : 'Pending';
    }
  }

  Color _orderStatusColor(String s) {
    switch (s) {
      case 'delivered': case 'completed': return const Color(0xFF10B981);
      case 'cancelled': case 'rejected': return const Color(0xFFEF4444);
      case 'out-for-delivery': case 'out_for_delivery': return const Color(0xFF8B5CF6);
      case 'confirmed': case 'preparing': return const Color(0xFF3B82F6);
      default: return const Color(0xFFF59E0B);
    }
  }

  Widget _hdrInfo(String label, String name, List<String> details) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
      const SizedBox(height: 3),
      Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
      ...details.where((d) => d.isNotEmpty).map((d) => Padding(padding: const EdgeInsets.only(top: 2), child: Text(d, style: const TextStyle(color: Colors.white70, fontSize: 10)))),
    ]);
  }
  Widget _sec(String title, IconData icon, Color color) => Row(children: [
    Icon(icon, size: 13, color: color), const SizedBox(width: 5),
    Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.1)),
  ]);
  Widget _div() => Container(height: 1, color: const Color(0xFFF1F5F9));
  Widget _medRow(int i, dynamic m) {
    final name = m is Map ? (m['name']?.toString() ?? m['medicine']?.toString() ?? 'Medicine') : m.toString();
    final dose = m is Map ? (m['dosage']?.toString() ?? m['dose']?.toString() ?? '') : '';
    final freq = m is Map ? (m['frequency']?.toString() ?? '') : '';
    final dur = m is Map ? (m['duration']?.toString() ?? '') : '';
    final note = m is Map ? (m['instructions']?.toString() ?? m['note']?.toString() ?? '') : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBFDBFE))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 22, height: 22, decoration: BoxDecoration(color: const Color(0xFF0036BC), borderRadius: BorderRadius.circular(5)),
              child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)))),
          const SizedBox(width: 9),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)))),
        ]),
        if (dose.isNotEmpty || freq.isNotEmpty || dur.isNotEmpty) Padding(
          padding: const EdgeInsets.only(left: 31, top: 5),
          child: Wrap(spacing: 10, runSpacing: 4, children: [
            if (dose.isNotEmpty) _pill('Dose', dose),
            if (freq.isNotEmpty) _pill('Freq', freq),
            if (dur.isNotEmpty) _pill('Duration', dur),
          ]),
        ),
        if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 31, top: 4),
            child: Text(note, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic))),
      ]),
    );
  }
  Widget _pill(String label, String value) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text('$label: ', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFBFDBFE))),
        child: Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0036BC)))),
  ]);
}
class _FindLabsSheet extends StatefulWidget {
  final List<dynamic> tests;
  final String? prescriptionId;
  const _FindLabsSheet({required this.tests, this.prescriptionId});

  @override
  State<_FindLabsSheet> createState() => _FindLabsSheetState();
}

class _FindLabsSheetState extends State<_FindLabsSheet> {
  final LaboratoryService _labService = LaboratoryService();
  List<dynamic> _labs = [];
  List<dynamic> _filteredLabs = [];
  bool _isLoading = true;
  String? _error;
  double? _userLat;
  double? _userLng;

  // 'nearest' or 'search'
  String _mode = 'nearest';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLabs();
    _getUserLocation();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      final completer = Completer<List<double>?>();
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
      final pos = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
      if (pos != null && mounted) {
        setState(() {
          _userLat = pos[0];
          _userLng = pos[1];
          _sortByDistance();
        });
        _fetchLabs();
      }
    } catch (_) {
      // Location unavailable
    }
  }

  double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  void _sortByDistance() {
    if (_userLat == null || _userLng == null) return;
    _labs.sort((a, b) {
      final aLat = ((a['latitude'] ?? a['lat']) as num?)?.toDouble();
      final aLng = ((a['longitude'] ?? a['lng']) as num?)?.toDouble();
      final bLat = ((b['latitude'] ?? b['lat']) as num?)?.toDouble();
      final bLng = ((b['longitude'] ?? b['lng']) as num?)?.toDouble();
      if (aLat == null || aLng == null) return 1;
      if (bLat == null || bLng == null) return -1;
      return _haversineDistance(_userLat!, _userLng!, aLat, aLng)
          .compareTo(_haversineDistance(_userLat!, _userLng!, bLat, bLng));
    });
    _filteredLabs = List.from(_labs);
  }

  void _filterByLocation(String query) {
    if (query.isEmpty) {
      setState(() => _filteredLabs = List.from(_labs));
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _filteredLabs = _labs.where((l) {
        final name = (l['lab_name'] ?? l['labName'] ?? l['name'] ?? '').toString().toLowerCase();
        final address = (l['address'] ?? '').toString().toLowerCase();
        final city = (l['city'] ?? '').toString().toLowerCase();
        return name.contains(q) || address.contains(q) || city.contains(q);
      }).toList();
    });
  }

  String? _getDistance(dynamic lab) {
    if (_userLat == null || _userLng == null) return null;
    final lat = ((lab['latitude'] ?? lab['lat']) as num?)?.toDouble();
    final lng = ((lab['longitude'] ?? lab['lng']) as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    final dist = _haversineDistance(_userLat!, _userLng!, lat, lng);
    if (dist < 1) return '${(dist * 1000).toStringAsFixed(0)} m';
    return '${dist.toStringAsFixed(1)} km';
  }

  Future<void> _fetchLabs() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final labs = await _labService.getAllLaboratories();
      if (mounted) {
        setState(() {
          _labs = labs;
          _filteredLabs = List.from(labs);
          _isLoading = false;
          if (_userLat != null) _sortByDistance();
        });
      }
    } catch (e) {
      debugPrint('âŒ Find Labs error: $e');
      if (mounted) setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.science_rounded,
                            color: Color(0xFF8B5CF6), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Find Labs',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A))),
                            Text('Select a lab to book your tests',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // â”€â”€ Mode toggle: Nearest | Search by Location â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Row(
                    children: [
                      _modeBtn('nearest', Icons.near_me_rounded, 'Nearest', const Color(0xFF8B5CF6)),
                      const SizedBox(width: 10),
                      _modeBtn('search', Icons.location_searching_rounded, 'Search by Location', const Color(0xFF8B5CF6)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Nearest banner
                  if (_mode == 'nearest')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _userLat != null ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _userLat != null
                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _userLat != null ? Icons.my_location_rounded : Icons.location_searching_rounded,
                            size: 16,
                            color: _userLat != null ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _userLat != null
                                  ? 'Sorted by nearest to your location'
                                  : 'Allow location to see nearest labs first',
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: _userLat != null ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Search field
                  if (_mode == 'search')
                    TextField(
                      controller: _searchCtrl,
                      onChanged: _filterByLocation,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Enter area, city or address...',
                        prefixIcon: const Icon(Icons.location_on_rounded, color: Color(0xFF8B5CF6), size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),

                  const SizedBox(height: 16),
                  // Ordered tests chips
                  const Text('Ordered Tests:',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: widget.tests.map((t) {
                      final n = t is Map
                          ? (t['name'] ?? t['testName'] ?? '').toString()
                          : t.toString();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: Text(n,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7C3AED),
                                fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                ],
              ),
            ),
            // Labs list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 40),
                              const SizedBox(height: 12),
                              const Text('Could not load labs', style: TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _fetchLabs,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _filteredLabs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.science_outlined, size: 48, color: Colors.grey[300]),
                                  const SizedBox(height: 12),
                                  Text(
                                    _mode == 'search' ? 'No labs found in this area' : 'No labs found',
                                    style: const TextStyle(color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                              itemCount: _filteredLabs.length,
                              itemBuilder: (ctx, i) => _labTile(_filteredLabs[i]),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeBtn(String mode, IconData icon, String label, Color color) {
    final isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _mode = mode;
            _searchCtrl.clear();
            if (mode == 'nearest') {
              _filteredLabs = List.from(_labs);
              if (_userLat != null) _sortByDistance();
            } else {
              _filteredLabs = List.from(_labs);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isSelected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _labTile(dynamic lab) {
    final name = lab['labName']?.toString() ??
        lab['lab_name']?.toString() ??
        lab['name']?.toString() ??
        'Laboratory';
    final address = lab['address']?.toString() ?? lab['location']?.toString() ?? '';
    final phone = lab['phone']?.toString() ?? lab['phoneNumber']?.toString() ?? '';
    final distance = _getDistance(lab);

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LabDetails(
              labData: lab,
              prescribedTests: widget.tests.map((t) {
                if (t is String) return t;
                if (t is Map) return (t['name'] ?? t['testName'] ?? t['test_name'] ?? '').toString();
                return t.toString();
              }).where((n) => n.isNotEmpty).toList(),
              prescriptionId: widget.prescriptionId,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.science_rounded,
                  color: Color(0xFF8B5CF6), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A))),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.location_on_rounded,
                          size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      Expanded(
                          child: Text(address,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                    ]),
                  ],
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.phone_rounded,
                          size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      Text(phone,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B))),
                    ]),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (distance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      distance,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: Color(0xFF94A3B8)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// FIND PHARMACIES SHEET
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _FindPharmaciesSheet extends StatefulWidget {
  final List<dynamic> medicines;
  final String? prescriptionId;
  const _FindPharmaciesSheet({required this.medicines, this.prescriptionId});

  @override
  State<_FindPharmaciesSheet> createState() => _FindPharmaciesSheetState();
}

class _FindPharmaciesSheetState extends State<_FindPharmaciesSheet> {
  final PharmacyService _pharmacyService = PharmacyService();
  final MedicalRecordService _medService = MedicalRecordService();
  List<dynamic> _pharmacies = [];
  List<dynamic> _filteredPharmacies = [];
  List<dynamic> _advisedPrescriptions = [];
  bool _isLoading = true;
  bool _showAdvised = false;
  double? _userLat;
  double? _userLng;

  // 'nearest' or 'search'
  String _mode = 'nearest';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPharmacies();
    _getUserLocation();
    _fetchAdvisedPrescriptions();
  }

  Future<void> _fetchAdvisedPrescriptions() async {
    try {
      final result = await _medService.getMyRecords();
      if (result['success'] == true && mounted) {
        final records = result['records'] as List<dynamic>;
        final withMeds = records.where((r) {
          final meds = (r['medicines'] as List?) ??
              (r['prescription'] is Map ? (r['prescription']['medicines'] as List?) : null) ?? [];
          return meds.isNotEmpty;
        }).toList();
        setState(() => _advisedPrescriptions = withMeds);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      final completer = Completer<List<double>?>();
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
      final pos = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
      if (pos != null && mounted) {
        setState(() {
          _userLat = pos[0];
          _userLng = pos[1];
          _sortByDistance();
        });
        _fetchPharmacies();
      }
    } catch (_) {}
  }

  double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  void _sortByDistance() {
    if (_userLat == null || _userLng == null) return;
    _pharmacies.sort((a, b) {
      final aLat = ((a['latitude'] ?? a['lat']) as num?)?.toDouble();
      final aLng = ((a['longitude'] ?? a['lng']) as num?)?.toDouble();
      final bLat = ((b['latitude'] ?? b['lat']) as num?)?.toDouble();
      final bLng = ((b['longitude'] ?? b['lng']) as num?)?.toDouble();
      if (aLat == null || aLng == null) return 1;
      if (bLat == null || bLng == null) return -1;
      return _haversineDistance(_userLat!, _userLng!, aLat, aLng)
          .compareTo(_haversineDistance(_userLat!, _userLng!, bLat, bLng));
    });
    _filteredPharmacies = List.from(_pharmacies);
  }

  void _filterByLocation(String query) {
    if (query.isEmpty) {
      setState(() => _filteredPharmacies = List.from(_pharmacies));
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _filteredPharmacies = _pharmacies.where((p) {
        final name = (p['pharmacy_name'] ?? p['pharmacyName'] ?? p['name'] ?? '').toString().toLowerCase();
        final address = (p['address'] ?? '').toString().toLowerCase();
        final city = (p['city'] ?? '').toString().toLowerCase();
        return name.contains(q) || address.contains(q) || city.contains(q);
      }).toList();
    });
  }

  String? _getDistance(dynamic pharmacy) {
    if (_userLat == null || _userLng == null) return null;
    final lat = ((pharmacy['latitude'] ?? pharmacy['lat']) as num?)?.toDouble();
    final lng = ((pharmacy['longitude'] ?? pharmacy['lng']) as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    final dist = _haversineDistance(_userLat!, _userLng!, lat, lng);
    if (dist < 1) return '${(dist * 1000).toStringAsFixed(0)} m';
    return '${dist.toStringAsFixed(1)} km';
  }

  Future<void> _fetchPharmacies() async {
    try {
      final pharmacies = await _pharmacyService.getAllPharmacies();
      if (mounted) {
        setState(() {
          _pharmacies = pharmacies;
          _filteredPharmacies = List.from(pharmacies);
          _isLoading = false;
          if (_userLat != null) _sortByDistance();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.local_pharmacy_rounded,
                            color: Color(0xFF3B82F6), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Find Pharmacies',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                            Text('Select a pharmacy for your medicines',
                                style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // â”€â”€ Mode toggle: Nearest | Search | Advised â”€â”€â”€â”€â”€â”€â”€â”€
                  Row(
                    children: [
                      _modeBtn('nearest', Icons.near_me_rounded, 'Nearest', const Color(0xFF3B82F6)),
                      const SizedBox(width: 10),
                      _modeBtn('search', Icons.location_searching_rounded, 'Search', const Color(0xFF3B82F6)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showAdvised = !_showAdvised),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _showAdvised ? const Color(0xFF10B981) : const Color(0xFF10B981).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.description_outlined, size: 14,
                                    color: _showAdvised ? Colors.white : const Color(0xFF10B981)),
                                const SizedBox(width: 6),
                                Text('Advised',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _showAdvised ? Colors.white : const Color(0xFF10B981))),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // â”€â”€ Nearest: location status banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  if (_mode == 'nearest')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _userLat != null ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _userLat != null
                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _userLat != null ? Icons.my_location_rounded : Icons.location_searching_rounded,
                            size: 16,
                            color: _userLat != null ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _userLat != null
                                  ? 'Sorted by nearest to your location'
                                  : 'Allow location to see nearest pharmacies first',
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: _userLat != null ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // â”€â”€ Search by Location: text field â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  if (_mode == 'search')
                    TextField(
                      controller: _searchCtrl,
                      onChanged: _filterByLocation,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Enter area, city or address...',
                        prefixIcon: const Icon(Icons.location_on_rounded, color: Color(0xFF3B82F6), size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),

                  const SizedBox(height: 12),
                  // Prescribed medicines chips
                  const Text('Prescribed Medicines:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: widget.medicines.map((m) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(m['name'] ?? '',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600)),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                ],
              ),
            ),
            Expanded(
              child: _showAdvised
                  ? _buildAdvisedMedicinesView(scrollCtrl)
                  : _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredPharmacies.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.local_pharmacy_outlined, size: 48, color: Colors.grey[300]),
                                  const SizedBox(height: 12),
                                  Text(
                                    _mode == 'search' ? 'No pharmacies found in this area' : 'No pharmacies found',
                                    style: const TextStyle(color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                              itemCount: _filteredPharmacies.length,
                              itemBuilder: (ctx, i) => _pharmacyTile(_filteredPharmacies[i]),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeBtn(String mode, IconData icon, String label, Color color) {
    final isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _mode = mode;
            _searchCtrl.clear();
            if (mode == 'nearest') {
              _filteredPharmacies = List.from(_pharmacies);
              if (_userLat != null) _sortByDistance();
            } else {
              _filteredPharmacies = List.from(_pharmacies);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isSelected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvisedMedicinesView(ScrollController scrollCtrl) {
    if (_advisedPrescriptions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.medication_outlined, size: 48, color: Color(0xFF94A3B8)),
              SizedBox(height: 12),
              Text('No advised medicines',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              SizedBox(height: 6),
              Text('Medicines your doctor has prescribed will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: _advisedPrescriptions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final rx = _advisedPrescriptions[i] as Map<String, dynamic>;
        final doctorName = (rx['doctor']?['name'] ?? rx['doctorName'] ?? 'Doctor').toString();
        final dateStr = rx['createdAt'] != null
            ? (() { try { return DateFormat('MMM dd, yyyy').format(DateTime.parse(rx['createdAt'].toString().replaceAll('/', '-')).toLocal()); } catch (_) { return ''; } })()
            : '';
        final meds = (rx['medicines'] as List?) ??
            (rx['prescription'] is Map ? (rx['prescription']['medicines'] as List?) : null) ?? [];
        final diagnoses = rx['diagnoses'] as List?;
        final diagnosis = (rx['diagnosis'] ?? (diagnoses != null && diagnoses.isNotEmpty ? diagnoses[0]['diagnosis'] : '') ?? '').toString();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
            boxShadow: [
              BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF3B82F6)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('$doctorName${dateStr.isNotEmpty ? " • $dateStr" : ""}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                  child: Text('${meds.length} med${meds.length == 1 ? "" : "s"}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                ),
              ]),
              if (diagnosis.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Diagnosis: $diagnosis',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 10),
              ...meds.map((m) {
                final name = m is Map ? (m['medicineName'] ?? m['name'] ?? '').toString() : m.toString();
                final dose = m is Map ? (m['dose'] ?? m['dosage'] ?? '').toString() : '';
                final formType = m is Map ? (m['formType'] ?? '').toString() : '';
                final freq = m is Map ? (m['frequency'] ?? '').toString().toUpperCase() : '';
                final dur = m is Map ? (m['duration'] ?? '').toString() : '';
                final parts = <String>[if (dose.isNotEmpty) dose, if (formType.isNotEmpty) formType, if (freq.isNotEmpty) freq, if (dur.isNotEmpty) dur];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const Icon(Icons.medication_rounded, size: 14, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                    Text(parts.join(' • '), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ]),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _pharmacyTile(dynamic pharmacy) {
    final name = pharmacy['pharmacyName']?.toString() ??
        pharmacy['pharmacy_name']?.toString() ??
        pharmacy['name']?.toString() ??
        'Pharmacy';
    final address = pharmacy['address']?.toString() ?? pharmacy['location']?.toString() ?? '';
    final phone = pharmacy['phone']?.toString() ?? pharmacy['phoneNumber']?.toString() ?? '';
    final distance = _getDistance(pharmacy);

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PharmacyPrescriptionScreen(
              pharmacy: Map<String, dynamic>.from(pharmacy is Map ? pharmacy : {}),
              prescribedMedicines: widget.medicines,
              medicalRecordId: widget.prescriptionId,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_pharmacy_rounded,
                  color: Color(0xFF3B82F6), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A))),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.location_on_rounded,
                          size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      Expanded(
                          child: Text(address,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                    ]),
                  ],
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.phone_rounded,
                          size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      Text(phone,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B))),
                    ]),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (distance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      distance,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: Color(0xFF94A3B8)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}






