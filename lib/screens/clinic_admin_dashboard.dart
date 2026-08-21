import 'package:flutter/material.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';

// Dashboard for a clinic-scoped admin account — single view of every
// booking (telehealth appointment, in-person appointment, or front-desk
// walk-in) for all doctors under their standalone iCare Clinic. This is
// the "hamare paas kaise information aayegi" visibility the client asked
// for, specific to standalone clinics (independent telehealth doctors
// still just get their own personal notification).
class ClinicAdminDashboard extends StatefulWidget {
  const ClinicAdminDashboard({super.key});

  @override
  State<ClinicAdminDashboard> createState() => _ClinicAdminDashboardState();
}

class _ClinicAdminDashboardState extends State<ClinicAdminDashboard> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  List<dynamic> _bookings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.get('/clinic-admin/bookings');
      final data = response.data;
      if (data is Map && data['success'] == true) {
        setState(() {
          _bookings = data['bookings'] ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _error = data is Map ? data['message']?.toString() : 'Failed to load bookings';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _typeColor(String type) => switch (type) {
        'telehealth' => Colors.indigo,
        'walk-in' => Colors.teal,
        _ => AppColors.primaryColor,
      };

  IconData _typeIcon(String type) => switch (type) {
        'telehealth' => Icons.video_call_outlined,
        'walk-in' => Icons.storefront_outlined,
        _ => Icons.event_available_outlined,
      };

  String _typeLabel(String type) => switch (type) {
        'telehealth' => 'Telehealth',
        'walk-in' => 'Walk-in',
        _ => 'Appointment',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Clinic Dashboard'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _bookings.isEmpty
                      ? ListView(
                          children: const [
                            Padding(
                              padding: EdgeInsets.only(top: 80),
                              child: Center(child: Text('No bookings yet.', style: TextStyle(color: Color(0xFF64748B)))),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _bookings.length,
                          itemBuilder: (context, index) {
                            final b = _bookings[index];
                            final type = b['bookingType']?.toString() ?? 'appointment';
                            final color = _typeColor(type);
                            final createdAt = DateTime.tryParse(b['createdAt']?.toString() ?? '');
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
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(_typeIcon(type), color: color, size: 18),
                                ),
                                title: Text(
                                  b['patientName']?.toString() ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${_typeLabel(type)} · Dr. ${b['doctorName'] ?? ''} · ${b['status'] ?? ''}'
                                  '${createdAt != null ? ' · ${createdAt.day}/${createdAt.month}/${createdAt.year}' : ''}',
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (b['paymentStatus'] == 'paid' ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    b['paymentStatus'] == 'paid' ? 'Paid' : 'Unpaid',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: b['paymentStatus'] == 'paid' ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
