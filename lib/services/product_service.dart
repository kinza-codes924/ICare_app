import 'package:flutter/foundation.dart';
import 'api_service.dart';

class ProductService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> getAllProducts({
    String? category,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (category != null) queryParams['category'] = category;
      if (search != null) queryParams['search'] = search;

      final response = await _apiService.get(
        '/products',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'products': response.data['products'] ?? [],
          'count': response.data['count'] ?? 0,
        };
      }
      return {'success': false, 'message': 'Failed to fetch products'};
    } catch (e) {
      debugPrint('Get products error: $e');
      return {'success': false, 'message': 'Failed to fetch products'};
    }
  }

  Future<Map<String, dynamic>> getProductById(int productId) async {
    try {
      final response = await _apiService.get('/products/$productId');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'product': response.data['product'],
        };
      }
      return {'success': false, 'message': 'Product not found'};
    } catch (e) {
      debugPrint('Get product error: $e');
      return {'success': false, 'message': 'Failed to fetch product'};
    }
  }

  Future<Map<String, dynamic>> addToCart({
    required int productId,
    required int quantity,
  }) async {
    try {
      final response = await _apiService.post(
        '/cart/add',
        {'productId': productId, 'quantity': quantity},
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Added to cart',
        };
      }
      return {'success': false, 'message': 'Failed to add to cart'};
    } catch (e) {
      debugPrint('Add to cart error: $e');
      return {'success': false, 'message': 'Failed to add to cart'};
    }
  }

  Future<Map<String, dynamic>> getCart() async {
    try {
      final response = await _apiService.get('/cart');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'cart': response.data['cart'] ?? [],
          'total': response.data['total'] ?? '0.00',
          'count': response.data['count'] ?? 0,
        };
      }
      return {'success': false, 'message': 'Failed to fetch cart'};
    } catch (e) {
      debugPrint('Get cart error: $e');
      return {'success': false, 'message': 'Failed to fetch cart'};
    }
  }

  Future<Map<String, dynamic>> updateCartItem({
    required int cartItemId,
    required int quantity,
  }) async {
    try {
      final response = await _apiService.put(
        '/cart/$cartItemId',
        {'quantity': quantity},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Cart updated'};
      }
      return {'success': false, 'message': 'Failed to update cart'};
    } catch (e) {
      debugPrint('Update cart error: $e');
      return {'success': false, 'message': 'Failed to update cart'};
    }
  }

  Future<Map<String, dynamic>> removeFromCart(int cartItemId) async {
    try {
      final response = await _apiService.delete('/cart/$cartItemId');

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Item removed'};
      }
      return {'success': false, 'message': 'Failed to remove item'};
    } catch (e) {
      debugPrint('Remove from cart error: $e');
      return {'success': false, 'message': 'Failed to remove item'};
    }
  }

  Future<Map<String, dynamic>> checkout({
    required String deliveryAddress,
    int? pharmacyId,
  }) async {
    try {
      final response = await _apiService.post(
        '/cart/checkout',
        {
          'deliveryAddress': deliveryAddress,
          if (pharmacyId != null) 'pharmacyId': pharmacyId,
        },
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Order placed successfully',
          'order': response.data['order'],
        };
      }
      return {'success': false, 'message': 'Failed to place order'};
    } catch (e) {
      debugPrint('Checkout error: $e');
      return {'success': false, 'message': 'Failed to place order'};
    }
  }
}
