import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:icare/services/gamification_service.dart';
import 'package:icare/widgets/back_button.dart';

class GamificationScreen extends StatefulWidget {
  const GamificationScreen({super.key});

  @override
  State<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends State<GamificationScreen>
    with SingleTickerProviderStateMixin {
  final GamificationService _gamificationService = GamificationService();
  late TabController _tabController;

  Map<String, dynamic>? _stats;
  List<dynamic> _leaderboard = [];
  bool _isLoading = true;
  bool _isLoadingLeaderboard = false;
  bool _isRedeeming = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _gamificationService.getMyStats();
      if (mounted) setState(() { _stats = stats; _isLoading = false; });
      if (stats['newBadges'] != null && (stats['newBadges'] as List).isNotEmpty) {
        _showNewBadgesDialog(stats['newBadges']);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLeaderboard() async {
    if (_isLoadingLeaderboard) return;
    setState(() => _isLoadingLeaderboard = true);
    try {
      final leaderboard = await _gamificationService.getLeaderboard();
      if (mounted) setState(() { _leaderboard = leaderboard; _isLoadingLeaderboard = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingLeaderboard = false);
    }
  }

  Future<void> _redeem(String rewardId, String name, int cost) async {
    final points = (_stats?['points'] ?? 0) as int;
    if (points < cost) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Not enough points. Need $cost, you have $points.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Redeem Reward', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Redeem "$name" for $cost points?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isRedeeming = true);
    final result = await _gamificationService.redeemReward(rewardId);
    if (!mounted) return;
    setState(() => _isRedeeming = false);
    if (result['success'] == true) {
      _showRedemptionSuccess(name, result['code'] ?? '', result['remainingPoints'] ?? 0);
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message']?.toString() ?? 'Redemption failed'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _showRedemptionSuccess(String name, String code, int remaining) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.redeem_rounded, color: Color(0xFF10B981), size: 22)),
          const SizedBox(width: 10),
          const Text('Reward Redeemed!', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('You have successfully redeemed "$name"!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
          if (code.isNotEmpty) ...[
            const Text('Your code:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3))),
              child: Text(code, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF6366F1), letterSpacing: 2)),
            ),
            const SizedBox(height: 8),
            const Text('Show this code when booking your appointment or lab test.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ],
          const SizedBox(height: 12),
          Text('Remaining points: $remaining', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Great!', style: TextStyle(fontWeight: FontWeight.w700)))],
      ),
    );
  }

  void _showNewBadgesDialog(List<dynamic> newBadges) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFFFBBF24).withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Text('🎉', style: TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 24),
            const Text('New Badge Earned!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
            const SizedBox(height: 16),
            ...newBadges.map((badge) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(children: [
                Text(badge['icon'] ?? '🏆', style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text(badge['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                Text(badge['description'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ]),
            )),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Awesome!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text('Rewards & Achievements', style: TextStyle(fontSize: 18, fontFamily: 'Gilroy-Bold', fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF6366F1),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          onTap: (index) {
            if (index == 2 && _leaderboard.isEmpty) _loadLeaderboard();
          },
          tabs: const [
            Tab(text: 'My Progress'),
            Tab(text: 'Redeem'),
            Tab(text: 'Leaderboard'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildMyProgressTab(), _buildRedeemTab(), _buildLeaderboardTab()],
            ),
    );
  }

  Widget _buildMyProgressTab() {
    if (_stats == null) return const Center(child: Text('No data available'));

    final points = (_stats!['points'] ?? 0) as int;
    final streak = (_stats!['streak'] ?? 0) as int;
    final badges = _stats!['badges'] as List? ?? [];
    final stats = _stats!['stats'] as Map<String, dynamic>? ?? {};
    final availableBadges = _stats!['availableBadges'] as List? ?? [];
    final history = _stats!['history'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Points + Streak Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                child: const Text('⭐', style: TextStyle(fontSize: 40)),
              ),
              const SizedBox(width: 20),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total Points', style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('$points', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 2),
                Text('≈ PKR ${(points * 0.01).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                const SizedBox(height: 4),
                Row(children: [
                  const Text('🔥', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text('$streak-day streak', style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
                ]),
              ])),
              GestureDetector(
                onTap: () => _tabController.animateTo(1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: const Text('Redeem', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // How to earn points
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('How to Earn Points', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF4338CA))),
              const SizedBox(height: 10),
              _earnRow('📊', 'Log a health metric', '+5 pts'),
              _earnRow('📅', 'Complete an appointment', '+20 pts'),
              _earnRow('🔬', 'Complete a lab test', '+15 pts'),
              _earnRow('📚', 'Complete a program', '+50 pts'),
              _earnRow('🔥', '7-day streak bonus', '+25 pts'),
            ]),
          ),

          if (history.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildPointsPieChart(history),
          ],

          const SizedBox(height: 24),

          // Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard('Appointments', stats['completedAppointments'] ?? 0, Icons.medical_services_rounded, const Color(0xFF10B981)),
              _buildStatCard('Lab Tests', stats['completedLabTests'] ?? 0, Icons.science_rounded, const Color(0xFF8B5CF6)),
              _buildStatCard('Programs', stats['completedPrograms'] ?? 0, Icons.school_rounded, const Color(0xFF3B82F6)),
              _buildStatCard('Badges', badges.length, Icons.emoji_events_rounded, const Color(0xFFFBBF24)),
            ],
          ),

          const SizedBox(height: 24),

          // Activity Feed
          if (history.isNotEmpty) ...[
            const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
            const SizedBox(height: 12),
            ...history.take(10).map((entry) => _buildActivityTile(entry)),
            const SizedBox(height: 24),
          ],

          // Badges Section
          const Text('Badges', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
            itemCount: availableBadges.length,
            itemBuilder: (context, index) {
              final badge = availableBadges[index];
              final earned = badge['earned'] == true;
              return _buildBadgeCard(badge['icon'] ?? '🏆', badge['name'] ?? '', badge['description'] ?? '', earned);
            },
          ),
        ]),
      ),
    );
  }

