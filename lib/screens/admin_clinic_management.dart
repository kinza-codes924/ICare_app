import 'package:flutter/material.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';

// Standalone iCare Clinics — same static ids as lib/data/icare_clinics_data.dart.
const Map<String, String> kIcareClinics = {
  'dental': 'iCare Dental & Aesthetic Centre',
  'derma': 'iCare Derma & Skin Care',
  'mother_child': 'iCare Mother & Child Care Centre',
  'physio': 'iCare Physiotherapy',
  'psychiatry': 'iCare Psychiatry',
  'lifestyle_wellness': 'iCare Lifestyle & Wellness',
};

// Admin screen for the standalone-clinic notification/dashboard system the
// client asked for: assign doctors to a clinic, and create clinic-admin
// accounts that get notified about every booking under that clinic.
class AdminClinicManagement extends StatefulWidget {
  const AdminClinicManagement({super.key});

  @override
  State<AdminClinicManagement> createState() => _AdminClinicManagementState();
}

class _AdminClinicManagementState extends State<AdminClinicManagement> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<dynamic> _clinicAdmins = [];
  List<dynamic> _doctors = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.get('/admin/clinic-admins'),
        _api.get('/admin/doctors-with-clinic'),
      ]);
      final clinicAdminsData = results[0].data;
      final doctorsData = results[1].data;
      setState(() {
        _clinicAdmins = clinicAdminsData is Map ? (clinicAdminsData['clinicAdmins'] ?? []) : [];
        _doctors = doctorsData is Map ? (doctorsData['doctors'] ?? []) : [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCreateClinicAdminDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String? selectedClinicId;
    String? error;
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: const Text('New Clinic Admin'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                  const SizedBox(height: 10),
                  TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Clinic', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedClinicId,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: kIcareClinics.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setModal(() => selectedClinicId = v),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty || passwordCtrl.text.isEmpty) {
                        setModal(() => error = 'Name, email and password are required');
                        return;
                      }
                      if (selectedClinicId == null) {
                        setModal(() => error = 'Please select a clinic');
                        return;
                      }
                      setModal(() {
                        submitting = true;
                        error = null;
                      });
                      try {
                        final response = await _api.post('/admin/clinic-admins', {
                          'name': nameCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'password': passwordCtrl.text,
                          'clinicId': selectedClinicId,
                        });
                        final data = response.data;
                        if (data is Map && data['success'] == true) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                        } else {
                          setModal(() {
                            submitting = false;
                            error = data is Map ? data['message']?.toString() : 'Failed to create';
                          });
                        }
                      } catch (e) {
                        setModal(() {
                          submitting = false;
                          error = e.toString();
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignDoctorClinic(Map doctor) async {
    String? selectedClinicId = doctor['clinicId']?.toString();
    if (selectedClinicId != null && selectedClinicId.isEmpty) selectedClinicId = null;
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: Text('Assign Clinic — ${doctor['name'] ?? ''}'),
          content: SizedBox(
            width: 380,
            child: DropdownButtonFormField<String?>(
              initialValue: selectedClinicId,
              decoration: const InputDecoration(labelText: 'Clinic', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('None (independent telehealth doctor)')),
                ...kIcareClinics.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
              ],
              onChanged: (v) => setModal(() => selectedClinicId = v),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      setModal(() => submitting = true);
                      try {
                        final response = await _api.put(
                          '/admin/doctors/${doctor['_id']}/clinic',
                          {'clinicId': selectedClinicId},
                        );
                        final data = response.data;
                        if (data is Map && data['success'] == true) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                        } else {
                          setModal(() => submitting = false);
                        }
                      } catch (_) {
                        setModal(() => submitting = false);
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('iCare Clinics'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Clinic Admins'),
            Tab(text: 'Assign Doctors'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _showCreateClinicAdminDialog,
              icon: const Icon(Icons.add),
              label: const Text('New Clinic Admin'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _load,
                  child: _clinicAdmins.isEmpty
                      ? ListView(
                          children: const [
                            Padding(
                              padding: EdgeInsets.only(top: 80),
                              child: Center(child: Text('No clinic admins yet.')),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _clinicAdmins.length,
                          itemBuilder: (context, index) {
                            final a = _clinicAdmins[index];
                            final clinicName = kIcareClinics[a['clinicId']?.toString()] ?? a['clinicId']?.toString() ?? '';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(a['name']?.toString() ?? ''),
                                subtitle: Text('${a['email'] ?? ''}\n$clinicName'),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
                RefreshIndicator(
                  onRefresh: _load,
                  child: _doctors.isEmpty
                      ? ListView(
                          children: const [
                            Padding(
                              padding: EdgeInsets.only(top: 80),
                              child: Center(child: Text('No approved doctors found.')),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _doctors.length,
                          itemBuilder: (context, index) {
                            final d = _doctors[index];
                            final clinicId = d['clinicId']?.toString();
                            final clinicName = (clinicId == null || clinicId.isEmpty)
                                ? 'Independent (telehealth)'
                                : (kIcareClinics[clinicId] ?? clinicId);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(d['name']?.toString() ?? ''),
                                subtitle: Text(clinicName),
                                trailing: TextButton(
                                  onPressed: () => _assignDoctorClinic(d),
                                  child: const Text('Assign Clinic'),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
