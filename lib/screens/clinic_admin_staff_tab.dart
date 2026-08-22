import 'package:flutter/material.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';

// One field in a staff-creation/edit form beyond name/email/password —
// e.g. Doctor's "specialization", Lab's "lab_name", Pharmacy's
// "pharmacy_name", Receptionist's "speciality" (+ assigned-doctors chips,
// handled separately since only Receptionist has that concept).
class StaffExtraField {
  final String key; // request body field name
  final String label;
  const StaffExtraField({required this.key, required this.label});
}

// Shared tab for a clinic admin managing one role's staff (Receptionist,
// Doctor, Lab, Pharmacy) under their own clinic — every /clinic-admin/*
// endpoint below already derives clinicId server-side from the caller's own
// ClinicAdminProfile, so this widget never needs a clinic picker or to send
// a clinicId anywhere.
class ClinicAdminStaffTab extends StatefulWidget {
  final String role; // display label, e.g. 'Receptionist'
  final String listEndpoint; // e.g. '/clinic-admin/receptionists'
  final String createEndpoint; // e.g. '/clinic-admin/receptionists'
  final String listKey; // response JSON key holding the array, e.g. 'receptionists'
  final List<StaffExtraField> extraFields;
  // Only Receptionist assigns doctors from the clinic's own doctor list —
  // when true, the create/edit dialogs fetch and show doctor chips.
  final bool showDoctorAssignment;

  const ClinicAdminStaffTab({
    super.key,
    required this.role,
    required this.listEndpoint,
    required this.createEndpoint,
    required this.listKey,
    this.extraFields = const [],
    this.showDoctorAssignment = false,
  });

  @override
  State<ClinicAdminStaffTab> createState() => _ClinicAdminStaffTabState();
}

class _ClinicAdminStaffTabState extends State<ClinicAdminStaffTab> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<dynamic> _items = [];
  List<dynamic> _doctors = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final futures = [
        _api.get(widget.listEndpoint),
        if (widget.showDoctorAssignment) _api.get('/clinic-admin/doctors'),
      ];
      final results = await Future.wait(futures);
      final listData = results[0].data;
      final doctorsData = widget.showDoctorAssignment ? results[1].data : null;
      setState(() {
        _items = listData is Map ? (listData[widget.listKey] ?? []) : [];
        _doctors = doctorsData is Map ? (doctorsData['doctors'] ?? []) : [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(Map item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${item['name'] ?? widget.role}?'),
        content: const Text('This account will be deactivated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.delete('${widget.listEndpoint}/${item['_id']}');
      _load();
    } catch (_) {}
  }

  Future<void> _showFormDialog({Map? existing}) async {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: existing?['email']?.toString() ?? '');
    final passwordCtrl = TextEditingController();
    final extraCtrls = {
      for (final f in widget.extraFields) f.key: TextEditingController(text: existing?[f.key]?.toString() ?? ''),
    };
    final selectedDoctorIds = <String>{
      if (isEdit) ...(existing['doctors'] as List? ?? []).map((d) => d['_id']?.toString() ?? ''),
    };
    String? error;
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: Text(isEdit ? 'Edit ${widget.role}' : 'New ${widget.role}'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isEdit) ...[
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                    const SizedBox(height: 10),
                    TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  for (final f in widget.extraFields) ...[
                    TextField(controller: extraCtrls[f.key], decoration: InputDecoration(labelText: f.label)),
                    const SizedBox(height: 10),
                  ],
                  if (widget.showDoctorAssignment) ...[
                    const SizedBox(height: 6),
                    const Text('Assign Doctors', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    if (_doctors.isEmpty)
                      const Text('No approved doctors in this clinic yet.', style: TextStyle(color: Colors.grey))
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
                  ],
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
                      if (!isEdit &&
                          (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty || passwordCtrl.text.isEmpty)) {
                        setModal(() => error = 'Name, email and password are required');
                        return;
                      }
                      setModal(() {
                        submitting = true;
                        error = null;
                      });
                      try {
                        final body = {
                          if (!isEdit) ...{
                            'name': nameCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'password': passwordCtrl.text,
                          },
                          for (final f in widget.extraFields) f.key: extraCtrls[f.key]!.text.trim(),
                          if (widget.showDoctorAssignment) 'doctorIds': selectedDoctorIds.toList(),
                        };
                        final response = isEdit
                            ? await _api.put('${widget.listEndpoint}/${existing['_id']}', body)
                            : await _api.post(widget.createEndpoint, body);
                        final data = response.data;
                        if (data is Map && data['success'] == true) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                        } else {
                          setModal(() {
                            submitting = false;
                            error = data is Map ? data['message']?.toString() : 'Failed';
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
                  : Text(isEdit ? 'Save' : 'Create'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
        icon: const Icon(Icons.add),
        label: Text('New ${widget.role}'),
        backgroundColor: AppColors.primaryColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 80),
                          child: Center(child: Text('No ${widget.role.toLowerCase()}s yet.')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final subtitleParts = <String>[
                          item['email']?.toString() ?? '',
                          (item['isApproved'] == true) ? 'Approved' : 'Pending approval',
                          for (final f in widget.extraFields)
                            if ((item[f.key]?.toString() ?? '').isNotEmpty) '${f.label}: ${item[f.key]}',
                          if (widget.showDoctorAssignment)
                            (item['doctors'] as List? ?? []).isEmpty
                                ? 'No doctors assigned'
                                : (item['doctors'] as List).map((d) => d['name']?.toString() ?? '').join(', '),
                        ];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(item['name']?.toString() ?? ''),
                            subtitle: Text(subtitleParts.where((s) => s.isNotEmpty).join('\n')),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () => _showFormDialog(existing: item),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                  onPressed: () => _remove(item),
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