  Widget _earnRow(String icon, String label, String pts) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
        Text(pts, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6366F1))),
      ]),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> entry) {
    final pts = (entry['points'] ?? 0) as int;
    final reason = entry['reason'] ?? '';
    final date = entry['date'] ?? '';
    final isEarn = pts > 0;

    final labels = {
      'log_health_metric': 'Logged a health metric',
      'complete_appointment': 'Completed an appointment',
      'complete_lab_test': 'Completed a lab test',
      'complete_program': 'Completed a program',
      'daily_goal': 'Reached daily goal',
      'streak_bonus': 'Streak bonus!',
      'rate_doctor': 'Rated a doctor',
      'redeem_consultation': 'Redeemed: Free Consultation',
      'redeem_lab_discount': 'Redeemed: Lab Discount',
    };
    final icons = {
      'log_health_metric': '📊',
      'complete_appointment': '🩺',
      'complete_lab_test': '🔬',
      'complete_program': '📚',
      'daily_goal': '🎯',
      'streak_bonus': '🔥',
      'rate_doctor': '⭐',
      'redeem_consultation': '🎫',
      'redeem_lab_discount': '🏷️',
    };

    String displayDate = '';
    try {
      final dt = DateTime.parse(date);
      displayDate = '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF5)),
      ),
      child: Row(children: [
        Text(icons[reason] ?? '⭐', style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(labels[reason] ?? reason, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
          if (displayDate.isNotEmpty) Text(displayDate, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ])),
        Text(isEarn ? '+$pts' : '$pts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isEarn ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
        const SizedBox(width: 4),
        Text('pts', style: TextStyle(fontSize: 11, color: isEarn ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
      ]),
    );
  }

  Widget _buildRedeemTab() {
    final points = (_stats?['points'] ?? 0) as int;
    final history = _stats?['history'] as List? ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Balance banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            const Text('💰', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your Balance', style: TextStyle(fontSize: 13, color: Colors.white70)),
              Text('$points points', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
              Text('≈ PKR ${(points * 0.01).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.white60)),
              const SizedBox(height: 2),
              const Text('1 pt = PKR 0.01', style: TextStyle(fontSize: 10, color: Colors.white54)),
            ]),
          ]),
        ),

        const SizedBox(height: 24),
        const Text('Available Rewards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        const SizedBox(height: 16),

        _buildRewardCard(
          icon: '🩺',
          title: 'Free Consultation',
          description: 'Get a free online consultation with any doctor',
          cost: 100,
          rewardId: 'free_consultation',
          color: const Color(0xFF10B981),
          points: points,
        ),
        const SizedBox(height: 12),
        _buildRewardCard(
          icon: '🔬',
          title: 'Lab Test Discount',
          description: '15% off on any lab test booking',
          cost: 150,
          rewardId: 'lab_discount',
          color: const Color(0xFF8B5CF6),
          points: points,
        ),

        // Monthly points chart
        if (history.isNotEmpty) ...[
          const SizedBox(height: 28),
          _buildMonthlyBarChart(history),
        ],

        // Redemption History
        const SizedBox(height: 28),
        const Text('Redemption History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        const SizedBox(height: 12),
        Builder(builder: (context) {
          final redemptions = (_stats?['redemptions'] ?? _stats?['redeemedRewards'] ?? []) as List<dynamic>;
          if (redemptions.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: const Row(children: [
                Text('📜', style: TextStyle(fontSize: 24)),
                SizedBox(width: 12),
                Text('No redemptions yet', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ]),
            );
          }
          const rewardLabels = {
            'free_consultation': 'Free Consultation',
            'lab_discount': 'Lab Test Discount (15% off)',
          };
          return Column(children: redemptions.take(5).map<Widget>((r) {
            final rawId = (r is Map ? r['rewardId'] ?? '' : '').toString();
            final title = rewardLabels[rawId] ?? (r is Map ? r['title'] ?? rawId.replaceAll('_', ' ') : 'Reward').toString();
            final pts = (r is Map ? r['cost'] ?? r['points'] ?? 0 : 0) as num;
            final date = (r is Map ? r['createdAt'] ?? r['date'] ?? '' : '').toString();
            String dateStr = '';
            try { dateStr = date.isNotEmpty ? '${DateTime.parse(date).toLocal().day}/${DateTime.parse(date).toLocal().month}/${DateTime.parse(date).toLocal().year}' : ''; } catch (_) {}
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8ECF5))),
              child: Row(children: [
                const Text('🎁', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  if (dateStr.isNotEmpty) Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ])),
                Text('-${pts.toInt()} pts', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
              ]),
            );
          }).toList());
        }),

        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(children: [
            const Text('🚀', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('More Rewards Coming!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              SizedBox(height: 4),
              Text('We\'re adding more exciting rewards. Keep earning points!', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ])),
          ]),
        ),
      ]),
    );
  }

  Widget _buildRewardCard({
    required String icon,
    required String title,
    required String description,
    required int cost,
    required String rewardId,
    required Color color,
    required int points,
  }) {
    final canRedeem = points >= cost;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
          child: Text(icon, style: const TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Row(children: [
            const Text('⭐', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text('$cost points', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ]),
        ])),
        const SizedBox(width: 12),
        _isRedeeming
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : ElevatedButton(
                onPressed: canRedeem ? () => _redeem(rewardId, title, cost) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canRedeem ? color : Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(canRedeem ? 'Redeem' : 'Need ${cost - points} more', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
      ]),
    );
  }

  Widget _buildLeaderboardTab() {
    if (_isLoadingLeaderboard) return const Center(child: CircularProgressIndicator());
    if (_leaderboard.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🏆', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 16),
        const Text('Leaderboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        const Text('No entries yet. Start earning points!', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _leaderboard.length,
      itemBuilder: (context, index) => _buildLeaderboardCard(_leaderboard[index], index),
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
        const SizedBox(height: 12),
        Text('$value', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      ]),
    );
  }

  Widget _buildBadgeCard(String icon, String name, String description, bool earned) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: earned ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: earned ? const Color(0xFFFBBF24).withValues(alpha: 0.3) : const Color(0xFFE2E8F0), width: earned ? 2 : 1),
        boxShadow: earned ? [BoxShadow(color: const Color(0xFFFBBF24).withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))] : null,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Opacity(opacity: earned ? 1.0 : 0.3, child: Text(icon, style: const TextStyle(fontSize: 32))),
        const SizedBox(height: 8),
        Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: earned ? const Color(0xFF0F172A) : const Color(0xFF94A3B8))),
      ]),
    );
  }

  // ── Charts ──────────────────────────────────────────────────────────────

  Widget _buildPointsPieChart(List<dynamic> history) {
    const reasonLabels = {
      'log_health_metric': 'Health Logs',
      'complete_appointment': 'Appointments',
      'complete_lab_test': 'Lab Tests',
      'complete_program': 'Programs',
      'daily_goal': 'Daily Goal',
      'streak_bonus': 'Streak Bonus',
      'rate_doctor': 'Doctor Rating',
    };
    const sliceColors = [
      Color(0xFF6366F1), Color(0xFF10B981), Color(0xFF8B5CF6),
      Color(0xFF3B82F6), Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF06B6D4),
    ];

    final Map<String, int> byReason = {};
    for (final e in history) {
      final pts = (e['points'] as num? ?? 0).toInt();
      final reason = (e['reason'] ?? 'other') as String;
      if (pts > 0) byReason[reason] = (byReason[reason] ?? 0) + pts;
    }
    if (byReason.isEmpty) return const SizedBox.shrink();

    final entries = byReason.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = byReason.values.fold(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECF5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.pie_chart_rounded, color: Color(0xFF6366F1), size: 18)),
          const SizedBox(width: 10),
          const Text('Points by Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const Spacer(),
          Text('$total pts total', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ]),
        const SizedBox(height: 20),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
            width: 140,
            height: 140,
            child: PieChart(PieChartData(
              sections: entries.asMap().entries.map((e) {
                final pct = e.value.value / total * 100;
                return PieChartSectionData(
                  value: e.value.value.toDouble(),
                  title: '${pct.toStringAsFixed(0)}%',
                  color: sliceColors[e.key % sliceColors.length],
                  radius: 55,
                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                );
              }).toList(),
              centerSpaceRadius: 30,
              sectionsSpace: 2,
            )),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.asMap().entries.map((e) {
              final label = reasonLabels[e.value.key] ?? e.value.key;
              final color = sliceColors[e.key % sliceColors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF374151)), overflow: TextOverflow.ellipsis)),
                  Text('${e.value.value}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                ]),
              );
            }).toList(),
          )),
        ]),
      ]),
    );
  }

  Widget _buildMonthlyBarChart(List<dynamic> history) {
    final now = DateTime.now();
    final months = List.generate(6, (i) => DateTime(now.year, now.month - (5 - i)));
    final monthKeys = months.map((m) => DateFormat('MMM yy').format(m)).toList();

    final earned = {for (final k in monthKeys) k: 0};
    final spent = {for (final k in monthKeys) k: 0};

    for (final e in history) {
      final pts = (e['points'] as num? ?? 0).toInt();
      final dateStr = (e['date'] ?? '') as String;
      if (dateStr.isEmpty) continue;
      try {
        final key = DateFormat('MMM yy').format(DateTime.parse(dateStr).toLocal());
        if (pts > 0) earned[key] = (earned[key] ?? 0) + pts;
        else spent[key] = (spent[key] ?? 0) + pts.abs();
      } catch (_) {}
    }

    final maxY = [...earned.values, ...spent.values].fold(0, (a, b) => a > b ? a : b).toDouble();
    if (maxY == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECF5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF10B981), size: 18)),
          const SizedBox(width: 10),
          const Text('Monthly Points', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _legendDot(const Color(0xFF10B981), 'Earned'),
          const SizedBox(width: 16),
          _legendDot(const Color(0xFFEF4444), 'Redeemed'),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY * 1.35,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF1E293B),
                getTooltipItem: (group, _, rod, rodIndex) {
                  final key = monthKeys[group.x];
                  final label = rodIndex == 0 ? 'Earned' : 'Redeemed';
                  return BarTooltipItem('$key\n$label: ${rod.toY.toInt()} pts',
                      const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600));
                },
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 28,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= monthKeys.length) return const SizedBox.shrink();
                  return Padding(padding: const EdgeInsets.only(top: 6),
                    child: Text(monthKeys[i].split(' ')[0], style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))));
                },
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFE8ECF5), strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            barGroups: monthKeys.asMap().entries.map((e) => BarChartGroupData(
              x: e.key,
              barsSpace: 4,
              barRods: [
                BarChartRodData(toY: (earned[e.value] ?? 0).toDouble(), color: const Color(0xFF10B981), width: 12, borderRadius: BorderRadius.circular(4)),
                BarChartRodData(toY: (spent[e.value] ?? 0).toDouble(), color: const Color(0xFFEF4444), width: 12, borderRadius: BorderRadius.circular(4)),
              ],
            )).toList(),
          )),
        ),
      ]),
    );
  }

  Widget _legendDot(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
  ]);

  Widget _buildLeaderboardCard(Map<String, dynamic> entry, int index) {
    final rank = entry['rank'] ?? index + 1;
    final name = entry['name'] ?? 'Anonymous';
    final points = entry['points'] ?? 0;
    final badgeCount = entry['badgeCount'] ?? 0;

    Color rankColor;
    String rankIcon;
    if (rank == 1) { rankColor = const Color(0xFFFBBF24); rankIcon = '🥇'; }
    else if (rank == 2) { rankColor = const Color(0xFF94A3B8); rankIcon = '🥈'; }
    else if (rank == 3) { rankColor = const Color(0xFFCD7F32); rankIcon = '🥉'; }
    else { rankColor = const Color(0xFF64748B); rankIcon = '#$rank'; }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rankColor.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(color: rankColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(rankIcon, style: TextStyle(fontSize: rank <= 3 ? 24 : 18, fontWeight: FontWeight.w900, color: rankColor))),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text('$badgeCount badges', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$points', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: rankColor)),
          const Text('points', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ]),
      ]),
    );
  }
}
