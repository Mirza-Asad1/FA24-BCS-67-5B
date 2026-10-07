import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/student.dart';
import '../database/database_helper.dart';
import 'add_student_screen.dart';
import 'student_list_screen.dart';
import 'edit_student_screen.dart';
import '../widgets/student_detail_dialog.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const DashboardScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _totalStudents = 0;
  Map<String, int> _deptStats = {};
  List<Student> _recentStudents = [];
  bool _isLoading = true;
  final TextEditingController _quickSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _quickSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    final total = await DatabaseHelper.instance.getStudentCount();
    final stats = await DatabaseHelper.instance.getDepartmentStatistics();
    final all = await DatabaseHelper.instance.getAllStudents(sortBy: 'id', ascending: false);
    final recent = all.take(5).toList();

    if (mounted) {
      setState(() {
        _totalStudents = total;
        _deptStats = stats;
        _recentStudents = recent;
        _isLoading = false;
      });
    }
  }

  Future<void> _seedSampleData() async {
    await DatabaseHelper.instance.seedSampleStudents();
    await _loadDashboardData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sample university student records loaded!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _navigateToAddStudent() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddStudentScreen()),
    );
    if (result == true) {
      _loadDashboardData();
    }
  }

  Future<void> _navigateToViewStudents([String? initialQuery]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentListScreen(initialSearchQuery: initialQuery),
      ),
    );
    _loadDashboardData();
  }

  Future<void> _navigateToEditStudent(Student student) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditStudentScreen(student: student)),
    );
    if (result == true) {
      _loadDashboardData();
    }
  }

  void _showStudentDetail(Student student) {
    showDialog(
      context: context,
      builder: (ctx) => StudentDetailDialog(
        student: student,
        onEdit: () => _navigateToEditStudent(student),
        onDelete: () async {
          if (student.id != null) {
            await DatabaseHelper.instance.deleteStudent(student.id!);
            _loadDashboardData();
          }
        },
      ),
    );
  }

  String _getPlatformName() {
    if (kIsWeb) return 'Web Application';
    if (Platform.isWindows) return 'Windows Desktop Edition';
    if (Platform.isAndroid) return 'Android Mobile Edition';
    if (Platform.isMacOS) return 'macOS Desktop Edition';
    if (Platform.isLinux) return 'Linux Desktop Edition';
    if (Platform.isIOS) return 'iOS Mobile Edition';
    return 'Cross-Platform Edition';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Student Record Manager',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  _getPlatformName(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: widget.isDarkMode ? 'Switch to Light Theme' : 'Switch to Dark Theme',
            icon: Icon(widget.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: widget.onToggleTheme,
          ),
          PopupMenuButton<String>(
            tooltip: 'Database Actions',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) async {
              if (val == 'seed') {
                await _seedSampleData();
              } else if (val == 'refresh') {
                await _loadDashboardData();
              } else if (val == 'clear') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear All Records?'),
                    content: const Text(
                      'Are you sure you want to delete all student records from SQLite? This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await DatabaseHelper.instance.deleteAllStudents();
                  _loadDashboardData();
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'seed',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Load Sample Students'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Refresh Data'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded, size: 20, color: theme.colorScheme.error),
                    const SizedBox(width: 10),
                    Text('Clear All Records', style: TextStyle(color: theme.colorScheme.error)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Hero Banner
                        _buildHeroBanner(theme),
                        const SizedBox(height: 24),

                        // Stats & Action Grid
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _buildMetricsSection(theme)),
                              const SizedBox(width: 20),
                              Expanded(flex: 2, child: _buildQuickActionCard(theme)),
                            ],
                          )
                        else ...[
                          _buildMetricsSection(theme),
                          const SizedBox(height: 20),
                          _buildQuickActionCard(theme),
                        ],

                        const SizedBox(height: 28),

                        // Quick Search Bar
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _quickSearchController,
                                    decoration: const InputDecoration(
                                      hintText: 'Quick search student by name, roll no, or department...',
                                      prefixIcon: Icon(Icons.search_rounded),
                                    ),
                                    onSubmitted: (val) {
                                      if (val.trim().isNotEmpty) {
                                        _navigateToViewStudents(val.trim());
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    final query = _quickSearchController.text.trim();
                                    _navigateToViewStudents(query.isEmpty ? null : query);
                                  },
                                  icon: const Icon(Icons.search_rounded),
                                  label: const Text('Search'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Department Distribution & Recent Students
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 1, child: _buildDepartmentDistribution(theme)),
                              const SizedBox(width: 20),
                              Expanded(flex: 2, child: _buildRecentStudentsList(theme)),
                            ],
                          )
                        else ...[
                          _buildRecentStudentsList(theme),
                          const SizedBox(height: 20),
                          _buildDepartmentDistribution(theme),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // Welcome Hero Banner
  Widget _buildHeroBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'University Mini Project • SQLite System',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Student Information Hub',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage student enrollment, roll records, departments, and contacts with offline SQLite database persistence.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storage_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Total Students and Stats Cards
  Widget _buildMetricsSection(ThemeData theme) {
    return Row(
      children: [
        // Total Students Card
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Students',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.people_alt_rounded, color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$_totalStudents',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active database records',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Departments Represented Card
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Departments',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_rounded, color: Colors.teal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_deptStats.length}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Distinct departments',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Quick Action Buttons Card
  Widget _buildQuickActionCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _navigateToAddStudent,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    label: const Text('Add Student'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToViewStudents(),
                    icon: const Icon(Icons.table_chart_rounded, size: 20),
                    label: const Text('View Students'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            if (_totalStudents == 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _seedSampleData,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                  label: const Text('Load 5 Demo Student Records'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Department Distribution Breakdown
  Widget _buildDepartmentDistribution(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart_outline_rounded, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Department Breakdown',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_deptStats.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No student records available',
                    style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                  ),
                ),
              )
            else
              ..._deptStats.entries.map((entry) {
                final ratio = _totalStudents > 0 ? entry.value / _totalStudents : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${entry.value} (${(ratio * 100).toStringAsFixed(0)}%)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // Recent Student Records
  Widget _buildRecentStudentsList(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.history_rounded, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Recently Enrolled Students',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _navigateToViewStudents(),
                  child: const Text('View All'),
                ),
              ],
            ),
            const Divider(),
            if (_recentStudents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.person_off_outlined,
                          size: 40, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4)),
                      const SizedBox(height: 8),
                      Text(
                        'No students registered yet',
                        style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentStudents.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final student = _recentStudents[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                      child: Text(
                        student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      student.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      '${student.rollNo} • ${student.department} (${student.semester})',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _navigateToEditStudent(student),
                        ),
                        IconButton(
                          tooltip: 'Details',
                          icon: const Icon(Icons.chevron_right_rounded, size: 20),
                          onPressed: () => _showStudentDetail(student),
                        ),
                      ],
                    ),
                    onTap: () => _showStudentDetail(student),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
