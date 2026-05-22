import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import '../utils/shared_pref.dart';

final _sharedPref = SharedPref();

class LabSupplyService {
  static Future<Map<String, dynamic>> getSupplies() async {
    try {
      final token = await _sharedPref.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/lab-supplies'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load supplies');
      }
    } catch (e) {
      throw Exception('Error loading supplies: $e');
    }
  }

  static Future<Map<String, dynamic>> getLowStockAlerts() async {
    try {
      final token = await _sharedPref.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/lab-supplies/low-stock'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load low stock alerts');
      }
    } catch (e) {
      throw Exception('Error loading low stock alerts: $e');
    }
  }

  static Future<Map<String, dynamic>> addSupply({
    required String itemName,
    required String category,
    required int currentStock,
    required int minStockLevel,
    required String unit,
    String? supplier,
    DateTime? expiryDate,
    String? notes,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/lab-supplies'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'itemName': itemName,
          'category': category,
          'currentStock': currentStock,
          'minStockLevel': minStockLevel,
          'unit': unit,
          if (supplier != null) 'supplier': supplier,
          if (expiryDate != null) 'expiryDate': expiryDate.toIso8601String(),
          if (notes != null) 'notes': notes,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to add supply');
      }
    } catch (e) {
      throw Exception('Error adding supply: $e');
    }
  }

  static Future<Map<String, dynamic>> updateStock({
    required String supplyId,
    required int currentStock,
    required String action, // 'set', 'add', 'subtract'
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/lab-supplies/$supplyId/stock'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'currentStock': currentStock, 'action': action}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to update stock');
      }
    } catch (e) {
      throw Exception('Error updating stock: $e');
    }
  }

  static Future<Map<String, dynamic>> deleteSupply(String supplyId) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/lab-supplies/$supplyId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to delete supply');
      }
    } catch (e) {
      throw Exception('Error deleting supply: $e');
    }
  }
}
