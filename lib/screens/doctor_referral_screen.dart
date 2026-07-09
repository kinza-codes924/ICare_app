import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/services/doctor_service.dart';
import 'package:icare/services/clinical_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:intl/intl.dart';

class DoctorReferralScreen extends StatefulWidget {
  final AppointmentDetail appointment;

  const DoctorReferralScreen({super.key, required this.appointment});

  @override
  State<DoctorReferralScreen> createState() => _DoctorReferralScreenState();
}

class _DoctorReferralScreenState extends State<DoctorReferralScreen> {
  final DoctorService _doctorService = DoctorService();
  final ClinicalService _clinicalService = ClinicalService();

  List<dynamic> _allDoctors = [];
  List<dynamic> _filteredDoctors = [];
  bool _isLoading = true;
  dynamic _selectedSpecialist;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // Requirement 13.3: Record Sharing
  List<dynamic> _patientRecords = [];
  final List<String> _selectedRecordIds = [];
  bool _isLoadingRecords = true;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
    _loadPatientRecords();
  }

  Future<void> _loadPatientRecords() async {
    try {
      final result = await _clinicalService.getPatientHistory(
        widget.appointment.patient!.id,
      );
      if (mounted) {
        setState(() {
          _patientRecords = result['history'] as List<dynamic>;
          _isLoadingRecords = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRecords = false);
    }
  }

  Future<void> _loadDoctors() async {
    try {
      final result = await _doctorService.getAllDoctors();
      if (mounted) {
        setState(() {
          _allDoctors = result['doctors'] as List<dynamic>;
          // Exclude self from list
          _allDoctors = _allDoctors
              .where((d) => d['user']['_id'] != widget.appointment.doctor)
              .toList();
          _filteredDoctors = _allDoctors;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterDoctors(String query) {
    setState(() {
      _filteredDoctors = _allDoctors.where((d) {
        final name = d['user']['name'].toString().toLowerCase();
        final spec = d['specialization']?.toString().toLowerCase() ?? '';
        return name.contains(query.toLowerCase()) ||
            spec.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _toggleRecordSelection(String id) {
    setState(() {
      if (_selectedRecordIds.contains(id)) {
        _selectedRecordIds.remove(id);
      } else {
        _selectedRecordIds.add(id);
      }
    });
  }

  Future<void> _createReferral() async {
    if (_selectedSpecialist == null || _reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a specialist and provide a reason.'),
        ),
      );
      return;
    }

    try {
      final result = await _clinicalService.createReferral({
        'patientId': widget.appointment.patient!.id,
        'referredTo': _selectedSpecialist['user']['_id'],
        'reason': _reasonController.text,
        'attachedRecords': _selectedRecordIds, // Req 13.3
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referral created successfully with shared records!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to complete action. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          leading: const CustomBackButton(),
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Clinical Referral',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'New Referral'),
              Tab(text: 'Track Referrals'),
            ],
            labelColor: AppColors.primaryColor,
            unselectedLabelColor: Color(0xFF64748B),
            indicatorColor: AppColors.primaryColor,
          ),
        ),
        body: TabBarView(
          children: [_buildNewReferralTab(), _buildTrackingTab()],
        ),
      ),
    );
  }

  Widget _buildNewReferralTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  '1. Select Specialist',
                  Icons.person_search_rounded,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or specialization',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: _filterDoctors,
                ),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: _filteredDoctors.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (ctx, i) {
                      final doc = _filteredDoctors[i];
                      final isSelected =
                          _selectedSpecialist != null &&
                          _selectedSpecialist['_id'] == doc['_id'];
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: AppColors.primaryColor.withValues(
                          alpha: 0.05,
                        ),
                        title: Text(
                          doc['user']['name'] ?? 'Doctor',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(doc['specialization'] ?? 'Specialist'),
                        onTap: () => setState(() => _selectedSpecialist = doc),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primaryColor,
                              )
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader(
                  '2. Share Clinical Records (Req 13.3)',
                  Icons.attachment_rounded,
                ),
                const SizedBox(height: 16),
                _isLoadingRecords
                    ? const Center(child: CircularProgressIndicator())
                    : _patientRecords.isEmpty
                    ? const Text('No records found for this patient.')
                    : Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: _patientRecords.length,
                          separatorBuilder: (_, _) => const Divider(),
                          itemBuilder: (ctx, i) {
                            final record = _patientRecords[i];
                            final id = record['_id'];
                            final isSelected = _selectedRecordIds.contains(id);
                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (_) => _toggleRecordSelection(id),
                              title: Text(
                                record['diagnosis'] ?? 'Clinical Note',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                DateFormat(
                                  'dd MMM yyyy',
                                ).format(DateTime.parse(record['createdAt'])),
                                style: const TextStyle(fontSize: 12),
                              ),
                              activeColor: AppColors.primaryColor,
                            );
                          },
                        ),
                      ),
                const SizedBox(height: 32),
                _buildSectionHeader(
                  '3. Clinical Reason',
                  Icons.description_rounded,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _reasonController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Explain the reason for referral...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    label: 'Submit Referral',
                    onPressed: _createReferral,
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryColor),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingTab() {
    // Requirement 13.11: Referral Tracking Dashboard
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Outbound Referrals',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        _buildReferralTrackCard(
          'Sarah Khan',
          'Cardiology',
          'Ahmed Ali',
          'Consulted',
          Colors.green,
        ),
        _buildReferralTrackCard(
          'Zoya Malik',
          'Dermatology',
          'Usman Raza',
          'Pending',
          Colors.orange,
        ),
        _buildReferralTrackCard(
          'Ahmed Raza',
          'Orthopedics',
          'Sana Khan',
          'In-Progress',
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildReferralTrackCard(
    String patient,
    String spec,
    String doc,
    String status,
    Color color,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '$spec - Dr. $doc',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
