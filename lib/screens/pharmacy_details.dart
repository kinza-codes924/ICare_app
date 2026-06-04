import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:icare/screens/login.dart';
import 'package:icare/screens/my_cart.dart';
import 'package:icare/services/cart_service.dart';
import 'package:icare/services/pharmacy_service.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/screens/consultation_details_screen.dart';
import 'package:icare/widgets/custom_text_input.dart';

class PharmacyDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> pharmacy;
  final List<dynamic>? prescribedMedicines;
  const PharmacyDetailsScreen({super.key, required this.pharmacy, this.prescribedMedicines});

  @override
  State<PharmacyDetailsScreen> createState() => _PharmacyDetailsScreenState();
}

class _PharmacyDetailsScreenState extends State<PharmacyDetailsScreen> {
  final PharmacyService _pharmacyService = PharmacyService();
  final CartService _cartService = CartService();
  final ImagePicker _picker = ImagePicker();
  List<dynamic> _medicines = [];
  bool _isLoading = true;
  bool _isPlacingOrder = false;
  String _searchQuery = '';
  XFile? _selectedPrescription;
  final Set<String> _addingToCart = {};
  final Map<String, int> _quantities = {}; // quantity per medicine id
  final Map<String, TextEditingController> _qtyControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchMedicines();
  }

  Future<void> _addToCart(dynamic med, {int quantity = 1}) async {
    final id = med['_id']?.toString() ?? '';
    // Do NOT guard here — caller manages _addingToCart state

    // Check if user is logged in
    final token = await SharedPref().getToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Login Required'),
            content: const Text('Please log in to add items to your cart.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white),
                child: const Text('Login'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Mock medicines — add to local cart state and show success
    if (id.startsWith('mock_')) {
      setState(() => _addingToCart.add(id));
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() => _addingToCart.remove(id));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${med['productName'] ?? 'Item'} added to cart'),
          backgroundColor: const Color(0xFF95BF47),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
      return;
    }

    // Pre-check: controlled medicines and vaccines require consultation before purchase
    final medCategory = (med['medicine_category'] ?? med['medicineCategory'] ?? '').toString();
    if (medCategory == 'Controlled' || medCategory == 'Vaccine') {
      if (mounted) _showConsultationRequiredDialog(medCategory);
      setState(() => _addingToCart.remove(id));
      return;
    }

    setState(() => _addingToCart.add(id));
    try {
      await _cartService.addItem(id, quantity);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${med['productName'] ?? med['name'] ?? 'Item'} added to cart'),
          backgroundColor: const Color(0xFF95BF47),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['requiresConsultation'] == true) {
            _showConsultationRequiredDialog((data['medicineCategory'] ?? 'Controlled').toString());
            return;
          }
          final errMsg = data is Map ? (data['message']?.toString() ?? 'Failed to add to cart') : 'Failed to add to cart';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(errMsg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ));
        }
      }
    } finally {
      if (mounted) setState(() => _addingToCart.remove(id));
    }
  }

  void _showConsultationRequiredDialog(String category) {
    final isVaccine = category.toLowerCase() == 'vaccine';
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
            child: Icon(
              isVaccine ? Icons.vaccines_rounded : Icons.medication_rounded,
              color: const Color(0xFFF59E0B), size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isVaccine ? 'Consultation Required' : 'Controlled Medicine',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ]),
        content: Text(
          isVaccine
              ? 'This vaccine can only be ordered after consultation with our doctor. Please book a consultation first.'
              : 'This medicine can only be purchased online after consultation with our doctor. It is mandatory to have a consultation with our doctor.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              isVaccine ? 'Book Consultation' : 'Connect to a Doctor Now',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchMedicines() async {
    try {
      final pharmacyId = widget.pharmacy['_id'];
      final data = await _pharmacyService.getMedicinesByPharmacyId(pharmacyId);
      if (mounted) {
        setState(() {
          // If pharmacy has no products, show Pakistani mock medicines
          _medicines = data.isNotEmpty ? data : _getPakistaniMockMedicines();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _medicines = _getPakistaniMockMedicines();
          _isLoading = false;
        });
      }
    }
  }

  /// Pakistani common medicines as fallback when pharmacy has no products
  List<Map<String, dynamic>> _getPakistaniMockMedicines() {
    return [
      {
        '_id': 'mock_1',
        'productName': 'Panadol (Paracetamol 500mg)',
        'brand': 'GSK Pakistan',
        'price': 35,
        'category': 'OTC',
        'description': 'Pain reliever and fever reducer',
        'stock_quantity': 100,
      },
      {
        '_id': 'mock_2',
        'productName': 'Brufen (Ibuprofen 400mg)',
        'brand': 'Abbott Pakistan',
        'price': 85,
        'category': 'OTC',
        'description': 'Anti-inflammatory pain reliever',
        'stock_quantity': 80,
      },
      {
        '_id': 'mock_3',
        'productName': 'Augmentin (Amoxicillin 625mg)',
        'brand': 'GSK Pakistan',
        'price': 420,
        'category': 'Prescription',
        'description': 'Antibiotic for bacterial infections',
        'stock_quantity': 50,
      },
      {
        '_id': 'mock_4',
        'productName': 'Risek (Omeprazole 20mg)',
        'brand': 'Getz Pharma',
        'price': 180,
        'category': 'Prescription',
        'description': 'Acid reflux and stomach ulcer treatment',
        'stock_quantity': 60,
      },
      {
        '_id': 'mock_5',
        'productName': 'Glucophage (Metformin 500mg)',
        'brand': 'Merck Pakistan',
        'price': 95,
        'category': 'Prescription',
        'description': 'Diabetes management medication',
        'stock_quantity': 70,
      },
      {
        '_id': 'mock_6',
        'productName': 'Lipitor (Atorvastatin 20mg)',
        'brand': 'Pfizer Pakistan',
        'price': 320,
        'category': 'Prescription',
        'description': 'Cholesterol lowering medication',
        'stock_quantity': 45,
      },
    ];
  }

  Future<void> _pickPrescription() async {
    final token = await SharedPref().getToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Login Required'),
            content: const Text('Please log in to upload a prescription.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white),
                child: const Text('Login'),
              ),
            ],
          ),
        );
      }
      return;
    }
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedPrescription = image;
      });
      _showUploadConfirmation();
    }
  }

  void _showUploadConfirmation() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CustomText(
              text: "Prescription Selected",
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: kIsWeb
                  ? Image.network(
                      _selectedPrescription!.path,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(_selectedPrescription!.path),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    label: "Cancel",
                    bgColor: Colors.grey[100],
                    labelColor: Colors.black,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    label: "Confirm & Order",
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _placePrescriptionOrder();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _placePrescriptionOrder() async {
    final pharmacyId = widget.pharmacy['_id']?.toString() ?? '';
    if (pharmacyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pharmacy ID not found'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isPlacingOrder = true);
    try {
      final medicines = widget.prescribedMedicines ?? [];
      await _pharmacyService.createPrescriptionOrder(
        pharmacyId: pharmacyId,
        medicines: medicines,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed! Pharmacy will confirm shortly.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Failed to place order';
        if (e is DioException) {
          // Extract the actual backend error message
          final data = e.response?.data;
          if (data is Map && data['message'] != null) {
            errorMsg = data['message'].toString();
          } else {
            errorMsg = 'Server error (${e.response?.statusCode ?? 'unknown'}). Please try again.';
          }
        } else {
          errorMsg = e.toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  List<dynamic> get _filteredMedicines {
    if (_searchQuery.isEmpty) return _medicines;
    return _medicines.where((m) {
      final name = (m['productName'] ?? m['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPharmacyInfo(),
                      if (widget.prescribedMedicines != null && widget.prescribedMedicines!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildPrescribedMedicinesBanner(),
                      ],
                      const SizedBox(height: 24),
                      _buildSearchBar(),
                      const SizedBox(height: 30),
                      _buildCategories(),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const CustomText(
                            text: "Available Medicines",
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                          CustomText(
                            text: "${_filteredMedicines.length} items",
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              _isLoading
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _filteredMedicines.isEmpty
                  ? SliverFillRemaining(child: _buildEmptyState())
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isDesktop ? 3 : 2,
                          mainAxisExtent: 260,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildMedicineCard(_filteredMedicines[index]),
                          childCount: _filteredMedicines.length,
                        ),
                      ),
                    ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          // View Cart (top) + Upload Rx (bottom) — stacked at bottom right
          Positioned(
            bottom: 24,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // View Cart — on top
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => MyCartScreen(
                      deliveryFee: (widget.pharmacy['delivery_fee'] as num?)?.toDouble() ?? 0.0,
                      pharmacyName: (widget.pharmacy['pharmacy_name'] ?? widget.pharmacy['name'] ?? '').toString(),
                    )),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF95BF47),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF95BF47).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text('View Cart',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Upload Rx — below
                _buildUploadRxButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primaryColor,
      leading: CustomBackButton(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryColor,
                    AppColors.primaryColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: Image.asset(
                        ImagePaths.pharmacyLogo,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomText(
                        text: widget.pharmacy['pharmacy_name']?.toString()
                            ?? widget.pharmacy['pharmacyName']?.toString()
                            ?? widget.pharmacy['user']?['name']?.toString()
                            ?? widget.pharmacy['name']?.toString()
                            ?? 'Pharmacy',
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                      const SizedBox(width: 8),
                      if (widget.pharmacy['isApproved'] == true)
                        const Icon(
                          Icons.verified_rounded,
                          color: Colors.blueAccent,
                          size: 20,
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

  Widget _buildPharmacyInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _infoItem(Icons.star_rounded, () {
            final r = widget.pharmacy['rating'];
            if (r == null || r == 0) return 'New';
            return (r is num) ? r.toStringAsFixed(1) : r.toString();
          }(), "Rating", Colors.amber),
          _divider(),
          _infoItem(
            Icons.access_time_filled_rounded,
            widget.pharmacy['openHours'] != null
                ? "${widget.pharmacy['openHours']['from']}-${widget.pharmacy['openHours']['to']}"
                : "8AM-10PM",
            "Hours",
            Colors.blue,
          ),
          _divider(),
          _infoItem(
            Icons.delivery_dining_rounded,
            widget.pharmacy['deliveryAvailable'] == true ? "Free" : "Pickup",
            "Delivery",
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        CustomText(text: value, fontWeight: FontWeight.bold, fontSize: 13),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 30, color: Colors.grey.withValues(alpha: 0.2));

  Widget _buildPrescribedMedicinesBanner() {
    final meds = widget.prescribedMedicines!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1D4ED8).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Doctor's Prescription",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                      Text('Prescribed medicines with dosage details',
                          style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${meds.length} Medicine${meds.length > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // Medicine cards — lab jaisa
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: meds.map((m) {
                final name = m is Map
                    ? (m['name'] ?? m['medicineName'] ?? '').toString()
                    : m.toString();
                final dosage = m is Map ? (m['dosage'] ?? '').toString() : '';
                final frequency = m is Map ? (m['frequency'] ?? '').toString() : '';
                final duration = m is Map ? (m['duration'] ?? '').toString() : '';
                final day = m is Map ? (m['day'] ?? '').toString() : '';
                final noon = m is Map ? (m['noon'] ?? '').toString() : '';
                final night = m is Map ? (m['night'] ?? '').toString() : '';
                final instructions = m is Map ? (m['instructions'] ?? '').toString() : '';

                // Calculate quantity: day + noon + night × duration days
                int totalQty = 0;
                try {
                  final d = int.tryParse(day) ?? 0;
                  final n = int.tryParse(noon) ?? 0;
                  final ni = int.tryParse(night) ?? 0;
                  final perDay = d + n + ni;
                  // Extract number from duration string e.g. "5 days" → 5
                  final durationMatch = RegExp(r'\d+').firstMatch(duration);
                  final durationDays = durationMatch != null ? int.tryParse(durationMatch.group(0)!) ?? 0 : 0;
                  if (perDay > 0 && durationDays > 0) {
                    totalQty = perDay * durationDays;
                  }
                } catch (_) {}

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Medicine name
                      Row(
                        children: [
                          const Icon(Icons.medication_rounded, color: Color(0xFF1D4ED8), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (totalQty > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D4ED8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Qty: $totalQty',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Dosage chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (day.isNotEmpty && day != '0')
                            _doseChip('☀️ Day: $day', const Color(0xFFF59E0B)),
                          if (noon.isNotEmpty && noon != '0')
                            _doseChip('🌤️ Noon: $noon', const Color(0xFFEF4444)),
                          if (night.isNotEmpty && night != '0')
                            _doseChip('🌙 Night: $night', const Color(0xFF6366F1)),
                          if (dosage.isNotEmpty && day.isEmpty)
                            _doseChip('💊 $dosage', const Color(0xFF0EA5E9)),
                          if (frequency.isNotEmpty && day.isEmpty)
                            _doseChip('🔄 $frequency', const Color(0xFF10B981)),
                          if (duration.isNotEmpty)
                            _doseChip('📅 $duration', const Color(0xFF64748B)),
                        ],
                      ),
                      // Calculation summary
                      if (totalQty > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            _buildQuantityText(day, noon, night, duration, totalQty),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1D4ED8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (instructions.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '📝 $instructions',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Order button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPlacingOrder ? null : _placePrescriptionOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: _isPlacingOrder
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _isPlacingOrder ? 'Placing Order...' : 'Order All Prescribed Medicines',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Center(
              child: Text(
                'Or browse & add individual medicines below',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _doseChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  String _buildQuantityText(String day, String noon, String night, String duration, int total) {
    final parts = <String>[];
    if (day.isNotEmpty && day != '0') parts.add('Day: $day');
    if (noon.isNotEmpty && noon != '0') parts.add('Noon: $noon');
    if (night.isNotEmpty && night != '0') parts.add('Night: $night');
    final perDay = parts.isNotEmpty ? parts.join(' + ') : '';
    if (perDay.isNotEmpty && duration.isNotEmpty) {
      return '($perDay) × $duration = $total tablets';
    }
    return 'Total: $total tablets';
  }

  Widget _buildSearchBar() {
    return CustomInputField(
      hintText: "Search for specific medicine...",
      borderRadius: 16,
      borderColor: const Color(0xFFF1F5F9),
      bgColor: const Color(0xFFF8FAFC),
      leadingIcon: const Icon(Icons.search_rounded, color: Colors.grey),
      onChanged: (v) => setState(() => _searchQuery = v),
    );
  }

  Widget _buildCategories() {
    final categories = [
      "Prescriptions",
      "OTC Medicines",
      "Vitamins",
      "Personal Care",
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories
            .map(
              (cat) => Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CustomText(
                  text: cat,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[700],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildMedicineImage(dynamic med) {
    final imageUrl = (med['imageUrl'] ?? med['image'] ?? '').toString().trim();
    final category = (med['category'] ?? med['medicine_category'] ?? '').toString();
    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, _, _) => _medicineIconFallback(category: category),
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Container(
                color: const Color(0xFFF8FAFC),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
      );
    }
    return _medicineIconFallback(category: category);
  }

  Widget _medicineIconFallback({String category = ''}) {
    final cat = category.toLowerCase();
    List<Color> colors;
    String emoji;

    if (cat.contains('pain') || cat.contains('relief')) {
      colors = [const Color(0xFFEF4444), const Color(0xFFDC2626)]; emoji = '💊';
    } else if (cat.contains('antibiotic')) {
      colors = [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)]; emoji = '🧬';
    } else if (cat.contains('diabetes')) {
      colors = [const Color(0xFF3B82F6), const Color(0xFF2563EB)]; emoji = '🩸';
    } else if (cat.contains('cardio') || cat.contains('heart')) {
      colors = [const Color(0xFFEC4899), const Color(0xFFDB2777)]; emoji = '❤️';
    } else if (cat.contains('gastric') || cat.contains('stomach')) {
      colors = [const Color(0xFFF59E0B), const Color(0xFFD97706)]; emoji = '🫃';
    } else if (cat.contains('allergy')) {
      colors = [const Color(0xFF10B981), const Color(0xFF059669)]; emoji = '🌿';
    } else if (cat.contains('vitamin') || cat.contains('supplement')) {
      colors = [const Color(0xFF06B6D4), const Color(0xFF0891B2)]; emoji = '💪';
    } else if (cat.contains('respiratory') || cat.contains('lung')) {
      colors = [const Color(0xFF6366F1), const Color(0xFF4F46E5)]; emoji = '🫁';
    } else {
      colors = [const Color(0xFF0036BC), const Color(0xFF1D4ED8)]; emoji = '💊';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 48)),
      ),
    );
  }

  void _showVaccineMedicineDialog(dynamic med) {
    final name = (med['productName'] ?? med['name'] ?? 'This vaccine').toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.vaccines_rounded, color: Color(0xFF7C3AED), size: 22),
          SizedBox(width: 10),
          Expanded(child: Text('Vaccine — Consultation Required', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_rounded, color: Color(0xFF7C3AED), size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(
                '$name is a vaccine.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF4C1D95), height: 1.5, fontWeight: FontWeight.w600),
              )),
            ]),
          ),
          const SizedBox(height: 16),
          const Text(
            'Vaccines must be administered under medical supervision. A consultation with our doctor is required before ordering a vaccine at your doorstep.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.6),
            textAlign: TextAlign.center,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsultationDetailsScreen()));
            },
            icon: const Icon(Icons.medical_services_rounded, size: 16),
            label: const Text('Book Consultation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _showControlledMedicineDialog(dynamic med) {
    final name = (med['productName'] ?? med['name'] ?? 'This medicine').toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_rounded, color: Color(0xFFDC2626), size: 22),
          SizedBox(width: 10),
          Expanded(child: Text('Controlled Medicine', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.lock_rounded, color: Color(0xFFDC2626), size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(
                '$name is a controlled medicine.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF7F1D1D), height: 1.5, fontWeight: FontWeight.w600),
              )),
            ]),
          ),
          const SizedBox(height: 16),
          const Text(
            'This medicine can only be purchased online after consultation with our doctor. It is mandatory to have a consultation with our doctor.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.6),
            textAlign: TextAlign.center,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsultationDetailsScreen()));
            },
            icon: const Icon(Icons.medical_services_rounded, size: 16),
            label: const Text('Connect to a Doctor Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrescriptionRequiredDialog(dynamic med) {
    final name = (med['productName'] ?? med['name'] ?? 'This medicine').toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.medical_services_rounded, color: Color(0xFFEF4444), size: 22),
          SizedBox(width: 10),
          Expanded(child: Text('Prescription Required', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.warning_rounded, color: Color(0xFFB45309), size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(
                '$name is a prescription-only medicine. A valid prescription from a licensed doctor is required.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF78350F), height: 1.5),
              )),
            ]),
          ),
          const SizedBox(height: 16),
          const Text(
            'Please consult with a doctor to get a prescription before purchasing this medicine.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
            textAlign: TextAlign.center,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // go back from pharmacy details
              // Navigate to doctor list — user can find a doctor from home
            },
            icon: const Icon(Icons.medical_services_rounded, size: 16),
            label: const Text('Connect to a Doctor Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _showOverLimitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.block_rounded, color: Color(0xFFEF4444), size: 22),
          SizedBox(width: 10),
          Expanded(child: Text('Quantity Limit Reached', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_rounded, color: Color(0xFFDC2626), size: 18),
              SizedBox(width: 10),
              Expanded(child: Text(
                'Without a prescription, a maximum of 30 units per medicine is allowed per order (3 doses/day × 10 days).',
                style: TextStyle(fontSize: 13, color: Color(0xFF7F1D1D), height: 1.5, fontWeight: FontWeight.w600),
              )),
            ]),
          ),
          const SizedBox(height: 14),
          const Text(
            'To order more than 30 units, you need a valid prescription from an iCare doctor.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
            textAlign: TextAlign.center,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK, Got It')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsultationDetailsScreen()));
            },
            icon: const Icon(Icons.medical_services_rounded, size: 16),
            label: const Text('Get a Prescription'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(dynamic med) {
    final id = med['_id']?.toString() ?? '';
    final isAdding = _addingToCart.contains(id);
    _quantities.putIfAbsent(id, () => 0);
    _qtyControllers.putIfAbsent(id, () => TextEditingController(text: _quantities[id].toString()));
    final qty = _quantities[id] ?? 0;
    final permission = (med['medicinePermission'] ?? 'OTC').toString();
    final isPrescriptionOnly = permission == 'Prescription Only';
    final medCat = (med['medicine_category'] ?? med['medicineCategory'] ?? '').toString().toLowerCase();
    final isControlled = permission == 'Controlled' ||
        (med['category'] ?? '').toString().toLowerCase() == 'controlled' ||
        medCat == 'controlled';
    final isVaccine = medCat == 'vaccine' ||
        (med['category'] ?? '').toString().toLowerCase() == 'vaccine' ||
        (med['productName'] ?? med['name'] ?? '').toString().toLowerCase().contains('vaccine') ||
        permission == 'Vaccine';

    return GestureDetector(
      // Tap card body → open details dialog
      onTap: () => _showMedicineDetails(med),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _buildMedicineImage(med),
              ),
            ),
            const SizedBox(height: 8),
            CustomText(
              text: med['productName'] ?? med['name'] ?? 'Medicine Name',
              fontWeight: FontWeight.bold,
              fontSize: 14,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              med['brand'] ?? med['manufacturer'] ?? 'Pharma Co.',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            CustomText(
              text: "PKR ${med['price'] ?? 0.0}",
              color: AppColors.primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isVaccine
                    ? const Color(0xFFEDE9FE)
                    : isControlled
                        ? const Color(0xFFFEE2E2)
                        : isPrescriptionOnly
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isVaccine ? 'Vaccine' : isControlled ? 'Controlled' : isPrescriptionOnly ? 'Rx Only' : 'OTC',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: isVaccine
                      ? const Color(0xFF6D28D9)
                      : isControlled
                          ? const Color(0xFFDC2626)
                          : isPrescriptionOnly
                              ? const Color(0xFFB45309)
                              : const Color(0xFF065F46),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Quantity controls: - | qty (typeable) | +
            GestureDetector(
              onTap: () {}, // absorb tap so card tap doesn't trigger
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  // Minus
                  GestureDetector(
                    onTap: () {
                      final current = _quantities[id] ?? 0;
                      if (current > 0) {
                        setState(() {
                          _quantities[id] = current - 1;
                          _qtyControllers[id]?.text = (current - 1).toString();
                        });
                      }
                    },
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: (qty > 0) ? AppColors.primaryColor : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.remove_rounded, size: 16,
                          color: (qty > 0) ? Colors.white : const Color(0xFF94A3B8)),
                    ),
                  ),
                  // Qty textfield
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 36,
                        child: TextField(
                          controller: _qtyControllers[id],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                          ),
                          onChanged: (v) {
                            final parsed = int.tryParse(v);
                            if (parsed != null && parsed >= 0) {
                              // Cap at 30 for non-prescription medicines
                              if (!isPrescriptionOnly && parsed > 30) {
                                _qtyControllers[id]?.text = '30';
                                _qtyControllers[id]?.selection = TextSelection.fromPosition(
                                  TextPosition(offset: '30'.length));
                                setState(() => _quantities[id] = 30);
                                _showOverLimitDialog();
                                return;
                              }
                              setState(() => _quantities[id] = parsed);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  // Plus
                  GestureDetector(
                    onTap: () {
                      final current = _quantities[id] ?? 0;
                      if (!isPrescriptionOnly && current >= 30) {
                        _showOverLimitDialog();
                        return;
                      }
                      setState(() {
                        _quantities[id] = current + 1;
                        _qtyControllers[id]?.text = (current + 1).toString();
                      });
                    },
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: AppColors.primaryColor.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            // Add to Cart button — shows when qty > 0
            if (qty > 0) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: isAdding ? null : () async {
                  if (isVaccine) {
                    _showVaccineMedicineDialog(med);
                    return;
                  }
                  if (isControlled) {
                    _showControlledMedicineDialog(med);
                    return;
                  }
                  if (isPrescriptionOnly) {
                    _showPrescriptionRequiredDialog(med);
                    return;
                  }
                  // Block order if qty > 30 without prescription
                  if (!isPrescriptionOnly && qty > 30) {
                    _showOverLimitDialog();
                    return;
                  }
                  setState(() => _addingToCart.add(id));
                  // Add qty times to cart
                  await _addToCart(med, quantity: qty);
                  if (mounted) {
                    setState(() {
                      _addingToCart.remove(id);
                      _quantities[id] = 0;
                      _qtyControllers[id]?.text = '0';
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isAdding ? Colors.grey[300] : AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: isAdding
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Add $qty to Cart',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMedicineDetails(dynamic med) {
    final name = (med['productName'] ?? med['name'] ?? 'Medicine').toString();
    final price = med['price'] ?? 0;
    final brand = (med['brand'] ?? med['manufacturer'] ?? '').toString();
    final description = (med['description'] ?? med['details'] ?? '').toString();
    final category = (med['category'] ?? '').toString();
    final inStock = (med['inStock'] ?? med['stock_quantity'] ?? 0);
    final dosage = (med['dosage'] ?? '').toString();
    final requiresPrescription = med['requiresPrescription'] == true || med['requires_prescription'] == true;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image header
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: _buildMedicineImage(med),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                if (brand.isNotEmpty)
                                  Text(brand, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Rs $price',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primaryColor)),
                              if (requiresPrescription)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                                  child: const Text('Rx Required', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B))),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (category.isNotEmpty) ...[
                        _detailChip(Icons.category_rounded, category),
                        const SizedBox(height: 6),
                      ],
                      if (dosage.isNotEmpty) ...[
                        _detailChip(Icons.medication_rounded, dosage),
                        const SizedBox(height: 6),
                      ],
                      _detailChip(
                        inStock is int && inStock > 0 ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        inStock is int && inStock > 0 ? 'In Stock ($inStock units)' : 'Out of Stock',
                        color: inStock is int && inStock > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text('Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        const SizedBox(height: 6),
                        Text(description, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5)),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                final id = med['_id']?.toString() ?? '';
                                if (_addingToCart.contains(id)) return;
                                setState(() => _addingToCart.add(id));
                                await _addToCart(med, quantity: 1);
                                if (mounted) setState(() => _addingToCart.remove(id));
                              },
                              icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                              label: const Text('Add to Cart'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
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
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String label, {Color? color}) {
    final c = color ?? const Color(0xFF64748B);
    return Row(
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, color: c)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const CustomText(
            text: "No medicines found",
            fontSize: 16,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
          const SizedBox(height: 8),
          const Text(
            "Try searching for something else",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadRxButton() {
    return InkWell(
      onTap: _pickPrescription,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primaryColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryColor.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload_file_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            CustomText(
              text: "Upload Physical Rx",
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ],
        ),
      ),
    );
  }
}
