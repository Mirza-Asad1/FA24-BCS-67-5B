// PDF Reader
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show Printing;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// =============================================================================
// 1. APP ENTRY & THEME
// =============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotifService.init();
  final app = AppState();
  await app.load();
  if (app.reminderOn) {
    await NotifService.scheduleDaily(
      app.reminderHour,
      app.reminderMinute,
      app.sound,
    );
  }
  runApp(ChangeNotifierProvider.value(value: app, child: const LumiApp()));
}

class AppColors {
  static const violet = Color(0xFF7C4DFF);
  static const cyan = Color(0xFF00E5FF);
  static const pink = Color(0xFFFF4FA3);
  static const amber = Color(0xFFFFB84D);
  static const mint = Color(0xFF00F5A0);

  static const primaryGrad = LinearGradient(
    colors: [violet, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const hotGrad = LinearGradient(
    colors: [pink, amber],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const mintGrad = LinearGradient(
    colors: [mint, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const titleGrad = LinearGradient(colors: [cyan, violet, pink]);

  static List<Color> bg(bool dark) => dark
      ? const [Color(0xFF0A0620), Color(0xFF160B3A), Color(0xFF08203F)]
      : const [Color(0xFFF2ECFF), Color(0xFFE4F6FF), Color(0xFFFFE9F4)];
}

bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

Color glass(BuildContext c) => isDark(c)
    ? Colors.white.withValues(alpha: 0.07)
    : Colors.white.withValues(alpha: 0.72);

Color softText(BuildContext c) => isDark(c) ? Colors.white70 : Colors.black54;

void toast(BuildContext c, String msg) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      brightness: b,
    ),
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: dark ? Colors.white : const Color(0xFF1B1140),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF2A1670) : const Color(0xFF3B2A8F),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

class LumiApp extends StatelessWidget {
  const LumiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<AppState, ThemeMode>((a) => a.themeMode);
    return MaterialApp(
      title: 'LumiPDF',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // One shared gradient background behind every screen.
      builder: (context, child) => GradientBackground(child: child!),
      home: const HomeShell(),
    );
  }
}

// =============================================================================
// 2. MODELS & SQLITE HELPER
// =============================================================================

class Doc {
  int? id;
  String name;
  String path;
  String description;
  String tags;
  bool isFavorite;
  int totalPages;
  int lastPage;
  int addedAt;
  String source;
  int? openedAt; // only filled for "recent" queries (not stored in documents)

  Doc({
    this.id,
    required this.name,
    required this.path,
    this.description = '',
    this.tags = '',
    this.isFavorite = false,
    this.totalPages = 0,
    this.lastPage = 1,
    required this.addedAt,
    this.source = 'import',
    this.openedAt,
  });

  double get progress =>
      totalPages <= 0 ? 0 : (lastPage / totalPages).clamp(0.0, 1.0).toDouble();

  List<String> get tagList =>
      tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

  factory Doc.fromMap(Map<String, Object?> m) => Doc(
    id: m['id'] as int?,
    name: m['name'] as String,
    path: m['path'] as String,
    description: (m['description'] as String?) ?? '',
    tags: (m['tags'] as String?) ?? '',
    isFavorite: ((m['is_favorite'] as int?) ?? 0) == 1,
    totalPages: (m['total_pages'] as int?) ?? 0,
    lastPage: (m['last_page'] as int?) ?? 1,
    addedAt: m['added_at'] as int,
    source: (m['source'] as String?) ?? 'import',
    openedAt: m['opened_at'] as int?,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'path': path,
    'description': description,
    'tags': tags,
    'is_favorite': isFavorite ? 1 : 0,
    'total_pages': totalPages,
    'last_page': lastPage,
    'added_at': addedAt,
    'source': source,
  };
}

class ExportTable {
  final String title;
  final List<String> headers;
  final List<List<String>> rows;
  const ExportTable(this.title, this.headers, this.rows);
}

/// Singleton wrapper around the SQLite database.
/// Tables: documents, bookmarks, history, settings.
class DbHelper {
  DbHelper._();
  static final DbHelper instance = DbHelper._();
  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'lumipdf.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE documents(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            path TEXT NOT NULL,
            description TEXT DEFAULT '',
            tags TEXT DEFAULT '',
            is_favorite INTEGER DEFAULT 0,
            total_pages INTEGER DEFAULT 0,
            last_page INTEGER DEFAULT 1,
            added_at INTEGER NOT NULL,
            source TEXT DEFAULT 'import'
          )''');
        await db.execute('''
          CREATE TABLE bookmarks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            document_id INTEGER NOT NULL,
            page_number INTEGER NOT NULL,
            note TEXT DEFAULT '',
            created_at INTEGER NOT NULL,
            FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
          )''');
        await db.execute('''
          CREATE TABLE history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            document_id INTEGER NOT NULL,
            opened_at INTEGER NOT NULL,
            last_page INTEGER DEFAULT 1,
            FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
          )''');
        await db.execute(
          'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)',
        );
      },
    );
  }

  // ---- documents ----
  Future<List<Doc>> allDocs() async {
    final d = await database;
    final rows = await d.query('documents', orderBy: 'added_at DESC');
    return rows.map(Doc.fromMap).toList();
  }

  Future<int> insertDoc(Doc doc) async {
    final d = await database;
    final map = doc.toMap()..remove('id');
    return d.insert('documents', map);
  }

  Future<void> updateDoc(Doc doc) async {
    final d = await database;
    await d.update(
      'documents',
      doc.toMap(),
      where: 'id = ?',
      whereArgs: [doc.id],
    );
  }

  Future<void> deleteDoc(int id) async {
    final d = await database;
    await d.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  // ---- history ----
  Future<void> touchHistory(int docId, int page) async {
    final d = await database;
    await d.delete('history', where: 'document_id = ?', whereArgs: [docId]);
    await d.insert('history', {
      'document_id': docId,
      'opened_at': DateTime.now().millisecondsSinceEpoch,
      'last_page': page,
    });
  }

  Future<void> updateProgress(int docId, int page, int total) async {
    final d = await database;
    await d.update(
      'documents',
      {'last_page': page, 'total_pages': total},
      where: 'id = ?',
      whereArgs: [docId],
    );
    await d.update(
      'history',
      {'last_page': page},
      where: 'document_id = ?',
      whereArgs: [docId],
    );
  }

  Future<List<Doc>> recentDocs() async {
    final d = await database;
    final rows = await d.rawQuery('''
      SELECT d.*, h.opened_at AS opened_at
      FROM history h JOIN documents d ON d.id = h.document_id
      ORDER BY h.opened_at DESC LIMIT 50''');
    return rows.map(Doc.fromMap).toList();
  }

  // ---- bookmarks ----
  Future<bool> toggleBookmark(int docId, int page) async {
    final d = await database;
    final ex = await d.query(
      'bookmarks',
      where: 'document_id = ? AND page_number = ?',
      whereArgs: [docId, page],
    );
    if (ex.isNotEmpty) {
      await d.delete('bookmarks', where: 'id = ?', whereArgs: [ex.first['id']]);
      return false;
    }
    await d.insert('bookmarks', {
      'document_id': docId,
      'page_number': page,
      'note': '',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return true;
  }

  Future<Set<int>> bookmarkPages(int docId) async {
    final d = await database;
    final rows = await d.query(
      'bookmarks',
      where: 'document_id = ?',
      whereArgs: [docId],
    );
    return rows.map((r) => r['page_number'] as int).toSet();
  }

  Future<List<Map<String, Object?>>> allBookmarks() async {
    final d = await database;
    return d.rawQuery('''
      SELECT b.id AS id, b.document_id AS document_id,
             b.page_number AS page_number, b.note AS note,
             b.created_at AS created_at, d.name AS name
      FROM bookmarks b JOIN documents d ON d.id = b.document_id
      ORDER BY b.created_at DESC''');
  }

  Future<void> deleteBookmark(int id) async {
    final d = await database;
    await d.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  // ---- settings (user preferences) ----
  Future<Map<String, String>> settings() async {
    final d = await database;
    final rows = await d.query('settings');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  Future<void> setSetting(String key, String value) async {
    final d = await database;
    await d.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

// ---- small helpers ----
String two(int n) => n.toString().padLeft(2, '0');

String fmtDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

String ago(int ms) {
  final diff = DateTime.now().difference(
    DateTime.fromMillisecondsSinceEpoch(ms),
  );
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}

String safeName(String s) => s.replaceAll(RegExp(r'[^\w\- ]'), '_').trim();

/// Folder where every imported / scanned PDF is stored (private to the app).
Future<Directory> pdfDir() async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(base.path, 'pdfs'));
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

// =============================================================================
// 3. APP STATE (Provider)
// =============================================================================

class AppState extends ChangeNotifier {
  final DbHelper _db = DbHelper.instance;

  List<Doc> docs = [];
  List<Doc> recent = [];
  List<Map<String, Object?>> bookmarks = [];
  String query = '';

  // user preferences (stored in the settings table)
  ThemeMode themeMode = ThemeMode.dark;
  int bgIndex = 0;
  String sound = 'default';
  bool reminderOn = false;
  int reminderHour = 20;
  int reminderMinute = 0;

  List<Doc> get filtered {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return docs;
    return docs
        .where(
          (d) =>
              d.name.toLowerCase().contains(q) ||
              d.tags.toLowerCase().contains(q) ||
              d.description.toLowerCase().contains(q),
        )
        .toList();
  }

  List<Doc> get favorites => docs.where((d) => d.isFavorite).toList();

  Future<void> load() async {
    final s = await _db.settings();
    themeMode = s['theme'] == 'light' ? ThemeMode.light : ThemeMode.dark;
    bgIndex = (int.tryParse(s['bg'] ?? '') ?? 0).clamp(
      0,
      readingBgs.length - 1,
    );
    sound = s['sound'] ?? 'default';
    reminderOn = s['reminder'] == '1';
    reminderHour = int.tryParse(s['rh'] ?? '') ?? 20;
    reminderMinute = int.tryParse(s['rm'] ?? '') ?? 0;
    await reload();
  }

  Future<void> reload() async {
    docs = await _db.allDocs();
    recent = await _db.recentDocs();
    bookmarks = await _db.allBookmarks();
    notifyListeners();
  }

  void setQuery(String q) {
    query = q;
    notifyListeners();
  }

  // ---- documents ----
  /// Lets the user pick PDFs, copies them into the app folder and saves them.
  Future<int> importPdfs() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (res == null) return 0;
    final dir = await pdfDir();
    var n = 0;
    String last = '';
    for (final f in res.files) {
      if (f.path == null) continue;
      final dest = p.join(
        dir.path,
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(f.path!)}',
      );
      await File(f.path!).copy(dest);
      last = p.basenameWithoutExtension(f.path!);
      await _db.insertDoc(
        Doc(
          name: last,
          path: dest,
          addedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      n++;
    }
    await reload();
    if (n > 0) {
      NotifService.showNow(
        'New document added',
        n == 1
            ? '"$last" is ready to read.'
            : '$n documents were added to your library.',
        sound,
      );
    }
    return n;
  }

  Future<void> addDoc(
    String name,
    String path, {
    String source = 'import',
  }) async {
    await _db.insertDoc(
      Doc(
        name: name,
        path: path,
        source: source,
        addedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await reload();
    NotifService.showNow(
      'New document added',
      '"$name" is ready to read.',
      sound,
    );
  }

  Future<void> toggleFavorite(Doc d) async {
    d.isFavorite = !d.isFavorite;
    await _db.updateDoc(d);
    await reload();
  }

  Future<void> saveDetails(Doc d, String name, String tags, String desc) async {
    d.name = name;
    d.tags = tags;
    d.description = desc;
    await _db.updateDoc(d);
    await reload();
  }

  Future<void> deleteDoc(Doc d) async {
    await _db.deleteDoc(d.id!);
    try {
      final f = File(d.path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    await reload();
  }

  // ---- history / progress ----
  Future<void> recordOpen(Doc d) async => _db.touchHistory(d.id!, d.lastPage);

  Future<void> recordProgress(Doc d, int page, int total) async {
    d.lastPage = page;
    if (total > 0) d.totalPages = total;
    await _db.updateProgress(d.id!, page, d.totalPages);
  }

  // ---- bookmarks ----
  Future<Set<int>> bookmarkPages(Doc d) => _db.bookmarkPages(d.id!);

  Future<bool> toggleBookmark(Doc d, int page) async {
    final added = await _db.toggleBookmark(d.id!, page);
    bookmarks = await _db.allBookmarks();
    notifyListeners();
    return added;
  }

  Future<void> removeBookmark(int id) async {
    await _db.deleteBookmark(id);
    bookmarks = await _db.allBookmarks();
    notifyListeners();
  }

  // ---- preferences ----
  Future<void> setTheme(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    await _db.setSetting('theme', m == ThemeMode.light ? 'light' : 'dark');
  }

  Future<void> setBg(int i) async {
    bgIndex = i;
    notifyListeners();
    await _db.setSetting('bg', '$i');
  }

  Future<void> setSound(String s) async {
    sound = s;
    notifyListeners();
    await _db.setSetting('sound', s);
    if (reminderOn) {
      await NotifService.scheduleDaily(reminderHour, reminderMinute, s);
    }
  }

  Future<void> setReminder(bool on) async {
    reminderOn = on;
    notifyListeners();
    await _db.setSetting('reminder', on ? '1' : '0');
    if (on) {
      await NotifService.requestPermission();
      await NotifService.scheduleDaily(reminderHour, reminderMinute, sound);
    } else {
      await NotifService.cancelDaily();
    }
  }

  Future<void> setReminderTime(int h, int m) async {
    reminderHour = h;
    reminderMinute = m;
    notifyListeners();
    await _db.setSetting('rh', '$h');
    await _db.setSetting('rm', '$m');
    if (reminderOn) await NotifService.scheduleDaily(h, m, sound);
  }

  // ---- export data ----
  ExportTable table(int kind) {
    if (kind == 0) {
      return ExportTable(
        'Library metadata',
        [
          'Name',
          'Tags',
          'Description',
          'Favorite',
          'Pages',
          'Last page',
          'Progress',
          'Added',
        ],
        [
          for (final d in docs)
            [
              d.name,
              d.tags,
              d.description,
              d.isFavorite ? 'Yes' : 'No',
              '${d.totalPages}',
              '${d.lastPage}',
              '${(d.progress * 100).round()}%',
              fmtDate(d.addedAt),
            ],
        ],
      );
    }
    if (kind == 1) {
      return ExportTable(
        'Reading history',
        ['Name', 'Last opened', 'Last page', 'Progress'],
        [
          for (final d in recent)
            [
              d.name,
              d.openedAt == null ? '' : fmtDate(d.openedAt!),
              '${d.lastPage}',
              '${(d.progress * 100).round()}%',
            ],
        ],
      );
    }
    return ExportTable(
      'Bookmarks',
      ['Document', 'Page', 'Note', 'Saved on'],
      [
        for (final b in bookmarks)
          [
            '${b['name']}',
            '${b['page_number']}',
            '${b['note'] ?? ''}',
            fmtDate(b['created_at'] as int),
          ],
      ],
    );
  }
}

// =============================================================================
// 4. NOTIFICATIONS SERVICE (local notifications + sound choice)
// =============================================================================

class NotifService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Sound options. Android ties sound to a channel, so each option has its
  /// own channel (id: lumipdf_<key>).
  static const Map<String, String> sounds = {
    'default': 'Default',
    'alarm': 'Alarm',
    'ringtone': 'Ringtone',
    'silent': 'Silent',
  };

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
  }

  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  static NotificationDetails _details(String key) {
    AndroidNotificationSound? s;
    if (key == 'alarm') {
      s = const UriAndroidNotificationSound(
        'content://settings/system/alarm_alert',
      );
    } else if (key == 'ringtone') {
      s = const UriAndroidNotificationSound(
        'content://settings/system/ringtone',
      );
    }
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'lumipdf_$key',
        'Reading notifications (${sounds[key] ?? 'Default'})',
        channelDescription: 'Reading reminders and new document alerts',
        importance: Importance.high,
        priority: Priority.high,
        playSound: key != 'silent',
        sound: s,
      ),
    );
  }

  static Future<void> showNow(
    String title,
    String body,
    String soundKey,
  ) async {
    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000 + 10,
        title,
        body,
        _details(soundKey),
      );
    } catch (_) {}
  }

  /// Daily reading reminder at [hour]:[minute] (device local time).
  static Future<void> scheduleDaily(
    int hour,
    int minute,
    String soundKey,
  ) async {
    final now = DateTime.now();
    var t = DateTime(now.year, now.month, now.day, hour, minute);
    if (t.isBefore(now)) t = t.add(const Duration(days: 1));
    // Convert the exact instant to UTC and repeat on its clock time every day.
    final when = tz.TZDateTime.from(t, tz.UTC);
    try {
      await _plugin.zonedSchedule(
        1,
        'Time to read',
        'Your daily reading goal is waiting. Pick up where you left off.',
        when,
        _details(soundKey),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }

  static Future<void> cancelDaily() => _plugin.cancel(1);
}

// =============================================================================
// 5. REUSABLE GLOW / GRADIENT UI + TRANSITIONS
// =============================================================================

class GradientBackground extends StatelessWidget {
  final Widget child;
  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.bg(dark),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: Orb(
              color: AppColors.violet,
              size: 300,
              alpha: dark ? 0.38 : 0.22,
            ),
          ),
          Positioned(
            bottom: 140,
            left: -110,
            child: Orb(
              color: AppColors.cyan,
              size: 280,
              alpha: dark ? 0.28 : 0.20,
            ),
          ),
          Positioned(
            top: 260,
            right: -120,
            child: Orb(
              color: AppColors.pink,
              size: 240,
              alpha: dark ? 0.16 : 0.14,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class Orb extends StatelessWidget {
  final Color color;
  final double size;
  final double alpha;
  const Orb({
    super.key,
    required this.color,
    required this.size,
    required this.alpha,
  });

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}

class GradientText extends StatelessWidget {
  final String text;
  final double size;
  const GradientText(this.text, {super.key, this.size = 24});

  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (r) => AppColors.titleGrad.createShader(r),
    child: Text(
      text,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: Colors.white,
      ),
    ),
  );
}

class GlowCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color glow;
  const GlowCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.glow = AppColors.violet,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final r = BorderRadius.circular(22);
    return Container(
      decoration: BoxDecoration(
        color: glass(context),
        borderRadius: r,
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.14)
              : AppColors.violet.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: dark ? 0.20 : 0.14),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: r,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Gradient gradient;
  final bool busy;
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.gradient = AppColors.primaryGrad,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(26);
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: r,
          boxShadow: [
            BoxShadow(
              color: AppColors.violet.withValues(alpha: 0.5),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: r,
            onTap: busy ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlowChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const GlowChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGrad : null,
          color: selected ? null : glass(context),
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.16)
                      : AppColors.violet.withValues(alpha: 0.22),
                ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.cyan.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : softText(context),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : (dark ? Colors.white : const Color(0xFF1B1140)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fade + slide-up entrance, staggered by [index].
class FadeSlide extends StatelessWidget {
  final int index;
  final Widget child;
  const FadeSlide({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final extra = (index > 8 ? 8 : index) * 70;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + extra),
      curve: Curves.easeOutCubic,
      builder: (context, v, ch) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 26 * (1 - v)), child: ch),
      ),
      child: child,
    );
  }
}

class ProgressGlow extends StatelessWidget {
  final double value;
  final double height;
  const ProgressGlow({super.key, required this.value, this.height = 7});

  @override
  Widget build(BuildContext context) {
    final track = isDark(context)
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.violet.withValues(alpha: 0.12);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0).toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Container(
        height: height,
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(height),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: v,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.mintGrad,
              borderRadius: BorderRadius.circular(height),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mint.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeSlide(
        index: 0,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGrad,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withValues(alpha: 0.5),
                      blurRadius: 36,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 42),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: softText(context), height: 1.4),
              ),
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class GlassSheet extends StatelessWidget {
  final Widget child;
  const GlassSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xFF1D0F4A), Color(0xFF0E1B42)]
                : const [Colors.white, Color(0xFFF1EAFF)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: AppColors.cyan.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.violet.withValues(alpha: 0.5),
              blurRadius: 40,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGrad,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget glassField(
  BuildContext c,
  TextEditingController ctl,
  String label,
  IconData icon, {
  int lines = 1,
  TextInputType? keyboard,
}) {
  return TextField(
    controller: ctl,
    minLines: lines,
    maxLines: lines,
    keyboardType: keyboard,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.violet),
      filled: true,
      fillColor: glass(c),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.cyan, width: 1.6),
      ),
    ),
  );
}

/// Page transition: fade + slight slide + scale.
Route<T> fadeScaleRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 450),
  reverseTransitionDuration: const Duration(milliseconds: 350),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, anim, _, child) {
    final c = CurvedAnimation(
      parent: anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: c,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(c),
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(c),
          child: child,
        ),
      ),
    );
  },
);

// =============================================================================
// 6. HOME SHELL + LIBRARY / FAVORITES / RECENT TABS
// =============================================================================

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  static const _titles = ['Library', 'Favorites', 'Recent', 'Scanner'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => NotifService.requestPermission(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [
      LibraryTab(),
      FavoritesTab(),
      RecentTab(),
      ScannerTab(),
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGrad,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.withValues(alpha: 0.6),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: KeyedSubtree(
                key: ValueKey(_tab),
                child: GradientText(_titles[_tab]),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () =>
                Navigator.of(context)
                    .push(fadeScaleRoute(const SettingsScreen())),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
      ),
      bottomNavigationBar: GlowNavBar(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class GlowNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const GlowNavBar({super.key, required this.index, required this.onTap});

  static const _items = [
    (Icons.auto_stories_rounded, 'Library'),
    (Icons.favorite_rounded, 'Favorites'),
    (Icons.history_rounded, 'Recent'),
    (Icons.document_scanner_rounded, 'Scanner'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: dark
              ? const Color(0xFF14092E).withValues(alpha: 0.88)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.12)
                : AppColors.violet.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.violet.withValues(alpha: 0.38),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                flex: i == index ? 2 : 1,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: i == index ? AppColors.primaryGrad : null,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: i == index
                          ? [
                              BoxShadow(
                                color: AppColors.cyan.withValues(alpha: 0.55),
                                blurRadius: 18,
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _items[i].$1,
                          size: 22,
                          color: i == index
                              ? Colors.white
                              : (dark ? Colors.white60 : Colors.black45),
                        ),
                        if (i == index) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _items[i].$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Library tab
class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});
  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: context.read<AppState>().query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final n = await context.read<AppState>().importPdfs();
    if (n > 0 && mounted) {
      toast(
        context,
        n == 1 ? 'PDF added to your library' : '$n PDFs added to your library',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final docs = app.filtered;
    final searching = app.query.trim().isNotEmpty;
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: TextField(
                controller: _search,
                onChanged: app.setQuery,
                decoration: InputDecoration(
                  hintText: 'Search by name, tag or description',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.cyan,
                  ),
                  suffixIcon: searching
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _search.clear();
                            app.setQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: glass(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(
                      color: AppColors.cyan,
                      width: 1.6,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: docs.isEmpty
                  ? EmptyState(
                      icon: searching
                          ? Icons.search_off_rounded
                          : Icons.picture_as_pdf_rounded,
                      title: searching ? 'No matches' : 'Your library is empty',
                      subtitle: searching
                          ? 'Try a different name, tag or description.'
                          : 'Add a PDF from your device or scan a paper document to get started.',
                      action: searching
                          ? null
                          : GradientButton(
                              label: 'Add PDF',
                              icon: Icons.add_rounded,
                              onTap: _add,
                            ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 160),
                      itemCount: docs.length,
                      itemBuilder: (_, i) => DocCard(
                        key: ValueKey('lib_${docs[i].id}'),
                        doc: docs[i],
                        scope: 'lib',
                        index: i,
                      ),
                    ),
            ),
          ],
        ),
        if (docs.isNotEmpty || searching)
          Positioned(
            right: 20,
            bottom: 100,
            child: GradientButton(
              label: 'Add PDF',
              icon: Icons.add_rounded,
              onTap: _add,
            ),
          ),
      ],
    );
  }
}

// -------------------------------------------------------------- Favorites tab
class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final favs = app.favorites;
    final marks = app.bookmarks;
    Widget title(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        t,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
    Widget hint(IconData i, String t) => GlowCard(
      child: Row(
        children: [
          Icon(i, color: AppColors.pink),
          const SizedBox(width: 12),
          Expanded(
            child: Text(t, style: TextStyle(color: softText(context))),
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
      children: [
        title('Favorite documents'),
        if (favs.isEmpty)
          hint(
            Icons.favorite_border_rounded,
            'Tap the heart on any document to pin it here.',
          )
        else
          for (var i = 0; i < favs.length; i++)
            DocCard(
              key: ValueKey('fav_${favs[i].id}'),
              doc: favs[i],
              scope: 'fav',
              index: i,
            ),
        const SizedBox(height: 18),
        title('Bookmarked pages'),
        if (marks.isEmpty)
          hint(
            Icons.bookmark_border_rounded,
            'Bookmark a page while reading to jump back to it later.',
          )
        else
          for (var i = 0; i < marks.length; i++)
            FadeSlide(
              key: ValueKey('bm_${marks[i]['id']}'),
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlowCard(
                  glow: AppColors.amber,
                  onTap: () {
                    final id = marks[i]['document_id'] as int;
                    final match = app.docs.where((d) => d.id == id);
                    if (match.isNotEmpty) {
                      openDoc(
                        context,
                        match.first,
                        page: marks[i]['page_number'] as int,
                      );
                    }
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppColors.hotGrad,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.pink.withValues(alpha: 0.5),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.bookmark_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${marks[i]['name']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Page ${marks[i]['page_number']}',
                              style: TextStyle(color: softText(context)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove bookmark',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () =>
                            app.removeBookmark(marks[i]['id'] as int),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

// ----------------------------------------------------------------- Recent tab
class RecentTab extends StatelessWidget {
  const RecentTab({super.key});

  @override
  Widget build(BuildContext context) {
    final recent = context.watch<AppState>().recent;
    if (recent.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'Nothing read yet',
        subtitle: 'Documents you open will show up here with the page you stopped at.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
      itemCount: recent.length,
      itemBuilder: (_, i) => DocCard(
        key: ValueKey('rec_${recent[i].id}'),
        doc: recent[i],
        scope: 'rec',
        index: i,
        showOpened: true,
      ),
    );
  }
}

// ------------------------------------------------------------------- Doc card
class DocCard extends StatelessWidget {
  final Doc doc;
  final String scope;
  final int index;
  final bool showOpened;
  const DocCard({
    super.key,
    required this.doc,
    required this.scope,
    required this.index,
    this.showOpened = false,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final tag = 'hero_${scope}_${doc.id}';
    final dark = isDark(context);
    final pct = (doc.progress * 100).round();
    return FadeSlide(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlowCard(
          onTap: () => openDoc(context, doc, heroTag: tag),
          child: Row(
            children: [
              Hero(
                tag: tag,
                child: Container(
                  width: 56,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: doc.source == 'scan'
                        ? AppColors.mintGrad
                        : AppColors.primaryGrad,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.violet.withValues(alpha: 0.55),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    doc.source == 'scan'
                        ? Icons.document_scanner_rounded
                        : Icons.picture_as_pdf_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (doc.tagList.isNotEmpty)
                      SizedBox(
                        height: 22,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final t in doc.tagList)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.cyan.withValues(
                                    alpha: dark ? 0.16 : 0.22,
                                  ),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: dark
                                        ? AppColors.cyan
                                        : const Color(0xFF006C7A),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    else
                      Text(
                        showOpened && doc.openedAt != null
                            ? 'Opened ${ago(doc.openedAt!)}'
                            : 'Added ${ago(doc.addedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: softText(context),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: ProgressGlow(value: doc.progress)),
                        const SizedBox(width: 8),
                        Text(
                          doc.totalPages == 0
                              ? 'New'
                              : '$pct%  (p.${doc.lastPage}/${doc.totalPages})',
                          style: TextStyle(
                            fontSize: 11,
                            color: softText(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Favorite',
                    onPressed: () => app.toggleFavorite(doc),
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (c, a) =>
                          ScaleTransition(scale: a, child: c),
                      child: Icon(
                        doc.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey(doc.isFavorite),
                        color: doc.isFavorite
                            ? AppColors.pink
                            : softText(context),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    color: dark ? const Color(0xFF1B1140) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (v) => docAction(context, doc, v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: _MenuRow(
                          Icons.edit_rounded,
                          'Rename / edit details',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'convert',
                        child: _MenuRow(
                          Icons.image_rounded,
                          'Convert to images',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'share',
                        child: _MenuRow(Icons.share_rounded, 'Share'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: _MenuRow(Icons.delete_rounded, 'Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MenuRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: AppColors.violet),
      const SizedBox(width: 12),
      Text(text),
    ],
  );
}

Future<void> docAction(BuildContext context, Doc doc, String action) async {
  final app = context.read<AppState>();
  switch (action) {
    case 'edit':
      await showEditSheet(context, doc);
      break;
    case 'convert':
      await showConvertSheet(context, doc);
      break;
    case 'share':
      await Share.shareXFiles([XFile(doc.path)], text: doc.name);
      break;
    case 'delete':
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete document?'),
          content: Text(
            '"${doc.name}" will be removed from your library together with its bookmarks and history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await app.deleteDoc(doc);
        if (context.mounted) toast(context, 'Deleted "${doc.name}"');
      }
      break;
  }
}

Future<void> openDoc(
  BuildContext context,
  Doc doc, {
  int? page,
  String? heroTag,
}) async {
  final app = context.read<AppState>();
  if (!File(doc.path).existsSync()) {
    toast(
      context,
      'This file is missing from the device. Delete it and import it again.',
    );
    return;
  }
  await Navigator.of(context).push(
    fadeScaleRoute(
      ViewerScreen(doc: doc, startPage: page ?? doc.lastPage, heroTag: heroTag),
    ),
  );
  await app.reload();
}

Future<void> showEditSheet(BuildContext context, Doc doc) {
  final app = context.read<AppState>();
  final name = TextEditingController(text: doc.name);
  final tags = TextEditingController(text: doc.tags);
  final desc = TextEditingController(text: doc.description);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => GlassSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit details',
            style: Theme.of(ctx).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          glassField(ctx, name, 'Name', Icons.edit_rounded),
          const SizedBox(height: 12),
          glassField(ctx, tags, 'Tags (comma separated)', Icons.sell_rounded),
          const SizedBox(height: 12),
          glassField(ctx, desc, 'Description', Icons.notes_rounded, lines: 3),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: GradientButton(
              label: 'Save changes',
              icon: Icons.check_rounded,
              onTap: () async {
                final n = name.text.trim().isEmpty
                    ? doc.name
                    : name.text.trim();
                await app.saveDetails(
                  doc,
                  n,
                  tags.text.trim(),
                  desc.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ),
        ],
      ),
    ),
  );
}

// =============================================================================
// 7. PDF VIEWER (read, zoom, jump, bookmark, progress, resume)
// =============================================================================

class ReadingBg {
  final String name;
  final Color swatch;
  final ColorFilter filter;
  const ReadingBg(this.name, this.swatch, this.filter);
}

final List<ReadingBg> readingBgs = [
  const ReadingBg(
    'Paper',
    Color(0xFFFFFFFF),
    ColorFilter.mode(Colors.white, BlendMode.multiply),
  ),
  const ReadingBg(
    'Sepia',
    Color(0xFFF4E4C1),
    ColorFilter.mode(Color(0xFFF4E4C1), BlendMode.multiply),
  ),
  const ReadingBg(
    'Mint',
    Color(0xFFD3F5E1),
    ColorFilter.mode(Color(0xFFD3F5E1), BlendMode.multiply),
  ),
  const ReadingBg(
    'Sky',
    Color(0xFFD3E9FF),
    ColorFilter.mode(Color(0xFFD3E9FF), BlendMode.multiply),
  ),
  const ReadingBg(
    'Night',
    Color(0xFF14142B),
    ColorFilter.matrix(<double>[
      -1, 0, 0, 0, 255, //
      0, -1, 0, 0, 255, //
      0, 0, -1, 0, 255, //
      0, 0, 0, 1, 0,
    ]),
  ),
];

class ViewerScreen extends StatefulWidget {
  final Doc doc;
  final int startPage;
  final String? heroTag;
  const ViewerScreen({
    super.key,
    required this.doc,
    required this.startPage,
    this.heroTag,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final PdfViewerController _ctrl = PdfViewerController();
  late final AppState _app;
  int _page = 1;
  int _total = 0;
  Set<int> _marks = {};

  @override
  void initState() {
    super.initState();
    _app = context.read<AppState>();
    _page = widget.startPage < 1 ? 1 : widget.startPage;
    _total = widget.doc.totalPages;
    _app.recordOpen(widget.doc);
    _app.bookmarkPages(widget.doc).then((s) {
      if (mounted) setState(() => _marks = s);
    });
  }

  Future<void> _toggleMark() async {
    final added = await _app.toggleBookmark(widget.doc, _page);
    setState(() => added ? _marks.add(_page) : _marks.remove(_page));
    if (mounted) {
      toast(context, added ? 'Page $_page bookmarked' : 'Bookmark removed');
    }
  }

  Future<void> _jumpDialog() async {
    final ctl = TextEditingController(text: '$_page');
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jump to page'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: _total > 0 ? '1 - $_total' : 'Page number',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctl.text.trim())),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (n == null) return;
    if (n < 1 || (_total > 0 && n > _total)) {
      if (mounted) toast(context, 'Enter a page between 1 and $_total');
      return;
    }
    _ctrl.jumpToPage(n);
  }

  void _showMarks() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final pages = _marks.toList()..sort();
          return GlassSheet(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bookmarks',
                  style: Theme.of(ctx).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (pages.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No bookmarks yet. Tap the bookmark icon to save a page.',
                      style: TextStyle(color: softText(ctx)),
                    ),
                  ),
                for (final pg in pages)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.bookmark_rounded,
                      color: AppColors.amber,
                    ),
                    title: Text('Page $pg'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _ctrl.jumpToPage(pg);
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        await _app.toggleBookmark(widget.doc, pg);
                        setState(() => _marks.remove(pg));
                        setSheet(() {});
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _zoom(double delta) {
    final z = (_ctrl.zoomLevel + delta).clamp(1.0, 4.0).toDouble();
    _ctrl.zoomLevel = z;
  }

  @override
  Widget build(BuildContext context) {
    final bgIndex = context.select<AppState, int>((a) => a.bgIndex);
    final dark = isDark(context);
    final marked = _marks.contains(_page);
    final pct = _total == 0 ? 0 : (_page / _total * 100).round();

    final icon = Container(
      width: 30,
      height: 36,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGrad,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan.withValues(alpha: 0.5),
            blurRadius: 10,
          ),
        ],
      ),
      child: const Icon(
        Icons.picture_as_pdf_rounded,
        color: Colors.white,
        size: 18,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            if (widget.heroTag != null)
              Hero(tag: widget.heroTag!, child: icon)
            else
              icon,
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.doc.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Bookmark this page',
            onPressed: _toggleMark,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(
                marked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                key: ValueKey(marked),
                color: marked ? AppColors.amber : null,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Jump to page',
            onPressed: _jumpDialog,
            icon: const Icon(Icons.pin_rounded),
          ),
          PopupMenuButton<String>(
            color: dark ? const Color(0xFF1B1140) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (v) {
              if (v == 'marks') _showMarks();
              if (v == 'convert') {
                showConvertSheet(context, widget.doc, page: _page);
              }
              if (v == 'share') {
                Share.shareXFiles([
                  XFile(widget.doc.path),
                ], text: widget.doc.name);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'marks',
                child: _MenuRow(Icons.bookmarks_rounded, 'All bookmarks'),
              ),
              PopupMenuItem(
                value: 'convert',
                child: _MenuRow(Icons.image_rounded, 'Convert to images'),
              ),
              PopupMenuItem(
                value: 'share',
                child: _MenuRow(Icons.share_rounded, 'Share'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.violet.withValues(alpha: 0.35),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ColorFiltered(
                  colorFilter: readingBgs[bgIndex].filter,
                  child: SfPdfViewer.file(
                    File(widget.doc.path),
                    controller: _ctrl,
                    pageSpacing: 6,
                    onDocumentLoaded: (details) {
                      final total = details.document.pages.count;
                      setState(() => _total = total);
                      _app.recordProgress(widget.doc, _page, total);
                      if (_page > 1) {
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _ctrl.jumpToPage(_page),
                        );
                      }
                    },
                    onDocumentLoadFailed: (d) => toast(
                      context,
                      'Could not open this PDF: ${d.description}',
                    ),
                    onPageChanged: (d) {
                      setState(() => _page = d.newPageNumber);
                      _app.recordProgress(widget.doc, d.newPageNumber, _total);
                    },
                  ),
                ),
              ),
            ),
          ),
          // ---- progress / navigation bar ----
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            decoration: BoxDecoration(
              color: dark
                  ? const Color(0xFF14092E).withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.12)
                    : AppColors.violet.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.violet.withValues(alpha: 0.3),
                  blurRadius: 24,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ProgressGlow(
                      value: _total == 0 ? 0 : _page / _total,
                      height: 8,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Zoom out',
                        onPressed: () => _zoom(-0.5),
                        icon: const Icon(Icons.zoom_out_rounded),
                      ),
                      IconButton(
                        tooltip: 'Previous page',
                        onPressed: () => _ctrl.previousPage(),
                        icon: const Icon(Icons.chevron_left_rounded, size: 30),
                      ),
                      Expanded(
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              _total == 0
                                  ? 'Loading...'
                                  : 'Page $_page of $_total  -  $pct% read',
                              key: ValueKey('$_page/$_total'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next page',
                        onPressed: () => _ctrl.nextPage(),
                        icon: const Icon(Icons.chevron_right_rounded, size: 30),
                      ),
                      IconButton(
                        tooltip: 'Zoom in',
                        onPressed: () => _zoom(0.5),
                        icon: const Icon(Icons.zoom_in_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 8. PDF -> IMAGE CONVERTER
// =============================================================================

Uint8List pngToJpg(Uint8List png) {
  final im = img.decodePng(png);
  if (im == null) return png;
  return Uint8List.fromList(img.encodeJpg(im, quality: 90));
}

Future<void> showConvertSheet(BuildContext context, Doc doc, {int? page}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ConvertSheet(doc: doc, page: page ?? doc.lastPage),
  );
}

class ConvertSheet extends StatefulWidget {
  final Doc doc;
  final int page;
  const ConvertSheet({super.key, required this.doc, required this.page});
  @override
  State<ConvertSheet> createState() => _ConvertSheetState();
}

class _ConvertSheetState extends State<ConvertSheet> {
  int _scope = 0; // 0 all, 1 current page, 2 range
  bool _jpg = false;
  bool _busy = false;
  double? _progress;
  List<String> _out = [];
  String? _error;
  late final TextEditingController _from = TextEditingController(text: '1');
  late final TextEditingController _to = TextEditingController(
    text: widget.doc.totalPages > 0 ? '${widget.doc.totalPages}' : '',
  );

  Future<void> _convert() async {
    List<int>? pages; // zero-based, null = all
    if (_scope == 1) {
      pages = [widget.page - 1];
    } else if (_scope == 2) {
      final a = int.tryParse(_from.text.trim());
      final b = int.tryParse(_to.text.trim());
      final total = widget.doc.totalPages;
      if (a == null ||
          b == null ||
          a < 1 ||
          b < a ||
          (total > 0 && b > total)) {
        setState(
          () => _error =
              'Enter a valid range${total > 0 ? ' (1 - $total)' : ''}.',
        );
        return;
      }
      pages = [for (var i = a; i <= b; i++) i - 1];
    }
    setState(() {
      _busy = true;
      _error = null;
      _out = [];
      _progress = 0;
    });
    try {
      final bytes = await File(widget.doc.path).readAsBytes();
      final ext = _jpg ? 'jpg' : 'png';
      final root =
          await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final dir = Directory(
        p.join(root.path, 'PDF Images', safeName(widget.doc.name)),
      );
      if (!await dir.exists()) await dir.create(recursive: true);

      final expected =
          pages?.length ??
          (widget.doc.totalPages > 0 ? widget.doc.totalPages : null);
      var i = 0;
      await for (final raster in Printing.raster(
        bytes,
        pages: pages,
        dpi: 150,
      )) {
        var data = await raster.toPng();
        if (_jpg) data = await compute(pngToJpg, data);
        final number = pages != null ? pages[i] + 1 : i + 1;
        final file = File(
          p.join(dir.path, 'page_${number.toString().padLeft(3, '0')}.$ext'),
        );
        await file.writeAsBytes(data);
        _out.add(file.path);
        i++;
        if (mounted) {
          setState(() => _progress = expected == null ? null : i / expected);
        }
      }
      if (mounted) setState(() => _progress = 1);
    } catch (e) {
      if (mounted) setState(() => _error = 'Conversion failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Convert to images',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            widget.doc.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: softText(context)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GlowChip(
                label: 'All pages',
                icon: Icons.collections_rounded,
                selected: _scope == 0,
                onTap: () => setState(() => _scope = 0),
              ),
              GlowChip(
                label: 'Page ${widget.page}',
                icon: Icons.crop_portrait_rounded,
                selected: _scope == 1,
                onTap: () => setState(() => _scope = 1),
              ),
              GlowChip(
                label: 'Range',
                icon: Icons.linear_scale_rounded,
                selected: _scope == 2,
                onTap: () => setState(() => _scope = 2),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: _scope == 2
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: glassField(
                            context,
                            _from,
                            'From',
                            Icons.first_page_rounded,
                            keyboard: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: glassField(
                            context,
                            _to,
                            'To',
                            Icons.last_page_rounded,
                            keyboard: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              GlowChip(
                label: 'PNG',
                selected: !_jpg,
                onTap: () => setState(() => _jpg = false),
              ),
              const SizedBox(width: 8),
              GlowChip(
                label: 'JPG',
                selected: _jpg,
                onTap: () => setState(() => _jpg = true),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.pink)),
          ],
          if (_busy || _out.isNotEmpty) ...[
            const SizedBox(height: 16),
            if (_progress == null)
              const LinearProgressIndicator()
            else
              ProgressGlow(value: _progress!, height: 9),
            const SizedBox(height: 8),
            Text(
              _busy
                  ? 'Converting... ${_out.length} done'
                  : '${_out.length} image${_out.length == 1 ? '' : 's'} saved to:\n${p.dirname(_out.first)}',
              style: TextStyle(color: softText(context), fontSize: 12),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!_busy && _out.isNotEmpty) ...[
                GradientButton(
                  label: 'Share',
                  icon: Icons.share_rounded,
                  gradient: AppColors.mintGrad,
                  onTap: () => Share.shareXFiles([
                    for (final f in _out) XFile(f),
                  ], text: '${widget.doc.name} - pages as images'),
                ),
                const SizedBox(width: 10),
              ],
              GradientButton(
                label: _out.isEmpty ? 'Convert' : 'Convert again',
                icon: Icons.auto_fix_high_rounded,
                busy: _busy,
                onTap: _busy ? null : _convert,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 9. SCANNER (camera -> crop -> enhance -> save as PDF)
// =============================================================================

/// Runs in a background isolate: resize + optional enhancement -> JPG bytes.
/// mode: 0 original, 1 enhanced (grayscale + contrast), 2 black & white.
Uint8List processImage(Map<String, dynamic> args) {
  final bytes = File(args['path'] as String).readAsBytesSync();
  var im = img.decodeImage(bytes);
  if (im == null) return bytes;
  im = img.bakeOrientation(im);
  if (im.width > 1700) im = img.copyResize(im, width: 1700);
  final mode = args['mode'] as int;
  if (mode >= 1) {
    im = img.grayscale(im);
    im = img.adjustColor(
      im,
      contrast: mode == 1 ? 1.35 : 1.9,
      brightness: mode == 1 ? 1.05 : 1.1,
    );
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 88));
}

/// Live preview filter that imitates the saved result.
ColorFilter scanFilter(int mode) {
  if (mode == 0) {
    return const ColorFilter.mode(Colors.transparent, BlendMode.dst);
  }
  final c = mode == 1 ? 1.25 : 1.8;
  final t = 255 * 0.5 * (1 - c);
  final r = 0.2126 * c, g = 0.7152 * c, b = 0.0722 * c;
  return ColorFilter.matrix(<double>[
    r, g, b, 0, t, //
    r, g, b, 0, t, //
    r, g, b, 0, t, //
    0, 0, 0, 1, 0,
  ]);
}

class ScannerTab extends StatefulWidget {
  const ScannerTab({super.key});
  @override
  State<ScannerTab> createState() => _ScannerTabState();
}

class _ScannerTabState extends State<ScannerTab> {
  final List<String> _pages = [];
  int _mode = 1;
  bool _busy = false;

  Future<void> _capture(ImageSource src) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: src,
        imageQuality: 95,
      );
      if (picked == null) return;
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop & adjust',
            toolbarColor: AppColors.violet,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppColors.violet,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
        ],
      );
      if (cropped == null) return;
      setState(() => _pages.add(cropped.path));
    } catch (e) {
      if (mounted) toast(context, 'Could not capture the image: $e');
    }
  }

  Future<String?> _askName() {
    final d = DateTime.now();
    final ctl = TextEditingController(
      text:
          'Scan_${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}',
    );
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as PDF'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Document name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = await _askName();
    if (name == null || name.isEmpty) return;
    setState(() => _busy = true);
    try {
      final pdf = pw.Document();
      for (final path in _pages) {
        final bytes = await compute(processImage, {
          'path': path,
          'mode': _mode,
        });
        final image = pw.MemoryImage(bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (_) =>
                pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
          ),
        );
      }
      final dir = await pdfDir();
      final file = File(
        p.join(
          dir.path,
          '${DateTime.now().millisecondsSinceEpoch}_${safeName(name)}.pdf',
        ),
      );
      await file.writeAsBytes(await pdf.save());
      if (!mounted) return;
      await context.read<AppState>().addDoc(name, file.path, source: 'scan');
      if (!mounted) return;
      setState(() => _pages.clear());
      toast(context, 'Saved "$name" to your library');
    } catch (e) {
      if (mounted) toast(context, 'Could not save the scan: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 90),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PulseButton(
                icon: Icons.photo_camera_rounded,
                onTap: () => _capture(ImageSource.camera),
              ),
              const SizedBox(height: 28),
              Text(
                'Scan a document',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Take a photo, crop the edges and save it as a clean PDF. Add as many pages as you need.',
                textAlign: TextAlign.center,
                style: TextStyle(color: softText(context), height: 1.4),
              ),
              const SizedBox(height: 22),
              GlowChip(
                label: 'Import from gallery',
                icon: Icons.photo_library_rounded,
                selected: false,
                onTap: () => _capture(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.74,
            ),
            itemCount: _pages.length,
            itemBuilder: (_, i) => FadeSlide(
              key: ValueKey(_pages[i]),
              index: i,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.violet.withValues(alpha: 0.45),
                          blurRadius: 22,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: ColorFiltered(
                        colorFilter: scanFilter(_mode),
                        child: Image.file(File(_pages[i]), fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGrad,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: GestureDetector(
                      onTap: () => setState(() => _pages.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          child: GlowCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GlowChip(
                      label: 'Original',
                      selected: _mode == 0,
                      onTap: () => setState(() => _mode = 0),
                    ),
                    GlowChip(
                      label: 'Enhanced',
                      selected: _mode == 1,
                      onTap: () => setState(() => _mode = 1),
                    ),
                    GlowChip(
                      label: 'B&W',
                      selected: _mode == 2,
                      onTap: () => setState(() => _mode = 2),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Add page (camera)',
                      onPressed: () => _capture(ImageSource.camera),
                      icon: const Icon(Icons.add_a_photo_rounded),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      tooltip: 'Add page (gallery)',
                      onPressed: () => _capture(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded),
                    ),
                    const Spacer(),
                    GradientButton(
                      label: 'Save PDF (${_pages.length})',
                      icon: Icons.picture_as_pdf_rounded,
                      gradient: AppColors.mintGrad,
                      busy: _busy,
                      onTap: _busy ? null : _save,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class PulseButton extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;
  const PulseButton({super.key, required this.onTap, required this.icon});
  @override
  State<PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<PulseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGrad,
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyan.withValues(alpha: 0.35 + 0.25 * t),
                  blurRadius: 30 + 30 * t,
                  spreadRadius: 4 + 10 * t,
                ),
                BoxShadow(
                  color: AppColors.violet.withValues(alpha: 0.45),
                  blurRadius: 50,
                ),
              ],
            ),
            child: Icon(widget.icon, size: 64, color: Colors.white),
          ),
        );
      },
    );
  }
}

// =============================================================================
// 10. SETTINGS (theme, reading background, notifications, export)
// =============================================================================

Future<void> exportAndShare(ExportTable t, bool asPdf) async {
  final dir = await getTemporaryDirectory();
  final base =
      '${t.title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
  late final File f;
  if (asPdf) {
    f = File(p.join(dir.path, '$base.pdf'));
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (_) => [
          pw.Header(
            level: 0,
            child: pw.Text(t.title, style: const pw.TextStyle(fontSize: 22)),
          ),
          pw.TableHelper.fromTextArray(
            headers: t.headers,
            data: t.rows,
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
    await f.writeAsBytes(await pdf.save());
  } else {
    f = File(p.join(dir.path, '$base.csv'));
    String cell(String s) => '"${s.replaceAll('"', '""')}"';
    final lines = [
      t.headers.map(cell).join(','),
      for (final r in t.rows) r.map(cell).join(','),
    ];
    await f.writeAsString(lines.join('\n'));
  }
  // The share sheet lists Gmail / other mail apps, so this also covers "email".
  await Share.shareXFiles(
    [XFile(f.path)],
    subject: 'LumiPDF - ${t.title}',
    text: 'Exported from LumiPDF',
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _kind = 0;
  bool _pdf = false;
  bool _busy = false;

  Widget _section(
    BuildContext c,
    int i,
    String title,
    IconData icon,
    Widget body,
  ) {
    return FadeSlide(
      index: i,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GlowCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.cyan),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: Theme.of(c).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              body,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final time = TimeOfDay(hour: app.reminderHour, minute: app.reminderMinute);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const GradientText('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          _section(
            context,
            0,
            'Appearance',
            Icons.palette_rounded,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    GlowChip(
                      label: 'Dark',
                      icon: Icons.dark_mode_rounded,
                      selected: app.themeMode == ThemeMode.dark,
                      onTap: () => app.setTheme(ThemeMode.dark),
                    ),
                    GlowChip(
                      label: 'Light',
                      icon: Icons.light_mode_rounded,
                      selected: app.themeMode == ThemeMode.light,
                      onTap: () => app.setTheme(ThemeMode.light),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Reading background',
                  style: TextStyle(color: softText(context)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < readingBgs.length; i++)
                      GestureDetector(
                        onTap: () => app.setBg(i),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: readingBgs[i].swatch,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: app.bgIndex == i
                                      ? AppColors.cyan
                                      : Colors.white24,
                                  width: app.bgIndex == i ? 3 : 1,
                                ),
                                boxShadow: app.bgIndex == i
                                    ? [
                                        BoxShadow(
                                          color: AppColors.cyan.withValues(
                                            alpha: 0.7,
                                          ),
                                          blurRadius: 16,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: app.bgIndex == i
                                  ? Icon(
                                      Icons.check_rounded,
                                      color: i == readingBgs.length - 1
                                          ? Colors.white
                                          : Colors.black87,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              readingBgs[i].name,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          _section(
            context,
            1,
            'Notifications',
            Icons.notifications_active_rounded,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Daily reading reminder'),
                  subtitle: const Text('A nudge to keep up your reading goal'),
                  value: app.reminderOn,
                  onChanged: app.setReminder,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  child: app.reminderOn
                      ? ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.schedule_rounded,
                            color: AppColors.amber,
                          ),
                          title: Text('Remind me at ${time.format(context)}'),
                          trailing: const Icon(Icons.edit_rounded, size: 18),
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: time,
                            );
                            if (t != null) {
                              app.setReminderTime(t.hour, t.minute);
                            }
                          },
                        )
                      : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: 8),
                Text(
                  'Notification sound',
                  style: TextStyle(color: softText(context)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in NotifService.sounds.entries)
                      GlowChip(
                        label: e.value,
                        icon: e.key == 'silent'
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        selected: app.sound == e.key,
                        onTap: () async {
                          await app.setSound(e.key);
                          NotifService.showNow(
                            'Sound preview',
                            '${e.value} selected',
                            e.key,
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                GradientButton(
                  label: 'Send test notification',
                  icon: Icons.send_rounded,
                  gradient: AppColors.hotGrad,
                  onTap: () async {
                    await NotifService.requestPermission();
                    NotifService.showNow(
                      'LumiPDF',
                      'Notifications are working.',
                      app.sound,
                    );
                  },
                ),
              ],
            ),
          ),
          _section(
            context,
            2,
            'Export & share',
            Icons.ios_share_rounded,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What to export',
                  style: TextStyle(color: softText(context)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    GlowChip(
                      label: 'Library metadata',
                      selected: _kind == 0,
                      onTap: () => setState(() => _kind = 0),
                    ),
                    GlowChip(
                      label: 'Reading history',
                      selected: _kind == 1,
                      onTap: () => setState(() => _kind = 1),
                    ),
                    GlowChip(
                      label: 'Bookmarks',
                      selected: _kind == 2,
                      onTap: () => setState(() => _kind = 2),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Format', style: TextStyle(color: softText(context))),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    GlowChip(
                      label: 'CSV',
                      icon: Icons.table_chart_rounded,
                      selected: !_pdf,
                      onTap: () => setState(() => _pdf = false),
                    ),
                    GlowChip(
                      label: 'PDF',
                      icon: Icons.picture_as_pdf_rounded,
                      selected: _pdf,
                      onTap: () => setState(() => _pdf = true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Export, share or email',
                  icon: Icons.mail_rounded,
                  busy: _busy,
                  onTap: () async {
                    setState(() => _busy = true);
                    try {
                      await exportAndShare(app.table(_kind), _pdf);
                    } catch (e) {
                      if (mounted) toast(context, 'Export failed: $e');
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
