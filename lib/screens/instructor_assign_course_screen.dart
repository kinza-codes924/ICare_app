import 'package:flutter/material.dart';
import 'package:icare/models/course.dart';
import 'package:icare/services/course_service.dart';
import 'package:icare/services/instructor_service.dart';
import 'package:icare/services/user_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';

class InstructorAssignCourseScreen extends StatefulWidget {
  final Course? initialCourse;

  const InstructorAssignCourseScreen({super.key, this.initialCourse});

  @override
  State<InstructorAssignCourseScreen> createState() =>
      _InstructorAssignCourseScreenState();
}

class _InstructorAssignCourseScreenState
    extends State<InstructorAssignCourseScreen> {
  final InstructorService _instructorService = InstructorService();
  final CourseService _courseService = CourseService();
  final UserService _userService = UserService();

  Course? _selectedCourse;
  List<Course> _myCourses = [];
  bool _isLoadingCourses = true;

  List<dynamic> _foundUsers = [];
  bool _isSearchingUsers = false;
  final TextEditingController _searchController = TextEditingController();
  dynamic _selectedUser;

  String _selectedRole = 'Doctor'; // Default to Doctor as per Req 9.5

  @override
  void initState() {
    super.initState();
    _selectedCourse = widget.initialCourse;
    _loadMyCourses();
  }

  Future<void> _loadMyCourses() async {
    try {
      final courses = await _courseService.getMyCourses();
      setState(() {
        _myCourses = courses;
        _isLoadingCourses = false;
        if (_selectedCourse == null && _myCourses.isNotEmpty) {
          _selectedCourse = _myCourses.first;
        }
      });
    } catch (e) {
      setState(() => _isLoadingCourses = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) return;
    setState(() => _isSearchingUsers = true);
    try {
      final result = await _userService.searchUsers(
        query: query,
        role: _selectedRole,
      );
      setState(() {
        _foundUsers = result['users'] ?? [];
        _isSearchingUsers = false;
      });
    } catch (e) {
      setState(() => _isSearchingUsers = false);
    }
  }

  Future<void> _assignCourse() async {
    if (_selectedCourse == null || _selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both a course and a user')),
      );
      return;
    }

    try {
      await _instructorService.assignCourse(
        _selectedCourse!.id,
        _selectedUser['_id'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course assigned successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Login failed. Please check your credentials.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
          'Assign Professional Development',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Select Program',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoadingCourses)
              const Center(child: CircularProgressIndicator())
            else if (_myCourses.isEmpty)
              const Text('No programs found. Create one first.')
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Course>(
                    isExpanded: true,
                    value: _selectedCourse,
                    items: _myCourses.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c.title));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCourse = val),
                  ),
                ),
              ),

            const SizedBox(height: 32),

            const Text(
              '2. Select Target Role',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildRoleOption('Doctor'),
                const SizedBox(width: 12),
                _buildRoleOption('Patient'),
              ],
            ),

            const SizedBox(height: 32),

            const Text(
              '3. Find User',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _searchUsers(_searchController.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onSubmitted: _searchUsers,
            ),

            const SizedBox(height: 16),

            if (_isSearchingUsers)
              const Center(child: CircularProgressIndicator())
            else if (_foundUsers.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _foundUsers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final user = _foundUsers[i];
                  final isSelected =
                      _selectedUser != null &&
                      _selectedUser['_id'] == user['_id'];
                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: AppColors.primaryColor.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primaryColor
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        user['name']?[0] ?? 'U',
                        style: const TextStyle(color: AppColors.primaryColor),
                      ),
                    ),
                    title: Text(
                      user['name'] ?? 'User',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(user['email'] ?? ''),
                    onTap: () => setState(() => _selectedUser = user),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.primaryColor,
                          )
                        : null,
                  );
                },
              )
            else if (_searchController.text.isNotEmpty)
              const Center(
                child: Text(
                  'No users found',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),

            const SizedBox(height: 40),

            CustomButton(
              label: 'Assign Program',
              onPressed: (_selectedCourse != null && _selectedUser != null)
                  ? _assignCourse
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleOption(String role) {
    final isSelected = _selectedRole == role;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = role;
          _foundUsers = [];
          _selectedUser = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryColor
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          role,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
