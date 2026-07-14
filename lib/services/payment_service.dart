import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Safepay payment gateway service.
///
/// Flow:
///  1. [createPayment] — backend calculates the amount server-side, creates a
///     Safepay session and returns a hosted checkout URL.
///  2. The app opens the checkout URL (new tab on web, external browser on mobile).
///  3. The app polls [verifyPayment] until the backend confirms the payment
///     with Safepay directly (status == 'paid'). Fulfillment (e.g. course
///     enrollment) happens on the backend at that moment.
class PaymentService {
  final ApiService _api = ApiService();

  /// Creates a payment on the backend.
  /// Returns:
  ///  { free: true }                                      → nothing to pay
  ///  { free: false, paymentId, checkoutUrl, amount, tracker } → open checkoutUrl
  Future<Map<String, dynamic>> createPayment({
    required String type, // 'course' | 'appointment' | 'lab' | 'pharmacy'
    required String refId,
    String method = 'safepay', // 'safepay' | 'cash' (lab collection / pharmacy COD)
    String? voucherCode,
    String? redirectUrl,
    String? cancelUrl,
  }) async {
    final response = await _api.post('/payments/create', {
      'type': type,
      'refId': refId,
      'method': method,
      if (voucherCode != null && voucherCode.isNotEmpty) 'voucherCode': voucherCode,
      if (redirectUrl != null) 'redirectUrl': redirectUrl,
      if (cancelUrl != null) 'cancelUrl': cancelUrl,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Payee (lab/pharmacy) confirms cash was received — fulfills the payment.
  Future<Map<String, dynamic>> markCashCollected(String paymentId) async {
    final response = await _api.post('/payments/$paymentId/cash-collected', {});
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Same, but looked up by booking/order id (lab & pharmacy screens).
  Future<Map<String, dynamic>> markCashCollectedByRef({
    required String type, // 'lab' | 'pharmacy'
    required String refId,
  }) async {
    final response = await _api.post('/payments/cash-collected-by-ref', {
      'type': type,
      'refId': refId,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Payee's cash payments still awaiting collection.
  Future<List<Map<String, dynamic>>> pendingCash() async {
    final response = await _api.get('/payments/pending-cash');
    final list = (response.data['payments'] as List?) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Admin revenue report with filters.
  Future<Map<String, dynamic>> adminReport({
    String? type,
    String? payeeId,
    String? method,
    String? status,
    DateTime? from,
    DateTime? to,
    double? minAmount,
    double? maxAmount,
  }) async {
    final response = await _api.get('/payments/report', queryParameters: {
      if (type != null && type.isNotEmpty) 'type': type,
      if (payeeId != null && payeeId.isNotEmpty) 'payeeId': payeeId,
      if (method != null && method.isNotEmpty) 'method': method,
      if (status != null && status.isNotEmpty) 'status': status,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      if (minAmount != null) 'minAmount': minAmount.toString(),
      if (maxAmount != null) 'maxAmount': maxAmount.toString(),
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Asks the backend to confirm the payment status with Safepay.
  /// Returns e.g. { success, status: 'paid'|'pending'|..., fulfilled: bool }
  Future<Map<String, dynamic>> verifyPayment(String paymentId) async {
    final response = await _api.get('/payments/$paymentId/verify');
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Polls [verifyPayment] every [interval] until the payment is paid,
  /// [timeout] elapses, or [isCancelled] returns true.
  /// Returns true if the payment was confirmed as paid + fulfilled.
  Future<bool> pollUntilPaid(
    String paymentId, {
    Duration interval = const Duration(seconds: 4),
    Duration timeout = const Duration(minutes: 15),
    bool Function()? isCancelled,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (isCancelled != null && isCancelled()) return false;
      try {
        final res = await verifyPayment(paymentId);
        if (res['status'] == 'paid') return true;
        if (res['status'] == 'failed' || res['status'] == 'expired') return false;
      } catch (e) {
        debugPrint('PaymentService.pollUntilPaid error (will retry): $e');
      }
      await Future.delayed(interval);
    }
    return false;
  }

  /// User's own payment history.
  Future<List<Map<String, dynamic>>> myPayments() async {
    final response = await _api.get('/payments/my');
    final list = (response.data['payments'] as List?) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
