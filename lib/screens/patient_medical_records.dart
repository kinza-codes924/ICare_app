import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/models/medical_record.dart';
import 'package:icare/services/medical_record_service.dart';
import 'package:icare/screens/medical_record_detail.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class PatientMedicalRecords extends ConsumerStatefulWidget {
  const PatientMedicalRecords({super.key});

  @override
  ConsumerState<PatientMedicalRecords> createState() =>
      _PatientMedicalRecordsState();
}

class _PatientMedicalRecordsState extends ConsumerState<PatientMedicalRecords> {
  final MedicalRecordService _medicalRecordService = MedicalRecordService();
  List<MedicalRecord> _records = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('🔍 Loading medical records...');
      final result = await _medicalRecordService.getMyRecords();

      debugPrint('📦 API Response: ${result['success']}');
      debugPrint('📦 Records count: ${result['records']?.length ?? 0}');

      if (result['success'] && mounted) {
        final recordsList = result['records'] as List<dynamic>;
        debugPrint('📋 Processing ${recordsList.length} records');

        final parsedRecords = <MedicalRecord>[];
        for (var i = 0; i < recordsList.length; i++) {
          try {
            final record = MedicalRecord.fromJson(recordsList[i]);
            parsedRecords.add(record);
            debugPrint('✅ Record $i parsed: ${record.diagnosis}');
          } catch (e) {
            debugPrint('❌ Error parsing record $i: $e');
            debugPrint('   Raw data: ${recordsList[i]}');
          }
        }

        setState(() {
          _records = parsedRecords;
          _isLoading = false;
        });

        debugPrint('✅ Successfully loaded ${_records.length} records');
      } else {
        debugPrint('❌ API returned success=false');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading records: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to load data. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  List<MedicalRecord> get _filteredRecords {
    if (_searchQuery.isEmpty) return _records;

    return _records.where((record) {
      final diagnosis = (record.diagnosis ?? '').toLowerCase();
      final symptoms = record.symptoms.join(' ').toLowerCase();
      final query = _searchQuery.toLowerCase();

      return diagnosis.contains(query) || symptoms.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Text(
          'My Medical Records'.tr(),
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Gilroy-Bold',
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(isDesktop ? 24 : 16),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search records...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredRecords.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.folder_off_rounded,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? (_isLoading
                                          ? 'Loading...'
                                          : 'No medical records found')
                                    : 'No records match your search',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              if (!_isLoading && _searchQuery.isEmpty) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Your doctor\'s records will appear here after a consultation',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadRecords,
                          child: ListView.builder(
                            padding: EdgeInsets.all(isDesktop ? 40 : 20),
                            itemCount: _filteredRecords.length,
                            itemBuilder: (context, index) {
                              return _buildRecordCard(_filteredRecords[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildRecordCard(MedicalRecord record) {
    final diagnosis = record.diagnosis ?? 'No diagnosis';
    final doctorName = record.doctor.name;
    final hasNotes = record.intakeNotes != null || record.soapNotes != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            debugPrint('📋 Tapped on record: ${record.id}');
            debugPrint('   Has intake notes: ${record.intakeNotes != null}');
            debugPrint('   Has SOAP notes: ${record.soapNotes != null}');
            debugPrint('   Appointment ID: ${record.appointmentId}');

            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (ctx) => MedicalRecordDetailScreen(record: record),
                  ),
                )
                .then((_) {
                  debugPrint('✅ Returned from detail screen');
                });
          },
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.medical_services_rounded,
                          color: Color(0xFF10B981),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              diagnosis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dr. $doctorName',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            if (hasNotes) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.description_rounded,
                                    size: 12,
                                    color: Colors.green.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Doctor notes available',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            DateFormat('MMM dd').format(record.createdAt),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            DateFormat('yyyy').format(record.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (record.symptoms.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: record.symptoms.take(3).map((symptom) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            symptom,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tap to View Full Details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryColor,
                        ),
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
}
