import 'package:flutter/material.dart';
import '../models/student.dart';
import '../database/database_helper.dart';
import 'add_student_screen.dart';
import 'edit_student_screen.dart';
import '../widgets/student_detail_dialog.dart';

class StudentListScreen extends StatefulWidget {
  final String? initialSearchQuery;

  const StudentListScreen({super.key, this.initialSearchQuery});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  late TextEditingController _searchController;
  List<Student> _allStudents = [];
  List<Student> _filteredStudents = [];
  bool _isLoading = true;

  String _selectedDepartmentFilter = 'All';
  String _selectedSemesterFilter = 'All';
  String _sortBy = 'id'; // 'id', 'name', 'rollNo'
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearchQuery ?? '');
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
    });

    final students = await DatabaseHelper.instance.getAllStudents(
      sortBy: _sortBy == 'rollNo' ? 'roll_no' : _sortBy,
      ascending: _sortAscending,
    );

    if (mounted) {
      setState(() {
        _allStudents = students;
        _isLoading = false;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredStudents = _allStudents.where((student) {
        // Search query matching Name or Roll Number or Department
        final matchesQuery = query.isEmpty ||
            student.name.toLowerCase().contains(query) ||
            student.rollNo.toLowerCase().contains(query) ||
            student.department.toLowerCase().contains(query);

        // Department filter
        final matchesDept = _selectedDepartmentFilter == 'All' ||
            student.department == _selectedDepartmentFilter;

        // Semester filter
        final matchesSem = _selectedSemesterFilter == 'All' ||
            student.semester == _selectedSemesterFilter;

        return matchesQuery && matchesDept && matchesSem;
      }).toList();
    });
  }

  Future<void> _navigateToAddStudent() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddStudentScreen()),
    );
    if (result == true) {
      _loadStudents();
    }
  }

  Future<void> _navigateToEditStudent(Student student) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditStudentScreen(student: student),
      ),
    );
    if (result == true) {
      _loadStudents();
    }
  }

  void _showStudentDetail(Student student) {
    showDialog(
      context: context,
      builder: (ctx) => StudentDetailDialog(
        student: student,
        onEdit: () => _navigateToEditStudent(student),
        onDelete: () => _confirmDelete(student),
      ),
    );
  }

  Future<void> _confirmDelete(Student student) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
            ),
            const SizedBox(width: 12),
            const Text('Delete Student'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this student record?',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: ${student.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Roll No: ${student.rollNo}'),
                  Text('Department: ${student.department}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && student.id != null) {
      await DatabaseHelper.instance.deleteStudent(student.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted student: ${student.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadStudents();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Records'),
        actions: [
          IconButton(
            tooltip: 'Refresh Records',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStudents,
          ),
          IconButton(
            tooltip: 'Add Student',
            icon: const Icon(Icons.add_rounded),
            onPressed: _navigateToAddStudent,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddStudent,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Student'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Controls Card: Search & Filters
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Search Bar Row
                      TextField(
                        controller: _searchController,
                        onChanged: (val) => _applyFilters(),
                        decoration: InputDecoration(
                          hintText: 'Search by student name, roll number, or department...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _searchController.clear();
                                    _applyFilters();
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Filter chips and sort options
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Department Filter
                          DropdownButton<String>(
                            value: _selectedDepartmentFilter,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.filter_list_rounded, size: 18),
                            items: [
                              'All',
                              'Computer Science',
                              'Information Technology',
                              'Electrical Engineering',
                              'Mechanical Engineering',
                              'Civil Engineering',
                              'Data Science & AI',
                              'Electronics & Communication',
                              'Business Administration',
                            ].map((dept) {
                              return DropdownMenuItem(
                                value: dept,
                                child: Text('Dept: $dept'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedDepartmentFilter = val;
                                  _applyFilters();
                                });
                              }
                            },
                          ),

                          // Semester Filter
                          DropdownButton<String>(
                            value: _selectedSemesterFilter,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.calendar_month_outlined, size: 18),
                            items: [
                              'All',
                              'Semester 1',
                              'Semester 2',
                              'Semester 3',
                              'Semester 4',
                              'Semester 5',
                              'Semester 6',
                              'Semester 7',
                              'Semester 8',
                            ].map((sem) {
                              return DropdownMenuItem(
                                value: sem,
                                child: Text('Sem: $sem'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedSemesterFilter = val;
                                  _applyFilters();
                                });
                              }
                            },
                          ),

                          // Sort By
                          DropdownButton<String>(
                            value: _sortBy,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.sort_rounded, size: 18),
                            items: const [
                              DropdownMenuItem(value: 'id', child: Text('Sort: ID')),
                              DropdownMenuItem(value: 'name', child: Text('Sort: Name')),
                              DropdownMenuItem(value: 'rollNo', child: Text('Sort: Roll No')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _sortBy = val;
                                });
                                _loadStudents();
                              }
                            },
                          ),

                          // Sort Order Toggle Button
                          IconButton(
                            tooltip: _sortAscending ? 'Ascending' : 'Descending',
                            icon: Icon(
                              _sortAscending
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _sortAscending = !_sortAscending;
                              });
                              _loadStudents();
                            },
                          ),

                          // Results Count Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_filteredStudents.length} of ${_allStudents.length} Students',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Content Area: Loading, Empty, Desktop Table, or Mobile List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredStudents.isEmpty
                      ? _buildEmptyState(theme)
                      : isDesktop
                          ? _buildDesktopTableView(theme)
                          : _buildMobileListView(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final hasActiveFilter = _searchController.text.isNotEmpty ||
        _selectedDepartmentFilter != 'All' ||
        _selectedSemesterFilter != 'All';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasActiveFilter ? Icons.search_off_rounded : Icons.school_outlined,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasActiveFilter ? 'No Matching Students' : 'No Students Registered Yet',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveFilter
                  ? 'Try modifying your search term or clearing active filters.'
                  : 'Start by adding your first student record to the database.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            if (hasActiveFilter)
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _selectedDepartmentFilter = 'All';
                    _selectedSemesterFilter = 'All';
                  });
                  _applyFilters();
                },
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Clear Filters'),
              )
            else
              ElevatedButton.icon(
                onPressed: _navigateToAddStudent,
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Add Student'),
              ),
          ],
        ),
      ),
    );
  }

  // Windows Desktop Table View
  Widget _buildDesktopTableView(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                theme.colorScheme.primary.withValues(alpha: 0.06),
              ),
              dataRowMinHeight: 52,
              dataRowMaxHeight: 64,
              columns: const [
                DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Roll No', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Semester', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: _filteredStudents.map((student) {
                return DataRow(
                  onSelectChanged: (_) => _showStudentDetail(student),
                  cells: [
                    DataCell(Text('#${student.id}')),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          student.rollNo,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                            child: Text(
                              student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(student.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    DataCell(Text(student.department)),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          student.semester,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(student.phone.isNotEmpty ? student.phone : '—')),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'View Details',
                            icon: const Icon(Icons.visibility_outlined, size: 20),
                            onPressed: () => _showStudentDetail(student),
                          ),
                          IconButton(
                            tooltip: 'Edit Student',
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            color: theme.colorScheme.primary,
                            onPressed: () => _navigateToEditStudent(student),
                          ),
                          IconButton(
                            tooltip: 'Delete Student',
                            icon: const Icon(Icons.delete_outline_rounded, size: 20),
                            color: theme.colorScheme.error,
                            onPressed: () => _confirmDelete(student),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // Android Mobile Responsive Card List View
  Widget _buildMobileListView(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: _filteredStudents.length,
      itemBuilder: (context, index) {
        final student = _filteredStudents[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showStudentDetail(student),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Avatar, Name, Roll No & Popup Menu
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                        child: Text(
                          student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Roll No: ${student.rollNo}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded),
                        onSelected: (val) {
                          if (val == 'view') {
                            _showStudentDetail(student);
                          } else if (val == 'edit') {
                            _navigateToEditStudent(student);
                          } else if (val == 'delete') {
                            _confirmDelete(student);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('View Details'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Edit Record'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18, color: theme.colorScheme.error),
                                const SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Bottom Info Chips: Department, Semester, Phone
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.account_balance_rounded, size: 14),
                        label: Text(student.department, style: const TextStyle(fontSize: 12)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Chip(
                        avatar: const Icon(Icons.calendar_month_rounded, size: 14),
                        label: Text(student.semester, style: const TextStyle(fontSize: 12)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      if (student.phone.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.phone_rounded, size: 14),
                          label: Text(student.phone, style: const TextStyle(fontSize: 12)),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
