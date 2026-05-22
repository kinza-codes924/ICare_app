import 'package:icare/services/api_service.dart';

class OrderService {
  final ApiService _apiService = ApiService();

  // Create order from cart
  Future<Map<String, dynamic>> createOrderFromCart({
    required String pharmacyId,
    required String deliveryOption,
    String? address,
  }) async {
    final response = await _apiService.post('/pharmacy/orders', {
      'pharmacyId': pharmacyId,
      'deliveryOption': deliveryOption,
      'address': address,
    });
    return response.data['order'];
  }

  // Get user's orders
  Future<List<dynamic>> getMyOrders({String? status}) async {
    String url = '/pharmacy/orders/my';
    if (status != null && status.isNotEmpty) {
      url += '?status=$status';
    }
    final response = await _apiService.get(url);
    return response.data['orders'] as List;
  }

  // Get order by ID
  Future<Map<String, dynamic>> getOrderById(String orderId) async {
    final response = await _apiService.get('/pharmacy/orders/$orderId');
    return response.data['order'];
  }

  // Cancel order
  Future<Map<String, dynamic>> cancelOrder(
    String orderId,
    String reason,
  ) async {
    final response = await _apiService.put('/pharmacy/orders/$orderId/cancel', {
      'reason': reason,
    });
    return response.data['order'];
  }
}
