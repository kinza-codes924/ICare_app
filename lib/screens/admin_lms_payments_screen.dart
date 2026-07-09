import 'package:flutter/material.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class AdminLmsPaymentsScreen extends StatefulWidget {
  const AdminLmsPaymentsScreen({super.key});

  @override
  State<AdminLmsPaymentsScreen> createState() => _AdminLmsPaymentsScreenState();
}

class _AdminLmsPaymentsScreenState extends State<AdminLmsPaymentsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _enrollments = [];
  bool _isLoading = true;
  int _total = 0;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/admin/lms/enrollments?limit=100');
      if (mounted) {
        setState(() {
          _enrollments = res.data['enrollments'] ?? [];
          _total = res.data['total'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filtered {
    if (_search.isEmpty) return _enrollments;
    final q = _search.toLowerCase();
    return _enrollments.where((e) {
      final student = e['student'] as Map? ?? {};
      final course = e['course'] as Map? ?? {};
      final name = (student['name'] ?? student['username'] ?? '').toString().toLowerCase();
      final email = (student['email'] ?? '').toString().toLowerCase();
      final title = (course['title'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || title.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('LMS Payment Management',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            Text('$_total total enrollments',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search student name, email or course…',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // ── Summary cards ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              _summaryCard('Total Enrollments', _total.toString(), Icons.people_rounded, AppColors.primaryColor),
              const SizedBox(width: 12),
              _summaryCard(
                'Completed',
                _enrollments.where((e) => e['completed'] == true).length.toString(),
                Icons.check_circle_outline_rounded,
                const Color(0xFF10B981),
              ),
              const SizedBox(width: 12),
              _summaryCard(
                'In Progress',
                _enrollments.where((e) => e['completed'] != true).length.toString(),
                Icons.auto_stories_outlined,
                const Color(0xFFF59E0B),
              ),
            ]),
          ),

          // ── List ───────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(_search.isEmpty ? 'No enrollments yet' : 'No results for "$_search"',
                              style: const TextStyle(fontSize: 15, color: Color(0xFF64748B))),
                        ]),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) => _buildRow(filtered[i], i),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ]),
      ),
    );
  }

  Widget _buildRow(dynamic e, int index) {
    final student = e['student'] as Map? ?? {};
    final course = e['course'] as Map? ?? {};
    final name = student['name']?.toString() ?? student['username']?.toString() ?? 'Unknown';
    final email = student['email']?.toString() ?? '';
    final courseTitle = course['title']?.toString() ?? 'Unknown Course';
    final price = course['discountedPrice'] ?? course['price'];
    final priceLabel = (price != null && price != 0) ? 'PKR ${price.toString()}' : 'Free';
    final enrolledAt = e['enrolledAt']?.toString() ?? '';
    final completed = e['completed'] == true;
    final progressData = e['progress'];
    int pct = 0;
    if (progressData is Map) pct = (progressData['percent'] ?? 0).toInt();

    String dateLabel = '';
    if (enrolledAt.isNotEmpty) {
      try { dateLabel = DateFormat('dd MMM yyyy').format(DateTime.parse(enrolledAt)); } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        // Avatar
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryColor),
          ),
        ),
        const SizedBox(width: 12),
        // Info
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            Text(email, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text(courseTitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        completed ? const Color(0xFF10B981) : AppColors.primaryColor),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$pct%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            ]),
          ]),
        ),
        const SizedBox(width: 12),
        // Right side
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: completed ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              completed ? 'Completed' : 'Active',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: completed ? const Color(0xFF059669) : const Color(0xFFD97706),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(priceLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(dateLabel, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ]),
      ]),
    );
  }
}
