import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/services/medical_record_service.dart';
import 'package:icare/models/medical_record.dart';
import 'package:icare/screens/medical_record_detail.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class HealthJourneyTimeline extends StatefulWidget {
  const HealthJourneyTimeline({super.key});

  @override
  State<HealthJourneyTimeline> createState() => _HealthJourneyTimelineState();
}

class _HealthJourneyTimelineState extends State<HealthJourneyTimeline> {
  final ApiService _apiService = ApiService();
  final MedicalRecordService _medicalRecordService = MedicalRecordService();
  List<dynamic> _timeline = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/clinical/health-journey');
      final data = response.data;
      if (data['success'] && mounted) {
        setState(() {
          _timeline = data['timeline'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: const Text('Unable to load data. Please try again.')));
      }
    }
  }

  List<dynamic> get _filteredTimeline {
    if (_selectedFilter == 'all') return _timeline;
    return _timeline
        .where((event) => event['type']?.toLowerCase() == _selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          'Health Journey',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Gilroy-Bold',
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTimeline.isEmpty
                ? _buildEmptyState()
                : _buildTimelineList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
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
                const Text(
                  'Your Health Journey',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track your complete medical history',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.timeline_rounded, size: 48, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All', 'all', Icons.list_rounded, Colors.blue),
          _buildFilterChip(
            'Consultation',
            'consultation',
            Icons.medical_services_rounded,
            Colors.green,
          ),
          _buildFilterChip(
            'Prescription',
            'prescription',
            Icons.medication_rounded,
            Colors.orange,
          ),
          _buildFilterChip(
            'Lab Test',
            'lab',
            Icons.science_rounded,
            Colors.purple,
          ),
          _buildFilterChip(
            'Program',
            'program',
            Icons.school_rounded,
            Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: () {
          setState(() => _selectedFilter = value);
        },
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : color),
        label: Text(label),
        backgroundColor: isSelected ? color : Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timeline_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No health events yet',
            style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineList() {
    return RefreshIndicator(
      onRefresh: _loadTimeline,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _filteredTimeline.length,
        itemBuilder: (context, index) {
          final event = _filteredTimeline[index];
          final isLast = index == _filteredTimeline.length - 1;
          return _buildTimelineItem(event, isLast);
        },
      ),
    );
  }

  Widget _buildTimelineItem(dynamic event, bool isLast) {
    final type = event['type'] ?? 'Event';
    final title = event['title'] ?? 'Health Event';
    final description = event['description'] ?? '';
    final doctor = event['doctor'] ?? 'Doctor';
    final date = DateTime.tryParse(event['date'] ?? '') ?? DateTime.now();
    final recordId = event['recordId']; // Get record ID for navigation

    final color = _getEventColor(type);
    final icon = _getEventIcon(type);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 80,
                color: Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: recordId != null ? () => _navigateToRecord(recordId) : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('MMM dd, yyyy').format(date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        size: 14,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        doctor,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  if (recordId != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Color(0xFF3B82F6),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Tap to view details',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _navigateToRecord(String recordId) async {
    debugPrint('🔍 Fetching medical record: $recordId');

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch the full medical record
      final result = await _medicalRecordService.getMyRecords();

      if (result['success']) {
        final records = (result['records'] as List<dynamic>)
            .map((r) => MedicalRecord.fromJson(r))
            .toList();

        // Find the specific record
        final record = records.firstWhere(
          (r) => r.id == recordId,
          orElse: () => throw Exception('Record not found'),
        );

        // Close loading dialog
        if (mounted) Navigator.pop(context);

        // Navigate to detail screen
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => MedicalRecordDetailScreen(record: record),
            ),
          );
        }
      } else {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load record details')),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching record: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: const Text('Something went wrong. Please try again.')));
      }
    }
  }

  Color _getEventColor(String type) {
    switch (type.toLowerCase()) {
      case 'consultation':
        return Colors.green;
      case 'prescription':
        return Colors.orange;
      case 'lab':
      case 'lab test':
        return Colors.purple;
      case 'program':
        return Colors.teal;
      default:
        return Colors.blue;
    }
  }

  IconData _getEventIcon(String type) {
    switch (type.toLowerCase()) {
      case 'consultation':
        return Icons.medical_services_rounded;
      case 'prescription':
        return Icons.medication_rounded;
      case 'lab':
      case 'lab test':
        return Icons.science_rounded;
      case 'program':
        return Icons.school_rounded;
      default:
        return Icons.event_rounded;
    }
  }
}
