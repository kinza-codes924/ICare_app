import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

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
    String discountType = 'percent'; // 'percent' | 'flat'
    String? selectedCourseId; // null = valid on any course

    List<dynamic> courses = [];
    try {
      final res = await LmsService().getInstructorCourses();
      courses = res['courses'] ?? [];
    } catch (_) {}

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create Discount Voucher', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service type — only Courses is wired up today
                  const Text('Service Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Courses'),
                        selected: true,
                        onSelected: (_) {},
                        selectedColor: AppColors.primaryColor.withValues(alpha: 0.15),
                      ),
                      ChoiceChip(
                        label: const Text('Consultation (coming soon)'),
                        selected: false,
                        onSelected: null,
                      ),
                      ChoiceChip(
                        label: const Text('Lab Test (coming soon)'),
                        selected: false,
                        onSelected: null,
                      ),
                      ChoiceChip(
                        label: const Text('Pharmacy (coming soon)'),
                        selected: false,
                        onSelected: null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
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
                  DropdownButtonFormField<String>(
                    initialValue: selectedCourseId,
                    decoration: const InputDecoration(
                      labelText: 'Applies To',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Any of my courses')),
                      ...courses.map((c) => DropdownMenuItem(
                            value: c['_id']?.toString(),
                            child: Text(c['title']?.toString() ?? 'Untitled', overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setS(() => selectedCourseId = v),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'percent', label: Text('% Off')),
                            ButtonSegment(value: 'flat', label: Text('Flat Amount')),
                          ],
                          selected: {discountType},
                          onSelectionChanged: (s) => setS(() => discountType = s.first),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: discountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: discountType == 'percent' ? 'Discount % (1–100) *' : 'Discount Amount (PKR) *',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(discountType == 'percent' ? Icons.percent_rounded : Icons.payments_outlined),
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
                final isValid = discountType == 'percent'
                    ? (discount >= 1 && discount <= 100)
                    : (discount >= 1);
                if (code.isEmpty || !isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(discountType == 'percent'
                          ? 'Enter a valid code and discount (1–100%)'
                          : 'Enter a valid code and a discount amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _api.post('/vouchers', {
                    'code': code,
                    'discount': discount,
                    'discountType': discountType,
                    if (selectedCourseId != null) 'courseId': selectedCourseId,
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
        leading: const CustomBackButton(),
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
                      final discountType = v['discountType']?.toString() ?? 'percent';
                      final discountLabel = discountType == 'flat' ? 'PKR $discount off' : '$discount% off';
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
                                      '$discountLabel · ${isUsed ? "Used" : "Available"}',
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
