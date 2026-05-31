import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/services/community_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class CommunityForumScreen extends StatefulWidget {
  const CommunityForumScreen({super.key});

  @override
  State<CommunityForumScreen> createState() => _CommunityForumScreenState();
}

class _CommunityForumScreenState extends State<CommunityForumScreen> {
  final CommunityService _communityService = CommunityService();
  bool _isLoading = true;

  // Exact order as required — hardcoded so deployment always shows this order
  List<String> _categories = const [
    'All',
    'General',
    'Diabetes',
    'Heart Health',
    'Mental Wellness',
    'Nutrition',
    'Pregnancy',
    'COVID-19',
  ];

  String _selectedCategory = 'All';
  List<dynamic> _posts = [];
  String? _currentUserId;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = await SharedPref().getUserData();
    if (mounted) {
      setState(() {
        _currentUserId = user?.id;
        _isAdmin = (user?.role ?? '').toLowerCase() == 'admin';
      });
    }
    await Future.wait([_loadCategories(), _loadPosts()]);
  }

  Future<void> _loadCategories() async {
    // Only append admin-added custom topics — never change the fixed default order
    final cats = await _communityService.getCategories();
    final customOnly = cats.where((c) => !_categories.contains(c)).toList();
    if (mounted && customOnly.isNotEmpty) {
      setState(() => _categories = [..._categories, ...customOnly]);
    }
  }

  Future<void> _loadPosts() async {
    if (mounted) setState(() => _isLoading = true);
    final posts = await _communityService.getPosts(_selectedCategory);
    if (mounted) setState(() { _posts = posts; _isLoading = false; });
  }

  void _onCategoryTap(String cat) {
    setState(() => _selectedCategory = cat);
    _loadPosts();
  }

  // ── Admin: Add New Topic ────────────────────────────────────────────────────

  void _showAddTopicDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add New Topic'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. Cardiology',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final ok = await _communityService.addCategory(name);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'Topic "$name" added!' : 'Failed to add topic'),
                  backgroundColor: ok ? Colors.green : Colors.red,
                ));
                if (ok) _loadCategories();
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── New Post ────────────────────────────────────────────────────────────────

  void _showNewPostDialog() {
    final contentCtrl = TextEditingController();
    String selectedCat = _selectedCategory == 'All' ? 'General' : _selectedCategory;
    final postCategories = _categories.where((c) => c != 'All').toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Start New Post',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: postCategories.contains(selectedCat) ? selectedCat : postCategories.first,
                items: postCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setModal(() => selectedCat = v!),
                decoration: InputDecoration(
                  labelText: 'Topic',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (contentCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await _communityService.createPost(
                      content: contentCtrl.text.trim(),
                      category: selectedCat,
                    );
                    _loadPosts();
                  },
                  child: const Text('Post', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Admin: Delete Post ──────────────────────────────────────────────────────

  void _confirmDeletePost(String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Post'),
        content: const Text('This post will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await _communityService.deletePost(postId);
              if (mounted && ok) {
                setState(() => _posts.removeWhere((p) => (p['_id'] ?? p['id'])?.toString() == postId));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
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
        title: const Text(
          'Health Community',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900),
        ),
        actions: [
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: 'Add New Topic',
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_circle_outline_rounded,
                        color: AppColors.primaryColor, size: 22),
                  ),
                  onPressed: _showAddTopicDialog,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewPostDialog,
        backgroundColor: AppColors.primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Start New Post',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildCategoryFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _posts.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadPosts,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                          itemCount: _posts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 16),
                          itemBuilder: (_, i) => _buildPostCard(_posts[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return Container(
      height: 56,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final isSelected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => _onCategoryTap(cat),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected ? AppColors.primaryColor : const Color(0xFFE2E8F0),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                cat,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostCard(dynamic post) {
    final postId = (post['_id'] ?? post['id'])?.toString() ?? '';
    final authorName = post['userName']?.toString() ?? 'User';
    final authorRole = post['userRole']?.toString() ?? '';
    final isDoctor = authorRole.toLowerCase() == 'doctor';
    final isAdminAuthor = authorRole.toLowerCase() == 'admin';
    final category = post['category']?.toString() ?? 'General';
    final content = post['content']?.toString() ?? '';
    final likeCount = post['likeCount'] ?? (post['likes'] as List?)?.length ?? 0;
    final commentCount = post['commentCount'] ?? (post['comments'] as List?)?.length ?? 0;
    DateTime? timestamp;
    try { timestamp = DateTime.parse(post['createdAt']?.toString() ?? ''); } catch (_) {}

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _CommunityPostDetailScreen(
            post: post,
            currentUserId: _currentUserId ?? '',
            isAdmin: _isAdmin,
            communityService: _communityService,
          ),
        ),
      ).then((_) => _loadPosts()),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author row
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isDoctor
                      ? const Color(0xFFDBEAFE)
                      : isAdminAuthor
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFF1F5F9),
                  child: Icon(
                    isDoctor ? Icons.medical_services_rounded : Icons.person_rounded,
                    color: isDoctor ? Colors.blue : isAdminAuthor ? Colors.orange : Colors.grey,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(authorName,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          if (isDoctor) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, color: Colors.blue, size: 14),
                          ],
                        ],
                      ),
                      if (timestamp != null)
                        Text(
                          DateFormat('MMM dd, yyyy').format(timestamp),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                    ],
                  ),
                ),
                // Category badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(category,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
                ),
                // Admin delete
                if (_isAdmin) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _confirmDeletePost(postId),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(content,
                style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.5),
                maxLines: 4,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.favorite_border_rounded, size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text('$likeCount', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(width: 18),
                const Icon(Icons.mode_comment_outlined, size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text('$commentCount', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const Spacer(),
                const Text('View →', style: TextStyle(fontSize: 12, color: AppColors.primaryColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No posts yet. Be the first to share!',
              style: TextStyle(fontSize: 15, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

// ── Post Detail Screen ────────────────────────────────────────────────────────

class _CommunityPostDetailScreen extends StatefulWidget {
  final dynamic post;
  final String currentUserId;
  final bool isAdmin;
  final CommunityService communityService;

  const _CommunityPostDetailScreen({
    required this.post,
    required this.currentUserId,
    required this.isAdmin,
    required this.communityService,
  });

  @override
  State<_CommunityPostDetailScreen> createState() => _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState extends State<_CommunityPostDetailScreen> {
  final TextEditingController _commentCtrl = TextEditingController();
  late List<dynamic> _comments;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _comments = List<dynamic>.from(widget.post['comments'] as List? ?? []);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    final postId = (widget.post['_id'] ?? widget.post['id'])?.toString() ?? '';
    final result = await widget.communityService.addComment(postId, text);
    if (mounted) {
      if (result['success'] == true) {
        _commentCtrl.clear();
        final newComment = result['comment'];
        if (newComment != null) {
          setState(() => _comments.add(newComment));
        } else {
          setState(() => _comments.add({
            'content': text,
            'userName': 'You',
            'createdAt': DateTime.now().toIso8601String(),
          }));
        }
      }
      setState(() => _isSending = false);
    }
  }

  void _confirmDeleteComment(String commentId, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Comment'),
        content: const Text('This comment will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final postId = (widget.post['_id'] ?? widget.post['id'])?.toString() ?? '';
              final ok = await widget.communityService.deleteComment(postId, commentId);
              if (mounted && ok) setState(() => _comments.removeAt(index));
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authorName = widget.post['userName']?.toString() ?? 'User';
    final authorRole = widget.post['userRole']?.toString() ?? '';
    final isDoctor = authorRole.toLowerCase() == 'doctor';
    final category = widget.post['category']?.toString() ?? 'General';
    final content = widget.post['content']?.toString() ?? '';
    DateTime? timestamp;
    try { timestamp = DateTime.parse(widget.post['createdAt']?.toString() ?? ''); } catch (_) {}

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Text(category,
            style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Post
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: isDoctor ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                            child: Icon(
                              isDoctor ? Icons.medical_services_rounded : Icons.person_rounded,
                              color: isDoctor ? Colors.blue : Colors.grey,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(authorName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    if (isDoctor) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified_rounded, color: Colors.blue, size: 14),
                                    ],
                                  ],
                                ),
                                if (timestamp != null)
                                  Text(DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp),
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(category,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(content, style: const TextStyle(fontSize: 15, color: Color(0xFF334155), height: 1.6)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Comments (${_comments.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                if (_comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('No comments yet. Be the first!',
                        style: TextStyle(color: Color(0xFF94A3B8)))),
                  )
                else
                  ..._comments.asMap().entries.map((entry) {
                    final i = entry.key;
                    final c = entry.value;
                    final commentId = (c['_id'] ?? c['id'])?.toString() ?? '';
                    final commentUserId = c['userId']?.toString() ?? '';
                    final canDelete = widget.isAdmin || commentUserId == widget.currentUserId;
                    DateTime? cTime;
                    try { cTime = DateTime.parse(c['createdAt']?.toString() ?? ''); } catch (_) {}
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFFF1F5F9),
                            child: const Icon(Icons.person_rounded, size: 16, color: Colors.grey),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(c['userName']?.toString() ?? 'User',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                    const Spacer(),
                                    if (cTime != null)
                                      Text(DateFormat('MMM dd').format(cTime),
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                    if (canDelete && commentId.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => _confirmDeleteComment(commentId, i),
                                        child: const Icon(Icons.delete_outline_rounded,
                                            color: Color(0xFFEF4444), size: 16),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(c['content']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          // Comment input
          Container(
            padding: EdgeInsets.only(
              left: 16, right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              top: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (_) => _addComment(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _addComment,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: _isSending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
