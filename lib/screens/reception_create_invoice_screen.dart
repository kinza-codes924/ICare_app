import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:icare/screens/reception_dashboard.dart';
import 'package:icare/services/reception_service.dart';
import 'package:icare/services/api_config.dart';
import 'package:icare/utils/theme.dart';

// Standalone invoice creation — no walk-in patient, no consultation, no
// doctor. Just a client name, freeform line items, and an SRB tax rate,
// generated in one submit rather than accruing incrementally like
// procedures during a visit (there's no persisted document until submit).
class ReceptionCreateInvoiceScreen extends StatefulWidget {
  const ReceptionCreateInvoiceScreen({super.key});

  @override
  State<ReceptionCreateInvoiceScreen> createState() => _ReceptionCreateInvoiceScreenState();
}

class _ReceptionCreateInvoiceScreenState extends State<ReceptionCreateInvoiceScreen> {
  final ReceptionService _service = ReceptionService();
  final _clientNameCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController(text: '15');
  final List<Map<String, dynamic>> _items = [];
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _taxRateCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold<double>(0, (sum, i) => sum + ((i['price'] as num?)?.toDouble() ?? 0));
  double get _taxRate => double.tryParse(_taxRateCtrl.text.trim()) ?? 0;
  double get _taxAmount => _subtotal * (_taxRate / 100);
  double get _total => _subtotal + _taxAmount;

  Future<void> _addItem() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String? dialogError;

    final item = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.add_shopping_cart_outlined, color: AppColors.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text('Add Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Item name',
                    prefixIcon: const Icon(Icons.edit_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Price (PKR)',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 12),
                  Text(dialogError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty) {
                          setModal(() => dialogError = 'Item name is required');
                          return;
                        }
                        Navigator.pop(ctx, {
                          'name': nameCtrl.text.trim(),
                          'price': double.tryParse(priceCtrl.text.trim()) ?? 0,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (item != null) setState(() => _items.add(item));
  }

  Future<void> _submit() async {
    if (_clientNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Client name is required');
      return;
    }
    if (_items.isEmpty) {
      setState(() => _error = 'Add at least one item');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await _service.createInvoice(
      clientName: _clientNameCtrl.text.trim(),
      items: _items,
      taxRate: _taxRate,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      final invoice = result['invoice'] as Map;
      final invoiceId = invoice['_id']?.toString() ?? '';
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReceptionInvoiceSummaryScreen(
            invoiceId: invoiceId,
            clientName: _clientNameCtrl.text.trim(),
          ),
        ),
      );
    } else {
      setState(() {
        _submitting = false;
        _error = result['message']?.toString() ?? 'Failed to create invoice';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Create Invoice'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Back to Front Desk',
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Client Name', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _clientNameCtrl,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          const Text('Items', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No items added yet.', style: TextStyle(color: Color(0xFF64748B))),
            )
          else
            ..._items.asMap().entries.map((e) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.receipt_outlined, color: AppColors.primaryColor, size: 18),
                    ),
                    title: Text(e.value['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('PKR ${(e.value['price'] as num?)?.toStringAsFixed(0) ?? '0'}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => setState(() => _items.removeAt(e.key)),
                    ),
                  ),
                )),
          OutlinedButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Item'),
          ),
          const SizedBox(height: 24),
          const Text('SRB Sales Tax Rate (%)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _taxRateCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _summaryRow('Subtotal', _subtotal),
                  _summaryRow('SRB Sales Tax (${_taxRate.toStringAsFixed(0)}%)', _taxAmount),
                  const Divider(),
                  _summaryRow('Total', _total, bold: true),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Generate Invoice'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 16 : 14,
      color: bold ? AppColors.primaryColor : const Color(0xFF64748B),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('PKR ${amount.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}

class ReceptionInvoiceSummaryScreen extends StatelessWidget {
  final String invoiceId;
  final String clientName;

  const ReceptionInvoiceSummaryScreen({
    super.key,
    required this.invoiceId,
    required this.clientName,
  });

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open — please try again')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Invoice Created'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: 'Back to Front Desk',
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const ReceptionDashboard()),
              (route) => false,
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
                    const SizedBox(height: 12),
                    Text(clientName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const Text('Invoice generated', style: TextStyle(color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openUrl(context, '${ApiConfig.baseUrl}/invoices/standalone/$invoiceId/pdf'),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Print Invoice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ReceptionDashboard()),
                  (route) => false,
                );
              },
              child: const Text('Back to Front Desk'),
            ),
          ],
        ),
      ),
    );
  }
}
