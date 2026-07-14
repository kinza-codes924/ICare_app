import 'package:flutter/material.dart';
import 'package:icare/services/payment_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

/// Admin: all payments across the platform with filters (type, method,
/// status, date range, amount range) + per-recipient revenue totals —
/// "is pharmacy / doctor / lab / instructor ke kitne paise aaye".
class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  final _service = PaymentService();

  // Filters
  String _type = '';      // '' = all
  String _method = '';    // '' = all
  String _status = 'paid';
  DateTimeRange? _dateRange;
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  String? _payeeId;
  String? _payeeName;

  // Data
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _totals = [];
  num _grandTotal = 0;
  num _grandDiscount = 0;
  num _grandCount = 0;

  static const _navy = Color(0xFF0F172A);
  static const _slate = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _service.adminReport(
        type: _type.isEmpty ? null : _type,
        method: _method.isEmpty ? null : _method,
        status: _status,
        payeeId: _payeeId,
        from: _dateRange?.start,
        to: _dateRange?.end.add(const Duration(days: 1)),
        minAmount: double.tryParse(_minCtrl.text.trim()),
        maxAmount: double.tryParse(_maxCtrl.text.trim()),
      );
      if (!mounted) return;
      setState(() {
        _payments = ((res['payments'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _totals = ((res['totals'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _grandTotal = (res['grandTotal'] as num?) ?? 0;
        _grandDiscount = (res['grandDiscount'] as num?) ?? 0;
        _grandCount = (res['grandCount'] as num?) ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _type = ''; _method = ''; _status = 'paid';
      _dateRange = null; _payeeId = null; _payeeName = null;
      _minCtrl.clear(); _maxCtrl.clear();
    });
    _load();
  }

  String _pkr(num v) => 'PKR ${NumberFormat('#,##0').format(v)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: const Text('Payments & Revenue',
            style: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Gilroy-Bold')),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _filtersPanel(),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 40),
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: _slate)),
                  ]),
                ),
              )
            else ...[
              _grandCards(),
              const SizedBox(height: 16),
              if (_totals.isNotEmpty) _totalsPanel(),
              const SizedBox(height: 16),
              _paymentsPanel(),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Filters ────────────────────────────────────────────────────────────────

  Widget _filtersPanel() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Filters',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _navy)),
              const Spacer(),
              if (_payeeId != null)
                InputChip(
                  label: Text('Recipient: ${_payeeName ?? ''}',
                      style: const TextStyle(fontSize: 12)),
                  onDeleted: () { setState(() { _payeeId = null; _payeeName = null; }); _load(); },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _dropdown('Type', _type, const {
                '': 'All types', 'course': 'Courses', 'appointment': 'Doctor Appointments',
                'lab': 'Lab Tests', 'pharmacy': 'Pharmacy Orders',
              }, (v) => setState(() => _type = v)),
              _dropdown('Method', _method, const {
                '': 'All methods', 'safepay': 'Online (Card/Wallet)', 'cash': 'Cash',
              }, (v) => setState(() => _method = v)),
              _dropdown('Status', _status, const {
                'paid': 'Paid', 'pending': 'Pending', 'failed': 'Failed', 'all': 'All statuses',
              }, (v) => setState(() => _status = v)),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(now.year - 2),
                    lastDate: now.add(const Duration(days: 1)),
                    initialDateRange: _dateRange,
                  );
                  if (picked != null) setState(() => _dateRange = picked);
                },
                icon: const Icon(Icons.date_range_rounded, size: 17),
                label: Text(
                  _dateRange == null
                      ? 'Date range'
                      : '${DateFormat('d MMM').format(_dateRange!.start)} – ${DateFormat('d MMM yy').format(_dateRange!.end)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              SizedBox(width: 110, child: _amountField(_minCtrl, 'Min PKR')),
              SizedBox(width: 110, child: _amountField(_maxCtrl, 'Max PKR')),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.filter_alt_rounded, size: 17),
                label: const Text('Apply'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
              TextButton(onPressed: _clearFilters, child: const Text('Clear')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown(String label, String value, Map<String, String> items, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: const TextStyle(fontSize: 13, color: _navy),
          items: items.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => onChanged(v ?? ''),
        ),
      ),
    );
  }

  Widget _amountField(TextEditingController c, String hint) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Grand totals ───────────────────────────────────────────────────────────

  Widget _grandCards() {
    Widget card(String label, String value, IconData icon, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEDF2F7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _slate, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 10),
              FittedBox(
                child: Text(value,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _navy)),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        card('Total Received', _pkr(_grandTotal), Icons.account_balance_wallet_rounded, const Color(0xFF10B981)),
        const SizedBox(width: 12),
        card('Total Discounts', _pkr(_grandDiscount), Icons.discount_rounded, const Color(0xFFF59E0B)),
        const SizedBox(width: 12),
        card('Transactions', '$_grandCount', Icons.receipt_long_rounded, const Color(0xFF2563EB)),
      ],
    );
  }

  // ── Per-recipient totals ───────────────────────────────────────────────────

  static const _typeMeta = <String, (String, Color)>{
    'course': ('Instructor', Color(0xFFD97706)),
    'appointment': ('Doctor', Color(0xFF2563EB)),
    'lab': ('Lab', Color(0xFF9333EA)),
    'pharmacy': ('Pharmacy', Color(0xFF059669)),
  };

  Widget _totalsPanel() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revenue by Recipient',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _navy)),
          const SizedBox(height: 4),
          const Text('Tap a row to filter payments for that recipient',
              style: TextStyle(fontSize: 12, color: _slate)),
          const SizedBox(height: 12),
          ..._totals.map((t) {
            final meta = _typeMeta[t['type']] ?? ('Other', _slate);
            final selected = _payeeId == t['payeeId']?.toString();
            return InkWell(
              onTap: () {
                setState(() {
                  _payeeId = t['payeeId']?.toString();
                  _payeeName = t['payeeName']?.toString();
                });
                _load();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                decoration: selected
                    ? BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12))
                    : null,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: meta.$2.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(meta.$1,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: meta.$2)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(t['payeeName']?.toString() ?? 'Unknown',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _navy)),
                    ),
                    Text('${t['count']} orders',
                        style: const TextStyle(fontSize: 12, color: _slate)),
                    const SizedBox(width: 16),
                    Text(_pkr((t['totalAmount'] as num?) ?? 0),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _navy)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Payments list ──────────────────────────────────────────────────────────

  Widget _paymentsPanel() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payments (${_payments.length})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _navy)),
          const SizedBox(height: 8),
          if (_payments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text('No payments match these filters',
                    style: TextStyle(color: _slate, fontSize: 13)),
              ),
            )
          else
            ..._payments.map(_paymentTile),
        ],
      ),
    );
  }

  Widget _paymentTile(Map<String, dynamic> p) {
    final meta = _typeMeta[p['type']] ?? ('Other', _slate);
    final status = p['status']?.toString() ?? '';
    final statusColor = switch (status) {
      'paid' => const Color(0xFF10B981),
      'pending' || 'created' => const Color(0xFFF59E0B),
      _ => const Color(0xFFEF4444),
    };
    final amount = (p['amount'] as num?) ?? 0;
    final original = (p['originalAmount'] as num?) ?? amount;
    final discount = (p['discountAmount'] as num?) ?? 0;
    final created = DateTime.tryParse(p['createdAt']?.toString() ?? '')?.toLocal();
    final isCash = p['method'] == 'cash';

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: meta.$2.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            switch (p['type']) {
              'course' => Icons.school_rounded,
              'appointment' => Icons.medical_services_rounded,
              'lab' => Icons.science_rounded,
              _ => Icons.local_pharmacy_rounded,
            },
            color: meta.$2, size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${p['payerName'] ?? 'User'}  →  ${p['payeeName'] ?? '-'}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _navy),
              ),
            ),
            Text(_pkr(amount),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _navy)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              if (created != null)
                Text(DateFormat('d MMM yyyy • h:mm a').format(created),
                    style: const TextStyle(fontSize: 11.5, color: _slate)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF64748B).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(isCash ? 'CASH' : 'CARD/WALLET',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _slate)),
              ),
            ],
          ),
        ),
        children: [
          _detailRow('Order placed', created != null ? DateFormat('EEEE, d MMMM yyyy • h:mm a').format(created) : '-'),
          _detailRow('Description', p['notes']?.toString() ?? '-'),
          _detailRow('Original price', _pkr(original)),
          if (discount > 0) _detailRow('Discount${p['voucherCode'] != null ? ' (${p['voucherCode']})' : ''}', '- ${_pkr(discount)}'),
          _detailRow('Total charged', _pkr(amount), bold: true),
          _detailRow('Payment method', isCash ? 'Cash' : 'Safepay (Card / Wallet / GPay)'),
          if (p['paidAt'] != null)
            _detailRow('Paid at', DateFormat('d MMM yyyy • h:mm a')
                .format(DateTime.tryParse(p['paidAt'].toString())?.toLocal() ?? DateTime.now())),
          if (isCash && p['cashCollectedAt'] != null)
            _detailRow('Cash collected', DateFormat('d MMM yyyy • h:mm a')
                .format(DateTime.tryParse(p['cashCollectedAt'].toString())?.toLocal() ?? DateTime.now())),
          _detailRow('Reference', p['safepayTracker']?.toString() ?? p['_id']?.toString() ?? '-'),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12, color: _slate)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                    color: _navy)),
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDF2F7)),
      ),
      child: child,
    );
  }
}
