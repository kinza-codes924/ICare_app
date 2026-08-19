import 'package:flutter/material.dart';
import 'package:icare/screens/reception_visit_summary.dart';
import 'package:icare/screens/reception_create_invoice_screen.dart';
import 'package:icare/services/reception_service.dart';
import 'package:icare/utils/theme.dart';

// Confirmed/paid walk-in visits and standalone invoices, merged into one
// chronological list — lets the receptionist look back at completed work.
class ReceptionRecordsScreen extends StatefulWidget {
  const ReceptionRecordsScreen({super.key});

  @override
  State<ReceptionRecordsScreen> createState() => _ReceptionRecordsScreenState();
}

class _ReceptionRecordsScreenState extends State<ReceptionRecordsScreen> {
  final ReceptionService _service = ReceptionService();
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _service.getRecords();
    if (!mounted) return;
    setState(() {
      _records = List<Map<String, dynamic>>.from(result['records'] ?? []);
      _loading = false;
    });
  }

  Future<void> _openRecord(Map<String, dynamic> record) async {
    final isVisit = record['recordType'] == 'visit';
    if (isVisit) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReceptionVisitSummary(
            consultationId: record['id'].toString(),
            patientName: record['title']?.toString() ?? '',
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReceptionInvoiceSummaryScreen(
            invoiceId: record['id'].toString(),
            clientName: record['title']?.toString() ?? '',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Records'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _records.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Center(child: Text('No confirmed records yet.', style: TextStyle(color: Color(0xFF64748B)))),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _records.length,
                      itemBuilder: (context, index) {
                        final r = _records[index];
                        final isVisit = r['recordType'] == 'visit';
                        final amount = (r['amount'] as num?)?.toDouble() ?? 0;
                        final createdAt = DateTime.tryParse(r['createdAt']?.toString() ?? '');
                        return Card(
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
                                color: (isVisit ? Colors.teal : Colors.indigo).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isVisit ? Icons.person_outline : Icons.receipt_long_outlined,
                                color: isVisit ? Colors.teal : Colors.indigo,
                                size: 18,
                              ),
                            ),
                            title: Text(r['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${isVisit ? 'Walk-in visit' : 'Invoice'} · PKR ${amount.toStringAsFixed(0)}'
                              '${createdAt != null ? ' · ${createdAt.day}/${createdAt.month}/${createdAt.year}' : ''}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _openRecord(r),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
