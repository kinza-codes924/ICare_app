import 'package:flutter/material.dart';
import 'package:icare/models/user.dart';
import 'package:icare/services/appointment_service.dart';
import 'package:icare/services/consultation_service.dart';
import 'package:icare/services/medical_record_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class PatientHistoryView extends StatefulWidget {
  final User patient;
  const PatientHistoryView({super.key, required this.patient});

  @override
  State<PatientHistoryView> createState() => _PatientHistoryViewState();
}

class _PatientHistoryViewState extends State<PatientHistoryView> {
  final AppointmentService _appointmentService = AppointmentService();
  final MedicalRecordService _medicalRecordService = MedicalRecordService();
  final ConsultationService _consultationService = ConsultationService();

  List<dynamic> _appointments = [];
  List<dynamic> _prescriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        _appointmentService.getMyAppointmentsDetailed(),
        _medicalRecordService.getDoctorRecords(),
        _consultationService.getPatientPrescriptions(patientId: widget.patient.id),
      ]);

      final apptResult = futures[0] as Map<String, dynamic>;
      final rxList = futures[2] as List<dynamic>;

      if (apptResult['success'] == true) {
        _appointments = (apptResult['appointments'] as List)
            .where((a) => a.patient?.id == widget.patient.id)
            .where((a) => a.status.toLowerCase() == 'completed' ||
                a.status.toLowerCase() == 'in_progress')
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      }

      _prescriptions = rxList
          .where((rx) => rx['isComplete'] == true)
          .toList()
        ..sort((a, b) {
          final aDate = (a['prescribedAt'] ?? a['createdAt'] ?? '').toString();
          final bDate = (b['prescribedAt'] ?? b['createdAt'] ?? '').toString();
          return bDate.compareTo(aDate);
        });
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.patient.name.isNotEmpty ? widget.patient.name[0].toUpperCase() : 'P';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryColor.withValues(alpha: 0.15),
              child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primaryColor)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.patient.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData, tooltip: 'Refresh'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Stats row ──────────────────────────────────────────
                  Row(
                    children: [
                      _statChip('${_appointments.length}', 'Consultations', AppColors.primaryColor),
                      const SizedBox(width: 8),
                      _statChip('${_prescriptions.length}', 'Prescriptions', const Color(0xFF10B981)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_prescriptions.isEmpty && _appointments.isEmpty)
                    _emptyState('No consultation history found', Icons.history_rounded)
                  else ...[
                    // ── Prescriptions section ──────────────────────────
                    if (_prescriptions.isNotEmpty) ...[
                      _sectionHeader('Prescriptions', Icons.description_rounded, const Color(0xFF10B981)),
                      const SizedBox(height: 8),
                      ..._prescriptions.map((rx) => _rxCard(rx)),
                      const SizedBox(height: 20),
                    ],

                    // ── Consultations section ──────────────────────────
                    if (_appointments.isNotEmpty) ...[
                      _sectionHeader('Past Consultations', Icons.calendar_today_rounded, AppColors.primaryColor),
                      const SizedBox(height: 8),
                      ..._appointments.map((appt) => _apptCard(appt)),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  // ── Prescription card ─────────────────────────────────────────────────────
  Widget _rxCard(dynamic rx) {
    final rawDate = rx['prescribedAt'] ?? rx['createdAt'] ?? '';
    DateTime? date;
    try { date = DateTime.parse(rawDate).toLocal(); } catch (_) {}
    final medicines = (rx['medicines'] as List?) ?? [];
    final diagnoses = (rx['diagnoses'] as List?) ?? [];
    final labTests = (rx['labTests'] as List?) ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD1FAE5), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showRxDetail(rx),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.description_rounded, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          date != null ? DateFormat('EEE, MMM dd yyyy').format(date) : 'Date unknown',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          date != null ? DateFormat('hh:mm a').format(date) : '',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(6)),
                    child: const Text('COMPLETE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ],
              ),
              if (diagnoses.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4, runSpacing: 4,
                  children: diagnoses.take(2).map((d) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(5), border: Border.all(color: const Color(0xFFFCA5A5))),
                    child: Text('${d['icd10Code'] ?? ''} ${d['diagnosis'] ?? ''}'.trim(),
                        style: const TextStyle(fontSize: 10, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                  )).toList(),
                ),
              ],
              if (medicines.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4, runSpacing: 4,
                  children: medicines.take(3).map((m) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(5), border: Border.all(color: const Color(0xFFA7F3D0))),
                    child: Text('${m['medicineName'] ?? ''}${m['dose']?.isNotEmpty == true ? ' ${m['dose']}' : ''}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF065F46), fontWeight: FontWeight.w600)),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('${medicines.length} med${medicines.length != 1 ? 's' : ''}  •  ${labTests.length} lab test${labTests.length != 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const Spacer(),
                  const Text('Tap for details', style: TextStyle(fontSize: 10, color: Color(0xFF10B981))),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Color(0xFF10B981)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRxDetail(dynamic rx) {
    final rawDate = rx['prescribedAt'] ?? rx['createdAt'] ?? '';
    DateTime? date;
    try { date = DateTime.parse(rawDate).toLocal(); } catch (_) {}
    final medicines = (rx['medicines'] as List?) ?? [];
    final diagnoses = (rx['diagnoses'] as List?) ?? [];
    final labTests = (rx['labTests'] as List?) ?? [];
    final doctorNotes = rx['doctorNotes']?.toString() ?? '';
    final soap = rx['soapNotes'] as Map<String, dynamic>?;
    final referral = rx['referralFollowUp'] as Map<String, dynamic>?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.description_rounded, color: Color(0xFF10B981), size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Prescription', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
                    if (date != null) Text(DateFormat('MMMM dd, yyyy • hh:mm a').format(date), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ])),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                  children: [
                    if (diagnoses.isNotEmpty) ...[
                      _rxSectionHead('Diagnosis', Icons.medical_information_rounded, const Color(0xFFEF4444)),
                      ...diagnoses.map((d) => _rxLine(
                        '${d['icd10Code']?.isNotEmpty == true ? '[${d['icd10Code']}] ' : ''}${d['diagnosis'] ?? ''}',
                        icon: Icons.fiber_manual_record, iconColor: const Color(0xFFEF4444), small: true,
                      )),
                      const SizedBox(height: 12),
                    ],
                    if (medicines.isNotEmpty) ...[
                      _rxSectionHead('Medications', Icons.medication_rounded, const Color(0xFF10B981)),
                      ...medicines.map((m) {
                        final name = m['medicineName']?.toString() ?? '';
                        final dose = m['dose']?.toString() ?? '';
                        final freq = m['frequencyDisplay']?.toString() ?? m['frequency']?.toString() ?? '';
                        final dur = m['duration']?.toString() ?? '';
                        final notes = m['notes']?.toString() ?? '';
                        return _rxLine('$name${dose.isNotEmpty ? ' — $dose' : ''}',
                          subtitle: [freq, dur, notes].where((s) => s.isNotEmpty).join(' · '),
                          icon: Icons.medication_outlined, iconColor: const Color(0xFF10B981),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                    if (labTests.isNotEmpty) ...[
                      _rxSectionHead('Lab Tests', Icons.biotech_rounded, const Color(0xFF8B5CF6)),
                      ...labTests.map((t) => _rxLine(t['testName']?.toString() ?? '',
                        icon: Icons.science_outlined, iconColor: const Color(0xFF8B5CF6), small: true)),
                      const SizedBox(height: 12),
                    ],
                    if (doctorNotes.isNotEmpty) ...[
                      _rxSectionHead("Doctor's Notes", Icons.notes_rounded, AppColors.primaryColor),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.primaryColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
                        child: Text(doctorNotes, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (soap != null && (soap['assessment']?.toString().isNotEmpty == true || soap['plan']?.toString().isNotEmpty == true)) ...[
                      _rxSectionHead('Clinical Notes', Icons.edit_note_rounded, const Color(0xFF0EA5E9)),
                      if (soap['subjective']?.isNotEmpty == true) _rxLine('Subjective: ${soap['subjective']}', icon: Icons.circle, iconColor: const Color(0xFF0EA5E9), small: true),
                      if (soap['assessment']?.isNotEmpty == true) _rxLine('Assessment: ${soap['assessment']}', icon: Icons.circle, iconColor: const Color(0xFF0EA5E9), small: true),
                      if (soap['plan']?.isNotEmpty == true) _rxLine('Plan: ${soap['plan']}', icon: Icons.circle, iconColor: const Color(0xFF0EA5E9), small: true),
                      const SizedBox(height: 12),
                    ],
                    if (referral != null && referral['referralType'] != null && referral['referralType'] != 'none') ...[
                      _rxSectionHead('Referral & Follow-up', Icons.event_repeat_rounded, const Color(0xFFEC4899)),
                      _rxLine('Referral: ${referral['referralType']}${referral['referralSpecialty'] != null ? ' — ${referral['referralSpecialty']}' : ''}',
                          icon: Icons.send_rounded, iconColor: const Color(0xFFEC4899), small: true),
                      if (referral['followUpDuration'] != null && referral['followUpDuration'] != 'none')
                        _rxLine('Follow-up: ${referral['followUpDuration']}',
                            icon: Icons.calendar_today_rounded, iconColor: const Color(0xFFEC4899), small: true),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Appointment card ──────────────────────────────────────────────────────
  Widget _apptCard(dynamic appt) {
    final date = appt.date as DateTime;
    final status = appt.status.toString().toLowerCase();
    final statusColor = _statusColor(status);
    // Clean up reason — remove "Instant consultation via Connect Now" junk
    String reason = appt.reason?.toString() ?? '';
    if (reason.toLowerCase().contains('instant consultation') ||
        reason.toLowerCase().contains('connect now') ||
        reason.toLowerCase().contains('channel:')) {
      reason = 'Instant / Connect Now Consultation';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withValues(alpha: 0.2), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showApptDetail(appt, reason),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.calendar_today_rounded, color: statusColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEE, MMM dd yyyy').format(date),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
                    Text('${appt.timeSlot ?? ''}  •  ${_statusLabel(status)}',
                        style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                    if (reason.isNotEmpty)
                      Text(reason.length > 50 ? '${reason.substring(0, 50)}...' : reason,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: statusColor.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }

  void _showApptDetail(dynamic appt, String reason) {
    final date = appt.date as DateTime;
    final status = appt.status.toString().toLowerCase();
    final statusColor = _statusColor(status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        maxChildSize: 0.7,
        minChildSize: 0.35,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.calendar_month_rounded, color: statusColor, size: 22)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(DateFormat('EEEE, MMMM dd, yyyy').format(date),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
                        Text(appt.timeSlot ?? '', style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
                      ])),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(8)),
                          child: Text(_statusLabel(status).toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white))),
                    ]),
                    const SizedBox(height: 16),
                    if (reason.isNotEmpty)
                      _detailTile(Icons.notes_rounded, 'Chief Complaint / Reason', reason, AppColors.primaryColor),
                    const SizedBox(height: 8),
                    _detailTile(Icons.person_rounded, 'Patient', widget.patient.name, const Color(0xFF3B82F6)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _statChip(String value, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _sectionHeader(String title, IconData icon, Color color) => Row(children: [
    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16)),
    const SizedBox(width: 8),
    Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: color)),
  ]);

  Widget _rxSectionHead(String label, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: color)),
    ]),
  );

  Widget _rxLine(String text, {String? subtitle, required IconData icon, required Color iconColor, bool small = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 3), child: Icon(icon, size: small ? 8 : 15, color: iconColor)),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text, style: TextStyle(fontSize: small ? 12 : 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
        if (subtitle != null && subtitle.trim().isNotEmpty)
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ])),
    ]),
  );

  Widget _detailTile(IconData icon, String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.15))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.8))),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
      ])),
    ]),
  );

  Widget _emptyState(String msg, IconData icon) => Center(
    child: Padding(padding: const EdgeInsets.all(48), child: Column(children: [
      Icon(icon, size: 56, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text(msg, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
    ])),
  );

  Color _statusColor(String status) {
    switch (status) {
      case 'completed': return const Color(0xFF10B981);
      case 'in_progress': return const Color(0xFF8B5CF6);
      default: return AppColors.primaryColor;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed': return 'Completed';
      case 'in_progress': return 'In Progress';
      default: return status;
    }
  }
}
