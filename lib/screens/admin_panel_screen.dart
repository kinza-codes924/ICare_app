import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/screens/admin_verification_panel.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:icare/widgets/back_button.dart';

/// Admin Panel
///
/// This is where admin-controlled users are onboarded:
/// - Laboratories (verified partners)
/// - Pharmacies (verified partners)
/// - Instructors (LMS teachers)
/// - Students (LMS learners)
/// - Doctor approvals
///
/// These roles CANNOT self-signup. Admin creates them.
class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  bool _isLoading = false;

  List<Map<String, dynamic>> _pendingDoctors = [];
  final List<Map<String, dynamic>> _laboratories = [];
  final List<Map<String, dynamic>> _pharmacies = [];
  final List<Map<String, dynamic>> _instructors = [];
  final List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _leaveRequests = [];
  List<Map<String, dynamic>> _credentials = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final lr = await _api.get('/admin/leave-requests');
      if (mounted) setState(() => _leaveRequests = List<Map<String, dynamic>>.from(lr.data['leaveRequests'] ?? []));
    } catch (_) {}
    try {
      final cr = await _api.get('/admin/credentials');
      if (mounted) setState(() => _credentials = List<Map<String, dynamic>>.from(cr.data['credentials'] ?? []));
    } catch (_) {}
    try {
      final pd = await _api.get('/admin/pending-users');
      if (mounted) setState(() => _pendingDoctors = List<Map<String, dynamic>>.from(pd.data['users'] ?? []));
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _updateLeaveStatus(String doctorId, String requestId, String status) async {
    try {
      await _api.put('/admin/leave-requests/$doctorId/$requestId', {'status': status});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Leave request $status.'),
          backgroundColor: status == 'approved' ? Colors.green : Colors.red,
        ));
        _loadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _updateCredentialStatus(String doctorId, String credId, String status) async {
    try {
      await _api.put('/admin/credentials/$doctorId/$credId', {'status': status});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Credential $status.'),
          backgroundColor: status == 'verified' ? Colors.green : Colors.red,
        ));
        _loadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Panel',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Gilroy-Bold',
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'Manage users and system settings',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                fontFamily: 'Gilroy-Medium',
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryColor),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primaryColor,
              labelColor: AppColors.primaryColor,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorWeight: 3,
              isScrollable: true,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                fontFamily: 'Gilroy-Bold',
              ),
              tabs: [
                Tab(text: 'PENDING APPROVALS (${_pendingDoctors.length})'),
                Tab(text: 'LABORATORIES (${_laboratories.length})'),
                Tab(text: 'PHARMACIES (${_pharmacies.length})'),
                Tab(text: 'INSTRUCTORS (${_instructors.length})'),
                Tab(text: 'STUDENTS (${_students.length})'),
                Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('LEAVE REQUESTS'),
                    if (_leaveRequests.where((r) => r['status'] == 'pending').isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          '${_leaveRequests.where((r) => r['status'] == 'pending').length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ],
                  ]),
                ),
                const Tab(text: 'COURSE CATEGORIES'),
                Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('CERTIFICATES'),
                    if (_credentials.where((c) => c['status'] == 'pending').isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primaryColor, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          '${_credentials.where((c) => c['status'] == 'pending').length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ],
                  ]),
                ),
                const Tab(text: 'STUDENT VERIFICATIONS'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDoctorApprovalsTab(),
                _buildLaboratoriesTab(),
                _buildPharmaciesTab(),
                _buildInstructorsTab(),
                _buildStudentsTab(),
                _buildLeaveRequestsTab(),
                _buildCourseCategoriesTab(),
                _buildCredentialsTab(),
                const AdminVerificationPanel(embedded: true),
              ],
            ),
    );
  }

  Widget _buildDoctorApprovalsTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pending Approvals',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFamily: 'Gilroy-Bold',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Review and approve user registrations (doctors, pharmacies, labs, instructors, students)',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          if (_pendingDoctors.isEmpty)
            _buildEmptyState('No pending approvals', Icons.check_circle_outline)
          else
            Expanded(
              child: ListView.builder(
                itemCount: _pendingDoctors.length,
                itemBuilder: (ctx, i) => _buildDoctorApprovalCard(_pendingDoctors[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLaboratoriesTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Laboratory Partners',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Gilroy-Bold'),
                  ),
                  SizedBox(height: 4),
                  Text('Verified lab partners in the system', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _addLaboratory,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Laboratory'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_laboratories.isEmpty)
            _buildEmptyState('No laboratories added', Icons.science_outlined)
          else
            Expanded(
              child: ListView.builder(
                itemCount: _laboratories.length,
                itemBuilder: (ctx, i) => _buildLabCard(_laboratories[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPharmaciesTab() {
    return Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Pharmacy Partners', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ElevatedButton.icon(onPressed: _addPharmacy, icon: const Icon(Icons.add), label: const Text('Add')),
      ]),
      if (_pharmacies.isEmpty) _buildEmptyState('No pharmacies', Icons.local_pharmacy_outlined),
    ]));
  }

  Widget _buildInstructorsTab() {
    return Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Instructors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ElevatedButton.icon(onPressed: _addInstructor, icon: const Icon(Icons.add), label: const Text('Add')),
      ]),
      if (_instructors.isEmpty) _buildEmptyState('No instructors', Icons.school_outlined),
    ]));
  }

  Widget _buildStudentsTab() {
    return Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Students', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ElevatedButton.icon(onPressed: _addStudent, icon: const Icon(Icons.add), label: const Text('Add')),
      ]),
      if (_students.isEmpty) _buildEmptyState('No students', Icons.person_outline),
    ]));
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.primaryColor.withValues(alpha: 0.06), shape: BoxShape.circle),
        child: Icon(icon, size: 48, color: AppColors.primaryColor.withValues(alpha: 0.5))),
      const SizedBox(height: 16),
      Text(msg, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    ]));
  }

  Widget _buildDoctorApprovalCard(Map<String, dynamic> d) {
    final role = d['role']?.toString() ?? 'unknown';
    final details = d['profileDetails'] as Map? ?? {};

    Widget infoRow(IconData icon, String label, String? value) {
      if (value == null || value.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)))),
        ]),
      );
    }

    String roleLabel() {
      switch (role) {
        case 'doctor': return 'Doctor';
        case 'pharmacy': return 'Pharmacy';
        case 'lab': return 'Laboratory';
        case 'student': return 'Student';
        case 'instructor': return 'Instructor';
        default: return role.isNotEmpty ? role[0].toUpperCase() + role.substring(1) : 'Unknown';
      }
    }

    final Color roleColor;
    switch (role) {
      case 'doctor': roleColor = const Color(0xFF0036BC); break;
      case 'pharmacy': roleColor = const Color(0xFF10B981); break;
      case 'lab': roleColor = const Color(0xFF8B5CF6); break;
      case 'student': roleColor = const Color(0xFFF59E0B); break;
      case 'instructor': roleColor = const Color(0xFFEF4444); break;
      default: roleColor = AppColors.primaryColor;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: roleColor.withValues(alpha: 0.05),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          ),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: roleColor.withValues(alpha: 0.15),
              child: Icon(Icons.person, color: roleColor),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['name'] ?? 'Unknown', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(d['email']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(roleLabel(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: roleColor)),
            ),
          ]),
        ),
        // Details
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            infoRow(Icons.phone_outlined, 'Phone', d['phone']?.toString()),
            infoRow(Icons.location_city_outlined, 'City', d['city']?.toString()),
            infoRow(Icons.location_on_outlined, 'Address', d['address']?.toString()),
            if (role == 'doctor') ...[
              infoRow(Icons.school_outlined, 'Qualification', (details['qualification'] ?? d['qualification'])?.toString()),
              infoRow(Icons.psychology_outlined, 'Specialization', (details['specialization'] ?? d['specialization'])?.toString()),
              infoRow(Icons.numbers_rounded, 'PMDC No.', (details['pmdcNumber'] ?? d['pmdcNumber'])?.toString()),
              infoRow(Icons.timeline_outlined, 'Experience', (details['experience'] ?? d['experience'])?.toString()),
              infoRow(Icons.local_hospital_outlined, 'Workplace', (details['workplace'] ?? d['workplace'])?.toString()),
              infoRow(Icons.schedule_outlined, 'Timings', (details['availableTimings'] ?? d['availableTimings'])?.toString()),
            ] else if (role == 'pharmacy') ...[
              infoRow(Icons.local_pharmacy_outlined, 'Pharmacy Name', (details['pharmacyName'] ?? d['pharmacyName'])?.toString()),
              infoRow(Icons.badge_outlined, 'Drug License', (details['drugLicenseNumber'] ?? d['drugLicenseNumber'])?.toString()),
              infoRow(Icons.person_outline, 'Pharmacist', (details['pharmacistName'] ?? d['pharmacistName'])?.toString()),
              infoRow(Icons.timeline_outlined, 'Years Operating', (details['yearsOfOperation'] ?? d['yearsOfOperation'])?.toString()),
            ] else if (role == 'lab') ...[
              infoRow(Icons.biotech_outlined, 'Lab Name', (details['labName'] ?? d['labName'])?.toString()),
              infoRow(Icons.badge_outlined, 'License No.', (details['labLicenseNumber'] ?? d['labLicenseNumber'])?.toString()),
              infoRow(Icons.timeline_outlined, 'Years Operating', (details['yearsOfOperation'] ?? d['yearsOfOperation'])?.toString()),
            ] else if (role == 'student') ...[
              infoRow(Icons.account_balance_outlined, 'University', (details['university'] ?? d['university'])?.toString()),
              infoRow(Icons.menu_book_outlined, 'Program', (details['program'] ?? d['program'])?.toString()),
              infoRow(Icons.timeline_outlined, 'Current Year', (details['currentYear'] ?? d['currentYear'])?.toString()),
              infoRow(Icons.badge_outlined, 'Student ID', (details['studentId'] ?? d['studentId'])?.toString()),
            ] else if (role == 'instructor') ...[
              infoRow(Icons.school_outlined, 'Qualification', (details['qualification'] ?? d['qualification'])?.toString()),
              infoRow(Icons.psychology_outlined, 'Specialization', (details['specialization'] ?? d['specialization'])?.toString()),
              infoRow(Icons.timeline_outlined, 'Experience', (details['experience'] ?? d['experience'])?.toString()),
              infoRow(Icons.account_balance_outlined, 'Institution', (details['institution'] ?? d['institution'])?.toString()),
              infoRow(Icons.menu_book_outlined, 'Proposed Courses', (details['proposedCourses'] ?? d['proposedCourses'])?.toString()),
            ],
            if ((details['comments'] ?? d['comments'])?.toString().isNotEmpty == true)
              infoRow(Icons.comment_outlined, 'Comments', (details['comments'] ?? d['comments'])?.toString()),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _rejectDoctor(d),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton.icon(
                onPressed: () => _approveDoctor(d),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _buildLabCard(Map<String, dynamic> lab) {
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [const Icon(Icons.science), const SizedBox(width: 12),
        Expanded(child: Text(lab['name'] ?? 'Lab')), IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () {})]));
  }

  void _addLaboratory() {
    showDialog(
      context: context,
      builder: (ctx) => _AddLaboratoryDialog(
        onAdd: (labData) async {
          setState(() => _isLoading = true);
          try {
            // In real implementation, call backend API
            await Future.delayed(const Duration(seconds: 1));

            setState(() {
              _laboratories.add(labData);
              _isLoading = false;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Laboratory "${labData['name']}" added successfully'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            }
          } catch (e) {
            setState(() => _isLoading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to add laboratory'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _addPharmacy() {
    showDialog(
      context: context,
      builder: (ctx) => _AddPharmacyDialog(
        onAdd: (pharmacyData) async {
          setState(() => _isLoading = true);
          try {
            await Future.delayed(const Duration(seconds: 1));
            setState(() {
              _pharmacies.add(pharmacyData);
              _isLoading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Pharmacy "${pharmacyData['name']}" added successfully'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            }
          } catch (e) {
            setState(() => _isLoading = false);
          }
        },
      ),
    );
  }

  void _addInstructor() {
    showDialog(
      context: context,
      builder: (ctx) => _AddInstructorDialog(
        onAdd: (instructorData) async {
          setState(() => _isLoading = true);
          try {
            await Future.delayed(const Duration(seconds: 1));
            setState(() {
              _instructors.add(instructorData);
              _isLoading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Instructor "${instructorData['name']}" added successfully'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            }
          } catch (e) {
            setState(() => _isLoading = false);
          }
        },
      ),
    );
  }

  void _addStudent() {
    showDialog(
      context: context,
      builder: (ctx) => _AddStudentDialog(
        onAdd: (studentData) async {
          setState(() => _isLoading = true);
          try {
            await Future.delayed(const Duration(seconds: 1));
            setState(() {
              _students.add(studentData);
              _isLoading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Student "${studentData['name']}" added successfully'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            }
          } catch (e) {
            setState(() => _isLoading = false);
          }
        },
      ),
    );
  }

  void _approveDoctor(Map<String, dynamic> d) async {
    final userId = d['_id']?.toString() ?? d['id']?.toString() ?? '';
    if (userId.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await _api.put('/admin/users/$userId/approve', {'status': 'approved'});
      if (mounted) {
        setState(() { _pendingDoctors.remove(d); _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${d['name'] ?? 'User'} approved successfully'),
          backgroundColor: const Color(0xFF10B981),
        ));
      }
    } catch (e) {
      // Fallback: try alternate endpoint pattern
      try {
        await _api.post('/admin/approve-user', {'userId': userId});
        if (mounted) {
          setState(() { _pendingDoctors.remove(d); _isLoading = false; });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${d['name'] ?? 'User'} approved successfully'),
            backgroundColor: const Color(0xFF10B981),
          ));
        }
      } catch (e2) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to approve: $e2'),
            backgroundColor: Colors.red,
          ));
        }
      }
    }
  }

  void _rejectDoctor(Map<String, dynamic> d) async {
    final userId = d['_id']?.toString() ?? d['id']?.toString() ?? '';
    if (userId.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await _api.put('/admin/users/$userId/reject', {'status': 'rejected'});
      if (mounted) {
        setState(() { _pendingDoctors.remove(d); _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${d['name'] ?? 'User'} rejected'),
          backgroundColor: const Color(0xFFF59E0B),
        ));
      }
    } catch (e) {
      try {
        await _api.post('/admin/reject-user', {'userId': userId});
        if (mounted) {
          setState(() { _pendingDoctors.remove(d); _isLoading = false; });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${d['name'] ?? 'User'} rejected'),
            backgroundColor: const Color(0xFFF59E0B),
          ));
        }
      } catch (e2) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to reject: $e2'),
            backgroundColor: Colors.red,
          ));
        }
      }
    }
  }

  // ── Leave Requests Tab ────────────────────────────────────────────────────

  Widget _buildLeaveRequestsTab() {
    final fmt = DateFormat('dd MMM yyyy');
    if (_leaveRequests.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(40),
        child: Text('No leave requests yet.', style: TextStyle(fontSize: 15, color: Color(0xFF64748B))),
      ));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _leaveRequests.length,
        itemBuilder: (_, i) {
          final r = _leaveRequests[i];
          final status = r['status']?.toString() ?? 'pending';
          final from = DateTime.tryParse(r['fromDate']?.toString() ?? '');
          final to   = DateTime.tryParse(r['toDate']?.toString() ?? '');
          final conflicts = r['conflictingAppointments'] as int? ?? 0;
          final Color statusColor = status == 'approved' ? Colors.green : status == 'rejected' ? Colors.red : const Color(0xFFF59E0B);

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r['doctorName']?.toString() ?? 'Doctor', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  if (r['doctorEmail'] != null) Text(r['doctorEmail'].toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.date_range_rounded, size: 15, color: Color(0xFF64748B)),
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
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => _updateLeaveStatus(r['doctorId'].toString(), r['_id'].toString(), 'approved'),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  )),
                ]),
              ],
            ]),
          );
        },
      ),
    );
  }

  // ── Credentials / Certificates Tab ───────────────────────────────────────

  Widget _buildCredentialsTab() {
    if (_credentials.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(40),
        child: Text('No certificate submissions yet.', style: TextStyle(fontSize: 15, color: Color(0xFF64748B))),
      ));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _credentials.length,
        itemBuilder: (_, i) {
          final c = _credentials[i];
          final status = c['status']?.toString() ?? 'pending';
          final Color statusColor = status == 'verified' ? Colors.green : status == 'rejected' ? Colors.red : const Color(0xFFF59E0B);

          final docUrl = c['documentUrl']?.toString() ?? '';
          final hasDoc = docUrl.isNotEmpty;
          return GestureDetector(
            onTap: hasDoc ? () async {
              final uri = Uri.tryParse(docUrl);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            } : null,
            child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: hasDoc ? statusColor.withValues(alpha: 0.3) : statusColor.withValues(alpha: 0.2)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF3B82F6), size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c['title']?.toString() ?? 'Certificate', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  Text('Dr. ${c['doctorName'] ?? ''}  •  ${c['type'] ?? ''}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(status == 'pending' ? 'UNVERIFIED' : status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
                ),
              ]),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: hasDoc ? () async {
                  final uri = Uri.tryParse(docUrl);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                } : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No document attached to this certificate.'), duration: Duration(seconds: 2)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: hasDoc ? const Color(0xFF3B82F6).withValues(alpha: 0.07) : Colors.grey.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: hasDoc ? const Color(0xFF3B82F6).withValues(alpha: 0.25) : Colors.grey.withValues(alpha: 0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(hasDoc ? Icons.description_outlined : Icons.description_outlined, color: hasDoc ? const Color(0xFF3B82F6) : Colors.grey, size: 16),
                    const SizedBox(width: 6),
                    Text('View Certificate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: hasDoc ? const Color(0xFF3B82F6) : Colors.grey)),
                    if (hasDoc) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.open_in_new_rounded, color: Color(0xFF3B82F6), size: 13),
                    ] else ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.block_rounded, color: Colors.grey, size: 13),
                    ],
                  ]),
                ),
              ),
              if (status == 'pending') ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => _updateCredentialStatus(c['doctorId'].toString(), c['_id'].toString(), 'rejected'),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => _updateCredentialStatus(c['doctorId'].toString(), c['_id'].toString(), 'verified'),
                    icon: const Icon(Icons.verified_rounded, size: 16),
                    label: const Text('Verify'),
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

  // ── Feature 1: Course Categories Tab ────────────────────────────────────────
  Widget _buildCourseCategoriesTab() {
    return _AdminCategoriesPanel(api: _api);
  }
}

