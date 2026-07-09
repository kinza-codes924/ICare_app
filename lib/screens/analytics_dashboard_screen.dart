import 'package:flutter/material.dart';
import 'package:icare/services/analytics_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<dynamic> _revenueTrends = [];
  List<dynamic> _geoDistribution = [];

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _analyticsService.getPlatformStats();
      final trends = await _analyticsService.getRevenueTrends();
      final geo = await _analyticsService.getGeoDistribution();
      if (mounted) {
        setState(() {
          _stats = stats;
          _revenueTrends = trends;
          _geoDistribution = geo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: const Text('Unable to load data. Please try again.')));
    }
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
          'Platform Analytics',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final url = await _analyticsService.exportReport(
                'platform_summary',
              );
              if (url.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Report exported! Download starting...'),
                  ),
                );
              }
            },
            icon: const Icon(
              Icons.download_rounded,
              color: AppColors.primaryColor,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsGrid(),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Revenue Trends'),
                  const SizedBox(height: 16),
                  _buildRevenueChart(),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Geographic Distribution'),
                  const SizedBox(height: 16),
                  _buildGeoDistribution(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Patients',
          _stats['totalPatients']?.toString() ?? '0',
          Icons.people_rounded,
          Colors.blue,
        ),
        _buildStatCard(
          'Total Revenue',
          'PKR ${_stats['totalRevenue']?.toString() ?? '0'}',
          Icons.payments_rounded,
          Colors.green,
        ),
        _buildStatCard(
          'Active Doctors',
          _stats['activeDoctors']?.toString() ?? '0',
          Icons.medical_services_rounded,
          Colors.purple,
        ),
        _buildStatCard(
          'Consultations',
          _stats['totalConsultations']?.toString() ?? '0',
          Icons.video_call_rounded,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    // Simple bar chart using containers
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _revenueTrends.map((trend) {
          final double value = (trend['value'] ?? 0.0) as double;
          final double height = (value / 1000) * 150; // Simple scaling
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 30,
                height: height.clamp(10, 150),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                trend['month'] ?? '',
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGeoDistribution() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _geoDistribution.length,
        separatorBuilder: (_, _) => const Divider(height: 32),
        itemBuilder: (context, index) {
          final item = _geoDistribution[index];
          final double percentage = (item['percentage'] ?? 0.0) as double;
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item['city'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '${(percentage * 100).toInt()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: percentage,
                backgroundColor: const Color(0xFFF1F5F9),
                color: AppColors.primaryColor,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        },
      ),
    );
  }
}
