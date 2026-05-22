import 'package:flutter/material.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/screens/chat_screen.dart';
import 'package:icare/screens/doctor_referral_screen.dart';
import 'package:icare/widgets/vitals_chart.dart';
import 'package:icare/screens/intake_notes_redesign.dart';
import 'package:icare/screens/soap_notes_redesign.dart';
import 'package:icare/screens/create_medical_record.dart';
import 'package:icare/screens/doctor_assign_program_screen.dart';
import 'package:icare/screens/video_call.dart';
import 'package:icare/services/appointment_service.dart';
import 'package:icare/services/doctor_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/screens/record_vitals_screen.dart';
import 'package:intl/intl.dart';

class ConsultationWorkflowScreen extends StatefulWidget {
  final AppointmentDetail appointment;

  const ConsultationWorkflowScreen({super.key, required this.appointment});

  @override
  State<ConsultationWorkflowScreen> createState() =>
      _ConsultationWorkflowScreenState();
}

class _ConsultationWorkflowScreenState extends State<ConsultationWorkflowScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DoctorService _doctorService = DoctorService();

  Map<String, dynamic>? _patientHistory;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPatientHistory();
  }

  Future<void> _loadPatientHistory() async {
    try {
      final result = await _doctorService.getPatientHistory(
        widget.appointment.patient!.id,
      );
      if (mounted) {
        setState(() {
          _patientHistory = result['history'];
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
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
            Text(
              'Consultation: ${widget.appointment.patient?.name ?? 'Patient'}',
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Reason: ${widget.appointment.reason ?? 'General Checkup'}',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.video_call_rounded,
              color: AppColors.primaryColor,
            ),
            tooltip: 'Start Video Consultation',
            onPressed: () async {
              // Doctor starts call — update status to in_progress so patient sees Rejoin
              final me = await SharedPref().getUserData();
              if (!context.mounted) return;
              try {
                await AppointmentService().updateAppointmentStatus(
                  appointmentId: widget.appointment.id ?? '',
                  status: 'in_progress',
                );
              } catch (_) {}
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoCall(
                    channelName: widget.appointment.id ?? 'consultation',
                    remoteUserName: widget.appointment.patient?.name ?? 'Patient',
                    isAudioOnly: false,
                    appointmentId: widget.appointment.id,
                    patientId: widget.appointment.patient?.id,
                    currentUserName: me?.name ?? widget.appointment.doctor?.name ?? 'Doctor',
                    currentUserId: me?.id ?? '',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_rounded, color: AppColors.primaryColor),
            tooltip: 'Message Patient',
            onPressed: () {
              // Open Chat with patient (Req 6.16)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    userId: widget.appointment.patient!.id,
                    userName: widget.appointment.patient!.name ?? 'Patient',
                  ),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primaryColor,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: AppColors.primaryColor,
          tabs: const [
            Tab(text: '1. History (DHR)', icon: Icon(Icons.history_rounded)),
            Tab(text: '2. Examination', icon: Icon(Icons.person_search_rounded)),
            Tab(text: '3. Diagnosis', icon: Icon(Icons.biotech_rounded)),
            Tab(text: '4. Treatment Plan', icon: Icon(Icons.assignment_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHistoryTab(),
          _buildExaminationTab(),
          _buildDiagnosisTab(),
          _buildTreatmentPlanTab(),
        ],
      ),
    );
  }

  Widget _buildVitalsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Vitals Recording',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => RecordVitalsScreen(
                        patientId: widget.appointment.patient!.id,
                        patientName: widget.appointment.patient!.name,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Record New Vitals',
                  style: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildVitalsCard(
            'Blood Pressure',
            '120/80',
            'mmHg',
            Icons.speed_rounded,
            Colors.red,
          ),
          const SizedBox(height: 12),
          _buildVitalsCard(
            'Heart Rate',
            '72',
            'bpm',
            Icons.favorite_rounded,
            Colors.pink,
          ),
          const SizedBox(height: 12),
          _buildVitalsCard('SpO2', '98', '%', Icons.air_rounded, Colors.blue),
          const SizedBox(height: 12),
          _buildVitalsCard(
            'Temperature',
            '98.6',
            '°F',
            Icons.thermostat_rounded,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsCard(
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 4),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    final records = _patientHistory?['records'] as List? ?? [];
    final vitals = _patientHistory?['vitals'] as List? ?? [];
    final lifestyle = _patientHistory?['lifestyle'] as List? ?? [];

    // Extract real vitals for charts
    final bpData = vitals.reversed
        .map(
          (v) =>
              double.tryParse(
                v['bloodPressure']?.toString().split('/')[0] ?? '0',
              ) ??
              0.0,
        )
        .toList();
    final hrData = vitals.reversed
        .map((v) => double.tryParse(v['heartRate']?.toString() ?? '0') ?? 0.0)
        .toList();
    final labels = vitals.reversed
        .map(
          (v) => v['createdAt'] != null
              ? DateFormat('MMM dd').format(DateTime.parse(v['createdAt']))
              : '',
        )
        .toList()
        .cast<String>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (vitals.length > 1) ...[
            _buildSectionHeader('Vital Signs Trends'),
            const SizedBox(height: 16),
            VitalsChart(
              title: 'Blood Pressure (Systolic)',
              data: bpData,
              labels: labels,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            VitalsChart(
              title: 'Heart Rate (bpm)',
              data: hrData,
              labels: labels,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 32),
          ],
          _buildSectionHeader('Patient Intake History'),
          const SizedBox(height: 16),
          if (records.isEmpty)
            const Center(child: Text('No previous intake notes found.'))
          else
            ...records.take(10).map((r) {
              final String recordType =
                  r['type']?.toString().toUpperCase() ?? 'RECORD';
              final String createdAt = r['createdAt'] ?? '';
              final String date = createdAt.isNotEmpty
                  ? DateFormat('dd MMM yyyy').format(DateTime.parse(createdAt))
                  : '—';
              final String diagnosis = r['diagnosis'] ?? 'Clinical Note';

              return _buildHistoryCard(
                recordType,
                date,
                diagnosis,
                null,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildVitalCard(dynamic v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('BP: ${v['bloodPressure'] ?? 'N/A'}'),
          Text('Pulse: ${v['heartRate'] ?? 'N/A'}'),
          Text('Temp: ${v['temperature'] ?? 'N/A'}°C'),
        ],
      ),
    );
  }

  Widget _buildRecordCard(dynamic r) {
    final warning = r['interactionWarning'] as String?;
    final labTests = r['labTests'] as List? ?? [];
    final abnormalLabs = labTests
        .where((l) => l['isAbnormal'] == true)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: (warning != null || abnormalLabs.isNotEmpty)
            ? Border.all(color: Colors.red.withValues(alpha: 0.5), width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (warning != null)
            _buildAlertRow(Icons.warning_amber_rounded, warning),
          if (abnormalLabs.isNotEmpty)
            _buildAlertRow(
              Icons.science_rounded,
              'ABNORMAL LABS: ${abnormalLabs.map((l) => l['testName']).join(', ')}',
            ),
          Text(
            r['diagnosis'] ?? 'No Diagnosis',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Dr. ${r['doctor']?['name'] ?? 'Doctor'} - ${r['createdAt'].toString().substring(0, 10)}',
          ),
        ],
      ),
    );
  }

  Widget _buildAlertRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLifestyleCard(List lifestyle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 12,
        children: lifestyle
            .map((l) => Chip(label: Text('${l['type']}: ${l['value']}')))
            .toList(),
      ),
    );
  }

  Widget _buildExaminationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Physical Examination & Intake'),
          _buildWorkflowAction(
            'Clinical Intake Notes',
            'Chief complaint, HPI, and medical history',
            Icons.list_alt_rounded,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    IntakeNotesRedesign(appointment: widget.appointment),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Clinical Assessment & Diagnosis'),
          const SizedBox(height: 16),
          _buildActionCard(
            'Standard SOAP Notes',
            'Record symptoms, observations, and assessment.',
            Icons.history_edu_rounded,
            Colors.blue,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SoapNotesRedesign(appointment: widget.appointment),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            'Specialist Referral',
            'Refer patient to another clinical specialist.',
            Icons.hail_rounded,
            Colors.orange,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DoctorReferralScreen(appointment: widget.appointment),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentPlanTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Treatment & Recommendations'),
          const SizedBox(height: 16),
          _buildActionCard(
            'Prescription & Lab Orders',
            'Issue medication and diagnostic test requests.',
            Icons.medication_rounded,
            Colors.green,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    CreateMedicalRecordScreen(appointment: widget.appointment),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            'Assign Health Program',
            'Enroll patient in a chronic care management program.',
            Icons.monitor_heart_rounded,
            Colors.red,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DoctorAssignProgramScreen(appointment: widget.appointment),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
    String type,
    String date,
    String diagnosis,
    VoidCallback? onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: AppColors.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      type,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  diagnosis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: onTap,
            icon: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Color(0xFFCBD5E1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
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
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFF64748B),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowAction(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return _buildActionCard(
      title,
      subtitle,
      icon,
      AppColors.primaryColor,
      onTap,
    );
  }
}
