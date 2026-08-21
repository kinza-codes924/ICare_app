import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/models/consultation_timer.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/services/medical_record_service.dart';
import 'package:icare/utils/api_constants.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/doc_preview_widget.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  final String initialTab;
  const AdminDashboard({super.key, this.initialTab = 'Pending'});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _users = [];
  // Extra profile details fetched per-user (keyed by userId)
  final Map<String, Map<String, dynamic>> _extraDetails = {};
  // LMS course-verification records (documents uploaded via the LMS purchase
  // flow, stored separately from the signup-time verificationDetails field),
  // keyed by userId.
  final Map<String, Map<String, dynamic>> _lmsVerifications = {};
  String _currentTab =
      'Pending'; // 'Pending', 'Student', 'Pharmacy', 'Laboratory', 'Instructor', 'PatientRecords'

  // Patient Records state
  final MedicalRecordService _medicalRecordService = MedicalRecordService();
  List<dynamic> _allPatientRecords = [];
  List<dynamic> _filteredPatientRecords = [];
  bool _isLoadingRecords = false;
  String _recordSearchQuery = '';
  String? _selectedDoctorFilter;
  List<String> _doctorNames = [];

  // Leave Requests & Certificates state
  List<Map<String, dynamic>> _leaveRequests = [];
  List<Map<String, dynamic>> _certificates = [];
  bool _isLoadingLeaves = false;
  bool _isLoadingCerts = false;

  // Community tab state
  List<dynamic> _communityPosts = [];
  List<dynamic> _communityTopics = [];
  bool _isLoadingCommunity = false;
  final Set<String> _expandedPostIds = {};

  // Doctor Tools tab state
  List<dynamic> _expiringLicenses = [];
  List<dynamic> _noReferrerDoctors = [];
  bool _isLoadingDoctorTools = false;

  // FAQs tab state
  List<dynamic> _faqs = [];
  bool _isLoadingFaqs = false;

  final ScrollController _tabScrollController = ScrollController();

  @override
  void dispose() {
    _tabScrollController.dispose();
    super.dispose();
  }

  // Route Cloudinary/Vercel Blob URLs through the backend's authenticated
  // proxy endpoints instead of opening the raw storage URL directly — same
  // pattern as AttachmentViewer._resolveUrl.
  Future<String> _resolveDocUrl(String original) async {
    try {
      final token = await SharedPref().getToken() ?? '';
      if (token.isEmpty) return original;
      final encoded = Uri.encodeComponent(original);
      final t = Uri.encodeComponent(token);
      if (original.contains('res.cloudinary.com')) {
        return '${ApiConstants.baseUrl}/upload/doc-stream?url=$encoded&token=$t';
      }
      if (original.contains('blob.vercel-storage.com')) {
        return '${ApiConstants.baseUrl}/upload/blob-download?url=$encoded&token=$t';
      }
      return original;
    } catch (_) {
      return original;
    }
  }

  Future<void> _openDocument(BuildContext context, String url, String label) async {
    // Base64 data URIs (legacy Work-With-Us uploads) have no remote host to
    // proxy through — open directly.
    if (url.startsWith('data:')) {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (_) {}
      return;
    }
    final proxyUrl = await _resolveDocUrl(url);
    if (!context.mounted) return;
    await showDocPreview(context, proxyUrl, label);
  }

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _fetchUsers();
    _checkClinicScoped();
  }

  // A clinic-scoped admin (created via Admin > iCare Clinics > New Clinic
  // Admin) is still role:'admin' at the auth level, but should land on the
  // clinic-specific bookings dashboard instead of the platform-wide admin
  // screen. Checked once on load, silently no-ops for regular admins.
  Future<void> _checkClinicScoped() async {
    try {
      final response = await _apiService.get('/clinic-admin/me');
      final data = response.data;
      if (data is Map && data['clinicId'] != null && mounted) {
        context.go('/clinic-admin/dashboard');
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(AdminDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _currentTab = widget.initialTab;
      _fetchUsers();
    }
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);

    try {
      final String endpoint;
      if (_currentTab == 'Pending') {
        endpoint = '/admin/pending-users';
      } else if (_currentTab == 'PatientRecords') {
        await _fetchPatientRecords();
        return;
      } else {
        // Map tab name to backend role
        final roleMap = {
          'Doctor': 'doctor',
          'Student': 'student',
          'Pharmacy': 'pharmacy',
          'Laboratory': 'lab',
          'Instructor': 'instructor',
        };
        final role = roleMap[_currentTab] ?? _currentTab.toLowerCase();
        endpoint = '/admin/approved-users?role=$role';
      }

      final response = await _apiService.get(endpoint);

      if (response.statusCode == 200) {
        final data = response.data;
        final users = List<dynamic>.from(data['users'] ?? []);
        setState(() { _users = users; });

        // Fetch extra details per-user in background (backend pending-users only returns 6 fields)
        if (_currentTab == 'Pending') {
          _fetchExtraDetailsForPendingUsers(users);
        }
        if (_currentTab == 'Pending' || _currentTab == 'Student') {
          _fetchLmsVerifications();
        }
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLmsVerifications() async {
    try {
      final r = await _apiService.get('/verification/all');
      if (r.statusCode == 200 && r.data is Map && r.data['success'] == true) {
        final list = List<dynamic>.from(r.data['verifications'] ?? []);
        final map = <String, Map<String, dynamic>>{};
        for (final v in list) {
          final rawUserId = v['userId'];
          final userId = (rawUserId is Map ? rawUserId['_id'] : rawUserId)?.toString() ?? '';
          if (userId.isEmpty) continue;
          map[userId] = Map<String, dynamic>.from(v as Map);
        }
        if (mounted) setState(() => _lmsVerifications
          ..clear()
          ..addAll(map));
      }
    } catch (_) {}
  }

  Future<void> _fetchExtraDetailsForPendingUsers(List<dynamic> users) async {
    for (final u in users) {
      final id = u['_id']?.toString() ?? '';
      final role = u['role']?.toString() ?? '';
      if (id.isEmpty || _extraDetails.containsKey(id)) continue;
      try {
        if (role == 'doctor') {
          final r = await _apiService.get('/doctors/$id');
          if (r.statusCode == 200) {
            final d = r.data;
            final doc = (d is Map && d['doctor'] != null) ? d['doctor'] : (d is Map ? d : null);
            if (doc != null && mounted) {
              setState(() => _extraDetails[id] = Map<String, dynamic>.from(doc as Map));
            }
          }
        } else if (role == 'pharmacy') {
          // Try common pharmacy profile endpoints
          for (final ep in ['/pharmacy/profile/$id', '/pharmacy/$id']) {
            try {
              final r = await _apiService.get(ep);
              if (r.statusCode == 200 && r.data is Map) {
                if (mounted) setState(() => _extraDetails[id] = Map<String, dynamic>.from(r.data as Map));
                break;
              }
            } catch (_) {}
          }
        } else if (role == 'lab') {
          for (final ep in ['/labs/$id', '/lab/$id', '/lab/profile/$id']) {
            try {
              final r = await _apiService.get(ep);
              if (r.statusCode == 200 && r.data is Map) {
                if (mounted) setState(() => _extraDetails[id] = Map<String, dynamic>.from(r.data as Map));
                break;
              }
            } catch (_) {}
          }
        } else if (role == 'instructor' || role == 'student') {
          // verificationDetails already included in pending-users response — just copy it
          final vd = u['verificationDetails'];
          if (vd is Map && vd.isNotEmpty && mounted) {
            setState(() => _extraDetails[id] = Map<String, dynamic>.from(vd));
          }
        }
      } catch (_) {}
    }
  }

  void _onTabChanged(String tab) {
    if (_currentTab == tab) return;
    setState(() {
      _currentTab = tab;
      _users = [];
    });
    if (tab == 'PatientRecords') {
      _fetchPatientRecords();
    } else if (tab == 'LeaveRequests') {
      _fetchLeaveRequests();
    } else if (tab == 'Certificates') {
      _fetchCertificates();
    } else if (tab == 'Community') {
      if (mounted) setState(() => _isLoading = false);
      _fetchCommunityData();
    } else if (tab == 'DoctorTools') {
      if (mounted) setState(() => _isLoading = false);
      _fetchDoctorToolsData();
    } else if (tab == 'FAQs') {
      if (mounted) setState(() => _isLoading = false);
      _fetchFaqs();
    } else if (tab == 'Commission') {
      if (mounted) setState(() => _isLoading = false);
    } else {
      _fetchUsers();
    }
  }

  Future<void> _fetchLeaveRequests() async {
    setState(() => _isLoadingLeaves = true);
    try {
      final r = await _apiService.get('/admin/leave-requests');
      if (mounted) setState(() => _leaveRequests = List<Map<String, dynamic>>.from(r.data['leaveRequests'] ?? []));
    } catch (_) {}
    if (mounted) setState(() => _isLoadingLeaves = false);
  }

  Future<void> _updateLeaveStatus(String doctorId, String requestId, String status) async {
    try {
      await _apiService.put('/admin/leave-requests/$doctorId/$requestId', {'status': status});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Leave request $status'),
          backgroundColor: status == 'approved' ? Colors.green : Colors.red,
        ));
        _fetchLeaveRequests();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _fetchCertificates() async {
    setState(() => _isLoadingCerts = true);
    try {
      final r = await _apiService.get('/admin/credentials');
      if (mounted) setState(() => _certificates = List<Map<String, dynamic>>.from(r.data['credentials'] ?? []));
    } catch (_) {}
    if (mounted) setState(() => _isLoadingCerts = false);
  }

  Future<void> _updateCredentialStatus(String doctorId, String credId, String status) async {
    try {
      await _apiService.put('/admin/credentials/$doctorId/$credId', {'status': status});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Certificate $status'),
          backgroundColor: status == 'verified' ? Colors.green : Colors.red,
        ));
        _fetchCertificates();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _fetchPatientRecords() async {
    setState(() => _isLoadingRecords = true);
    try {
      final response = await _apiService.get('/medical-records/all');
      if (response.statusCode == 200) {
        final records = response.data['records'] is List ? response.data['records'] as List : [];
        final doctors = records
            .map((r) => r['doctor']?['name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        setState(() {
          _allPatientRecords = records;
          _filteredPatientRecords = records;
          _doctorNames = doctors;
        });
      }
    } catch (e) {
      debugPrint('Error fetching patient records: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRecords = false);
    }
  }

  void _filterPatientRecords() {
    setState(() {
      _filteredPatientRecords = _allPatientRecords.where((r) {
        final patientName = r['patient']?['name']?.toString().toLowerCase() ?? '';
        final patientPhone = r['patient']?['phoneNumber']?.toString() ?? '';
        final doctorName = r['doctor']?['name']?.toString() ?? '';
        final matchesSearch = _recordSearchQuery.isEmpty ||
            patientName.contains(_recordSearchQuery.toLowerCase()) ||
            patientPhone.contains(_recordSearchQuery);
        final matchesDoctor = _selectedDoctorFilter == null ||
            doctorName == _selectedDoctorFilter;
        return matchesSearch && matchesDoctor;
      }).toList();
    });
  }

  Future<void> _approveUser(String userId, {String? role}) async {
    try {
      final response = await _apiService.post(
        '/admin/approve-user/$userId',
        role != null ? {'role': role} : {},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'User approved successfully',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        _fetchUsers();
      }
    } catch (e) {
      debugPrint('Error approving user: $e');
    }
  }

  Future<void> _rejectUser(String userId, {String? role}) async {
    try {
      final response = await _apiService.post(
        '/admin/reject-user/$userId',
        role != null ? {'role': role} : {},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'User rejected successfully',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        _fetchUsers();
      }
    } catch (e) {
      debugPrint('Error rejecting user: $e');
    }
  }

  static const _allRoles = ['doctor', 'student', 'instructor', 'patient', 'lab', 'pharmacy'];
  static const _roleLabels = {
    'doctor': 'Doctor',
    'student': 'Student',
    'instructor': 'Instructor',
    'patient': 'Patient',
    'lab': 'Laboratory',
    'pharmacy': 'Pharmacy',
  };

  Future<void> _showManageRolesDialog(Map user) async {
    final userId = user['_id']?.toString() ?? '';
    final primaryRole = (user['role']?.toString() ?? '').toLowerCase();
    final existingRoles = ((user['roles'] as List?) ?? [])
        .map((e) => e.toString().toLowerCase())
        .toSet();
    final selected = <String>{primaryRole, ...existingRoles};

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.swap_horiz_rounded, color: Color(0xFF0036BC)),
            const SizedBox(width: 10),
            Expanded(child: Text('Manage Roles — ${user['name'] ?? user['username'] ?? 'User'}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          ]),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select every role this account can switch between. The primary role (below) stays locked.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                ..._allRoles.map((r) {
                  final isPrimary = r == primaryRole;
                  final isChecked = selected.contains(r);
                  return CheckboxListTile(
                    value: isChecked,
                    onChanged: isPrimary
                        ? null
                        : (v) => setDialogState(() {
                              if (v == true) {
                                selected.add(r);
                              } else {
                                selected.remove(r);
                              }
                            }),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Row(children: [
                      Text(_roleLabels[r] ?? r, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      if (isPrimary) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0036BC).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Primary', style: TextStyle(fontSize: 10, color: Color(0xFF0036BC), fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ]),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0036BC), foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;
    try {
      final response = await _apiService.put(
        '/admin/users/$userId/roles',
        {'roles': selected.toList()},
      );
      if (mounted && response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Roles updated successfully'), backgroundColor: Colors.green),
        );
        _fetchUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update roles: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Admin System Control',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _buildAdminTabBar(),
        ),
      ),
      floatingActionButton: _currentTab == 'FAQs'
          ? FloatingActionButton.extended(
              onPressed: () => _showFaqDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add FAQ'),
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              elevation: 2,
            )
          : _currentTab == 'Community'
          ? FloatingActionButton.extended(
              onPressed: () => _showAddTopicDialog(),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Add Topic', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF7C3AED),
              elevation: 2,
            )
          : _currentTab != 'Pending' && _currentTab != 'PatientRecords'
              && _currentTab != 'LeaveRequests' && _currentTab != 'Certificates'
              && _currentTab != 'Commission' && _currentTab != 'DoctorTools'
              && _currentTab != 'CourseCategories'
          ? FloatingActionButton.extended(
              onPressed: () => _showAddUserDialog(),
              backgroundColor: AppColors.primaryColor,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                'Add $_currentTab',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: _currentTab == 'LeaveRequests'
          ? _buildLeaveRequestsTab()
          : _currentTab == 'Certificates'
          ? _buildCertificatesTab()
          : _currentTab == 'Commission'
          ? _buildCommissionTab()
          : _currentTab == 'DoctorTools'
          ? _buildDoctorToolsTab()
          : _currentTab == 'Community'
          ? _buildCommunityTab()
          : _currentTab == 'FAQs'
          ? _buildFaqsTab()
          : _currentTab == 'PatientRecords'
          ? _buildPatientRecordsTab()
          : _currentTab == 'CourseCategories'
          ? _buildCourseCategoriesTab()
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _currentTab == 'Pending'
                        ? Icons.check_circle_outline
                        : Icons.group_off_rounded,
                    size: 80,
                    color: Colors.blueGrey.shade200,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentTab == 'Pending'
                        ? "All Caught Up!"
                        : "No users found",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentTab == 'Pending'
                        ? "No pending users waiting for approval."
                        : "No verified users in this category yet.",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user['name'] ?? 'Unknown User',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user['email'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // For a role-request on an already-approved
                            // account, `role` is the OLD active role — the
                            // role(s) actually awaiting a decision live in
                            // pendingRoles, and there can be more than one
                            // queued up (e.g. an old unresolved request plus
                            // a newer one), so show every pending role, not
                            // just the first.
                            Builder(builder: (context) {
                              final pending = List<String>.from(user['pendingRoles'] ?? []);
                              final showPending = _currentTab == 'Pending' &&
                                  user['isExistingAccount'] == true &&
                                  pending.isNotEmpty;
                              if (!showPending) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _currentTab == 'Pending'
                                        ? Colors.orange.shade100
                                        : Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    user['role'] ?? 'Unspecified',
                                    style: TextStyle(
                                      color: _currentTab == 'Pending'
                                          ? Colors.orange.shade800
                                          : Colors.green.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }
                              return Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                alignment: WrapAlignment.end,
                                children: pending
                                    .map((r) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            r,
                                            style: TextStyle(
                                              color: Colors.orange.shade800,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              );
                            }),
                          ],
                        ),
                        if (user['isExistingAccount'] == true &&
                            List<String>.from(user['roles'] ?? []).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: List<String>.from(user['roles'] ?? [])
                                .where((r) => r != user['role'])
                                .map((r) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.amber.shade400),
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(Icons.verified_rounded, size: 12, color: Colors.amber.shade800),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Already approved as $r',
                                          style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w700, fontSize: 11),
                                        ),
                                      ]),
                                    ))
                                .toList(),
                          ),
                        ],
                        // ── Registration details block(s) ────────────────
                        // One block per role this card needs a decision on:
                        // the account's base role for a brand-new signup, or
                        // every pending role for a multi-role account (each
                        // stored under its own verificationDetailsByRole[role]
                        // bucket so a second role's application never masks
                        // the first's saved details/documents).
                        Builder(builder: (ctx) {
                          final pendingRoles = user['isExistingAccount'] == true
                              ? List<String>.from(user['pendingRoles'] ?? [])
                              : <String>[];
                          final rolesToShow = pendingRoles.isNotEmpty
                              ? pendingRoles
                              : [user['role']?.toString() ?? ''];
                          final vdByRole = (user['verificationDetailsByRole'] as Map?) ?? {};
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: rolesToShow
                                .map((r) => _buildRoleDetailsSection(
                                      ctx,
                                      user,
                                      r,
                                      (vdByRole[r] as Map?) ?? (user['verificationDetails'] as Map?) ?? {},
                                      showRoleHeader: rolesToShow.length > 1,
                                    ))
                                .toList(),
                          );
                        }),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showManageRolesDialog(user),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0036BC),
                                side: const BorderSide(color: Color(0xFF0036BC)),
                              ),
                              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                              label: const Text('Manage Roles'),
                            ),
                          ],
                        ),
                        if (_currentTab == 'Pending') ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Builder(builder: (context) {
                            final pending = user['isExistingAccount'] == true
                                ? List<String>.from(user['pendingRoles'] ?? [])
                                : <String>[];
                            // A brand-new (never-approved) account has no
                            // pendingRoles to disambiguate — one approve/
                            // reject pair for the whole account is correct.
                            if (pending.isEmpty) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _rejectUser(user['_id']),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    icon: const Icon(Icons.close, size: 18),
                                    label: const Text('Reject & Delete'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _approveUser(user['_id']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.check, size: 18, color: Colors.white),
                                    label: const Text('Approve Access', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              );
                            }
                            // An already-approved account can have more than
                            // one role queued (e.g. an older unresolved
                            // request plus a new one) — decide each role
                            // independently instead of one button guessing
                            // which role it applies to.
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: pending
                                  .map((r) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Requested: $r',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF334155),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                TextButton.icon(
                                                  onPressed: () => _rejectUser(user['_id'], role: r),
                                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                  icon: const Icon(Icons.close, size: 18),
                                                  label: const Text('Reject'),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton.icon(
                                                  onPressed: () => _approveUser(user['_id'], role: r),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  icon: const Icon(Icons.check, size: 18, color: Colors.white),
                                                  label: Text('Approve $r', style: const TextStyle(color: Colors.white)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final orgController = TextEditingController();
    final licenseController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Add New $_currentTab',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Create a verified account for a $_currentTab. System credentials will be emailed to them.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              _buildDialogField(
                nameController,
                'Full Name',
                Icons.person_rounded,
              ),
              const SizedBox(height: 16),
              _buildDialogField(
                emailController,
                'Email Address',
                Icons.email_rounded,
              ),
              const SizedBox(height: 16),
              _buildDialogField(
                orgController,
                'Organization / University',
                Icons.business_rounded,
              ),
              const SizedBox(height: 16),
              _buildDialogField(
                licenseController,
                'License / Student ID',
                Icons.badge_rounded,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || emailController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                final userData = {
                  'name': nameController.text,
                  'email': emailController.text,
                  'role': _currentTab,
                  'verificationDetails': {
                    'organizationName': orgController.text,
                    'licenseNumber': licenseController.text,
                  },
                };

                final response = await _apiService.post(
                  '/admin/create-user',
                  userData,
                );

                if (response.statusCode == 200 || response.statusCode == 201) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '$_currentTab added and credentials emailed!',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
                _fetchUsers();
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Unable to complete action. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add & Notify'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildPatientRecordsTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Search bar
              TextField(
                onChanged: (v) {
                  _recordSearchQuery = v;
                  _filterPatientRecords();
                },
                decoration: InputDecoration(
                  hintText: 'Search by patient name or phone number',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 12),
              // Doctor filter dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedDoctorFilter,
                decoration: InputDecoration(
                  labelText: 'Filter by Doctor',
                  prefixIcon: const Icon(Icons.person_search_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Doctors')),
                  ..._doctorNames.map((name) => DropdownMenuItem(value: name, child: Text('Dr. $name'))),
                ],
                onChanged: (val) {
                  _selectedDoctorFilter = val;
                  _filterPatientRecords();
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${_filteredPatientRecords.length} records found',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingRecords
              ? const Center(child: CircularProgressIndicator())
              : _filteredPatientRecords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No patient records found', style: TextStyle(fontSize: 16, color: Color(0xFF64748B))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredPatientRecords.length,
                  itemBuilder: (ctx, i) {
                    final r = _filteredPatientRecords[i];
                    final patientName = r['patient']?['name'] ?? 'Unknown';
                    final patientPhone = r['patient']?['phoneNumber'] ?? '';
                    final doctorName = r['doctor']?['name'] ?? 'Unknown';
                    final diagnosis = r['diagnosis'] ?? 'No diagnosis';
                    final date = r['createdAt'] != null
                        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(r['createdAt']))
                        : '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                patientName.isNotEmpty ? patientName[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(patientName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                if (patientPhone.isNotEmpty)
                                  Text(patientPhone, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                Text(diagnosis, style: const TextStyle(fontSize: 13, color: Color(0xFF475569)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.person_rounded, size: 12, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 4),
                                    Text('Dr. $doctorName', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 4),
                                    Text(date, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAdminTabBar() {
    final pendingLeaves = _leaveRequests.where((r) => r['status'] == 'pending').length;
    final pendingCerts  = _certificates.where((c) => c['status'] == 'pending').length;
    return Container(
      height: 60,
      color: Colors.transparent,
      child: Row(
        children: [
          // Left arrow
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
            onPressed: () {
              _tabScrollController.animateTo(
                (_tabScrollController.offset - 180).clamp(0.0, _tabScrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          // Scrollable tabs
          Expanded(
            child: SingleChildScrollView(
              controller: _tabScrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabItem('Pending',        Icons.pending_actions_rounded),
                  _buildTabItem('Doctor',         Icons.medical_services_rounded),
                  _buildTabItem('Student',        Icons.school_rounded),
                  _buildTabItem('Pharmacy',       Icons.local_pharmacy_rounded),
                  _buildTabItem('Laboratory',     Icons.biotech_rounded),
                  _buildTabItem('Instructor',     Icons.cast_for_education_rounded),
                  _buildTabItem('PatientRecords', Icons.folder_shared_rounded),
                  _buildTabItemBadge('LeaveRequests', Icons.event_note_rounded, pendingLeaves),
                  _buildTabItemBadge('Certificates',  Icons.verified_rounded,   pendingCerts),
                  _buildTabItem('Commission',     Icons.percent_rounded),
                  _buildTabItem('DoctorTools',    Icons.manage_accounts_rounded),
                  _buildTabItem('CourseCategories', Icons.category_rounded),
                  _buildTabItem('Community',      Icons.forum_rounded),
                  _buildTabItem('FAQs',           Icons.help_outline_rounded),
                ],
              ),
            ),
          ),
          // Right arrow
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
            onPressed: () {
              _tabScrollController.animateTo(
                (_tabScrollController.offset + 180).clamp(0.0, _tabScrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  // ── Course Categories Tab ────────────────────────────────────────────────
  Widget _buildCourseCategoriesTab() {
    return _CourseCategoriesPanel(apiService: _apiService);
  }

  Widget _buildTabItem(String title, IconData icon) {
    bool isActive = _currentTab == title;
    final displayTitle = title == 'PatientRecords' ? 'Patient Records'
        : title == 'CourseCategories' ? 'Course Categories'
        : title;
    return GestureDetector(
      onTap: () => _onTabChanged(title),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? AppColors.primaryColor : Colors.white),
            const SizedBox(width: 8),
            Text(
              displayTitle,
              style: TextStyle(
                color: isActive ? AppColors.primaryColor : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Renders one role's registration details + submitted documents. Called
  // once per role a pending card needs a decision on — a multi-role account
  // can have more than one role queued, each with its own saved
  // verificationDetails bucket, so this can't just read user['role'] once.
  Widget _buildRoleDetailsSection(
    BuildContext ctx,
    Map<String, dynamic> user,
    String role,
    Map rawVd, {
    required bool showRoleHeader,
  }) {
    final userId = user['_id']?.toString() ?? '';
    // _extraDetails is fetched per-user (not per-role), so only merge it in
    // when this section is for the account's current active role — mixing
    // it into a different pending role's section would misattribute data.
    final vd = <String, dynamic>{
      ...rawVd,
      if (role == user['role']?.toString()) ...?_extraDetails[userId],
    };
    final rows = <Widget>[];

    void addRow(IconData icon, String label, dynamic val) {
      final s = val?.toString() ?? '';
      if (s.isEmpty || s == 'null') return;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 13, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          Expanded(child: Text(s, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)))),
        ]),
      ));
    }

    addRow(Icons.phone_outlined, 'Phone', user['phone']);
    addRow(Icons.location_city_outlined, 'City', user['city'] ?? vd['location']);
    addRow(Icons.location_on_outlined, 'Address', user['address']);

    final createdAt = user['createdAt']?.toString() ?? '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        addRow(Icons.calendar_today_outlined, 'Registered', '${dt.day}/${dt.month}/${dt.year}');
      } catch (_) {}
    }

    if (role == 'doctor') {
      addRow(Icons.school_outlined, 'Qualification', vd['qualification']);
      addRow(Icons.psychology_outlined, 'Specialization', vd['specialization'] ?? (vd['specialties'] as List?)?.join(', '));
      addRow(Icons.numbers_rounded, 'PMDC No.', vd['pmdcNumber'] ?? vd['licenseNumber']);
      addRow(Icons.timeline_outlined, 'Experience', vd['experience'] != null ? '${vd['experience']} yrs' : null);
      addRow(Icons.local_hospital_outlined, 'Clinic/Workplace', vd['clinicName'] ?? vd['organizationName']);
      addRow(Icons.location_on_outlined, 'Clinic Address', vd['clinicAddress']);
      addRow(Icons.schedule_outlined, 'Timings', vd['availableTimings']);
      final days = vd['availableDays'];
      if (days != null && (days as List).isNotEmpty) addRow(Icons.event_outlined, 'Available Days', days.join(', '));
    } else if (role == 'pharmacy') {
      addRow(Icons.local_pharmacy_outlined, 'Pharmacy Name', vd['pharmacyName'] ?? vd['organizationName'] ?? vd['name']);
      addRow(Icons.badge_outlined, 'Drug License', vd['drugLicenseNumber'] ?? vd['licenseNumber']);
      addRow(Icons.person_outline, 'Pharmacist', vd['pharmacistName'] ?? vd['credentials']);
      addRow(Icons.timeline_outlined, 'Years Operating', vd['yearsOfOperation']);
      addRow(Icons.schedule_outlined, 'Operating Hours', vd['operatingHours']);
      final days = vd['operatingDays'];
      if (days != null && (days as List).isNotEmpty) addRow(Icons.event_outlined, 'Operating Days', days.join(', '));
    } else if (role == 'lab') {
      addRow(Icons.biotech_outlined, 'Lab Name', vd['labName'] ?? vd['organizationName'] ?? vd['name']);
      addRow(Icons.badge_outlined, 'License No.', vd['labLicenseNumber'] ?? vd['licenseNumber']);
      addRow(Icons.timeline_outlined, 'Years Operating', vd['yearsOfOperation']);
      addRow(Icons.schedule_outlined, 'Operating Hours', vd['operatingHours']);
    } else if (role == 'student') {
      addRow(Icons.account_balance_outlined, 'University', vd['university'] ?? vd['organizationName']);
      addRow(Icons.menu_book_outlined, 'Program', vd['program'] ?? vd['credentials']);
      addRow(Icons.timeline_outlined, 'Current Year', vd['currentYear']);
      addRow(Icons.badge_outlined, 'Student ID', vd['studentId']);
    } else if (role == 'instructor') {
      addRow(Icons.school_outlined, 'Qualification', vd['qualification']);
      addRow(Icons.psychology_outlined, 'Specialization', vd['specialization']);
      addRow(Icons.timeline_outlined, 'Experience', vd['experience'] != null ? '${vd['experience']} yrs' : null);
      addRow(Icons.account_balance_outlined, 'Institution', vd['institution'] ?? vd['organizationName']);
      addRow(Icons.menu_book_outlined, 'Proposed Courses', vd['proposedCourses']);
    }
    addRow(Icons.comment_outlined, 'Comments', vd['comments']);

    final docEntries = <Map<String, String>>[];
    void addDoc(String label, String? dataKey, String? nameKey) {
      final data = vd[dataKey]?.toString() ?? '';
      if (data.isEmpty) return;
      docEntries.add({'label': label, 'data': data, 'name': vd[nameKey]?.toString() ?? label});
    }
    addDoc('CNIC / ID', 'cnicDocument', 'cnicDocumentName');
    addDoc('PMDC Certificate', 'pmdcCertDocument', 'pmdcCertDocumentName');
    addDoc('Experience Certificate', 'experienceCertDocument', 'experienceCertDocumentName');
    addDoc('Drug License', 'drugLicenseDocument', 'drugLicenseDocumentName');
    addDoc('Registration Certificate', 'regCertDocument', 'regCertDocumentName');
    addDoc('Lab License', 'labLicenseDocument', 'labLicenseDocumentName');
    addDoc('Accreditation Certificate', 'accredCertDocument', 'accredCertDocumentName');
    addDoc('Tests List', 'testsListDocument', 'testsListDocumentName');
    addDoc('Student ID', 'studentIdDocument', 'studentIdDocumentName');
    addDoc('CV / Resume', 'cvDocument', 'cvDocumentName');

    // LMS course-purchase verification documents (uploaded via
    // POST /verification/upload, a separate flow from signup).
    if (role == user['role']?.toString()) {
      final lmsVerification = _lmsVerifications[userId];
      if (lmsVerification != null) {
        final lmsDocs = List<dynamic>.from(lmsVerification['documents'] ?? []);
        for (final d in lmsDocs) {
          final url = d['url']?.toString() ?? '';
          if (url.isEmpty) continue;
          docEntries.add({
            'label': 'LMS: ${d['type']?.toString() ?? 'Document'}',
            'data': url,
            'name': d['fileName']?.toString() ?? 'Document',
          });
        }
      }
    }

    if (rows.isEmpty && docEntries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showRoleHeader)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Requested role: ${role[0].toUpperCase()}${role.substring(1)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0036BC)),
            ),
          ),
        if (rows.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Registration Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF3B4DA8))),
              const SizedBox(height: 8),
              ...rows,
            ]),
          ),
        if (docEntries.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Submitted Documents', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: docEntries.map((doc) => GestureDetector(
                    onTap: () => _openDocument(ctx, doc['data']!, doc['label']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.insert_drive_file_outlined, size: 14, color: Color(0xFFB45309)),
                          const SizedBox(width: 5),
                          Text(doc['label']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
                          const SizedBox(width: 4),
                          const Icon(Icons.open_in_new_rounded, size: 11, color: Color(0xFFB45309)),
                        ],
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Tab with pending badge ──────────────────────────────────────────────────

  Widget _buildTabItemBadge(String title, IconData icon, int badgeCount) {
    final isActive = _currentTab == title;
    final displayTitle = title == 'LeaveRequests' ? 'Leave Requests' : 'Certificates';
    return GestureDetector(
      onTap: () => _onTabChanged(title),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? AppColors.primaryColor : Colors.white),
            const SizedBox(width: 6),
            Text(displayTitle, style: TextStyle(color: isActive ? AppColors.primaryColor : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(10)),
                child: Text('$badgeCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Leave Requests Tab ─────────────────────────────────────────────────────

  Widget _buildLeaveRequestsTab() {
    if (_isLoadingLeaves) return const Center(child: CircularProgressIndicator());
    if (_leaveRequests.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        const Text('No leave requests yet.', style: TextStyle(fontSize: 16, color: Color(0xFF64748B))),
        TextButton.icon(onPressed: _fetchLeaveRequests, icon: const Icon(Icons.refresh_rounded), label: const Text('Refresh')),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _fetchLeaveRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _leaveRequests.length,
        itemBuilder: (_, i) {
          final r = _leaveRequests[i];
          final status = r['status']?.toString() ?? 'pending';
          final from = r['fromDate'] != null ? DateTime.tryParse(r['fromDate'].toString()) : null;
          final to   = r['toDate']   != null ? DateTime.tryParse(r['toDate'].toString())   : null;
          final conflicts = r['conflictingAppointments'] as int? ?? 0;
          final Color statusColor = status == 'approved' ? Colors.green : status == 'rejected' ? Colors.red : const Color(0xFFF59E0B);
          final fmt = DateFormat('dd MMM yyyy');

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r['doctorName']?.toString() ?? 'Doctor', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    if (r['doctorEmail'] != null) Text(r['doctorEmail'].toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: statusColor)),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.date_range_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(from != null && to != null ? '${fmt.format(from)}  →  ${fmt.format(to)}' : 'Date TBD',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
                if (r['reason']?.toString().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text('Reason: ${r['reason']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
                if (conflicts > 0) ...[
                  const SizedBox(height: 4),
                  Text('⚠️ $conflicts conflicting appointment(s)', style: const TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.w600)),
                ],
                if (status == 'pending') ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => _updateLeaveStatus(r['doctorId'].toString(), r['_id'].toString(), 'rejected'),
                      icon: const Icon(Icons.close_rounded, size: 16), label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton.icon(
                      onPressed: () => _updateLeaveStatus(r['doctorId'].toString(), r['_id'].toString(), 'approved'),
                      icon: const Icon(Icons.check_rounded, size: 16), label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    )),
                  ]),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Certificates Tab ───────────────────────────────────────────────────────

  Widget _buildCertificatesTab() {
    if (_isLoadingCerts) return const Center(child: CircularProgressIndicator());
    if (_certificates.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.workspace_premium_rounded, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        const Text('No certificate submissions yet.', style: TextStyle(fontSize: 16, color: Color(0xFF64748B))),
        TextButton.icon(onPressed: _fetchCertificates, icon: const Icon(Icons.refresh_rounded), label: const Text('Refresh')),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _fetchCertificates,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _certificates.length,
        itemBuilder: (_, i) {
          final c = _certificates[i];
          final status = c['status']?.toString() ?? 'pending';
          final Color statusColor = status == 'verified' ? Colors.green : status == 'rejected' ? Colors.red : const Color(0xFFF59E0B);

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF3B82F6), size: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c['title']?.toString() ?? 'Certificate', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    Text('Dr. ${c['doctorName'] ?? ''}  •  ${c['type'] ?? ''}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(status == 'pending' ? 'UNVERIFIED' : status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: statusColor)),
                  ),
                ]),
                if (status == 'pending') ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => _updateCredentialStatus(c['doctorId'].toString(), c['_id'].toString(), 'rejected'),
                      icon: const Icon(Icons.close_rounded, size: 16), label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton.icon(
                      onPressed: () => _updateCredentialStatus(c['doctorId'].toString(), c['_id'].toString(), 'verified'),
                      icon: const Icon(Icons.verified_rounded, size: 16), label: const Text('Verify'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    )),
                  ]),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Commission Tab (Admin only) ────────────────────────────────────────────
  Widget _buildCommissionTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _apiService.get('/admin/commission-stats').then((r) =>
          r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{}),
      builder: (context, snap) {
        final data = snap.data ?? {};
        final totalRevenue = data['totalRevenue'] ?? 0;
        final iCareCommission = data['iCareCommission'] ?? data['platformCommission'] ?? 0;
        final doctorEarnings = data['doctorEarnings'] ?? 0;
        final commissionRate = data['commissionRate'] ?? 10;
        final transactions = data['transactions'] is List ? data['transactions'] as List : [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0036BC), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('iCare Platform Commission',
                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Rs. ${_fmt(iCareCommission)}',
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                          Text('$commissionRate% of total revenue',
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Stats row
              Row(
                children: [
                  Expanded(child: _commissionBox('Total Revenue', 'Rs. ${_fmt(totalRevenue)}', const Color(0xFF10B981))),
                  const SizedBox(width: 12),
                  Expanded(child: _commissionBox('Doctor Earnings', 'Rs. ${_fmt(doctorEarnings)}', const Color(0xFF8B5CF6))),
                ],
              ),
              const SizedBox(height: 16),
              // Commission rate setting
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.percent_rounded, color: AppColors.primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Commission Rate', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          Text('Currently $commissionRate% per consultation',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _showCommissionRateDialog(commissionRate),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        elevation: 0,
                      ),
                      child: const Text('Edit Rate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Consultation time limit setting
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_rounded, color: Color(0xFF8B5CF6), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Max Consultation Duration', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          Text('Default: ${ConsultationTimer.maxDuration.inMinutes} minutes per session',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _showConsultationTimeLimitDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        elevation: 0,
                      ),
                      child: const Text('Edit Limit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Recent transactions
              if (snap.connectionState == ConnectionState.waiting)
                const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
              else if (transactions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: const Center(child: Text('No commission transactions yet.', style: TextStyle(color: Color(0xFF64748B)))),
                )
              else ...[
                const Text('Recent Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Column(
                    children: transactions.take(20).toList().asMap().entries.map((e) {
                      final i = e.key;
                      final t = e.value as Map;
                      return Column(
                        children: [
                          if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.receipt_rounded, color: Color(0xFF10B981), size: 18),
                            ),
                            title: Text(t['doctorName']?.toString() ?? 'Doctor', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: Text(t['date']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            trailing: Text('Rs. ${_fmt(t['commission'] ?? 0)}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF10B981))),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _commissionBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  String _fmt(dynamic val) {
    final n = (val is num) ? val.toInt() : int.tryParse('$val') ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  void _showCommissionRateDialog(dynamic currentRate) {
    final ctrl = TextEditingController(text: '$currentRate');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Set Commission Rate', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the platform commission percentage (0–100)', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. 10',
                suffixText: '%',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final rate = double.tryParse(ctrl.text.trim());
              if (rate == null || rate < 0 || rate > 100) return;
              Navigator.pop(ctx);
              try {
                await _apiService.post('/admin/commission-rate', {'rate': rate});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Commission rate updated to $rate%'), backgroundColor: Colors.green),
                  );
                  setState(() {}); // refresh
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to update rate'), backgroundColor: Colors.red),
                );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showConsultationTimeLimitDialog() {
    final ctrl = TextEditingController(text: '${ConsultationTimer.maxDuration.inMinutes}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Max Consultation Duration', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Set the maximum consultation time in minutes (default: 30)',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true,
            decoration: InputDecoration(hintText: 'e.g. 30', suffixText: 'min',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true, fillColor: const Color(0xFFF8FAFC))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final mins = int.tryParse(ctrl.text.trim());
              if (mins == null || mins < 5 || mins > 120) return;
              ConsultationTimer.maxDuration = Duration(minutes: mins);
              Navigator.pop(ctx);
              try {
                await _apiService.post('/admin/consultation-settings', {'maxDurationMinutes': mins});
              } catch (_) {}
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Max consultation time set to $mins minutes'), backgroundColor: Colors.green));
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Community Management Tab ───────────────────────────────────────────────
  Widget _buildCommunityTab() {
    if (_isLoadingCommunity) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _fetchCommunityData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: _buildCommunityChildren(),
      ),
    );
  }

  List<Widget> _buildCommunityChildren() {
    final List<Widget> widgets = [];

    // ── Topics header ──────────────────────────────────────────────────
    widgets.add(const Text('Community Topics',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))));
    widgets.add(const SizedBox(height: 10));

    if (_communityTopics.isEmpty) {
      widgets.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No custom topics yet. Default topics are always available.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
      ));
    } else {
      final List<Widget> chips = [];
      for (final raw in _communityTopics) {
        try {
          final Map<String, dynamic> t = raw is Map<String, dynamic>
              ? raw
              : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
          final name = t['name']?.toString() ?? '';
          final id = t['_id']?.toString() ?? '';
          if (name.isEmpty) continue;
          chips.add(Chip(
            label: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            backgroundColor: const Color(0xFFEDE9FE),
            side: const BorderSide(color: Color(0xFF7C3AED), width: 1),
            deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF7C3AED)),
            onDeleted: id.isEmpty ? null : () => _deleteTopic(id, name),
          ));
        } catch (_) {}
      }
      widgets.add(Wrap(spacing: 8, runSpacing: 8, children: chips));
    }

    widgets.add(const SizedBox(height: 24));
    widgets.add(const Divider(color: Color(0xFFE2E8F0)));
    widgets.add(const SizedBox(height: 12));

    // ── Posts header ──────────────────────────────────────────────────
    widgets.add(Text('All Posts (${_communityPosts.length})',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))));
    widgets.add(const SizedBox(height: 10));

    if (_communityPosts.isEmpty) {
      widgets.add(const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No posts yet.', style: TextStyle(color: Color(0xFF94A3B8)))),
      ));
    } else {
      for (final raw in _communityPosts) {
        try {
          final Map<String, dynamic> p = raw is Map<String, dynamic>
              ? raw
              : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});

          final postId = p['_id']?.toString() ?? p['id']?.toString() ?? '';
          final author = p['userName']?.toString() ?? p['authorName']?.toString() ?? 'User';
          final content = p['content']?.toString() ?? '';
          final cat = p['category']?.toString() ?? 'General';

          // Safe numeric extraction (handles int, double, null)
          int likesCount = 0;
          final lc = p['likeCount'];
          if (lc is int) {
            likesCount = lc;
          } else if (lc is num) {
            likesCount = lc.toInt();
          } else if (p['likes'] is List) {
            likesCount = (p['likes'] as List).length;
          }

          int commentsCount = 0;
          final cc = p['commentCount'];
          if (cc is int) {
            commentsCount = cc;
          } else if (cc is num) {
            commentsCount = cc.toInt();
          } else if (p['comments'] is List) {
            commentsCount = (p['comments'] as List).length;
          }

          widgets.add(Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      author.isNotEmpty ? author[0].toUpperCase() : 'U',
                      style: const TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(author,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(cat,
                                  style: const TextStyle(
                                      fontSize: 10, fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.favorite_rounded, size: 14, color: Color(0xFFEF4444)),
                            const SizedBox(width: 4),
                            Text('$likesCount',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: commentsCount > 0 && postId.isNotEmpty
                                  ? () => setState(() {
                                        if (_expandedPostIds.contains(postId)) {
                                          _expandedPostIds.remove(postId);
                                        } else {
                                          _expandedPostIds.add(postId);
                                        }
                                      })
                                  : null,
                              child: Row(children: [
                                const Icon(Icons.chat_bubble_rounded, size: 14, color: AppColors.primaryColor),
                                const SizedBox(width: 4),
                                Text('$commentsCount',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                if (commentsCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    _expandedPostIds.contains(postId) ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                    size: 14, color: AppColors.primaryColor,
                                  ),
                                ],
                              ]),
                            ),
                            const Spacer(),
                            if (postId.isNotEmpty)
                              GestureDetector(
                                onTap: () => _adminDeletePost(postId),
                                child: const Icon(Icons.delete_outline_rounded,
                                    size: 20, color: Color(0xFFEF4444)),
                              ),
                          ],
                        ),
                        // Expandable comments section
                        if (_expandedPostIds.contains(postId)) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 8),
                          ...() {
                            final rawComments = p['comments'];
                            if (rawComments is! List || rawComments.isEmpty) {
                              return [const Text('No comments.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))];
                            }
                            return rawComments.map<Widget>((rc) {
                              final c = rc is Map<String, dynamic> ? rc : (rc is Map ? Map<String, dynamic>.from(rc) : <String, dynamic>{});
                              final commentId = c['_id']?.toString() ?? '';
                              final commentAuthor = c['userName']?.toString() ?? 'User';
                              final commentText = c['content']?.toString() ?? '';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 13,
                                      backgroundColor: const Color(0xFFE0F2FE),
                                      child: Text(commentAuthor.isNotEmpty ? commentAuthor[0].toUpperCase() : 'U',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(commentAuthor, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                        Text(commentText, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                      ]),
                                    ),
                                    if (commentId.isNotEmpty)
                                      GestureDetector(
                                        onTap: () => _adminDeleteComment(postId, commentId, commentAuthor),
                                        child: const Padding(
                                          padding: EdgeInsets.only(left: 6),
                                          child: Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList();
                          }(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ));
        } catch (_) {}
      }
    }

    return widgets;
  }

  Future<void> _fetchCommunityData() async {
    if (mounted) setState(() => _isLoadingCommunity = true);
    try {
      final postsRes = await _apiService.get('/community/posts');
      final topicsRes = await _apiService.get('/community/categories-full');
      if (mounted) {
        setState(() {
        _communityPosts = (postsRes.data['posts'] is List) ? postsRes.data['posts'] as List : [];
        _communityTopics = (topicsRes.data['topics'] is List) ? topicsRes.data['topics'] as List : [];
      });
      }
    } catch (_) {
      try {
        final postsRes = await _apiService.get('/community/posts');
        if (mounted) {
          setState(() {
          _communityPosts = (postsRes.data['posts'] is List) ? postsRes.data['posts'] as List : [];
          _communityTopics = [];
        });
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _isLoadingCommunity = false);
  }

  void _showAddTopicDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Community Topic', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl, autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Dental Health', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _apiService.post('/community/categories', {'name': name});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Topic "$name" added!'), backgroundColor: Colors.green));
                  _fetchCommunityData();
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTopic(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Topic', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Delete topic "$name"? Existing posts in this topic are not affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _apiService.delete('/community/categories/$id');
      if (mounted) { _fetchCommunityData(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Topic deleted'), backgroundColor: Colors.green)); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _adminDeletePost(String postId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('This post will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _apiService.delete('/community/posts/$postId');
      if (mounted) { _expandedPostIds.remove(postId); _fetchCommunityData(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted'), backgroundColor: Colors.green)); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _adminDeleteComment(String postId, String commentId, String author) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Delete this comment by $author?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _apiService.delete('/community/posts/$postId/comments/$commentId');
      if (mounted) { _fetchCommunityData(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment deleted'), backgroundColor: Colors.green)); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  // ── Doctor Tools Tab (6.1.4 license expiry, 6.1.5 max time, 6.1.6 no referrer) ─
  Widget _buildDoctorToolsTab() {
    if (_isLoadingDoctorTools) return const Center(child: CircularProgressIndicator());
    {
        final expiringDoctors = _expiringLicenses;
        final noReferrerDoctors = _noReferrerDoctors;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Max Consultation Time (6.1.5) ──────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
              ),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.timer_rounded, color: Color(0xFF8B5CF6), size: 22)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Max Consultation Duration', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  Text('Currently: ${ConsultationTimer.maxDuration.inMinutes} min per session',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ])),
                ElevatedButton(
                  onPressed: _showConsultationTimeLimitDialog,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                  child: const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),

            // ── Expiring Licenses (6.1.4) ────────────────────────────────
            Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 8),
              Text('Licenses Expiring Within 30 Days (${expiringDoctors.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ]),
            const SizedBox(height: 10),
            if (expiringDoctors.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF86EFAC))),
                child: const Row(children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 10),
                  Text('All doctor licenses are valid for more than 30 days.', style: TextStyle(color: Color(0xFF065F46), fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              )
            else
              ...expiringDoctors.map((d) {
                final name = d['name']?.toString() ?? 'Doctor';
                final expiry = d['licenseExpiry'] != null ? DateTime.tryParse(d['licenseExpiry'].toString()) : null;
                final daysLeft = expiry != null ? expiry.difference(DateTime.now()).inDays : 0;
                final color = daysLeft <= 7 ? Colors.red : const Color(0xFFF59E0B);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: color.withValues(alpha: 0.06),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: color.withValues(alpha: 0.3))),
                  child: ListTile(
                    leading: Icon(Icons.person_rounded, color: color),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text(expiry != null ? 'Expires: ${DateFormat('dd MMM yyyy').format(expiry)}' : 'No expiry date',
                        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text('$daysLeft days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
                    ),
                  ),
                );
              }),

            const SizedBox(height: 24),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),

            // ── No Referrer Report (6.1.6) ─────────────────────────────
            Row(children: [
              const Icon(Icons.link_off_rounded, color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 8),
              Text('No-Referrer Doctors (${noReferrerDoctors.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ]),
            const SizedBox(height: 6),
            const Text('Doctors with no referral source recorded — admin-only view.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            const SizedBox(height: 10),
            if (noReferrerDoctors.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF86EFAC))),
                child: const Row(children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 10),
                  Text('All doctors have a referral source.', style: TextStyle(color: Color(0xFF065F46), fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              )
            else
              ...noReferrerDoctors.map((d) => Card(
                margin: const EdgeInsets.only(bottom: 8), elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFFEE2E2), child: Icon(Icons.person_off_rounded, color: Color(0xFFEF4444), size: 20)),
                  title: Text(d['name']?.toString() ?? 'Doctor', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text(d['email']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  trailing: const Chip(label: Text('No Referrer', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                      backgroundColor: Color(0xFFFEE2E2), side: BorderSide.none, padding: EdgeInsets.symmetric(horizontal: 4)),
                ),
              )),
          ],
        );
    }
  }

  Future<void> _fetchDoctorToolsData() async {
    if (mounted) setState(() => _isLoadingDoctorTools = true);
    try {
      final r = await _apiService.get('/admin/doctor-tools');
      if (mounted) {
        setState(() {
        _expiringLicenses = (r.data['expiringLicenses'] is List) ? r.data['expiringLicenses'] as List : [];
        _noReferrerDoctors = (r.data['noReferrerDoctors'] is List) ? r.data['noReferrerDoctors'] as List : [];
      });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingDoctorTools = false);
  }

  // ─── FAQs Tab ─────────────────────────────────────────────────────────────

  Future<void> _fetchFaqs() async {
    if (mounted) setState(() => _isLoadingFaqs = true);
    try {
      final r = await _apiService.get('/faqs/all');
      if (mounted) setState(() => _faqs = (r.data['faqs'] is List) ? r.data['faqs'] as List : []);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingFaqs = false);
  }

  Future<void> _showFaqDialog({Map<String, dynamic>? existing}) async {
    final questionCtrl = TextEditingController(text: existing?['question']?.toString() ?? '');
    final answerCtrl = TextEditingController(text: existing?['answer']?.toString() ?? '');
    String selectedType = existing?['accountType']?.toString() ?? 'general';

    const accountTypes = ['general', 'patient', 'doctor', 'pharmacy', 'lab', 'instructor', 'student'];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existing == null ? 'Add FAQ' : 'Edit FAQ',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Account Type', border: OutlineInputBorder()),
                  items: accountTypes.map((t) => DropdownMenuItem(value: t,
                    child: Text(t[0].toUpperCase() + t.substring(1)))).toList(),
                  onChanged: (v) => setS(() => selectedType = v ?? 'general'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: questionCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Question *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: answerCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Answer *', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, elevation: 0),
              onPressed: () async {
                final q = questionCtrl.text.trim();
                final a = answerCtrl.text.trim();
                if (q.isEmpty || a.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  if (existing == null) {
                    await _apiService.post('/faqs', {'question': q, 'answer': a, 'accountType': selectedType});
                  } else {
                    await _apiService.put('/faqs/${existing['_id']}', {'question': q, 'answer': a, 'accountType': selectedType});
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(existing == null ? 'FAQ added!' : 'FAQ updated!'),
                      backgroundColor: Colors.green,
                    ));
                    _fetchFaqs();
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                }
              },
              child: Text(existing == null ? 'Add FAQ' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteFaq(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete FAQ?'),
        content: const Text('This FAQ will be permanently removed.'),
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
      await _apiService.delete('/faqs/$id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FAQ deleted'), backgroundColor: Colors.green));
        _fetchFaqs();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildFaqsTab() {
    if (_isLoadingFaqs) return const Center(child: CircularProgressIndicator());
    const typeColors = {
      'general': Color(0xFF6366F1),
      'patient': Color(0xFF10B981),
      'doctor': Color(0xFF3B82F6),
      'pharmacy': Color(0xFFF59E0B),
      'lab': Color(0xFF8B5CF6),
      'instructor': Color(0xFFEF4444),
      'student': Color(0xFF06B6D4),
    };
    return _faqs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.help_outline_rounded, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('No FAQs yet', style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showFaqDialog(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add First FAQ'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, elevation: 0),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: _faqs.length,
              itemBuilder: (_, i) {
                final Map<String, dynamic> faq = _faqs[i] is Map<String, dynamic>
                    ? _faqs[i] as Map<String, dynamic>
                    : (_faqs[i] is Map ? Map<String, dynamic>.from(_faqs[i] as Map) : <String, dynamic>{});
                final id = faq['_id']?.toString() ?? '';
                final q = faq['question']?.toString() ?? '';
                final a = faq['answer']?.toString() ?? '';
                final type = faq['accountType']?.toString() ?? 'general';
                final color = typeColors[type] ?? const Color(0xFF6366F1);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                          child: Text(type[0].toUpperCase() + type.substring(1),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(q, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                              const SizedBox(height: 6),
                              Text(a, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF6366F1)),
                              tooltip: 'Edit',
                              onPressed: () => _showFaqDialog(existing: faq),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                              tooltip: 'Delete',
                              onPressed: () => _deleteFaq(id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
  }
}

// ── Course Categories Panel ─────────────────────────────────────────────────
class _CourseCategoriesPanel extends StatefulWidget {
  final ApiService apiService;
  const _CourseCategoriesPanel({required this.apiService});
  @override
  State<_CourseCategoriesPanel> createState() => _CourseCategoriesPanelState();
}

class _CourseCategoriesPanelState extends State<_CourseCategoriesPanel> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.apiService.get('/admin/categories?all=true');
      if (mounted) setState(() {
        _categories = List<Map<String, dynamic>>.from(res.data['categories'] ?? []);
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Course Category', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Category Name *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()), maxLines: 2),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            Navigator.pop(context);
            try {
              await widget.apiService.post('/admin/categories', {'name': nameCtrl.text.trim(), 'description': descCtrl.text.trim()});
              _load();
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
          child: const Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  Future<void> _toggleActive(Map<String, dynamic> cat) async {
    try {
      await widget.apiService.put('/admin/categories/${cat['_id']}', {'isActive': !(cat['isActive'] as bool? ?? true)});
      _load();
    } catch (_) {}
  }

  Future<void> _delete(Map<String, dynamic> cat) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Delete Category'),
      content: Text('Delete "${cat['name']}"? It will be hidden from instructors.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (confirm != true) return;
    try { await widget.apiService.delete('/admin/categories/${cat['_id']}'); _load(); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Course Categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
            SizedBox(height: 4),
            Text('Manage categories shown to instructors when creating courses.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ])),
          ElevatedButton.icon(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Category'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ]),
        const SizedBox(height: 20),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_categories.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(40), child: Column(children: [
            const Icon(Icons.category_outlined, size: 56, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            const Text('No categories yet.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _showAddDialog, child: const Text('Add First Category')),
          ])))
        else
          Expanded(child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final isActive = cat['isActive'] as bool? ?? true;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isActive ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: isActive ? const Color(0xFF10B981) : const Color(0xFFCBD5E1), shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(cat['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
                      if ((cat['description'] ?? '').toString().isNotEmpty)
                        Text(cat['description'].toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ])),
                    Switch(value: isActive, onChanged: (_) => _toggleActive(cat), activeColor: const Color(0xFF10B981)),
                    IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20), onPressed: () => _delete(cat)),
                  ]),
                );
              },
            ),
          )),
      ]),
    );
  }
}