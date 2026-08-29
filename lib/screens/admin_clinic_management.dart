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

const Map<String, IconData> _kClinicIcons = {
  'dental': Icons.sentiment_satisfied_alt_rounded,
  'derma': Icons.face_retouching_natural_rounded,
  'mother_child': Icons.family_restroom_rounded,
  'physio': Icons.accessibility_new_rounded,
  'psychiatry': Icons.psychology_rounded,
  'lifestyle_wellness': Icons.spa_rounded,
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
    _tabController.addListener(() => setState(() {}));
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
        builder: (ctx, setModal) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
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
                          child: Icon(Icons.admin_panel_settings_outlined, color: AppColors.primaryColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text('New Clinic Admin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailCtrl,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedClinicId,
                      decoration: InputDecoration(
                        labelText: 'Clinic',
                        prefixIcon: const Icon(Icons.storefront_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: kIcareClinics.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) => setModal(() => selectedClinicId = v),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        const SizedBox(width: 8),
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: submitting
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Create'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editClinicAdmin(Map admin) async {
    String? selectedClinicId = admin['clinicId']?.toString();
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Clinic — ${admin['name'] ?? ''}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: selectedClinicId,
                    decoration: InputDecoration(labelText: 'Clinic', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    items: kIcareClinics.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setModal(() => selectedClinicId = v),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: submitting || selectedClinicId == null
                            ? null
                            : () async {
                                setModal(() => submitting = true);
                                try {
                                  final response = await _api.put('/admin/clinic-admins/${admin['_id']}', {'clinicId': selectedClinicId});
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteClinicAdmin(Map admin) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Clinic Admin?'),
        content: Text('This will deactivate the login for ${admin['name'] ?? 'this account'}. This can be undone from the main Admin Users list.'),
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
      await _api.delete('/admin/clinic-admins/${admin['_id']}');
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove clinic admin')),
        );
      }
    }
  }

  Future<void> _toggleWalkin(Map doctor, bool enabled) async {
    final id = doctor['_id']?.toString() ?? '';
    if (id.isEmpty) return;
    // Optimistic flip so the switch responds immediately; rolled back below
    // if the server rejects it.
    setState(() => doctor['walkinEnabled'] = enabled);
    try {
      final response = await _api.put('/admin/doctors/$id/walkin', {'walkinEnabled': enabled});
      final data = response.data;
      if (!(data is Map && data['success'] == true)) throw Exception('failed');
    } catch (_) {
      if (mounted) {
        setState(() => doctor['walkinEnabled'] = !enabled);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update walk-in access')),
        );
      }
    }
  }

  Future<void> _assignDoctorClinic(Map doctor) async {
    String? selectedClinicId = doctor['clinicId']?.toString();
    if (selectedClinicId != null && selectedClinicId.isEmpty) selectedClinicId = null;
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assign Clinic — ${doctor['name'] ?? ''}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedClinicId,
                    decoration: InputDecoration(labelText: 'Clinic', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('None (independent telehealth doctor)')),
                      ...kIcareClinics.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setModal(() => selectedClinicId = v),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      const SizedBox(width: 8),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 100),
          child: Column(
            children: [
              Icon(icon, size: 48, color: const Color(0xFFCBD5E1)),
              const SizedBox(height: 12),
              Text(message, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('iCare Clinics'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: AppColors.primaryColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Clinic Admins'),
                Tab(text: 'Assign Doctors'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
        child: _tabController.index == 0
            ? FloatingActionButton.extended(
                key: const ValueKey('fab-clinic-admin'),
                onPressed: _showCreateClinicAdminDialog,
                backgroundColor: AppColors.primaryColor,
                icon: const Icon(Icons.add),
                label: const Text('New Clinic Admin'),
              )
            : const SizedBox.shrink(key: ValueKey('fab-none')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _load,
                  child: _clinicAdmins.isEmpty
                      ? _emptyState('No clinic admins yet.', Icons.admin_panel_settings_outlined)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                          itemCount: _clinicAdmins.length,
                          itemBuilder: (context, index) {
                            final a = _clinicAdmins[index];
                            final clinicId = a['clinicId']?.toString() ?? '';
                            final clinicName = kIcareClinics[clinicId] ?? clinicId;
                            final icon = _kClinicIcons[clinicId] ?? Icons.storefront_outlined;
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(milliseconds: 250 + index * 40),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) => Opacity(
                                opacity: value,
                                child: Transform.translate(offset: Offset(0, (1 - value) * 12), child: child),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryColor.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(icon, color: AppColors.primaryColor, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(a['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                            const SizedBox(height: 2),
                                            Text(a['email']?.toString() ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryColor.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                clinicName,
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryColor),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8)),
                                        onSelected: (v) {
                                          if (v == 'edit') _editClinicAdmin(a);
                                          if (v == 'delete') _deleteClinicAdmin(a);
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit Clinic')])),
                                          PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Remove', style: TextStyle(color: Colors.red))])),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                RefreshIndicator(
                  onRefresh: _load,
                  child: _doctors.isEmpty
                      ? _emptyState('No approved doctors found.', Icons.medical_services_outlined)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: _doctors.length,
                          itemBuilder: (context, index) {
                            final d = _doctors[index];
                            final clinicId = d['clinicId']?.toString();
                            final isIndependent = clinicId == null || clinicId.isEmpty;
                            final clinicName = isIndependent ? 'Independent (telehealth)' : (kIcareClinics[clinicId] ?? clinicId);
                            final icon = isIndependent ? Icons.videocam_outlined : (_kClinicIcons[clinicId] ?? Icons.storefront_outlined);
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(milliseconds: 250 + index * 30),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) => Opacity(
                                opacity: value,
                                child: Transform.translate(offset: Offset(0, (1 - value) * 12), child: child),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (isIndependent ? const Color(0xFF64748B) : AppColors.primaryColor).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(icon, color: isIndependent ? const Color(0xFF64748B) : AppColors.primaryColor, size: 20),
                                  ),
                                  title: Text(d['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(clinicName, style: const TextStyle(fontSize: 13)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Walk-ins are a front-desk feature, so
                                      // the admin picks which doctors get the
                                      // card rather than every doctor seeing it.
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('Walk-in', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                          Switch(
                                            value: d['walkinEnabled'] == true,
                                            onChanged: (v) => _toggleWalkin(d, v),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 4),
                                      OutlinedButton(
                                        onPressed: () => _assignDoctorClinic(d),
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Assign'),
                                      ),
                                    ],
                                  ),
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
