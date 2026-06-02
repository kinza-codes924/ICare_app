import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/screens/login.dart';
import 'package:icare/services/cart_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyCartScreen extends StatefulWidget {
  final double? deliveryFee;
  final String? pharmacyName;
  const MyCartScreen({super.key, this.deliveryFee, this.pharmacyName});

  @override
  State<MyCartScreen> createState() => _MyCartScreenState();
}

class _MyCartScreenState extends State<MyCartScreen> {
  final CartService _cartService = CartService();
  List<dynamic> _cartItems = [];
  bool _isLoading = true;
  final bool _isCheckingOut = false;
  bool _isLoggedIn = true;
  String _promoCode = '';
  double _discount = 0;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() => _isLoading = true);

    final token = await SharedPref().getToken();
    if (token == null || token.isEmpty) {
      if (mounted) setState(() { _isLoggedIn = false; _isLoading = false; });
      return;
    }

    final result = await _cartService.getCart();
    if (mounted) {
      setState(() {
        _isLoggedIn = true;
        _cartItems = result['cart'] ?? [];
        _isLoading = false;
      });
    }
  }

  Future<void> _updateQuantity(String itemId, int newQty) async {
    if (newQty < 1) {
      await _removeItem(itemId);
      return;
    }
    try {
      await _cartService.updateItem(itemId, newQty);
      _loadCart();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update quantity'.tr()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeItem(String itemId) async {
    try {
      await _cartService.removeItem(itemId);
      _loadCart();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item removed from cart'.tr()),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove item'.tr()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _clearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear Cart'.tr()),
        content: Text('Are you sure you want to remove all items?'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel'.tr())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Clear'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _cartService.clearCart();
      _loadCart();
    }
  }

  Future<void> _checkout() async {
    if (_cartItems.isEmpty) return;

    // Navigate to proper checkout screen
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _CheckoutScreen(
          cartItems: _cartItems,
          subtotal: _subtotal,
          discount: _discount,
          total: _total,
          deliveryFee: _effectiveDeliveryFee,
          cartService: _cartService,
        ),
      ),
    );

    if (result == true) {
      // Order placed — reload cart (should be empty now)
      _loadCart();
    }
  }

  double get _subtotal {
    double total = 0;
    for (final item in _cartItems) {
      final price = double.tryParse(
              (item['product']?['price'] ?? item['price'] ?? 0).toString()) ??
          0;
      final qty = (item['quantity'] ?? 1) as int;
      total += price * qty;
    }
    return total;
  }

  double get _effectiveDeliveryFee => widget.deliveryFee ?? 0;
  double get _total => _subtotal - (_subtotal * _discount / 100) + _effectiveDeliveryFee;

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
          'My Cart'.tr(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          if (_cartItems.isNotEmpty)
            TextButton(
              onPressed: _clearCart,
              child: Text('Clear All'.tr(), style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isLoggedIn
              ? _buildLoginRequired()
              : _cartItems.isEmpty
                  ? _buildEmptyCart()
                  : isDesktop
                      ? _buildDesktopLayout()
                      : _buildMobileLayout(),
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, size: 64, color: AppColors.primaryColor),
            ),
            const SizedBox(height: 24),
            Text(
              'Login Required'.tr(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              'Please log in to view your cart and place orders.'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              icon: const Icon(Icons.login_rounded),
              label: Text('Log In'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: AppColors.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your cart is empty'.tr(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse medicines and add them to your cart'.tr(),
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.local_pharmacy_rounded),
            label: Text('Browse Medicines'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCart,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _cartItems.length,
              itemBuilder: (ctx, i) => _buildCartItem(_cartItems[i]),
            ),
          ),
        ),
        _buildOrderSummaryPanel(),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: RefreshIndicator(
            onRefresh: _loadCart,
            child: ListView.builder(
              padding: const EdgeInsets.all(32),
              itemCount: _cartItems.length,
              itemBuilder: (ctx, i) => _buildCartItem(_cartItems[i]),
            ),
          ),
        ),
        Container(
          width: 380,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(-4, 0),
              ),
            ],
          ),
          child: _buildOrderSummaryPanel(isDesktop: true),
        ),
      ],
    );
  }

  Widget _buildCartItem(dynamic item) {
    final product = item['product'] ?? item;
    final name = product['productName'] ?? product['name'] ?? product['title'] ?? 'Medicine';
    final brand = product['brand'] ?? product['manufacturer'] ?? '';
    final price = double.tryParse((product['price'] ?? 0).toString()) ?? 0;
    final qty = (item['quantity'] ?? 1) as int;
    final itemId = item['_id']?.toString() ?? item['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Medicine icon with category color
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _medicineGradient(product['category'] ?? product['medicine_category'] ?? ''),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _medicineEmoji(product['category'] ?? product['medicine_category'] ?? ''),
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (brand.isNotEmpty)
                  Text(
                    brand,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                const SizedBox(height: 8),
                Text(
                  'PKR ${(price * qty).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF95BF47),
                  ),
                ),
              ],
            ),
          ),
          // Quantity controls + delete
          Column(
            children: [
              IconButton(
                onPressed: () => _removeItem(itemId),
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _qtyBtn(Icons.remove, () => _updateQuantity(itemId, qty - 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '$qty',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  _qtyBtn(Icons.add, () => _updateQuantity(itemId, qty + 1)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF0F172A)),
      ),
    );
  }

  Widget _buildOrderSummaryPanel({bool isDesktop = false}) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : 20),
      decoration: isDesktop
          ? null
          : const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4)),
              ],
            ),
      child: SafeArea(
        child: Column(
          mainAxisSize: isDesktop ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop) ...[
              Text(
                'Order Summary'.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 24),
            ],
            // Promo code
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _promoCode = v),
                    decoration: InputDecoration(
                      hintText: 'Promo code'.tr(),
                      hintStyle: const TextStyle(fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // Apply promo: SAVE10 = 10%, SAVE20 = 20%
                    if (_promoCode.toUpperCase() == 'SAVE10') {
                      setState(() => _discount = 10);
                    } else if (_promoCode.toUpperCase() == 'SAVE20') {
                      setState(() => _discount = 20);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Invalid promo code'.tr()), backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text('Apply'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _summaryRow('${'Subtotal'.tr()} (${_cartItems.length} ${'items'.tr()})', 'PKR ${_subtotal.toStringAsFixed(0)}'),
            if (_discount > 0)
              _summaryRow('${'Discount'.tr()} ($_discount%)', '-PKR ${(_subtotal * _discount / 100).toStringAsFixed(0)}',
                  isNegative: true),
            _summaryRow('Delivery'.tr(), _effectiveDeliveryFee > 0 ? 'PKR ${_effectiveDeliveryFee.toStringAsFixed(0)}' : 'Free'.tr()),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total'.tr(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                Text(
                  'PKR ${_total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF95BF47),
                  ),
                ),
              ],
            ),
            SizedBox(height: isDesktop ? 0 : 16),
            if (isDesktop) const Spacer(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isCheckingOut ? null : _checkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isCheckingOut
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        '${'Checkout'.tr()} • PKR ${_total.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isNegative ? Colors.red : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _medicineGradient(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('pain') || cat.contains('relief')) return [const Color(0xFFEF4444), const Color(0xFFDC2626)];
    if (cat.contains('antibiotic')) return [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)];
    if (cat.contains('diabetes') || cat.contains('sugar')) return [const Color(0xFF3B82F6), const Color(0xFF2563EB)];
    if (cat.contains('cardio') || cat.contains('heart')) return [const Color(0xFFEC4899), const Color(0xFFDB2777)];
    if (cat.contains('gastric') || cat.contains('stomach')) return [const Color(0xFFF59E0B), const Color(0xFFD97706)];
    if (cat.contains('allergy')) return [const Color(0xFF10B981), const Color(0xFF059669)];
    if (cat.contains('vitamin') || cat.contains('supplement')) return [const Color(0xFF06B6D4), const Color(0xFF0891B2)];
    if (cat.contains('respiratory') || cat.contains('lung')) return [const Color(0xFF6366F1), const Color(0xFF4F46E5)];
    return [const Color(0xFF0036BC), const Color(0xFF1D4ED8)];
  }

  String _medicineEmoji(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('pain')) return '💊';
    if (cat.contains('antibiotic')) return '🧬';
    if (cat.contains('diabetes')) return '🩸';
    if (cat.contains('cardio') || cat.contains('heart')) return '❤️';
    if (cat.contains('gastric')) return '🫃';
    if (cat.contains('allergy')) return '🌿';
    if (cat.contains('vitamin') || cat.contains('supplement')) return '💪';
    if (cat.contains('respiratory')) return '🫁';
    return '💊';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CHECKOUT SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class _CheckoutScreen extends StatefulWidget {
  final List<dynamic> cartItems;
  final double subtotal;
  final double discount;
  final double total;
  final double deliveryFee;
  final CartService cartService;

  const _CheckoutScreen({
    required this.cartItems,
    required this.subtotal,
    required this.discount,
    required this.total,
    this.deliveryFee = 0,
    required this.cartService,
  });

  @override
  State<_CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<_CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  String _paymentMethod = 'Cash on Delivery';
  bool _isPlacing = false;
  List<Map<String, String>> _savedAddresses = [];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('saved_delivery_addresses') ?? '[]';
      final decoded = jsonDecode(raw) as List? ?? [];
      final instr = prefs.getString('delivery_instructions') ?? '';
      if (mounted) {
        setState(() {
          _savedAddresses = decoded.map((e) => Map<String, String>.from(e as Map)).toList();
          _instructionsCtrl.text = instr;
        });
      }
    } catch (_) {}
  }

  void _showSavedAddressesSheet() {
    if (_savedAddresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No saved addresses. Add one in Settings → Pharmacy.'.tr()), backgroundColor: Colors.orange, duration: const Duration(seconds: 3)));
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Select Saved Address'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ..._savedAddresses.map((addr) => ListTile(
            leading: const Icon(Icons.location_on_outlined, color: Color(0xFF10B981)),
            title: Text(addr['label'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text('${addr['street'] ?? ''}${(addr['city'] ?? '').isNotEmpty ? ', ${addr['city']}' : ''}', style: const TextStyle(fontSize: 12)),
            onTap: () {
              _addressCtrl.text = addr['street'] ?? '';
              _cityCtrl.text = addr['city'] ?? '';
              Navigator.pop(ctx);
            },
          )),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isPlacing = true);

    final address = '${_addressCtrl.text.trim()}, ${_cityCtrl.text.trim()}';

    try {
      final result = await widget.cartService.checkout(deliveryAddress: address);
      if (mounted) {
        if (result['success'] == true) {
          _showOrderSuccess();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Order failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Order failed. Please try again.';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null) {
            msg = data['message'].toString();
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlacing = false);
    }
  }

  void _showOrderSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 48),
              ),
              const SizedBox(height: 20),
              Text(
                'Order Placed!'.tr(),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                'Your order has been placed successfully.\nThe pharmacy will confirm shortly.'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text('Done'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
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
        title: Text(
          'Checkout'.tr(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),
      ),
      body: isDesktop ? _buildDesktop() : _buildMobile(),
    );
  }

  Widget _buildMobile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderItems(),
            const SizedBox(height: 24),
            _buildDeliveryForm(),
            const SizedBox(height: 24),
            _buildPaymentMethod(),
            const SizedBox(height: 24),
            _buildOrderTotal(),
            const SizedBox(height: 24),
            _buildPlaceOrderBtn(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderItems(),
                  const SizedBox(height: 32),
                  _buildDeliveryForm(),
                  const SizedBox(height: 32),
                  _buildPaymentMethod(),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: 380,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(-4, 0))],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                _buildOrderTotal(),
                const SizedBox(height: 24),
                _buildPlaceOrderBtn(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order Items'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
          ),
          child: Column(
            children: widget.cartItems.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final product = item['product'] ?? item;
              final name = product['productName'] ?? product['name'] ?? 'Medicine';
              final price = double.tryParse((product['price'] ?? 0).toString()) ?? 0;
              final qty = (item['quantity'] ?? 1) as int;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(child: Text('💊', style: TextStyle(fontSize: 22))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                              Text('Qty: $qty',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                        Text(
                          'PKR ${(price * qty).toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                  if (i < widget.cartItems.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Delivery Address'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const Spacer(),
          TextButton.icon(
            onPressed: _showSavedAddressesSheet,
            icon: const Icon(Icons.bookmarks_outlined, size: 16),
            label: Text('Saved'.tr(), style: const TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryColor),
          ),
        ]),
        const SizedBox(height: 12),
        _formField(_addressCtrl, 'Street Address'.tr(), Icons.home_outlined,
            validator: (v) => v == null || v.isEmpty ? 'Address is required'.tr() : null),
        const SizedBox(height: 12),
        _formField(_cityCtrl, 'City'.tr(), Icons.location_city_outlined,
            validator: (v) => v == null || v.isEmpty ? 'City is required'.tr() : null),
        const SizedBox(height: 20),
        Text('Delivery Instructions'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        Text('Optional — pre-filled from your saved preferences'.tr(), style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        const SizedBox(height: 8),
        TextFormField(
          controller: _instructionsCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'e.g. Leave at door, Ring bell twice...'.tr(),
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.sticky_note_2_outlined, color: Color(0xFF94A3B8), size: 20),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryColor, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _formField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
        filled: true,
        fillColor: Colors.white,
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
          borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildPaymentMethod() {
    // Only Cash on Delivery and Credit/Debit Card
    final methods = [
      {'label': 'Cash on Delivery'.tr(), 'icon': Icons.money_rounded, 'color': const Color(0xFF10B981)},
      {'label': 'Credit / Debit Card'.tr(), 'icon': Icons.credit_card_rounded, 'color': const Color(0xFF3B82F6)},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Method'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
          ),
          child: Column(
            children: methods.asMap().entries.map((entry) {
              final i = entry.key;
              final method = entry.value['label'] as String;
              final icon = entry.value['icon'] as IconData;
              final color = entry.value['color'] as Color;
              final isSelected = _paymentMethod == method;
              return Column(
                children: [
                  InkWell(
                    onTap: () => setState(() => _paymentMethod = method),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? AppColors.primaryColor : const Color(0xFFCBD5E1),
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            method,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColors.primaryColor : const Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          Icon(icon, color: color, size: 20),
                        ],
                      ),
                    ),
                  ),
                  if (i < methods.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderTotal() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Summary'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 16),
          _row('Subtotal'.tr(), 'PKR ${widget.subtotal.toStringAsFixed(0)}'),
          if (widget.discount > 0)
            _row('${'Discount'.tr()} (${widget.discount.toInt()}%)',
                '-PKR ${(widget.subtotal * widget.discount / 100).toStringAsFixed(0)}',
                color: Colors.red),
          _row('Delivery'.tr(), widget.deliveryFee > 0 ? 'PKR ${widget.deliveryFee.toStringAsFixed(0)}' : 'Free'.tr(), color: widget.deliveryFee > 0 ? null : const Color(0xFF10B981)),
          _row('Payment'.tr(), _paymentMethod),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total'.tr(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              Text(
                'PKR ${widget.total.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primaryColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color ?? const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildPlaceOrderBtn() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isPlacing ? null : _placeOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isPlacing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_bag_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    '${'Place Order'.tr()} • PKR ${widget.total.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
      ),
    );
  }
}