// Laboratory Addition Dialog
class _AddLaboratoryDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  const _AddLaboratoryDialog({required this.onAdd});

  @override
  State<_AddLaboratoryDialog> createState() => _AddLaboratoryDialogState();
}

class _AddLaboratoryDialogState extends State<_AddLaboratoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add Laboratory Partner', style: TextStyle(fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Laboratory Name *', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone *', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _licenseController,
                decoration: const InputDecoration(labelText: 'License Number *', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address *', border: OutlineInputBorder()),
                maxLines: 2,
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City *', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final labData = {
                'name': _nameController.text,
                'email': _emailController.text,
                'phone': _phoneController.text,
                'license': _licenseController.text,
                'address': _addressController.text,
                'city': _cityController.text,
                'createdAt': DateTime.now().toIso8601String(),
              };
              Navigator.pop(context);
              widget.onAdd(labData);
            }
          },
          child: const Text('Add Laboratory'),
        ),
      ],
    );
  }
}

// Pharmacy Addition Dialog
class _AddPharmacyDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  const _AddPharmacyDialog({required this.onAdd});

  @override
  State<_AddPharmacyDialog> createState() => _AddPharmacyDialogState();
}

class _AddPharmacyDialogState extends State<_AddPharmacyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add Pharmacy Partner'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Pharmacy Name *'), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
            TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email *'), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
            TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone *'), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
            TextFormField(controller: _licenseController, decoration: const InputDecoration(labelText: 'License *'), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
            TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: 'Address *'), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context);
            widget.onAdd({'name': _nameController.text, 'email': _emailController.text, 'phone': _phoneController.text, 'license': _licenseController.text, 'address': _addressController.text});
          }
        }, child: const Text('Add')),
      ],
    );
  }
}

