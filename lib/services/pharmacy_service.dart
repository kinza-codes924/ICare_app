import 'package:flutter/foundation.dart';
import 'package:icare/services/api_service.dart';

class PharmacyService {
  final ApiService _apiService = ApiService();
  String? _cachedPharmacyId;

  // Get all pharmacies (public endpoint)
  Future<List<dynamic>> getAllPharmacies() async {
    final response = await _apiService.get('/pharmacy/get_all_pharmacy');
    final list = response.data['pharmacies'] as List? ?? [];
    return list.map((p) {
      final map = Map<String, dynamic>.from(p);
      final userId = map['_id']?.toString() ?? map['id']?.toString();
      map['userId'] = userId;
      map['_id'] = userId;
      map['id'] = userId;
      final displayName = map['pharmacy_name']?.toString()
          ?? map['pharmacyName']?.toString()
          ?? map['name']?.toString()
          ?? 'Pharmacy';
      map['pharmacyName'] = displayName;
      map['pharmacy_name'] = displayName;
      map['name'] = displayName;
      return map;
    }).toList();
  }

  // Get nearby pharmacies within radius (km) of given coordinates
  Future<List<dynamic>> getNearbyPharmacies(double lat, double lng, {double radius = 20}) async {
    final response = await _apiService.get(
      '/pharmacy/nearby?lat=$lat&lng=$lng&radius=$radius',
    );
    final list = response.data['pharmacies'] as List? ?? [];
    return list.map((p) {
      final map = Map<String, dynamic>.from(p);
      final userId = map['_id']?.toString() ?? map['id']?.toString();
      map['userId'] = userId;
      map['_id'] = userId;
      map['id'] = userId;
      final displayName = map['pharmacy_name']?.toString()
          ?? map['pharmacyName']?.toString()
          ?? map['name']?.toString()
          ?? 'Pharmacy';
      map['pharmacyName'] = displayName;
      map['pharmacy_name'] = displayName;
      map['name'] = displayName;
      return map;
    }).toList();
  }

  // Get pharmacy profile for logged-in pharmacist
  Future<Map<String, dynamic>> getPharmacyProfile() async {
    final response = await _apiService.get('/pharmacy/profile');
    final pharmacy = response.data['pharmacy'];
    _cachedPharmacyId = pharmacy['_id'];
    return pharmacy;
  }

