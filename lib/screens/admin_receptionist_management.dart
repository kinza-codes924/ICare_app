import 'package:flutter/material.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

class AdminReceptionistManagement extends StatefulWidget {
  const AdminReceptionistManagement({super.key});

  @override
  State<AdminReceptionistManagement> createState() => _AdminReceptionistManagementState();
}

class _AdminReceptionistManagementState extends State<AdminReceptionistManagement> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<dynamic> _receptionists = [];
  List<dynamic> _doctors = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.get('/admin/receptionists'),
        _api.get('/admin/approved-users', queryParameters: {'role': 'Doctor'}),
      ]);
      final receptionistsData = results[0].data;
      final doctorsData = results[1].data;
      setState(() {
        _receptionists = receptionistsData is Map ? (receptionistsData['receptionists'] ?? []) : [];
        _doctors = doctorsData is Map ? (doctorsData['users'] ?? []) : [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final selectedDoctorIds = <String>{};
    String? error;
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: const Text('New Receptionist'),
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
                  const Text('Assign Doctors', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (_doctors.isEmpty)
                    const Text('No approved doctors found.', style: TextStyle(color: Colors.grey))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _doctors.map((d) {
                        final id = d['_id']?.toString() ?? '';
                        final name = d['name']?.toString() ?? '';
                        final selected = selectedDoctorIds.contains(id);
                        return FilterChip(
                          label: Text(name),
                          selected: selected,
                          onSelected: (v) => setModal(() {
                            if (v) {
                              selectedDoctorIds.add(id);
                            } else {
                              selectedDoctorIds.remove(id);
                            }
                          }),
                        );
                      }).toList(),
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
                      setModal(() {
                        submitting = true;
                        error = null;
                      });
                      try {
                        final response = await _api.post('/admin/receptionists', {
                          'name': nameCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'password': passwordCtrl.text,
                          'doctorIds': selectedDoctorIds.toList(),
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

  Future<void> _showEditDoctorsDialog(Map receptionist) async {
    final currentDoctorIds = (receptionist['doctors'] as List? ?? [])
        .map((d) => d['_id']?.toString() ?? '')
        .toSet();
    final selectedDoctorIds = {...currentDoctorIds};
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: Text('Edit Doctors — ${receptionist['name'] ?? ''}'),
          content: SizedBox(
            width: 400,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _doctors.map((d) {
                final id = d['_id']?.toString() ?? '';
                final name = d['name']?.toString() ?? '';
                final selected = selectedDoctorIds.contains(id);
                return FilterChip(
                  label: Text(name),
                  selected: selected,
                  onSelected: (v) => setModal(() {
                    if (v) {
                      selectedDoctorIds.add(id);
                    } else {
                      selectedDoctorIds.remove(id);
                    }
                  }),
                );
              }).toList(),
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
                          '/admin/receptionists/${receptionist['_id']}/doctors',
                          {'doctorIds': selectedDoctorIds.toList()},
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
        leading: const CustomBackButton(),
        title: const Text('Receptionists'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Receptionist'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _receptionists.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Center(child: Text('No receptionists yet.')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _receptionists.length,
                      itemBuilder: (context, index) {
                        final r = _receptionists[index];
                        final doctors = (r['doctors'] as List? ?? []).map((d) => d['name']?.toString() ?? '').join(', ');
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(r['name']?.toString() ?? ''),
                            subtitle: Text(
                              '${r['email'] ?? ''}\n'
                              '${(r['isApproved'] == true) ? 'Approved' : 'Pending approval'} • '
                              '${doctors.isEmpty ? 'No doctors assigned' : doctors}',
                            ),
                            isThreeLine: true,
                            trailing: TextButton(
                              onPressed: () => _showEditDoctorsDialog(r),
                              child: const Text('Edit Doctors'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
