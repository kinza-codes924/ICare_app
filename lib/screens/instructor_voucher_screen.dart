import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';

class InstructorVoucherScreen extends StatefulWidget {
  const InstructorVoucherScreen({super.key});

  @override
  State<InstructorVoucherScreen> createState() => _InstructorVoucherScreenState();
}

class _InstructorVoucherScreenState extends State<InstructorVoucherScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _vouchers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  Future<void> _loadVouchers() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/vouchers');
      if (mounted) setState(() { _vouchers = res.data['vouchers'] ?? []; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showCreateDialog() async {
    final codeCtrl = TextEditingController();
    final discountCtrl = TextEditingController();
    DateTime? expiresAt;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create Discount Voucher', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Voucher Code *',
                    hintText: 'e.g. SAVE50',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.confirmation_number_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: discountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Discount % (1–100) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.percent_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        expiresAt == null
                            ? 'No expiry date'
                            : 'Expires: ${expiresAt!.day}/${expiresAt!.month}/${expiresAt!.year}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (d != null) setS(() => expiresAt = d);
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: const Text('Set Expiry'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0,
              ),
              onPressed: () async {
                final code = codeCtrl.text.trim().toUpperCase();
                final discount = int.tryParse(discountCtrl.text.trim()) ?? 0;
                if (code.isEmpty || discount < 1 || discount > 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid code and discount (1–100%)'), backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _api.post('/vouchers', {
                    'code': code,
                    'discount': discount,
                    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Voucher "$code" created!'), backgroundColor: Colors.green),
                    );
                    _loadVouchers();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteVoucher(String id, String code) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Voucher'),
        content: Text('Delete voucher "$code"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.delete('/vouchers/$id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voucher deleted'), backgroundColor: Colors.green),
        );
        _loadVouchers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Discount Vouchers', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New Voucher'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vouchers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No vouchers yet', style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      const Text('Create a discount voucher for your students', style: TextStyle(fontSize: 13, color: Color(0xFFCBD5E1))),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showCreateDialog,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create Voucher'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadVouchers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _vouchers.length,
                    itemBuilder: (_, i) {
                      final v = _vouchers[i];
                      final code = v['code']?.toString() ?? '';
                      final discount = v['discount']?.toString() ?? '';
                      final usedBy = v['usedBy'];
                      final isUsed = usedBy != null;
                      final expiresAt = v['expiresAt'];
                      String? expiryText;
                      if (expiresAt != null) {
                        try {
                          final d = DateTime.parse(expiresAt.toString());
                          final isExpired = d.isBefore(DateTime.now());
                          expiryText = isExpired ? 'Expired ${d.day}/${d.month}/${d.year}' : 'Expires ${d.day}/${d.month}/${d.year}';
                        } catch (_) {}
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isUsed ? const Color(0xFFE2E8F0) : AppColors.primaryColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: isUsed ? const Color(0xFFF1F5F9) : AppColors.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.confirmation_number_rounded,
                                  color: isUsed ? const Color(0xFF94A3B8) : AppColors.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(code, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                                        const SizedBox(width: 10),
                                        if (!isUsed)
                                          GestureDetector(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: code));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('"$code" copied!'), duration: const Duration(seconds: 1)),
                                              );
                                            },
                                            child: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF94A3B8)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$discount% off · ${isUsed ? "Used" : "Available"}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isUsed ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
                                      ),
                                    ),
                                    if (expiryText != null)
                                      Text(expiryText, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              ),
                              if (!isUsed)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                                  tooltip: 'Delete',
                                  onPressed: () => _deleteVoucher(v['_id']?.toString() ?? '', code),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
