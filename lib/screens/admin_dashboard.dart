import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/models/consultation_timer.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/services/medical_record_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _fetchUsers();
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
        setState(() {
          _users = data['users'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        final records = response.data['records'] as List? ?? [];
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

  Future<void> _approveUser(String userId) async {
    try {
      final response = await _apiService.post(
        '/admin/approve-user/$userId',
        {},
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

  Future<void> _rejectUser(String userId) async {
    try {
      final response = await _apiService.post('/admin/reject-user/$userId', {});
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabItem('Pending', Icons.pending_actions_rounded),
                _buildTabItem('Doctor', Icons.medical_services_rounded),
                _buildTabItem('Student', Icons.school_rounded),
                _buildTabItem('Pharmacy', Icons.local_pharmacy_rounded),
                _buildTabItem('Laboratory', Icons.science_rounded),
                _buildTabItem('Instructor', Icons.person_add_rounded),
                _buildTabItem('PatientRecords', Icons.folder_shared_rounded),
                _buildTabItemBadge('LeaveRequests', Icons.event_busy_rounded,
                    _leaveRequests.where((r) => r['status'] == 'pending').length),
                _buildTabItemBadge('Certificates', Icons.workspace_premium_rounded,
                    _certificates.where((c) => c['status'] == 'pending').length),
                _buildTabItem('Commission', Icons.monetization_on_rounded),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _currentTab != 'Pending' && _currentTab != 'PatientRecords'
          && _currentTab != 'LeaveRequests' && _currentTab != 'Certificates'
          && _currentTab != 'Commission'
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
          : _currentTab == 'PatientRecords'
          ? _buildPatientRecordsTab()
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
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
                            ),
                          ],
                        ),
                        if (user['verificationDetails'] != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                if (user['verificationDetails']['organizationName'] !=
                                        null &&
                                    user['verificationDetails']['organizationName']
                                        .toString()
                                        .isNotEmpty)
                                  _buildDetailRow(
                                    Icons.business_rounded,
                                    "Organization",
                                    user['verificationDetails']['organizationName'],
                                  ),
                                if (user['verificationDetails']['location'] !=
                                        null &&
                                    user['verificationDetails']['location']
                                        .toString()
                                        .isNotEmpty)
                                  _buildDetailRow(
                                    Icons.location_on_rounded,
                                    "Location",
                                    user['verificationDetails']['location'],
                                  ),
                                if (user['verificationDetails']['licenseNumber'] !=
                                        null &&
                                    user['verificationDetails']['licenseNumber']
                                        .toString()
                                        .isNotEmpty)
                                  _buildDetailRow(
                                    Icons.badge_rounded,
                                    "License/Accreditation",
                                    user['verificationDetails']['licenseNumber'],
                                  ),
                                if (user['verificationDetails']['credentials'] !=
                                        null &&
                                    user['verificationDetails']['credentials']
                                        .toString()
                                        .isNotEmpty)
                                  _buildDetailRow(
                                    Icons.school_rounded,
                                    "Specialty/Credentials",
                                    user['verificationDetails']['credentials'],
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (_currentTab == 'Pending') ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _rejectUser(user['_id']),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text('Reject & Delete'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _approveUser(user['_id']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Approve Access',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildTabItem(String title, IconData icon) {
    bool isActive = _currentTab == title;
    final displayTitle = title == 'PatientRecords' ? 'Patient Records' : title;
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary500),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
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
        final transactions = (data['transactions'] as List?) ?? [];

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
}