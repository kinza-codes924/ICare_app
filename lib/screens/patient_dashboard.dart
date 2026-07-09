import 'package:flutter/material.dart';
import 'package:icare/screens/public_home.dart';

/// Patient Dashboard now shows the same public home layout (mobile view)
class PatientDashboard extends StatelessWidget {
  const PatientDashboard({super.key});

  @override
  Widget build(BuildContext context) => const PublicHomeBody();
}

// ══════════════════════════════════════════════════════════════════════════════
// OLD IMPLEMENTATION (ARCHIVED)
// ══════════════════════════════════════════════════════════════════════════════
/*
class _PatientDashboardState_OLD extends State<PatientDashboard> {
  final AppointmentService _appointmentService = AppointmentService();
  final MedicalRecordService _medicalRecordService = MedicalRecordService();
  final CourseService _courseService = CourseService();
  final GamificationService _gamificationService = GamificationService();

  List<AppointmentDetail> _appointments = [];
  List<dynamic> _medicalRecords = [];
  List<dynamic> _assignedPrograms = [];
  int _points = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final appointmentsResult = await _appointmentService
          .getMyAppointmentsDetailed();
      final recordsResult = await _medicalRecordService.getMyRecords();

      // Fetch assigned programs (care plans)
      List<dynamic> programs = [];
      try {
        programs = await _courseService.myPurchases();
      } catch (_) {
        // Silently handle — programs section stays empty
      }

      if (appointmentsResult['success']) {
        _appointments =
            appointmentsResult['appointments'] as List<AppointmentDetail>;
      }

      if (recordsResult['success']) {
        _medicalRecords = recordsResult['records'] as List<dynamic>;
      }

      final gamificationResult = await _gamificationService.getMyStats();
      if (gamificationResult['success'] == true) {
        _points = gamificationResult['points'] ?? 0;
      }

      _assignedPrograms = programs;
    } catch (_) {
      // Silent fail — dashboard still shows with available data
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<AppointmentDetail> get _upcomingAppointments {
    final now = DateTime.now();
    return _appointments.where((a) {
      return (a.status == 'confirmed' || a.status == 'pending') &&
          a.date.isAfter(now.subtract(const Duration(days: 1)));
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(authProvider).user?.name ?? 'Patient';
    final mrNumber = ref.watch(authProvider).user?.mrNumber;
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isDesktop ? 32 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeHeader(userName, mrNumber),
                    const SizedBox(height: 24),
                    _buildQuickStats(isDesktop),
                    const SizedBox(height: 24),
                    _buildActiveTreatmentOverview(),
                    const SizedBox(height: 24),
                    _buildGamificationCard(context, isDesktop),
                    const SizedBox(height: 24),
                    _buildGamificationSummary(),
                    const SizedBox(height: 24),
                    _buildUrgentCareAction(),
                    const SizedBox(height: 24),
                    _buildUpcomingAppointments(),
                    const SizedBox(height: 32),
                    _buildLifestyleTrackerBanner(),
                    const SizedBox(height: 32),
                    _buildHealthJourneyBanner(),
                    const SizedBox(height: 24),
                    _buildLabResultsOverview(),
                    const SizedBox(height: 24),
                    _buildCarePlans(),
                    const SizedBox(height: 24),
                    _buildSubscriptionBanner(),
                    const SizedBox(height: 24),
                    _buildQuickActions(isDesktop),
                    const SizedBox(height: 24),
                    _buildUnifiedTimeline(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeHeader(String userName, String? mrNumber) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello,',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                // MR Number badge
                if (mrNumber != null && mrNumber.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge_rounded,
                            color: Colors.white70, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          mrNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  DateFormat('EEEE, MMMM dd, yyyy').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTreatmentOverview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.medical_information_rounded, color: Color(0xFF6366F1), size: 22),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Active Care',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Your current treatment overview',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          // Row of 3 tiles
          IntrinsicHeight(
            child: Row(
              children: [
                _buildCareTile(
                  Icons.medication_rounded,
                  const Color(0xFF3B82F6),
                  'My Medications',
                  'View prescriptions',
                  () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const PatientPrescriptions()),
                  ),
                ),
                Container(width: 1, color: const Color(0xFFF1F5F9)),
                _buildCareTile(
                  Icons.biotech_rounded,
                  const Color(0xFF8B5CF6),
                  'My Lab Tests',
                  'View test orders & reports',
                  () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const PatientLabOrdersScreen()),
                  ),
                ),
                Container(width: 1, color: const Color(0xFFF1F5F9)),
                _buildCareTile(
                  Icons.health_and_safety_rounded,
                  const Color(0xFF10B981),
                  'My Programs',
                  'Health & care plans',
                  () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const Courses(myPurchased: true)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareTile(IconData icon, Color color, String title, String subtitle, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(0),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats(bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (isDesktop) {
          return Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Appointments',
                  _appointments.length,
                  Icons.calendar_month_rounded,
                  const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Medical Records',
                  _medicalRecords.length,
                  Icons.folder_rounded,
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Health Points',
                  _points,
                  Icons.stars_rounded,
                  const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Upcoming',
                  _upcomingAppointments.length,
                  Icons.schedule_rounded,
                  const Color(0xFF8B5CF6),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Appts',
                    _appointments.length,
                    Icons.calendar_month_rounded,
                    const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Records',
                    _medicalRecords.length,
                    Icons.folder_rounded,
                    const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Points',
                    _points,
                    Icons.stars_rounded,
                    const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Upcoming',
                    _upcomingAppointments.length,
                    Icons.schedule_rounded,
                    const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Upcoming Appointments',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const MyAppointmentsListScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('View All'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _upcomingAppointments.isEmpty
            ? Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_available_rounded,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No upcoming appointments',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: _upcomingAppointments.take(3).map((appointment) {
                  return _buildAppointmentCard(appointment);
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildAppointmentCard(AppointmentDetail appointment) {
    final statusColor = _getStatusColor(appointment.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [statusColor, statusColor.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                appointment.doctor?.name.substring(0, 1).toUpperCase() ?? 'D',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dr. ${appointment.doctor?.name ?? 'Doctor'}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM dd').format(appointment.date),
                      style: TextStyle(
                        fontSize: 13,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      appointment.timeSlot,
                      style: TextStyle(
                        fontSize: 13,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              appointment.status.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _buildActionCard(
              'Find Doctors',
              Icons.search_rounded,
              const Color(0xFF3B82F6),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => const DoctorsList()),
                );
              },
            ),
            _buildActionCard(
              'My Records',
              Icons.folder_rounded,
              const Color(0xFF10B981),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const PatientMedicalRecords(),
                  ),
                );
              },
            ),
            _buildActionCard(
              'Prescriptions',
              Icons.medication_rounded,
              const Color(0xFFF59E0B),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const PatientPrescriptions(),
                  ),
                );
              },
            ),
            _buildActionCard(
              'Health Journey',
              Icons.timeline_rounded,
              const Color(0xFF0EA5E9),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const HealthJourneyTimeline(),
                  ),
                );
              },
            ),
            _buildActionCard(
              'Health Tracker',
              Icons.favorite_rounded,
              const Color(0xFFEF4444),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => const HealthTracker()),
                );
              },
            ),
            _buildActionCard(
              'Subscriptions',
              Icons.card_membership_rounded,
              const Color(0xFFEC4899),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const SubscriptionScreen(),
                  ),
                );
              },
            ),
            _buildActionCard(
              'Achievements',
              Icons.emoji_events_rounded,
              const Color(0xFFFBBF24),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const GamificationScreen(),
                  ),
                );
              },
            ),
            _buildActionCard(
              'My Lab Tests',
              Icons.science_rounded,
              const Color(0xFF8B5CF6),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const PatientLabOrdersScreen(),
                  ),
                );
              },
            ),
            _buildActionCard(
              'Book Lab Test',
              Icons.biotech_rounded,
              const Color(0xFF7C3AED),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => const LabsListScreen()),
                );
              },
            ),
            _buildActionCard(
              'Pharmacies',
              Icons.local_pharmacy_rounded,
              const Color(0xFF14B8A6),
              () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (ctx) => PharmaciesScreen()));
              },
            ),
            _buildActionCard(
              'Reminders',
              Icons.alarm_rounded,
              const Color(0xFFF43F5E),
              () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (ctx) => ReminderList()));
              },
            ),
            _buildActionCard(
              'Lifestyle',
              Icons.directions_run_rounded,
              const Color(0xFF6366F1),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const LifestyleTrackerScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedTimeline() {
    if (_medicalRecords.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Unified Health Timeline',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 16),
        ..._medicalRecords.take(5).expand((record) {
          final date = DateTime.parse(record['createdAt']);
          final diagnosis = record['diagnosis'] ?? 'No diagnosis';
          final List assignedCourses = record['assignedCourses'] ?? [];
          final List labReports = record['labReportUrls'] ?? [];
          final Map prescriptionMap = record['prescription'] ?? {};
          final List medicines = prescriptionMap['medicines'] ?? [];

          List<Widget> timelineEvents = [];

          // 1. Primary Consultation Event
          timelineEvents.add(
            _buildTimelineItem(
              title: diagnosis,
              subtitle:
                  'Consultation with ${record['doctor']?['name'] ?? 'Doctor'}',
              date: date,
              icon: Icons.medical_services_rounded,
              color: const Color(0xFF10B981),
            ),
          );

          // 2. LMS Health Program Event
          for (var course in assignedCourses) {
            String cTitle = 'Health Program';
            if (course is String)
              cTitle = course;
            else if (course is Map)
              cTitle = course['title'] ?? course['name'] ?? 'Health Program';
            timelineEvents.add(
              _buildTimelineItem(
                title: cTitle,
                subtitle: 'Care Plan Assigned',
                date: date.add(const Duration(minutes: 5)),
                icon: Icons.health_and_safety_rounded,
                color: const Color(0xFF8B5CF6),
                isSecondary: true,
              ),
            );
          }

          // 3. Pharmacy Event
          if (medicines.isNotEmpty) {
            timelineEvents.add(
              _buildTimelineItem(
                title: '${medicines.length} Medication(s) Prescribed',
                subtitle: 'Awaiting Pharmacy Fulfillment',
                date: date.add(const Duration(minutes: 10)),
                icon: Icons.medication_rounded,
                color: const Color(0xFFF59E0B),
                isSecondary: true,
              ),
            );
          }

          // 4. Lab Request Event
          if (labReports.isNotEmpty) {
            timelineEvents.add(
              _buildTimelineItem(
                title: 'Laboratory Request Issued',
                subtitle: '${labReports.length} Test(s) Ordered',
                date: date.add(const Duration(minutes: 15)),
                icon: Icons.science_rounded,
                color: const Color(0xFF3B82F6),
                isSecondary: true,
              ),
            );
          }

          return timelineEvents;
        }).toList(),
      ],
    );
  }

  Widget _buildTimelineItem({
    required String title,
    required String subtitle,
    required DateTime date,
    required IconData icon,
    required Color color,
    bool isSecondary = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12, left: isSecondary ? 24 : 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSecondary
              ? color.withValues(alpha: 0.1)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('MMM dd').format(date),
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFF10B981);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'completed':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildGamificationCard(BuildContext context, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF101828), // Sleek deep navy/black
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: const AssetImage(
            'assets/images/stars_bg.png',
          ), // Optional background pattern
          fit: BoxFit.cover,
          opacity: 0.1,
          onError: (_, __) => const SizedBox.shrink(),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Color(0xFFF59E0B),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Health Challenge',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    fontFamily: 'Gilroy-Bold',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Catch stars and earn Health Points!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontFamily: 'Gilroy-Medium',
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const StarClickGame()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Play Now',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarePlans() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Care Plans',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const Courses(myPurchased: true),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('My Progress'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _assignedPrograms.isEmpty
            ? Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.health_and_safety_rounded,
                        color: AppColors.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No active care plans',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Assigned programs will appear here.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _assignedPrograms.length,
                  itemBuilder: (context, index) {
                    final program = _assignedPrograms[index];
                    final title =
                        program['title'] ??
                        program['course']?['title'] ??
                        'Care Plan';
                    double progress = 0.0;
                    final progressData = program['progress'];
                    if (progressData is int) progress = progressData / 100.0;
                    if (progressData is Map)
                      progress = (progressData['percent'] ?? 0) / 100.0;

                    return Container(
                      width: 250,
                      margin: const EdgeInsets.only(right: 12),
                      child: InkWell(
                        onTap: () {
                          final enrollment = program;
                          final course = program['course'] ?? program;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => ViewCourse(
                                courseData: course,
                                enrollmentId:
                                    enrollment['_id'] ?? enrollment['id'],
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primaryColor.withValues(
                                alpha: 0.2,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryColor.withValues(
                                  alpha: 0.05,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.medical_services_rounded,
                                    color: AppColors.primaryColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Progress',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    '${(progress * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                backgroundColor: AppColors.primaryColor
                                    .withValues(alpha: 0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryColor,
                                ),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(3),
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
    );
  }

  Widget _buildUrgentCareAction() {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Requesting urgent care...')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emergency_rounded,
                color: Color(0xFFEF4444),
                size: 28,
              ),
            ),
            const SizedBox(width: 20),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Urgent Care',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Need immediate assistance?',
                    style: TextStyle(fontSize: 14, color: Color(0xFFDC2626)),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFFDC2626),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGamificationSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFDE68A),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Color(0xFFD97706),
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Rewards',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF92400E),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'You have earned 450 points this week!',
                  style: TextStyle(fontSize: 14, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Text(
                'Level 4',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 6,
                width: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLifestyleTrackerBanner() {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (ctx) => const LifestyleTrackerScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.monitor_heart_rounded,
                color: Color(0xFF10B981),
                size: 28,
              ),
            ),
            const SizedBox(width: 20),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lifestyle Tracker',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Log your daily health habits.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthJourneyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'YOUR HEALTH JOURNEY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Track your complete healthcare timeline in one unified view.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const HealthJourneyScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2563EB),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View Timeline',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabResultsOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Lab Results',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildLabResultRow(
                'HbA1c',
                '5.7 %',
                'Normal',
                const Color(0xFF10B981),
              ),
              const Divider(height: 24),
              _buildLabResultRow(
                'Cholesterol',
                '210 mg/dL',
                'High',
                const Color(0xFFEF4444),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'View Full Reports',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabResultRow(
    String test,
    String value,
    String status,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              test,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            Text(
              'Last updated 2 days ago',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Color(0xFF0F172A),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

*/
