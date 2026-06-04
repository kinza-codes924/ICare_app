import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/services/pharmacy_service.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/rating_dialog.dart';
import 'package:icare/utils/pdf_invoice_generator.dart';
import 'package:intl/intl.dart';

class PharmacyOrders extends ConsumerStatefulWidget {
  const PharmacyOrders({super.key});

  @override
  ConsumerState<PharmacyOrders> createState() => _PharmacyOrdersState();
}

class _PharmacyOrdersState extends ConsumerState<PharmacyOrders>
    with SingleTickerProviderStateMixin {
  final PharmacyService _pharmacyService = PharmacyService();
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    try {
      setState(() => _isLoading = true);
      // Always load ALL orders, then filter client-side by tab
      // This avoids backend comma-separated status issues
      debugPrint('📋 Loading all orders...');
      final orders = await _pharmacyService.getPharmacyOrders(status: 'all');
      debugPrint('✅ Received ${orders.length} orders from backend');

      setState(() {
        _orders = orders.map((o) {
          final user = o['user'] as Map<String, dynamic>?;
          final orderId = o['_id']?.toString();

          if (orderId == null || orderId.isEmpty) {
            debugPrint('⚠️ Skipping order with missing ID');
            return null;
          }

          // Normalize status: replace hyphens with underscores
          final rawStatus = (o['status'] ?? 'pending').toString();
          final normalizedStatus = rawStatus.replaceAll('-', '_');

          debugPrint('📦 Order ID: $orderId, Status: $normalizedStatus');

          return {
            '_id': orderId,
            'id': o['orderNumber'] ?? '#${orderId.substring(0, 8)}',
            'customerName': user?['name'] ?? user?['username'] ?? 'Patient',
            'customerPhone': user?['phoneNumber'] ?? user?['phone'] ?? 'N/A',
            'customerEmail': user?['email'] ?? '',
            'items': ((o['items'] as List?)?.length ?? 0) +
                ((o['prescriptionItems'] as List?)?.length ?? 0),
            'itemsList': (o['items'] as List?) ?? [],
            'total': _calcOrderTotal(o),
            'status': normalizedStatus,
            'date': o['createdAt'] != null
                ? DateTime.parse(o['createdAt'])
                : DateTime.now(),
            'orderType': o['orderType'] ?? 'cart',
            'deliveryAddress': o['deliveryAddress'] ?? o['delivery_address'] ?? '',
            'expectedDeliveryTime': o['expectedDeliveryTime'] ?? o['expected_delivery_time'] ?? '',
            'medicines': [
              ...((o['items'] as List?) ?? []).map((item) {
                final name = (item['product_name'] ??
                    item['productName'] ??
                    item['name'] ??
                    'Medicine').toString();
                return _sanitizeText(name) ?? name;
              }),
              ...((o['prescriptionItems'] as List?) ?? []).map((item) {
                final name = (item['productName'] ??
                    item['name'] ??
                    'Medicine').toString();
                return _sanitizeText(name) ?? name;
              }),
              // Walk-in orders: parse medicines text string
              ...(() {
                final walkInText = (o['walkInMedicines'] ?? '').toString().trim();
                if (walkInText.isEmpty) return <String>[];
                return walkInText.split(',').map((m) => m.trim()).where((m) => m.isNotEmpty).toList();
              })(),
            ],
            'prescriptionText': _sanitizeText(o['prescriptionText']?.toString()),
            'medicalRecord': o['medicalRecord'],
            'prescriptionId': o['prescriptionId'],
          };
        }).whereType<Map<String, dynamic>>().toList();
        debugPrint('✅ Processed ${_orders.length} valid orders');
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading orders: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load orders. Please try again.')),
        );
      }
    }
  }

  String _getCurrentStatus() {
    switch (_tabController.index) {
      case 0:
        return 'all';
      case 1:
        return 'pending'; // Awaiting Fulfillment
      case 2:
        return 'confirmed,preparing,out_for_delivery'; // Processing (all active states)
      case 3:
        return 'completed'; // Dispensed
      default:
        return 'all';
    }
  }

  Future<void> _promptRejectOrder(String orderId) async {
    final custom = TextEditingController();
    String category = 'stock';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Reject order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select a reason for the prescribing doctor / admin logs:'),
                const SizedBox(height: 8),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('No referrer'),
                  subtitle: const Text('Admin reporting only — hidden from doctor Clinical Flags'),
                  value: 'no_referrer',
                  groupValue: category,
                  onChanged: (v) => setSt(() => category = v ?? category),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Stock / availability'),
                  value: 'stock',
                  groupValue: category,
                  onChanged: (v) => setSt(() => category = v ?? category),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Invalid prescription'),
                  value: 'invalid',
                  groupValue: category,
                  onChanged: (v) => setSt(() => category = v ?? category),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Other'),
                  value: 'other',
                  groupValue: category,
                  onChanged: (v) => setSt(() => category = v ?? category),
                ),
                if (category == 'other') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: custom,
                    decoration: const InputDecoration(
                      hintText: 'Describe reason',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reject', style: TextStyle(color: Color(0xFFEF4444))),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      custom.dispose();
      return;
    }

    String reason;
    switch (category) {
      case 'no_referrer':
        reason = 'No referrer';
        break;
      case 'stock':
        reason = 'Stock / availability';
        break;
      case 'invalid':
        reason = 'Invalid prescription';
        break;
      default:
        reason = custom.text.trim().isNotEmpty ? custom.text.trim() : 'Other';
    }
    custom.dispose();

    await _updateOrderStatus(orderId, 'rejected', rejectionReason: reason);
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus,
      {String? expectedDelivery, String? rejectionReason}) async {
    try {
      debugPrint('🔄 Attempting to update order $orderId to $newStatus');

      await _pharmacyService.updateOrderStatus(
        orderId,
        newStatus,
        rejectionReason: rejectionReason,
      );
      debugPrint('✅ Order status updated successfully');

      if (mounted) {
        // Show success message based on action
        String message;
        Color bgColor = const Color(0xFF10B981);

        switch (newStatus) {
          case 'confirmed':
            message = '✓ Order accepted successfully';
            break;
          case 'rejected':
            message = '✗ Order rejected';
            bgColor = const Color(0xFFEF4444);
            break;
          case 'preparing':
            message = '✓ Order moved to preparing';
            break;
          case 'out_for_delivery':
            message = '✓ Order dispatched for delivery';
            break;
          case 'completed':
            message = '✓ Order marked as delivered';
            break;
          default:
            message = '✓ Order status updated';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: bgColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }

      // Small delay to ensure message is visible before reload
      await Future.delayed(const Duration(milliseconds: 500));

      // Reload orders to get fresh data
      await _loadOrders();
    } catch (e) {
      debugPrint('❌ Error updating order status: $e');

      // Check if it's a 404 error (backend bug - order in list but can't update)
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('404') || errorMsg.contains('not found')) {
        if (mounted) {
          // Remove the broken order from UI immediately
          setState(() {
            _orders.removeWhere((o) => o['_id'] == orderId);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '⚠ Backend error: Order removed from list',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              backgroundColor: const Color(0xFFEF4444),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✗ Failed to update: ${e.toString()}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              backgroundColor: const Color(0xFFEF4444),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _showDispatchDialog(String orderId, List items) async {
    // Check for controlled medicines exceeding 30-unit cap
    final violatingItems = items.where((item) {
      final isControlled = item['isControlled'] == true;
      final qty = (item['quantity'] ?? item['qty'] ?? 0) as int;
      return isControlled && qty > 30;
    }).toList();

    if (violatingItems.isNotEmpty && mounted) {
      final names = violatingItems.map((i) => i['productName'] ?? i['name'] ?? 'Unknown').join(', ');
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Color(0xFF8B5CF6), size: 22),
              SizedBox(width: 10),
              Flexible(child: Text('Controlled Medicine Warning', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
            ],
          ),
          content: Text(
            'This order contains controlled medicine(s) exceeding the 30-unit limit:\n\n$names\n\nPlease verify prescription before dispatching.',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white),
              child: const Text('Proceed Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final deliveryController = TextEditingController();
    TimeOfDay? selectedTime;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.delivery_dining_rounded, color: Color(0xFF8B5CF6), size: 22),
              SizedBox(width: 10),
              Text('Dispatch Order', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter the expected delivery time before dispatching. This will be shown to the patient.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Expected Delivery Time *',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedTime = picked;
                          deliveryController.text = picked.format(ctx);
                        });
                      }
                    },
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: deliveryController,
                        decoration: InputDecoration(
                          hintText: 'Tap to select time',
                          suffixIcon: const Icon(Icons.access_time_rounded, color: Color(0xFF8B5CF6)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Expected delivery time is required' : null,
                      ),
                    ),
                  ),
                  if (selectedTime != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F0FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF8B5CF6)),
                          const SizedBox(width: 8),
                          Text(
                            'Patient will be notified: delivery by ${selectedTime!.format(ctx)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6D28D9)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx);
                  _updateOrderStatus(orderId, 'out_for_delivery',
                      expectedDelivery: deliveryController.text);
                }
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Dispatch'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getOrdersByStatus(String status) {
    if (status == 'all') return _orders;

    if (status == 'processing') {
      // Processing tab: confirmed, preparing, out_for_delivery, out-for-delivery
      return _orders.where((o) {
        final s = (o['status']?.toString() ?? '').replaceAll('-', '_');
        return s == 'confirmed' || s == 'preparing' || s == 'out_for_delivery';
      }).toList();
    }

    if (status == 'pending') {
      // Awaiting Fulfillment: pending orders
      return _orders.where((o) {
        final s = (o['status']?.toString() ?? '').replaceAll('-', '_');
        return s == 'pending';
      }).toList();
    }

    if (status == 'completed') {
      // Dispensed: completed/delivered orders
      return _orders.where((o) {
        final s = (o['status']?.toString() ?? '').replaceAll('-', '_');
        return s == 'completed' || s == 'delivered';
      }).toList();
    }

    // Fallback: exact match
    return _orders.where((o) {
      final s = (o['status']?.toString() ?? '').replaceAll('-', '_');
      return s == status.replaceAll('-', '_');
    }).toList();
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
        title: const Text(
          'Orders',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Gilroy-Bold',
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _loadOrders,
            tooltip: 'Refresh orders',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryColor,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: AppColors.primaryColor,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Awaiting Fulfillment'),
            Tab(text: 'Processing'),
            Tab(text: 'Dispensed'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateWalkInOrderDialog(context),
        backgroundColor: AppColors.primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Create Order',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList(_getOrdersByStatus('all'), isDesktop),
          _buildOrdersList(_getOrdersByStatus('pending'), isDesktop),
          _buildOrdersList(_getOrdersByStatus('processing'), isDesktop),
          _buildOrdersList(_getOrdersByStatus('completed'), isDesktop),
        ],
      ),
    );
  }

  void _showCreateWalkInOrderDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final notesController = TextEditingController();
    bool isSubmitting = false;
    String deliveryOption = 'pickup';
    // Selected medicines from inventory
    final List<Map<String, dynamic>> selectedMedicines = [];
    List<Map<String, dynamic>> inventoryMeds = [];
    bool medsLoading = true;
    final searchCtrl = TextEditingController();
    final prescriptionCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Load inventory on first build — setModalState is in scope here
          if (medsLoading && inventoryMeds.isEmpty) {
            _pharmacyService.getMedicines().then((meds) {
              setModalState(() {
                inventoryMeds = meds.map((m) => {
                  'name': (m['productName'] ?? m['name'] ?? 'Unknown').toString(),
                  'id': m['_id'] ?? '',
                  'price': (m['price'] ?? 0).toDouble(),
                  'stock': (m['stock_quantity'] ?? m['quantity'] ?? m['stock'] ?? 0),
                  'permission': (m['medicinePermission'] ?? 'OTC').toString(),
                  'category': (m['category'] ?? '').toString(),
                  'medicine_category': (m['medicine_category'] ?? m['medicineCategory'] ?? 'OTC').toString(),
                }).toList();
                medsLoading = false;
              });
            }).catchError((_) { setModalState(() { medsLoading = false; }); });
          }

          final filtered = inventoryMeds.where((m) {
            final q = searchCtrl.text.toLowerCase();
            return q.isEmpty || m['name'].toString().toLowerCase().contains(q);
          }).toList();

          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: AppColors.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.add_circle_rounded, color: AppColors.primaryColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Create Walk-in Order', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)))),
                    ]),
                    const SizedBox(height: 24),
                    _buildWalkInField(controller: nameController, label: 'Patient Name', icon: Icons.person_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                    const SizedBox(height: 12),
                    _buildWalkInField(controller: phoneController, label: 'Contact Number', icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                    const SizedBox(height: 20),
                    // Medicines from inventory
                    const Text('Medicines Required', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFEA580C)),
                        SizedBox(width: 8),
                        Expanded(child: Text(
                          'All the medicines available in inventory will be shown here only. Add medicine to inventory first if not visible.',
                          style: TextStyle(fontSize: 11, color: Color(0xFFEA580C)),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    // Search field
                    TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search inventory medicines...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                        filled: true, fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      ),
                    ),
                    if (medsLoading) ...[
                      const SizedBox(height: 12),
                      const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ] else if (filtered.isEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('No medicines found in inventory', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ] else ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 180,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final med = filtered[i];
                            final isSelected = selectedMedicines.any((s) => s['id'] == med['id']);
                            final isControlledMed = med['permission'] == 'Controlled' ||
                                med['category'].toString().toLowerCase() == 'controlled' ||
                                (med['medicine_category'] ?? '').toString().toLowerCase() == 'controlled';
                            return ListTile(
                              dense: true,
                              title: Row(children: [
                                Expanded(child: Text(med['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                                if (isControlledMed)
                                  Container(
                                    margin: const EdgeInsets.only(left: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)),
                                    child: const Text('Controlled', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                                  ),
                              ]),
                              subtitle: Text('PKR ${med['price'].toStringAsFixed(0)} • Stock: ${med['stock']}', style: const TextStyle(fontSize: 11)),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle_rounded, color: AppColors.primaryColor, size: 20)
                                  : Icon(Icons.add_circle_outline_rounded, color: Colors.grey.shade400, size: 20),
                              onTap: () {
                                setModalState(() {
                                  if (isSelected) {
                                    selectedMedicines.removeWhere((s) => s['id'] == med['id']);
                                  } else {
                                    selectedMedicines.add(med);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    if (selectedMedicines.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: selectedMedicines.map((m) => Chip(
                          label: Text(m['name'], style: const TextStyle(fontSize: 11)),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => setModalState(() => selectedMedicines.removeWhere((s) => s['id'] == m['id'])),
                          backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                        )).toList(),
                      ),
                    ],
                    if (selectedMedicines.isEmpty && !medsLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('At least one medicine is required', style: TextStyle(fontSize: 11, color: Colors.red.shade400)),
                      ),
                    if (selectedMedicines.any((m) =>
                        m['permission'] == 'Controlled' ||
                        m['category'].toString().toLowerCase() == 'controlled' ||
                        (m['medicine_category'] ?? '').toString().toLowerCase() == 'controlled')) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.warning_rounded, size: 16, color: Color(0xFFDC2626)),
                          SizedBox(width: 8),
                          Expanded(child: Text(
                            'Controlled drug(s) selected. A valid iCare prescription ID is required to proceed.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF7F1D1D), fontWeight: FontWeight.w600),
                          )),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: prescriptionCtrl,
                        decoration: InputDecoration(
                          labelText: 'iCare Prescription ID *',
                          hintText: 'Enter prescription reference ID',
                          prefixIcon: const Icon(Icons.receipt_long_rounded, color: Color(0xFFDC2626), size: 18),
                          filled: true,
                          fillColor: const Color(0xFFFEF2F2),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        validator: (_) {
                          final hasControlled = selectedMedicines.any((m) =>
                              m['permission'] == 'Controlled' ||
                              m['category'].toString().toLowerCase() == 'controlled' ||
                              (m['medicine_category'] ?? '').toString().toLowerCase() == 'controlled');
                          if (hasControlled && prescriptionCtrl.text.trim().isEmpty) {
                            return 'Prescription ID is required for controlled medicines';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Text('Delivery Option', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _buildDeliveryOption(
                        label: 'Pickup', icon: Icons.store_rounded, value: 'pickup',
                        selected: deliveryOption, onTap: () => setModalState(() => deliveryOption = 'pickup'),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDeliveryOption(
                        label: 'Delivery', icon: Icons.delivery_dining_rounded, value: 'delivery',
                        selected: deliveryOption, onTap: () => setModalState(() => deliveryOption = 'delivery'),
                      )),
                    ]),
                    if (deliveryOption == 'delivery') ...[
                      const SizedBox(height: 12),
                      _buildWalkInField(controller: addressController, label: 'Delivery Address', icon: Icons.location_on_rounded),
                    ],
                    const SizedBox(height: 12),
                    _buildWalkInField(controller: notesController, label: 'Notes (optional)', icon: Icons.notes_rounded, maxLines: 2),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : () async {
                          if (!formKey.currentState!.validate()) return;
                          if (selectedMedicines.isEmpty) {
                            setModalState(() {}); // trigger rebuild to show error
                            return;
                          }
                          setModalState(() => isSubmitting = true);
                          final medNames = selectedMedicines.map((m) => m['name']).join(', ');
                          final walkInItems = selectedMedicines.map((m) => {
                            'name': m['name'].toString(),
                            'price': (m['price'] as num?)?.toDouble() ?? 0.0,
                            'quantity': 1,
                          }).toList();
                          final walkInTotal = walkInItems.fold<double>(0, (sum, i) => sum + ((i['price'] as num) * (i['quantity'] as num)));
                          try {
                            await _pharmacyService.createWalkInOrder(
                              patientName: nameController.text.trim(),
                              contact: phoneController.text.trim(),
                              medicines: medNames,
                              deliveryOption: deliveryOption,
                              address: addressController.text.trim(),
                              notes: notesController.text.trim(),
                              prescriptionId: prescriptionCtrl.text.trim().isNotEmpty ? prescriptionCtrl.text.trim() : null,
                              totalAmount: walkInTotal,
                              items: walkInItems,
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Manual order created successfully'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
                              );
                            }
                            _loadOrders();
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Create Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWalkInField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primaryColor, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primaryColor, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDeliveryOption({
    required String label,
    required IconData icon,
    required String value,
    required String selected,
    required VoidCallback onTap,
  }) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primaryColor : const Color(0xFFE2E8F0), width: isSelected ? 2 : 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: isSelected ? AppColors.primaryColor : const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: isSelected ? AppColors.primaryColor : const Color(0xFF64748B))),
        ]),
      ),
    );
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> orders, bool isDesktop) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'No orders found',
              style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isDesktop ? 40 : 20),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return _buildOrderCard(orders[index]);
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] as String;
    final statusColor = _getStatusColor(status);
    final date = order['date'] as DateTime;
    final isDoctorReferred = order['medicalRecord'] != null;
    final isPrescriptionOrder = order['orderType'] == 'prescription';
    final isManualOrder = (order['orderType'] ?? '').toString().contains('walk');
    final hasPrescriptionText =
        order['prescriptionText'] != null &&
        order['prescriptionText'].toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDoctorReferred
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : statusColor.withValues(alpha: 0.2),
          width: isDoctorReferred ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isManualOrder)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFF6366F1)),
                        SizedBox(width: 6),
                        Text('Order Created Manually', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6366F1))),
                      ],
                    ),
                  ),
                if (isDoctorReferred || isPrescriptionOrder)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isPrescriptionOrder
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                          : const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPrescriptionOrder
                              ? Icons.upload_file_rounded
                              : Icons.medical_services_rounded,
                          size: 14,
                          color: isPrescriptionOrder
                              ? const Color(0xFF8B5CF6)
                              : const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isPrescriptionOrder
                              ? 'Prescription Order'
                              : 'Doctor Referred',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isPrescriptionOrder
                                ? const Color(0xFF8B5CF6)
                                : const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.shopping_bag_rounded,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order['id'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Patient Name',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order['customerName'],
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if ((order['customerPhone'] ?? 'N/A') != 'N/A') ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.phone_rounded, size: 11, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  order['customerPhone'],
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                          if ((order['deliveryAddress'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 11, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    order['deliveryAddress'],
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if ((order['customerEmail'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.email_rounded, size: 11, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    order['customerEmail'],
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStatusLabel(status),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show prescription text if doctor-referred
                if (hasPrescriptionText) ...[
                  const Text(
                    'Prescription:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      order['prescriptionText'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Items:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final rawItems = order['itemsList'] as List? ?? [];
                  final medicines = order['medicines'] as List? ?? [];
                  if (rawItems.isNotEmpty) {
                    return Column(
                      children: rawItems.map<Widget>((item) {
                        final name = (item['product_name'] ?? item['productName'] ?? item['name'] ?? '').toString();
                        final qty = item['quantity'] ?? item['qty'] ?? 1;
                        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(name, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('x$qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor)),
                              ),
                              if (price > 0) ...[
                                const SizedBox(width: 8),
                                Text('PKR ${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  }
                  return Column(
                    children: medicines.map<Widget>((medicine) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(medicine.toString(), style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                        ],
                      ),
                    )).toList(),
                  );
                }),
                if (order['prescriptionText'] != null &&
                    (order['prescriptionText'] as String).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.description_rounded,
                              color: Color(0xFF166534),
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'CLINICAL PRESCRIPTION',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          order['prescriptionText'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF064E3B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (order['medicalRecord'] != null) ...[
                          const Divider(height: 16, color: Color(0xFFBBF7D0)),
                          Text(
                            "Diagnosis: ${order['medicalRecord']['diagnosis'] ?? 'N/A'}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if ((order['prescriptionId'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF0369A1)),
                      const SizedBox(width: 8),
                      const Text('Prescription Ref: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0369A1))),
                      Expanded(
                        child: Text(
                          order['prescriptionId'].toString(),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF0C4A6E)),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 16),
                Builder(builder: (_) {
                  final deliveryFee = (order['deliveryFee'] ?? order['delivery_fee'] ?? 0) as num;
                  return Column(
                    children: [
                      if (deliveryFee > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Delivery Fee', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            Text('PKR ${deliveryFee.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 6),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Amount', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              Text(
                                'PKR ${order['total']}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Order Date', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              Text(
                                DateFormat('MMM dd, HH:mm').format(date),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  );
                }),
                if (status == 'pending') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _promptRejectOrder(order['_id']),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _updateOrderStatus(order['_id'], 'confirmed'),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (status == 'confirmed') ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _updateOrderStatus(order['_id'], 'preparing'),
                      icon: const Icon(Icons.medication_rounded, size: 18),
                      label: const Text('Start Preparing'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ] else if (status == 'preparing') ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showDispatchDialog(order['_id'], order['itemsList'] as List),
                      icon: const Icon(Icons.delivery_dining_rounded, size: 18),
                      label: const Text('Dispatch Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ] else if (status == 'out_for_delivery' || status == 'out-for-delivery') ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _markAsCompleted(order['_id'], order['customerName']),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Mark as Delivered'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ] else if (status == 'completed') ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _downloadInvoice(order),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download Invoice'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0036BC),
                        side: const BorderSide(color: Color(0xFF0036BC)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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

  Future<void> _downloadInvoice(Map<String, dynamic> order) async {
    try {
      final medicinesList = (order['medicines'] as List? ?? order['items'] as List? ?? []);
      final total = (order['total'] ?? order['totalAmount'] ?? order['amount'] ?? 0).toDouble();
      final perItem = medicinesList.isNotEmpty ? total / medicinesList.length : 0.0;

      final items = medicinesList.map((medicine) {
        if (medicine is Map) {
          return {
            'name': medicine['name']?.toString() ?? medicine['productName']?.toString() ?? 'Item',
            'quantity': medicine['quantity'] ?? 1,
            'price': (medicine['price'] ?? medicine['unitPrice'] ?? perItem).toDouble(),
          };
        }
        return {'name': medicine.toString(), 'quantity': 1, 'price': perItem};
      }).toList();

      if (items.isEmpty) {
        items.add({'name': 'Pharmacy Order', 'quantity': 1, 'price': total});
      }

      // Parse date safely
      DateTime orderDate;
      final rawDate = order['date'] ?? order['createdAt'] ?? order['orderDate'];
      if (rawDate is DateTime) {
        orderDate = rawDate;
      } else if (rawDate != null) {
        orderDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
      } else {
        orderDate = DateTime.now();
      }

      final pharmacyName = ref.read(authProvider).user?.name ?? 'iCare Pharmacy';
      await PdfInvoiceGenerator.generatePharmacyInvoice(
        orderNumber: (order['id'] ?? order['_id'] ?? 'N/A').toString(),
        patientName: (order['customerName'] ?? order['patientName'] ?? order['patient_name'] ?? 'Patient').toString(),
        patientPhone: (order['customerPhone'] ?? order['phone'] ?? order['patientPhone'] ?? 'N/A').toString(),
        patientAddress: (order['address'] ?? order['deliveryAddress'] ?? 'N/A').toString(),
        patientEmail: (order['customerEmail'] ?? '').toString(),
        items: items,
        deliveryFee: (order['deliveryFee'] ?? order['delivery_fee'] ?? 0).toDouble(),
        totalAmount: total,
        orderDate: orderDate,
        pharmacyName: pharmacyName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate invoice: $e')),
        );
      }
    }
  }

  Future<void> _markAsCompleted(String orderId, String customerName) async {
    try {
      await _updateOrderStatus(orderId, 'completed');

      if (mounted) {
        final rated = await showRatingDialog(
          context: context,
          title: 'How was your experience?',
          subtitle: 'Rate your experience with $customerName\'s order',
          satisfactionQuestion: 'Are you satisfied with this order?',
          onSubmit: (rating, satisfied, comment) async {
            try {
              await _pharmacyService.submitOrderRating(orderId, rating, comment);
            } catch (e) {
              debugPrint('Failed to submit rating: $e');
            }
          },
        );

        if (rated == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thank you for your feedback!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Utils.showErrorSnackBar(context, e);
      }
    }
  }

  /// Removes "undefined" / "null" strings injected by backend template rendering
  String? _sanitizeText(String? text) {
    if (text == null) return null;
    final cleaned = text
        .replaceAll(RegExp(r'\bundefined\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bnull\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r',\s*,'), ',')
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  /// Calculate order total: use saved totalAmount if > 0,
  /// otherwise sum items price × quantity
  double _calcOrderTotal(Map<String, dynamic> o) {
    final saved = o['totalAmount'];
    if (saved != null && saved is num && saved > 0) return saved.toDouble();
    final items = o['items'] as List? ?? [];
    if (items.isEmpty) return 0;
    return items.fold(0.0, (sum, item) {
      final price = (item['price'] ?? 0) as num;
      final qty = (item['quantity'] ?? 1) as num;
      return sum + (price * qty);
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase().replaceAll('-', '_')) {
      case 'pending':
        return const Color(0xFFF59E0B);       // Orange - Awaiting
      case 'confirmed':
        return const Color(0xFF3B82F6);       // Blue - Accepted
      case 'preparing':
        return const Color(0xFF8B5CF6);       // Purple - Preparing
      case 'out_for_delivery':
        return const Color(0xFF0EA5E9);       // Sky - Dispatched
      case 'completed':
      case 'delivered':
        return const Color(0xFF10B981);       // Green - Done
      case 'cancelled':
      case 'rejected':
        return const Color(0xFFEF4444);       // Red - Cancelled
      default:
        return const Color(0xFF64748B);
    }
  }

  /// Human-readable status label
  String _getStatusLabel(String status) {
    switch (status.toLowerCase().replaceAll('-', '_')) {
      case 'pending':        return 'AWAITING';
      case 'confirmed':      return 'ACCEPTED';
      case 'preparing':      return 'PREPARING';
      case 'out_for_delivery': return 'DISPATCHED';
      case 'completed':
      case 'delivered':      return 'DELIVERED';
      case 'cancelled':      return 'CANCELLED';
      case 'rejected':       return 'REJECTED';
      default:               return status.toUpperCase();
    }
  }
}