  // Update pharmacy profile
  Future<Map<String, dynamic>> updatePharmacyProfile(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiService.post(
        '/pharmacy/add_pharmacy_details',
        data,
      );
      return response.data['pharmacy'] ?? response.data['existingProfile'];
    } catch (e) {
      debugPrint('Error updating pharmacy profile: $e');
      rethrow;
    }
  }

  Future<String> _getPharmacyId() async {
    try {
      if (_cachedPharmacyId != null) {
        debugPrint('✅ Using cached pharmacy ID: $_cachedPharmacyId');
        return _cachedPharmacyId!;
      }
      debugPrint('🔍 Fetching pharmacy profile from: /pharmacy/profile');
      final profile = await getPharmacyProfile();
      debugPrint('✅ Got pharmacy profile, ID: ${profile['_id']}');
      return profile['_id'];
    } catch (e) {
      debugPrint('❌ Error getting pharmacy ID: $e');
      rethrow;
    }
  }

  // Get pharmacy statistics
  Future<Map<String, dynamic>> getPharmacyStats() async {
    try {
      debugPrint('📊 Getting pharmacy stats...');
      final pharmacyId = await _getPharmacyId();
      debugPrint('✅ Pharmacy ID: $pharmacyId');

      // Get all orders for the pharmacy
      debugPrint('📦 Fetching orders from: /pharmacy/orders/pharmacy/list');
      final ordersResponse = await _apiService.get(
        '/pharmacy/orders/pharmacy/list',
      );
      final orders = (ordersResponse.data['orders'] as List?) ?? [];
      debugPrint('✅ Got ${orders.length} orders');

      // Get all medicines for the pharmacy
      debugPrint(
        '💊 Fetching medicines from: /pharmacy/products?pharmacyId=$pharmacyId',
      );
      final medicinesResponse = await _apiService.get(
        '/pharmacy/products?pharmacyId=$pharmacyId',
      );
      final medicines = (medicinesResponse.data['medicines'] as List?) ?? [];
      debugPrint('✅ Got ${medicines.length} medicines');

      // Calculate stats
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final totalOrders = orders.length;
      final pendingOrders = orders.where((o) => o['status'] == 'pending').length;
      final completedOrders = orders.where((o) => o['status'] == 'completed').length;

      final todayOrders = orders.where((o) {
        try {
          final raw = o['createdAt'];
          if (raw == null) return false;
          final dt = raw is DateTime ? raw : DateTime.parse(raw.toString());
          return dt.isAfter(todayStart) || dt.isAtSameMomentAs(todayStart);
        } catch (_) { return false; }
      }).length;

      final totalProducts = medicines.length;
      final lowStock = medicines
          .where((m) => ((m['stock_quantity'] ?? m['quantity'] ?? 0) as num) < 10)
          .length;

      final revenue = orders
          .where((o) => o['status'] == 'completed')
          .fold<double>(0, (sum, o) => sum + ((o['totalAmount'] ?? o['total_amount'] ?? 0) as num).toDouble());

      return {
        'todayOrders': todayOrders,
        'totalOrders': totalOrders,
        'pendingOrders': pendingOrders,
        'completedOrders': completedOrders,
        'totalProducts': totalProducts,
        'lowStock': lowStock,
        'revenue': revenue.toInt(),
      };
    } catch (e) {
      debugPrint('❌ Error getting pharmacy stats: $e');
      // Return default stats instead of throwing
      return {
        'todayOrders': 0,
        'totalOrders': 0,
        'pendingOrders': 0,
        'completedOrders': 0,
        'totalProducts': 0,
        'lowStock': 0,
        'revenue': 0,
      };
    }
  }

  Future<List<dynamic>> getMedicines({String? category, String? search}) async {
    final pharmacyId = await _getPharmacyId();
    return getMedicinesByPharmacyId(
      pharmacyId,
      category: category,
      search: search,
    );
  }

  Future<List<dynamic>> getMedicinesByPharmacyId(
    String pharmacyId, {
    String? category,
    String? search,
  }) async {
    String url = '/pharmacy/products?pharmacyId=$pharmacyId';
    if (category != null && category != 'All') {
      url += '&category=${Uri.encodeComponent(category)}';
    }
    if (search != null && search.isNotEmpty) {
      url += '&q=${Uri.encodeComponent(search)}';
    }
    final response = await _apiService.get(url);
    final data = response.data;
    return (data['medicines'] ?? data['products'] ?? data['data'] ?? []) as List;
  }

  Future<Map<String, dynamic>> createMedicine(Map<String, dynamic> data) async {
    final response = await _apiService.post('/pharmacy/products', data);
    return (response.data['medicine'] ?? response.data['product'] ?? response.data['data'] ?? {}) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMedicine(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiService.put('/pharmacy/products/$id', data);
    return (response.data['medicine'] ?? response.data['product'] ?? response.data['data'] ?? {}) as Map<String, dynamic>;
  }

  Future<void> deleteMedicine(String id) async {
    await _apiService.delete('/pharmacy/products/$id');
  }

  Future<Map<String, dynamic>> createPrescriptionOrder({
    required String pharmacyId,
    required List<dynamic> medicines,
    String? medicalRecordId,
    String deliveryOption = 'pickup',
    String address = '',
  }) async {
    // Backend uses POST /pharmacy/orders with items array
    // Default price Rs. 500 per medicine if not specified
    const int defaultMedicinePrice = 500;
    final items = medicines.map((m) {
      final price = (m['price'] != null && (m['price'] as num) > 0)
          ? (m['price'] as num).toInt()
          : defaultMedicinePrice;
      return {
        'productName': m['name'] ?? m['productName'] ?? '',
        'product_name': m['name'] ?? m['productName'] ?? '',
        'quantity': 1,
        'price': price,
        'dosage': m['dosage'] ?? '',
        'frequency': m['frequency'] ?? '',
      };
    }).toList();

    // Calculate total from items
    final totalAmount = items.fold<int>(
      0, (sum, item) => sum + ((item['price'] as int) * (item['quantity'] as int)),
    );

    final response = await _apiService.post('/pharmacy/orders', {
      'pharmacyId': pharmacyId,
      'items': items,
      'deliveryAddress': address,
      'totalAmount': totalAmount,
      'deliveryFee': 0,
      if (medicalRecordId != null) 'prescriptionId': medicalRecordId,
    });
    return response.data;
  }

  // Order Management
  Future<List<dynamic>> getPharmacyOrders({String? status}) async {
    String url = '/pharmacy/orders/pharmacy/list';
    if (status != null && status != 'all') {
      url += '?status=$status';
    }
    final response = await _apiService.get(url);
    return response.data['orders'] as List;
  }

  Future<Map<String, dynamic>> getOrderById(String orderId) async {
    final response = await _apiService.get('/pharmacy/orders/$orderId');
    return response.data['order'];
  }

  Future<Map<String, dynamic>> updateOrderStatus(
    String orderId,
    String status, {
    String? rejectionReason,
  }) async {
    debugPrint('🔄 Updating order $orderId to status: $status');
    final body = <String, dynamic>{'status': status};
    if (rejectionReason != null && rejectionReason.trim().isNotEmpty) {
      body['rejectionReason'] = rejectionReason.trim();
    }
    final response = await _apiService.put(
      '/pharmacy/orders/$orderId',
      body,
    );
    debugPrint('✅ Order status updated successfully');
    return response.data['order'] ?? {};
  }

  Future<void> submitOrderRating(String orderId, int rating, String comment) async {
    await _apiService.post('/pharmacy/orders/$orderId/rating', {
      'rating': rating,
      'comment': comment,
    });
  }

  // Analytics
  Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final pharmacyId = await _getPharmacyId();

      final ordersResponse = await _apiService.get(
        '/pharmacy/orders/pharmacy/list',
      );
      final orders = ordersResponse.data['orders'] as List;

      final medicinesResponse = await _apiService.get(
        '/pharmacy/products?pharmacyId=$pharmacyId',
      );
      final medicines = medicinesResponse.data['medicines'] as List;

      // Revenue from delivered/completed orders
      final completedOrders = orders
          .where((o) => ['delivered', 'completed'].contains(o['status']))
          .toList();
      final totalRevenue = completedOrders.fold<double>(
        0,
        (sum, o) => sum + (o['totalAmount'] ?? 0).toDouble(),
      );

      final totalOrders = orders.length;
      final averageOrderValue =
          totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

      // Order status breakdown
      final ordersAccepted = orders
          .where((o) =>
              !['pending', 'cancelled', 'rejected'].contains(o['status']))
          .length;
      final ordersCompleted = completedOrders.length;
      final ordersProcessing = orders
          .where((o) =>
              ['confirmed', 'preparing', 'out-for-delivery']
                  .contains(o['status']))
          .length;
      final ordersPending =
          orders.where((o) => o['status'] == 'pending').length;
      final failedDeliveries = orders
          .where((o) => ['cancelled', 'rejected'].contains(o['status']))
          .length;

      // Product metrics
      final outOfStockCount =
          medicines.where((m) => (m['stock_quantity'] ?? 0) == 0).length;

      // Top selling products — aggregate from order items
      final Map<String, Map<String, dynamic>> productSales = {};
      for (final order in orders) {
        final items = order['items'] as List? ?? [];
        for (final item in items) {
          final name =
              item['product_name']?.toString() ?? 'Unknown';
          final qty = (item['quantity'] ?? 1).toDouble();
          final price = (item['price'] ?? 0).toDouble();
          productSales.putIfAbsent(
              name, () => {'name': name, 'sales': 0.0, 'revenue': 0.0});
          productSales[name]!['sales'] =
              (productSales[name]!['sales'] as double) + qty;
          productSales[name]!['revenue'] =
              (productSales[name]!['revenue'] as double) + (qty * price);
        }
      }
      final sortedProducts = productSales.values.toList()
        ..sort((a, b) =>
            (b['sales'] as double).compareTo(a['sales'] as double));
      final topSellingProducts = sortedProducts.take(5).map((p) => {
            'name': p['name'],
            'sales': (p['sales'] as double).toInt(),
            'revenue': (p['revenue'] as double).toInt(),
          }).toList();

      return {
        'totalRevenue': totalRevenue.toInt(),
        'totalOrders': totalOrders,
        'averageOrderValue': averageOrderValue,
        'ordersAccepted': ordersAccepted,
        'ordersCompleted': ordersCompleted,
        'ordersProcessing': ordersProcessing,
        'ordersPending': ordersPending,
        'failedDeliveries': failedDeliveries,
        'outOfStockCount': outOfStockCount,
        'complaintsCount': 0,
        'averageRating': 0.0,
        'averageProcessTime': 'N/A',
        'responseTime': '< 30m',
        'topSellingProducts': topSellingProducts,
      };
    } catch (e) {
      debugPrint('Error getting analytics: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createWalkInOrder({
    required String patientName,
    required String contact,
    required String medicines,
    required String deliveryOption,
    String? address,
    String? notes,
    String? prescriptionId,
    double totalAmount = 0,
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final response = await _apiService.post('/pharmacy/orders/walk-in', {
        'patientName': patientName,
        'contact': contact,
        'medicines': medicines,
        'deliveryOption': deliveryOption,
        if (address != null && address.isNotEmpty) 'deliveryAddress': address,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (prescriptionId != null && prescriptionId.isNotEmpty) 'prescriptionId': prescriptionId,
        'totalAmount': totalAmount,
        if (items != null && items.isNotEmpty) 'items': items,
        'orderType': 'walk-in',
        'status': 'pending',
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error creating walk-in order: $e');
      rethrow;
    }
  }
}
