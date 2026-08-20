import 'package:flutter/material.dart';
import 'package:icare/screens/in_consultation_prescription_form.dart';
import 'package:icare/services/doctor_service.dart';
import 'package:icare/utils/theme.dart';

// Front-desk walk-in patients referred to this doctor by a receptionist.
// These have appointmentId:null so they never show up in the normal
// appointments list — this screen is their only doctor-facing entry point.
class DoctorWalkinPatientsScreen extends StatefulWidget {
  const DoctorWalkinPatientsScreen({super.key});

  @override
  State<DoctorWalkinPatientsScreen> createState() => _DoctorWalkinPatientsScreenState();
}

class _DoctorWalkinPatientsScreenState extends State<DoctorWalkinPatientsScreen> {
  final DoctorService _service = DoctorService();
  List<Map<String, dynamic>> _walkins = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _service.getWalkinPatients();
    if (!mounted) return;
    setState(() {
      _walkins = List<Map<String, dynamic>>.from(result['walkins'] ?? []);
      _loading = false;
    });
  }

  void _openPatient(Map<String, dynamic> w) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InConsultationPrescriptionForm(
          consultationId: w['_id']?.toString() ?? '',
          walkInPatientName: w['patientName']?.toString(),
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Walk-In Patients'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _walkins.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Center(child: Text('No walk-in patients yet.', style: TextStyle(color: Color(0xFF64748B)))),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _walkins.length,
                      itemBuilder: (context, index) {
                        final w = _walkins[index];
                        final hasRx = w['hasPrescription'] == true;
                        final paid = w['paymentStatus'] == 'paid';
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
                                color: AppColors.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.person_outline, color: AppColors.primaryColor, size: 18),
                            ),
                            title: Text(w['patientName']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              [
                                if ((w['reason']?.toString() ?? '').isNotEmpty) w['reason'].toString(),
                                hasRx ? 'Prescription added' : 'No prescription yet',
                                paid ? 'Paid' : 'Unpaid',
                              ].join(' · '),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _openPatient(w),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
