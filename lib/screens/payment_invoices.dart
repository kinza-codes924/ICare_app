import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/utils/pdf_invoice_generator.dart';
import '../services/laboratory_service.dart';
import '../services/pharmacy_service.dart';
import 'package:intl/intl.dart';

class PaymentInvoices extends StatefulWidget {
  final bool isPharmacy;
  const PaymentInvoices({super.key, this.isPharmacy = false});

  @override
  State<PaymentInvoices> createState() => _PaymentInvoicesState();
}

class _PaymentInvoicesState extends State<PaymentInvoices>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LaboratoryService _labService = LaboratoryService();
  final PharmacyService _pharmacyService = PharmacyService();
  String _selectedFilter = "All";
  bool _isLoading = true;
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _labDoctors = [];
  String _labName = 'iCare Laboratory';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedFilter = "All";
            break;
          case 1:
            _selectedFilter = "Paid";
            break;
        }
      });
    });
    _fetchInvoices();
  }

  Future<void> _fetchInvoices() async {
    setState(() => _isLoading = true);
    try {
      if (widget.isPharmacy) {
        final orders = await _pharmacyService.getPharmacyOrders();
        setState(() {
          _invoices = orders.map((o) {
            final rawStatus = o['status']?.toString() ?? '';
            // Only show completed/paid orders
            final status = rawStatus == 'completed' ? 'Paid' : 'Paid';
            final dateStr = o['createdAt'] ?? o['date'] ?? '';
            DateTime? dateObj = DateTime.tryParse(dateStr);
            final formattedDate = dateObj != null
                ? DateFormat('dd MMM, yyyy').format(dateObj)
                : '—';
            final id = o['orderNumber'] ?? "INV-${(o['_id'] ?? '').toString().replaceAll(RegExp(r'.+(.{6})'), r'\1')}";
            final items = (o['items'] as List<dynamic>?)
                    ?.map((i) => i['name'] ?? i['medicineName'] ?? '')
                    .where((s) => s.isNotEmpty)
                    .join(', ') ??
                'Medicine Order';
            return {
              "id": id,
              "patient": o['patient']?['name'] ?? o['customerName'] ?? "Customer",
              "test": items.isEmpty ? 'Medicine Order' : items,
              "amount": (o['totalAmount'] ?? o['total'] ?? 0).toDouble(),
              "date": formattedDate,
              "status": status,
              "method": o['paymentMethod'] ?? "Cash",
            };
          }).where((inv) => inv['status'] == 'Paid').toList(); // Only show paid invoices
          _isLoading = false;
        });
      } else {
        final profile = await _labService.getProfile();
        final labId = profile['_id'] ?? profile['id'] ?? '';
        // Store lab doctors and name for PDF footer
        final doctorsList = (profile['doctors'] as List<dynamic>? ?? []);
        _labDoctors = doctorsList
            .map((d) => {
                  'name': d['name']?.toString() ?? '',
                  'education': d['education']?.toString() ?? '',
                  'designation': d['designation']?.toString() ?? '',
                })
            .where((d) => (d['name'] as String).isNotEmpty)
            .toList();
        _labName = profile['labName'] ?? profile['lab_name'] ?? profile['name'] ?? 'iCare Laboratory';
        final bookings = await _labService.getBookings(labId);
        setState(() {
          _invoices = bookings.map((b) {
            // Only show completed/paid orders
            final status = b['status'] == 'completed' ? 'Paid' : 'Paid';
            final dateStr = b['createdAt'] ?? b['test_date'] ?? b['date'] ?? '';
            DateTime? dateObj = DateTime.tryParse(dateStr);
            final formattedDate = dateObj != null
                ? DateFormat('dd MMM, yyyy').format(dateObj)
                : DateFormat('dd MMM, yyyy').format(DateTime.now());
            final id = b['bookingNumber'] ?? b['_id']?.toString() ?? 'N/A';
            final shortId = id.length > 6 ? 'LAB-${id.substring(id.length - 6).toUpperCase()}' : 'LAB-$id';
            // Patient name — try multiple field names
            final patientName = b['patient_name'] ??
                b['patientName'] ??
                b['patient']?['name'] ??
                b['patient']?['username'] ??
                'Patient';
            // Test name
            final testName = b['test_type'] ?? b['testName'] ?? b['test'] ?? 'Laboratory Test';
            // Default prices by test type
            final defaultPrices = {
              'cbc': 800, 'complete blood count': 800,
              'lipid profile': 1500, 'lft': 1200, 'liver function': 1200,
              'kft': 1200, 'kidney function': 1200,
              'thyroid': 1800, 'hba1c': 1500, 'diabetes': 1500,
              'vitamin d': 2000, 'covid': 3500, 'pcr': 3500,
              'urine': 500, 'blood sugar': 400,
            };
            final testLower = testName.toLowerCase();
            double price = (b['price'] ?? b['amount'] ?? b['totalAmount'] ?? 0).toDouble();
            if (price == 0) {
              for (final key in defaultPrices.keys) {
                if (testLower.contains(key)) { price = defaultPrices[key]!.toDouble(); break; }
              }
              if (price == 0) price = 1000;
            }
            return {
              "id": shortId,
              "patient": patientName,
              "test": testName,
              "amount": price,
              "date": formattedDate,
              "status": status,
              "method": b['paymentMethod'] ?? "Cash",
            };
          }).where((inv) => inv['status'] == 'Paid').toList(); // Only show paid invoices
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching invoices: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredInvoices {
    if (_selectedFilter == "All") return _invoices;
    return _invoices.where((i) => i["status"] == _selectedFilter).toList();
  }

  double get _totalRevenue => _invoices
      .where((i) => i["status"] == "Paid")
      .fold(0.0, (sum, i) => sum + (i["amount"] as double));

  Future<void> _downloadInvoice(Map<String, dynamic> invoice) async {
    try {
      // Parse date safely
      DateTime invoiceDate;
      final rawDate = invoice['date'];
      if (rawDate is DateTime) {
        invoiceDate = rawDate;
      } else if (rawDate != null) {
        try {
          invoiceDate = DateFormat('dd MMM, yyyy').parse(rawDate.toString());
        } catch (_) {
          invoiceDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
        }
      } else {
        invoiceDate = DateTime.now();
      }

      final amount = (invoice['amount'] ?? 0).toDouble();
      final id = (invoice['id'] ?? invoice['_id'] ?? 'N/A').toString();
      final patient = (invoice['patient'] ?? invoice['patientName'] ?? 'Patient').toString();
      final test = (invoice['test'] ?? invoice['testName'] ?? 'Service').toString();

      if (widget.isPharmacy) {
        await PdfInvoiceGenerator.generatePharmacyInvoice(
          orderNumber: id,
          patientName: patient,
          patientPhone: 'N/A',
          patientAddress: 'N/A',
          items: [{'name': test, 'quantity': 1, 'price': amount}],
          deliveryFee: 0,
          totalAmount: amount,
          orderDate: invoiceDate,
          pharmacyName: 'iCare Pharmacy',
        );
      } else {
        await PdfInvoiceGenerator.generateLabInvoice(
          bookingNumber: id,
          patientName: patient,
          patientPhone: 'N/A',
          testName: test,
          testPrice: amount,
          bookingDate: invoiceDate,
          labName: _labName,
          doctors: _labDoctors.isNotEmpty ? _labDoctors : null,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate invoice: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 600;

    return Scaffold(
      backgroundColor: isDesktop
          ? const Color(0xFFF0F4F8)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: CustomText(
          text: widget.isPharmacy ? "Order Invoices".tr() : "Payment Invoices".tr(),
          fontFamily: "Gilroy-Bold",
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF0F172A),
        ),
        actions: isDesktop
            ? [
                Container(
                  margin: const EdgeInsets.only(right: 20),
                  child: ElevatedButton.icon(
                    onPressed: _fetchInvoices,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text("Refresh"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ]
            : [
                IconButton(
                  onPressed: _fetchInvoices,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : isDesktop
          ? _buildDesktopLayout()
          : _buildMobileLayout(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1300),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Summary Cards ──────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: "Total Revenue".tr(),
                      amount: "PKR ${_totalRevenue.toStringAsFixed(0)}",
                      subtitle:
                          "${_invoices.where((i) => i['status'] == 'Paid').length} invoices paid",
                      icon: Icons.account_balance_wallet_rounded,
                      gradientColors: [
                        const Color(0xFF10B981),
                        const Color(0xFF059669),
                      ],
                      bgAccent: const Color(0xFFD1FAE5),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildSummaryCard(
                      title: "Total Invoices".tr(),
                      amount: "${_invoices.length}",
                      subtitle: "This month".tr(),
                      icon: Icons.receipt_long_rounded,
                      gradientColors: [
                        const Color(0xFF3B82F6),
                        const Color(0xFF1D4ED8),
                      ],
                      bgAccent: const Color(0xFFDBEAFE),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ─── Filter Tabs + Table ────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Tab Bar
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Row(
                        children: [
                          Text(
                            "Invoice List".tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const Spacer(),
                          Flexible(
                            child: TabBar(
                              controller: _tabController,
                              indicatorColor: AppColors.primaryColor,
                              indicatorWeight: 3,
                              labelColor: AppColors.primaryColor,
                              unselectedLabelColor: const Color(0xFF94A3B8),
                              dividerColor: Colors.transparent,
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              tabs: [
                                Tab(text: "All (${_invoices.length})"),
                                Tab(
                                  text:
                                      "Paid (${_invoices.where((i) => i['status'] == 'Paid').length})",
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            flex: 2,
                            child: Text(
                              "INVOICE ID",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const Expanded(
                            flex: 3,
                            child: Text(
                              "PATIENT",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              widget.isPharmacy ? "ORDER ITEMS" : "TEST",
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "DATE",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "AMOUNT",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "METHOD",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "STATUS",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          SizedBox(width: 60),
                        ],
                      ),
                    ),

                    // Table Rows
                    ..._filteredInvoices.asMap().entries.map((entry) {
                      final i = entry.key;
                      final inv = entry.value;
                      final isLast = i == _filteredInvoices.length - 1;
                      return _buildDesktopRow(inv, isLast);
                    }),

                    if (_filteredInvoices.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 48,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "No invoices found",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[400],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildDesktopRow(Map<String, dynamic> inv, bool isLast) {
    final statusColors = _getStatusColors(inv["status"]);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade100)),
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(20))
            : null,
      ),
      child: Row(
        children: [
          // Invoice ID
          Expanded(
            flex: 2,
            child: Text(
              inv["id"],
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF3B82F6),
              ),
            ),
          ),
          // Patient
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryColor.withValues(alpha: 0.1),
                        AppColors.primaryColor.withValues(alpha: 0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      inv["patient"].toString().substring(0, 1),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  inv["patient"],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          // Test
          Expanded(
            flex: 3,
            child: Text(
              inv["test"],
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Date
          Expanded(
            flex: 2,
            child: Text(
              inv["date"],
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Amount
          Expanded(
            flex: 2,
            child: Text(
              "PKR ${(inv["amount"] as double).toStringAsFixed(2)}",
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          // Method
          Expanded(
            flex: 2,
            child: Text(
              inv["method"],
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Status
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColors["bg"],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                inv["status"],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColors["fg"],
                ),
              ),
            ),
          ),
          // Action
          const SizedBox(width: 12),
          SizedBox(
            width: 48,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _downloadInvoice(inv),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.download_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Summary strip
        Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: ScallingConfig.scale(16),
            vertical: ScallingConfig.scale(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  "Total Revenue",
                  "PKR ${_totalRevenue.toStringAsFixed(0)}",
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStat(
                  "Total Invoices",
                  "${_invoices.length}",
                  const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
        ),

        // Tab Bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primaryColor,
            indicatorWeight: 3,
            labelColor: AppColors.primaryColor,
            unselectedLabelColor: const Color(0xFF94A3B8),
            dividerColor: Colors.transparent,
            isScrollable: true,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: "All"),
              Tab(text: "Paid"),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Invoice Cards
        Expanded(
          child: _filteredInvoices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 48,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "No invoices found",
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: ScallingConfig.scale(16),
                  ),
                  itemCount: _filteredInvoices.length,
                  itemBuilder: (ctx, i) {
                    return _buildMobileInvoiceCard(_filteredInvoices[i]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMobileInvoiceCard(Map<String, dynamic> inv) {
    final statusColors = _getStatusColors(inv["status"]);

    return Container(
      margin: EdgeInsets.only(bottom: ScallingConfig.scale(12)),
      padding: EdgeInsets.all(ScallingConfig.scale(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                inv["id"],
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF3B82F6),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColors["bg"],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  inv["status"],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColors["fg"],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: ScallingConfig.scale(12)),

          // Patient & Test
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryColor.withValues(alpha: 0.12),
                      AppColors.primaryColor.withValues(alpha: 0.04),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    inv["patient"].toString().substring(0, 1),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inv["patient"],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      inv["test"],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "PKR ${(inv["amount"] as double).toStringAsFixed(2)}",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),

          SizedBox(height: ScallingConfig.scale(12)),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 6),
                Text(
                  inv["date"],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                if (inv["method"] != "—") ...[
                  Icon(
                    Icons.payment_rounded,
                    size: 13,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    inv["method"],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSummaryCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required Color bgAccent,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors[0].withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgAccent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: gradientColors[0],
                  size: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bgAccent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: gradientColors[0],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, Color> _getStatusColors(String status) {
    switch (status) {
      case "Paid":
        return {"bg": const Color(0xFFD1FAE5), "fg": const Color(0xFF059669)};
      case "Pending":
        return {"bg": const Color(0xFFFEF3C7), "fg": const Color(0xFFD97706)};
      case "Overdue":
        return {"bg": const Color(0xFFFEE2E2), "fg": const Color(0xFFDC2626)};
      default:
        return {"bg": const Color(0xFFF1F5F9), "fg": const Color(0xFF64748B)};
    }
  }
}