// Instructor Addition Dialog
class _AddInstructorDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  const _AddInstructorDialog({required this.onAdd});

  @override
  State<_AddInstructorDialog> createState() => _AddInstructorDialogState();
}

class _AddInstructorDialogState extends State<_AddInstructorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _specialtyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add Instructor'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name *'), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
            TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email *'), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
            TextFormField(controller: _specialtyController, decoration: const InputDecoration(labelText: 'Specialty *'), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context);
            widget.onAdd({'name': _nameController.text, 'email': _emailController.text, 'specialty': _specialtyController.text});
          }
        }, child: const Text('Add')),
      ],
    );
  }
}

// Student Addition Dialog
class _AddStudentDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  const _AddStudentDialog({required this.onAdd});

  @override
  State<_AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<_AddStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add Student'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name *'), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
            TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email *'), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context);
            widget.onAdd({'name': _nameController.text, 'email': _emailController.text});
          }
        }, child: const Text('Add')),
      ],
    );
  }
}

// ── Feature 1: Admin Categories Panel ────────────────────────────────────────
class _AdminCategoriesPanel extends StatefulWidget {
  final ApiService api;
  const _AdminCategoriesPanel({required this.api});

  @override
  State<_AdminCategoriesPanel> createState() => _AdminCategoriesPanelState();
}

