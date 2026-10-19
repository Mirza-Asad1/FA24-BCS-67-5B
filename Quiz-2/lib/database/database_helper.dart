import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/patient.dart';
import '../models/patient_document.dart';

/// Handles all SQLite operations (offline storage) and file copying.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'doctor_app.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE patients(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            age INTEGER NOT NULL,
            gender TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT,
            address TEXT,
            blood_group TEXT,
            condition TEXT,
            notes TEXT,
            image_path TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE documents(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            path TEXT NOT NULL,
            is_image INTEGER NOT NULL,
            added_at TEXT NOT NULL,
            FOREIGN KEY(patient_id) REFERENCES patients(id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  // ---------------------------------------------------------------- CREATE
  Future<int> insertPatient(Patient p) async {
    final db = await database;
    return db.insert('patients', p.toMap()..remove('id'));
  }

  Future<int> insertDocument(PatientDocument d) async {
    final db = await database;
    return db.insert('documents', d.toMap()..remove('id'));
  }

  // ------------------------------------------------------------------ READ
  Future<List<Patient>> getPatients({String query = ''}) async {
    final db = await database;
    final rows = query.trim().isEmpty
        ? await db.query('patients', orderBy: 'id DESC')
        : await db.query(
            'patients',
            where: 'name LIKE ? OR condition LIKE ? OR phone LIKE ?',
            whereArgs: ['%$query%', '%$query%', '%$query%'],
            orderBy: 'id DESC',
          );
    return rows.map(Patient.fromMap).toList();
  }

  Future<Patient?> getPatient(int id) async {
    final db = await database;
    final rows = await db.query('patients', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Patient.fromMap(rows.first);
  }

  Future<List<PatientDocument>> getDocuments(int patientId) async {
    final db = await database;
    final rows = await db.query('documents',
        where: 'patient_id = ?', whereArgs: [patientId], orderBy: 'id DESC');
    return rows.map(PatientDocument.fromMap).toList();
  }

  Future<int> countPatients() async {
    final db = await database;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM patients')) ??
        0;
  }

  Future<int> countDocuments() async {
    final db = await database;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM documents')) ??
        0;
  }

  Future<int> countToday() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    return Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM patients WHERE created_at >= ?', [start])) ??
        0;
  }

  // ---------------------------------------------------------------- UPDATE
  Future<int> updatePatient(Patient p) async {
    final db = await database;
    return db.update('patients', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  // ---------------------------------------------------------------- DELETE
  Future<void> deletePatient(Patient p) async {
    final db = await database;
    final docs = await getDocuments(p.id!);
    for (final d in docs) {
      await deleteFile(d.path);
    }
    if (p.imagePath != null) await deleteFile(p.imagePath!);
    await db.delete('patients', where: 'id = ?', whereArgs: [p.id]);
  }

  Future<void> deleteDocument(PatientDocument d) async {
    final db = await database;
    await deleteFile(d.path);
    await db.delete('documents', where: 'id = ?', whereArgs: [d.id]);
  }

  // ----------------------------------------------------------- FILE STORAGE
  /// Copies a picked file into the app's private folder and returns new path.
  Future<String> saveFile(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(join(dir.path, 'patient_files'));
    if (!await folder.exists()) await folder.create(recursive: true);
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${basename(sourcePath)}';
    final saved = await File(sourcePath).copy(join(folder.path, fileName));
    return saved.path;
  }

  Future<void> deleteFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
