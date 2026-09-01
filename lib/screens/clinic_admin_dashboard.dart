import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/clinic_admin_staff_tab.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

// Dashboard for a clinic-scoped admin account. Tab 1 is the original
// booking-visibility view (every telehealth appointment, in-person
// appointment, or front-desk walk-in for doctors under their standalone
// iCare Clinic — the "hamare paas kaise information aayegi" ask). Tabs 2-5
// let the clinic admin create/manage their own clinic's Receptionist,
// Doctor, Lab, and Pharmacy staff — every /clinic-admin/* endpoint derives
// the clinic from the logged-in admin's own account server-side, so none of
// these tabs ever need a clinic picker.
class ClinicAdminDashboard extends ConsumerStatefulWidget {
  const ClinicAdminDashboard({super.key});

  @override
  ConsumerState<ClinicAdminDashboard> createState() => _ClinicAdminDashboardState();
}

class _ClinicAdminDashboardState extends ConsumerState<ClinicAdminDashboard> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 5, vsync: this);

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out?'),
        content: const Text('You will need to sign in again to access the clinic dashboard.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authProvider.notifier).setUserLogout();
      if (mounted) context.go('/login');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        // Same as admin_clinic_management: maybePop() does nothing when this
        // route is the only one on the stack (opened by URL).
        leading: const CustomBackButton(color: Colors.white),
        title: const Text('Clinic Dashboard'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log Out',
            onPressed: _confirmLogout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Bookings'),
            Tab(text: 'Receptionists'),
            Tab(text: 'Doctors'),
            Tab(text: 'Lab'),
            Tab(text: 'Pharmacy'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _BookingsTab(),
          ClinicAdminStaffTab(
            role: 'Receptionist',
            listEndpoint: '/clinic-admin/receptionists',
            createEndpoint: '/clinic-admin/receptionists',
            listKey: 'receptionists',
            extraFields: [StaffExtraField(key: 'speciality', label: 'Speciality')],
            showDoctorAssignment: true,
          ),
          ClinicAdminStaffTab(
            role: 'Doctor',
            listEndpoint: '/clinic-admin/doctors',
            createEndpoint: '/clinic-admin/doctors',
            listKey: 'doctors',
            extraFields: [StaffExtraField(key: 'specialization', label: 'Specialization')],
          ),
          ClinicAdminStaffTab(
            role: 'Lab',
            listEndpoint: '/clinic-admin/lab',
            createEndpoint: '/clinic-admin/lab',
            listKey: 'labs',
            extraFields: [StaffExtraField(key: 'lab_name', label: 'Lab Name')],
          ),
          ClinicAdminStaffTab(
            role: 'Pharmacy',
            listEndpoint: '/clinic-admin/pharmacy',
            createEndpoint: '/clinic-admin/pharmacy',
            listKey: 'pharmacies',
            extraFields: [StaffExtraField(key: 'pharmacy_name', label: 'Pharmacy Name')],
          ),
        ],
      ),
    );
  }
}

// Original bookings-visibility view, unchanged — now Tab 0 of
// ClinicAdminDashboard instead of the whole screen.
class _BookingsTab extends StatefulWidget {
  const _BookingsTab();

  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  List<dynamic> _bookings = [];
  String _filter = 'all'; // all | appointment | telehealth | walk-in

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

  List<dynamic> get _filteredBookings =>
      _filter == 'all' ? _bookings : _bookings.where((b) => b['bookingType'] == _filter).toList();

  int _countOf(String type) => _bookings.where((b) => b['bookingType'] == type).length;
  int get _paidCount => _bookings.where((b) => b['paymentStatus'] == 'paid').length;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildStatsHeader()),
                      SliverToBoxAdapter(child: _buildFilterChips()),
                      _filteredBookings.isEmpty
                          ? SliverFillRemaining(
                              hasScrollBody: false,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 60),
                                child: Column(
                                  children: [
                                    const Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFCBD5E1)),
                                    const SizedBox(height: 12),
                                    const Text('No bookings yet.', style: TextStyle(color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                            )
                          : SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final b = _filteredBookings[index];
                                    final type = b['bookingType']?.toString() ?? 'appointment';
                                    final color = _typeColor(type);
                                    final createdAt = DateTime.tryParse(b['createdAt']?.toString() ?? '');
                                    return TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: 1),
                                      duration: Duration(milliseconds: 220 + (index.clamp(0, 10)) * 35),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, value, child) => Opacity(
                                        opacity: value,
                                        child: Transform.translate(offset: Offset(0, (1 - value) * 10), child: child),
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
                                              color: color.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(_typeIcon(type), color: color, size: 20),
                                          ),
                                          title: Text(
                                            b['patientName']?.toString() ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                          subtitle: Text(
                                            '${_typeLabel(type)} · Dr. ${b['doctorName'] ?? ''} · ${b['status'] ?? ''}'
                                            '${createdAt != null ? ' · ${createdAt.day}/${createdAt.month}/${createdAt.year}' : ''}',
                                            style: const TextStyle(fontSize: 12.5),
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
                                      ),
                                    );
                                  },
                                  childCount: _filteredBookings.length,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(child: _statCard('Total', _bookings.length.toString(), Icons.event_note_outlined, AppColors.primaryColor)),
          const SizedBox(width: 10),
          Expanded(child: _statCard('Paid', _paidCount.toString(), Icons.check_circle_outline, Colors.green)),
          const SizedBox(width: 10),
          Expanded(child: _statCard('Walk-in', _countOf('walk-in').toString(), Icons.storefront_outlined, Colors.teal)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(opacity: v, child: Transform.scale(scale: 0.9 + 0.1 * v, child: child)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final options = [
      ('all', 'All'),
      ('appointment', 'Appointments'),
      ('telehealth', 'Telehealth'),
      ('walk-in', 'Walk-in'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: options.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final (value, label) = options[i];
            final selected = _filter == value;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setState(() => _filter = value),
                selectedColor: AppColors.primaryColor,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: selected ? AppColors.primaryColor : const Color(0xFFE2E8F0)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
