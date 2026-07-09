import 'package:flutter/material.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:intl/intl.dart';

class DoctorForumScreen extends StatefulWidget {
  const DoctorForumScreen({super.key});

  @override
  State<DoctorForumScreen> createState() => _DoctorForumScreenState();
}

class _DoctorForumScreenState extends State<DoctorForumScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _posts = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'General',
    'Case Study',
    'Clinical Research',
    'Platform Help',
  ];

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    try {
      final categoryParam = _selectedCategory == 'All'
          ? ''
          : '?category=$_selectedCategory';
      final response = await _apiService.get('/forum$categoryParam');
      if (mounted) {
        setState(() {
          _posts = response.data['posts'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreatePostDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String category = 'General';
    bool isAnonymized = false;
    List<String> attachedImages = [];
    List<String> attachedDocuments = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Start a Discussion',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    hintText: 'Post Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  items: _categories
                      .where((c) => c != 'All')
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setModalState(() => category = v!),
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Share your thoughts or clinical case...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // ── ATTACHMENTS ─────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Implement image picker
                          setModalState(() => attachedImages.add('image_${DateTime.now().millisecondsSinceEpoch}.jpg'));
                        },
                        icon: const Icon(Icons.image_rounded, size: 18),
                        label: const Text('Add Image'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF3B82F6),
                          side: const BorderSide(color: Color(0xFF3B82F6)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Implement document picker
                          setModalState(() => attachedDocuments.add('document_${DateTime.now().millisecondsSinceEpoch}.pdf'));
                        },
                        icon: const Icon(Icons.attach_file_rounded, size: 18),
                        label: const Text('Add Document'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8B5CF6),
                          side: const BorderSide(color: Color(0xFF8B5CF6)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (attachedImages.isNotEmpty || attachedDocuments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Attachments',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...attachedImages.map((img) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.image_rounded, size: 16, color: Color(0xFF3B82F6)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  img,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => setModalState(() => attachedImages.remove(img)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        )),
                        ...attachedDocuments.map((doc) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.description_rounded, size: 16, color: Color(0xFF8B5CF6)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  doc,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => setModalState(() => attachedDocuments.remove(doc)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Post Anonymously'),
                  subtitle: const Text('Hide your name from other specialists'),
                  value: isAnonymized,
                  onChanged: (v) => setModalState(() => isAnonymized = v),
                ),
                const SizedBox(height: 24),
                CustomButton(
                  label: 'Publish Post',
                  onPressed: () async {
                    if (titleController.text.isEmpty ||
                        contentController.text.isEmpty) {
                      return;
                    }
                    try {
                      await _apiService.post('/forum', {
                        'title': titleController.text,
                        'content': contentController.text,
                        'category': category,
                        'isAnonymized': isAnonymized,
                        'attachedImages': attachedImages,
                        'attachedDocuments': attachedDocuments,
                      });
                      Navigator.pop(ctx);
                      _fetchPosts();
                    } catch (e) {
                      debugPrint('Post creation error: $e');
                    }
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Specialist Forum',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildCategoryFilter(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _posts.isEmpty
                ? const Center(child: Text('No discussions found.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _posts.length,
                    itemBuilder: (ctx, i) => _buildPostCard(_posts[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePostDialog,
        label: const Text('Start Discussion'),
        icon: const Icon(Icons.add_comment_rounded),
        backgroundColor: AppColors.primaryColor,
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 60,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _categories.length,
        itemBuilder: (ctx, i) {
          final isSelected = _selectedCategory == _categories[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_categories[i]),
              selected: isSelected,
              onSelected: (v) {
                setState(() => _selectedCategory = _categories[i]);
                _fetchPosts();
              },
              selectedColor: AppColors.primaryColor.withValues(alpha: 0.2),
              checkmarkColor: AppColors.primaryColor,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostCard(dynamic post) {
    final bool isVerified = post['author']?['isVerified'] ?? true;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (ctx) => ForumDetailScreen(post: post)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    (post['author']?['name'] ?? 'D')[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            post['author']?['name'] ?? 'Doctor',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              color: Colors.blue,
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        DateFormat(
                          'MMM dd, yyyy',
                        ).format(DateTime.parse(post['createdAt'])),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    post['category'],
                    style: const TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              post['title'],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              post['content'],
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildPostStat(
                  Icons.thumb_up_off_alt_rounded,
                  '${post['likes']?.length ?? 0}',
                ),
                const SizedBox(width: 16),
                _buildPostStat(
                  Icons.chat_bubble_outline_rounded,
                  '${post['comments']?.length ?? 0}',
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {}, // Report
                  icon: const Icon(
                    Icons.flag_outlined,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostStat(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
      ],
    );
  }
}

class ForumDetailScreen extends StatefulWidget {
  final dynamic post;
  const ForumDetailScreen({super.key, required this.post});

  @override
  State<ForumDetailScreen> createState() => _ForumDetailScreenState();
}

class _ForumDetailScreenState extends State<ForumDetailScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _commentController = TextEditingController();
  List<dynamic> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _comments = widget.post['comments'] ?? [];
    _isLoading = false;
  }

  Future<void> _postComment() async {
    if (_commentController.text.isEmpty) return;
    try {
      await _apiService.post('/forum/${widget.post['_id']}/comment', {
        'content': _commentController.text,
      });
      _commentController.clear();
      // In a real app, we'd fetch updated comments here
      setState(() {
        _comments.add({
          'content': _commentController.text,
          'author': {'name': 'You', 'isVerified': true},
          'createdAt': DateTime.now().toIso8601String(),
        });
      });
    } catch (e) {
      debugPrint('Comment error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Discussion',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPostHeader(),
                  const SizedBox(height: 20),
                  Text(
                    widget.post['title'],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.post['content'],
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const Divider(height: 40),
                  Text(
                    'Comments (${_comments.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_comments.isEmpty)
                    const Center(
                      child: Text('No comments yet. Be the first to respond!'),
                    )
                  else
                    ..._comments.map((c) => _buildCommentTile(c)),
                ],
              ),
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
          child: const Icon(Icons.person, color: AppColors.primaryColor),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.post['author']?['name'] ?? 'Doctor',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              DateFormat(
                'MMM dd, yyyy',
              ).format(DateTime.parse(widget.post['createdAt'])),
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentTile(dynamic comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[100],
            child: const Icon(Icons.person, size: 16, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment['author']?['name'] ?? 'Doctor',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (comment['author']?['isVerified'] ?? true) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        color: Colors.blue,
                        size: 12,
                      ),
                    ],
                    const Spacer(),
                    Text(
                      DateFormat(
                        'MMM dd',
                      ).format(DateTime.parse(comment['createdAt'])),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment['content'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 10,
        top: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Add a clinical response...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _postComment,
            icon: const Icon(Icons.send_rounded, color: AppColors.primaryColor),
          ),
        ],
      ),
    );
  }
}
