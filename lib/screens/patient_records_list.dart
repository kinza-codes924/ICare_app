import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/models/medical_record.dart';
import 'package:icare/services/medical_record_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/screens/medical_record_detail.dart';
import 'package:intl/intl.dart';

class PatientRecordsListScreen extends StatefulWidget {
  const PatientRecordsListScreen({super.key});

  @override
  State<PatientRecordsListScreen> createState() =>
      _PatientRecordsListScreenState();
}

class _PatientRecordsListScreenState extends State<PatientRecordsListScreen> {
  final MedicalRecordService _service = MedicalRecordService();
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
      debugPrint('📋 Patient Records - Fetching records...');
      final result = await _service.getDoctorRecords();

      debugPrint('📋 Patient Records - Result success: ${result['success']}');

      if (result['success']) {
        final recordsList = result['records'] as List;
        debugPrint('📋 Patient Records - Found ${recordsList.length} records');

        final parsedRecords = <MedicalRecord>[];
        for (var i = 0; i < recordsList.length; i++) {
          try {
            debugPrint('📋 Parsing record $i: ${recordsList[i]}');
            final record = MedicalRecord.fromJson(recordsList[i]);
            parsedRecords.add(record);
            debugPrint('✅ Record $i parsed successfully');
          } catch (e) {
            debugPrint('❌ Error parsing record $i: $e');
          }
        }

        setState(() {
          _records = parsedRecords;
          _isLoading = false;
        });
        debugPrint(
          '✅ Patient Records - Loaded ${_records.length} records into state',
        );
      } else {
        debugPrint('❌ Patient Records - Failed: ${result['message']}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Patient Records - Exception: $e');
      setState(() => _isLoading = false);
    }
  }

  List<MedicalRecord> get _filteredRecords {
    if (_searchQuery.isEmpty) return _records;
    return _records.where((r) {
      return r.patient.name.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (r.diagnosis?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 600;
    final filteredList = _filteredRecords;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Patient Records",
          style: TextStyle(
            fontSize: 18,
            fontFamily: "Gilroy-Bold",
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            color: Colors.white,
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search by patient name or diagnosis',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryColor),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
          ),

          // Records List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No patient records found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadRecords,
                    child: ListView.builder(
                      padding: EdgeInsets.all(isDesktop ? 24 : 16),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final record = filteredList[index];
                        return _buildRecordCard(record);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(MedicalRecord record) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => MedicalRecordDetailScreen(record: record),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    record.patient.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 22,
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
                      record.patient.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (record.diagnosis != null)
                      Text(
                        record.diagnosis!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM dd, yyyy').format(record.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
