import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/student.dart';

class DatabaseHelper {
  static const String _databaseName = 'student_manager.db';
  static const int _databaseVersion = 1;

  static const String tableStudents = 'students';
  static const String columnId = 'id';
  static const String columnName = 'name';
  static const String columnRollNo = 'roll_no';
  static const String columnDepartment = 'department';
  static const String columnSemester = 'semester';
  static const String columnPhone = 'phone';

  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Retrieve active database or initialize it
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize SQLite database with cross-platform support (Windows Desktop & Android Mobile)
  Future<Database> _initDatabase() async {
    final String path = await _getDatabaseFilePath();

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  /// Resolve platform-specific database file location
  Future<String> _getDatabaseFilePath() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      // Windows Desktop initialization via sqflite_common_ffi
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      final directory = await getApplicationDocumentsDirectory();
      final dbFolder = Directory(join(directory.path, 'StudentManager'));
      if (!await dbFolder.exists()) {
        await dbFolder.create(recursive: true);
      }
      return join(dbFolder.path, _databaseName);
    } else {
      // Android / iOS standard database path
      final databasesPath = await getDatabasesPath();
      return join(databasesPath, _databaseName);
    }
  }

  /// Create database table matching the specification
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableStudents (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnName TEXT NOT NULL,
        $columnRollNo TEXT NOT NULL UNIQUE,
        $columnDepartment TEXT NOT NULL,
        $columnSemester TEXT NOT NULL,
        $columnPhone TEXT
      )
    ''');
  }

  // ================= CRUD OPERATIONS =================

  /// INSERT: Add a new student record
  /// Throws DatabaseException if roll number is not unique
  Future<int> insertStudent(Student student) async {
    final db = await database;
    return await db.insert(
      tableStudents,
      student.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// SELECT: Retrieve all student records
  Future<List<Student>> getAllStudents({String? sortBy = 'id', bool ascending = false}) async {
    final db = await database;
    final order = ascending ? 'ASC' : 'DESC';
    final List<Map<String, dynamic>> maps = await db.query(
      tableStudents,
      orderBy: '$sortBy $order',
    );

    return maps.map((map) => Student.fromMap(map)).toList();
  }

  /// SELECT: Find a student by ID
  Future<Student?> getStudentById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableStudents,
      where: '$columnId = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Student.fromMap(maps.first);
    }
    return null;
  }

  /// SELECT / SEARCH: Search students by Name, Roll Number, or Department
  Future<List<Student>> searchStudents(String query) async {
    final db = await database;
    final cleanQuery = '%${query.trim()}%';

    final List<Map<String, dynamic>> maps = await db.query(
      tableStudents,
      where: '''
        $columnName LIKE ? OR 
        $columnRollNo LIKE ? OR 
        $columnDepartment LIKE ?
      ''',
      whereArgs: [cleanQuery, cleanQuery, cleanQuery],
      orderBy: '$columnName ASC',
    );

    return maps.map((map) => Student.fromMap(map)).toList();
  }

  /// Check if a Roll Number already exists in the database
  Future<bool> isRollNumberTaken(String rollNo, {int? excludeId}) async {
    final db = await database;
    final normalizedRoll = rollNo.trim().toUpperCase();

    String whereClause = '$columnRollNo = ?';
    List<dynamic> whereArgs = [normalizedRoll];

    if (excludeId != null) {
      whereClause += ' AND $columnId != ?';
      whereArgs.add(excludeId);
    }

    final result = await db.query(
      tableStudents,
      columns: [columnId],
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );

    return result.isNotEmpty;
  }

  /// UPDATE: Update an existing student record
  Future<int> updateStudent(Student student) async {
    final db = await database;
    if (student.id == null) {
      throw ArgumentError('Student ID cannot be null for an update operation');
    }

    return await db.update(
      tableStudents,
      student.toMap(),
      where: '$columnId = ?',
      whereArgs: [student.id],
    );
  }

  /// DELETE: Remove a student record by ID
  Future<int> deleteStudent(int id) async {
    final db = await database;
    return await db.delete(
      tableStudents,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  /// DELETE: Delete all student records (for reset/demo purposes)
  Future<int> deleteAllStudents() async {
    final db = await database;
    return await db.delete(tableStudents);
  }

  /// ANALYTICS: Get total count of students
  Future<int> getStudentCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableStudents'),
    );
    return count ?? 0;
  }

  /// ANALYTICS: Get count grouped by department
  Future<Map<String, int>> getDepartmentStatistics() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT $columnDepartment, COUNT(*) as count 
      FROM $tableStudents 
      GROUP BY $columnDepartment
      ORDER BY count DESC
    ''');

    final Map<String, int> stats = {};
    for (var row in results) {
      final dept = row[columnDepartment] as String;
      final count = row['count'] as int;
      stats[dept] = count;
    }
    return stats;
  }

  /// SEED: Populate sample student records for demonstration
  Future<void> seedSampleStudents() async {
    final count = await getStudentCount();
    if (count > 0) return; // Do not overwrite existing data

    final sampleStudents = [
      const Student(
        name: 'Alex Johnson',
        rollNo: 'CS-2024-001',
        department: 'Computer Science',
        semester: 'Semester 4',
        phone: '+1 (555) 234-5678',
      ),
      const Student(
        name: 'Sophia Patel',
        rollNo: 'IT-2024-015',
        department: 'Information Technology',
        semester: 'Semester 6',
        phone: '+1 (555) 345-6789',
      ),
      const Student(
        name: 'Marcus Williams',
        rollNo: 'EE-2024-022',
        department: 'Electrical Engineering',
        semester: 'Semester 2',
        phone: '+1 (555) 456-7890',
      ),
      const Student(
        name: 'Emma Rodriguez',
        rollNo: 'ME-2024-041',
        department: 'Mechanical Engineering',
        semester: 'Semester 8',
        phone: '+1 (555) 567-8901',
      ),
      const Student(
        name: 'David Chen',
        rollNo: 'CS-2024-089',
        department: 'Computer Science',
        semester: 'Semester 4',
        phone: '+1 (555) 678-9012',
      ),
    ];

    for (var student in sampleStudents) {
      await insertStudent(student);
    }
  }

  /// Close database connection
  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}
