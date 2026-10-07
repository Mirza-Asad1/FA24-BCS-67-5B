import 'package:flutter/material.dart';
import '../models/student.dart';
import '../database/database_helper.dart';

class StudentForm extends StatefulWidget {
  final Student? initialStudent;
  final Future<void> Function(Student student) onSubmit;
  final String submitButtonText;

  const StudentForm({
    super.key,
    this.initialStudent,
    required this.onSubmit,
    this.submitButtonText = 'Save Student',
  });

  @override
  State<StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<StudentForm> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _rollNoController;
  late TextEditingController _phoneController;

  String? _selectedDepartment;
  String? _selectedSemester;
  bool _isLoading = false;
  String? _rollErrorMessage;
  int _resetKeyCount = 0;

  static const List<String> departments = [
    'Computer Science',
    'Information Technology',
    'Electrical Engineering',
    'Mechanical Engineering',
    'Civil Engineering',
    'Data Science & AI',
    'Electronics & Communication',
    'Business Administration',
  ];

  static const List<String> semesters = [
    'Semester 1',
    'Semester 2',
    'Semester 3',
    'Semester 4',
    'Semester 5',
    'Semester 6',
    'Semester 7',
    'Semester 8',
  ];

  @override
  void initState() {
    super.initState();
    final student = widget.initialStudent;
    _nameController = TextEditingController(text: student?.name ?? '');
    _rollNoController = TextEditingController(text: student?.rollNo ?? '');
    _phoneController = TextEditingController(text: student?.phone ?? '');

    if (student != null) {
      _selectedDepartment = departments.contains(student.department)
          ? student.department
          : (student.department.isNotEmpty ? student.department : departments.first);
      _selectedSemester = semesters.contains(student.semester)
          ? student.semester
          : (student.semester.isNotEmpty ? student.semester : semesters.first);
    } else {
      _selectedDepartment = departments.first;
      _selectedSemester = semesters.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollNoController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _resetForm() {
    if (widget.initialStudent != null) {
      final s = widget.initialStudent!;
      _nameController.text = s.name;
      _rollNoController.text = s.rollNo;
      _phoneController.text = s.phone;
      setState(() {
        _selectedDepartment = s.department;
        _selectedSemester = s.semester;
        _rollErrorMessage = null;
        _resetKeyCount++;
      });
    } else {
      _formKey.currentState?.reset();
      _nameController.clear();
      _rollNoController.clear();
      _phoneController.clear();
      setState(() {
        _selectedDepartment = departments.first;
        _selectedSemester = semesters.first;
        _rollErrorMessage = null;
        _resetKeyCount++;
      });
    }
  }

  Future<void> _handleSave() async {
    setState(() {
      _rollErrorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final rollNo = _rollNoController.text.trim();

    // Check duplicate roll number in SQLite database
    final isTaken = await DatabaseHelper.instance.isRollNumberTaken(
      rollNo,
      excludeId: widget.initialStudent?.id,
    );

    if (isTaken) {
      setState(() {
        _rollErrorMessage = 'This Roll Number is already registered for another student.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final student = Student(
        id: widget.initialStudent?.id,
        name: _nameController.text.trim(),
        rollNo: rollNo.toUpperCase(),
        department: _selectedDepartment ?? departments.first,
        semester: _selectedSemester ?? semesters.first,
        phone: _phoneController.text.trim(),
      );

      await widget.onSubmit(student);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section: Personal Information
          _buildSectionHeader('Student Details', Icons.person_rounded, theme),
          const SizedBox(height: 16),

          // Student Name
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Student Full Name *',
              hintText: 'e.g., Alex Johnson',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter student name';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Roll Number
          TextFormField(
            controller: _rollNoController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Roll Number * (Unique ID)',
              hintText: 'e.g., CS-2024-001',
              prefixIcon: const Icon(Icons.badge_outlined),
              errorText: _rollErrorMessage,
            ),
            onChanged: (val) {
              if (_rollErrorMessage != null) {
                setState(() {
                  _rollErrorMessage = null;
                });
              }
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter student roll number';
              }
              if (value.trim().length < 3) {
                return 'Roll number must be at least 3 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Section: Academic Information
          _buildSectionHeader('Academic Details', Icons.school_rounded, theme),
          const SizedBox(height: 16),

          // Department Dropdown
          DropdownButtonFormField<String>(
            key: ValueKey('dept_$_resetKeyCount'),
            initialValue: _selectedDepartment,
            decoration: const InputDecoration(
              labelText: 'Department *',
              prefixIcon: Icon(Icons.account_balance_outlined),
            ),
            isExpanded: true,
            items: departments.map((dept) {
              return DropdownMenuItem(
                value: dept,
                child: Text(dept, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedDepartment = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a department';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Semester Dropdown
          DropdownButtonFormField<String>(
            key: ValueKey('sem_$_resetKeyCount'),
            initialValue: _selectedSemester,
            decoration: const InputDecoration(
              labelText: 'Semester *',
              prefixIcon: Icon(Icons.calendar_today_outlined),
            ),
            items: semesters.map((sem) {
              return DropdownMenuItem(
                value: sem,
                child: Text(sem),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedSemester = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a semester';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Section: Contact Information
          _buildSectionHeader('Contact Information', Icons.contact_phone_rounded, theme),
          const SizedBox(height: 16),

          // Phone Number
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: 'e.g., +1 (555) 019-2834',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                if (digitsOnly.length < 7) {
                  return 'Please enter a valid phone number';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          // Action Buttons
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleSave,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_isLoading ? 'Saving...' : widget.submitButtonText),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _resetForm,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reset'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Divider(
            color: theme.dividerColor.withValues(alpha: 0.2),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}
