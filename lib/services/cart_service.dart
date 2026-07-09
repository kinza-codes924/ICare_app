import 'package:flutter/foundation.dart';
import 'package:icare/services/api_service.dart';

class CartService {
  final ApiService _apiService = ApiService();

  // Get user's cart
  Future<Map<String, dynamic>> getCart() async {
    try {
      final response = await _apiService.get('/cart');
      return {'success': true, 'cart': response.data['cart'] ?? [], 'total': response.data['total'] ?? '0'};
    } catch (e) {
      debugPrint('CartService.getCart error: $e');
      return {'success': false, 'cart': [], 'total': '0'};
    }
  }

  // Add item to cart — backend: POST /cart/add { productId, quantity }
  Future<Map<String, dynamic>> addItem(String productId, int quantity, {String? prescriptionId}) async {
    try {
      final response = await _apiService.post('/cart/add', {
        'productId': productId,
        'quantity': quantity,
        if (prescriptionId != null) 'prescriptionId': prescriptionId,
      });
      return response.data;
    } catch (e) {
      debugPrint('CartService.addItem error: $e');
      rethrow;
    }
  }

  // Update item quantity — backend: PUT /cart/:id { quantity }
  Future<Map<String, dynamic>> updateItem(String cartItemId, int quantity) async {
    try {
      final response = await _apiService.put('/cart/$cartItemId', {'quantity': quantity});
      return response.data;
    } catch (e) {
      debugPrint('CartService.updateItem error: $e');
      rethrow;
    }
  }

  // Remove item — backend: DELETE /cart/:id
  Future<void> removeItem(String cartItemId) async {
    try {
      await _apiService.delete('/cart/$cartItemId');
    } catch (e) {
      debugPrint('CartService.removeItem error: $e');
      rethrow;
    }
  }

  // Clear entire cart
  Future<void> clearCart() async {
    try {
      await _apiService.delete('/cart');
    } catch (e) {
      debugPrint('CartService.clearCart error: $e');
    }
  }

  // Checkout
  Future<Map<String, dynamic>> checkout({
    required String deliveryAddress,
    String? pharmacyId,
  }) async {
    try {
      final response = await _apiService.post('/cart/checkout', {
        'deliveryAddress': deliveryAddress,
        if (pharmacyId != null) 'pharmacyId': pharmacyId,
      });
      return response.data;
    } catch (e) {
      debugPrint('CartService.checkout error: $e');
      rethrow;
    }
  }
}