class _AdminCategoriesPanelState extends State<_AdminCategoriesPanel> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.api.get('/admin/categories?all=true');
      if (mounted) setState(() { _categories = List<Map<String, dynamic>>.from(res.data['categories'] ?? []); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Course Category'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Category Name *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await widget.api.post('/admin/categories', {'name': nameCtrl.text.trim(), 'description': descCtrl.text.trim()});
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category added!'), backgroundColor: Colors.green));
                _load();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> cat) async {
    try {
      await widget.api.put('/admin/categories/${cat['_id']}', {'isActive': !(cat['isActive'] as bool? ?? true)});
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _delete(Map<String, dynamic> cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Delete "${cat['name']}"? Existing courses keep their category value.'),
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
    if (confirm == true) {
      await widget.api.delete('/admin/categories/${cat['_id']}');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Course Categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Category'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white),
          ),
        ]),
        const SizedBox(height: 8),
        const Text('Manage categories available to instructors when creating courses.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        const SizedBox(height: 20),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (!_loading && _categories.isEmpty)
          const Center(child: Text('No categories yet. Add your first one.', style: TextStyle(color: Color(0xFF94A3B8)))),
        if (!_loading)
          ...(_categories.map((cat) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (cat['isActive'] as bool? ?? true) ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cat['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('Value: ${cat['value'] ?? ''}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                if ((cat['description'] as String?)?.isNotEmpty == true)
                  Text(cat['description'].toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ])),
              Switch(
                value: cat['isActive'] as bool? ?? true,
                onChanged: (_) => _toggleActive(cat),
                activeColor: AppColors.primaryColor,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () => _delete(cat),
                tooltip: 'Delete',
              ),
            ]),
          ))),
      ]),
    );
  }
}
