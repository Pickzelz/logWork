import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform, File, Directory;
import 'package:path_provider/path_provider.dart';
import '../models/activity.dart';
import '../models/recurring_schedule.dart';

class ActivityDb {
  static final ActivityDb _instance = ActivityDb._internal();
  factory ActivityDb() => _instance;
  ActivityDb._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final databasesPath = await _resolveDatabaseDir();
    final path = join(databasesPath, 'log_work.db');
    // If an older database exists in the sqflite default location, copy it to the
    // new application support directory so existing user data is preserved.
    try {
      final oldDbDir = await getDatabasesPath();
      final oldDbPath = join(oldDbDir, 'log_work.db');
      if (oldDbPath != path) {
        final oldFile = File(oldDbPath);
        final newFile = File(path);
        if (await oldFile.exists() && !await newFile.exists()) {
          // Ensure destination directory exists
          final destDir = Directory(databasesPath);
          if (!await destDir.exists()) await destDir.create(recursive: true);
          await oldFile.copy(path);
        }
      }
    } catch (_) {
      // ignore copy errors and continue — we'll create a fresh DB if needed
    }
    final db = await openDatabase(path, version: 1, onCreate: _onCreate);
    await _ensureMigrations(db);
    // Debug: write DB path and schedule count to C:\Temp for troubleshooting
    try {
      final countRes = await db.rawQuery('SELECT COUNT(*) as c FROM recurring_schedules');
      final cnt = (countRes.isNotEmpty ? countRes.first['c'] : 0) ?? 0;
      final info = 'dbPath=$path\nexists=${await File(path).exists()}\nschedules=$cnt\n';
      try {
        final tmp = File(r'C:\Temp\log_work_db_info.txt');
        await tmp.create(recursive: true);
        await tmp.writeAsString(info);
      } catch (_) {}
    } catch (_) {
      try {
        final info = 'dbPath=$path\nexists=${await File(path).exists()}\nschedules=ERR\n';
        final tmp = File(r'C:\Temp\log_work_db_info.txt');
        await tmp.create(recursive: true);
        await tmp.writeAsString(info);
      } catch (_) {}
    }
    return db;
  }

  Future<String> _resolveDatabaseDir() async {
    // On mobile platforms, use sqflite's default location.
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      return await getDatabasesPath();
    }
    // On desktop/web, store under an app-specific directory to ensure write access.
    // For web, sqflite is not used, but return a temp-like string anyway.
    try {
      final dir = await getApplicationSupportDirectory();
      return dir.path;
    } catch (_) {
      // Fallback to sqflite default if available
      return await getDatabasesPath();
    }
  }

  FutureOr<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        name TEXT,
        firstStartTime TEXT,
        startTime TEXT,
        endTime TEXT,
        accumulated INTEGER,
        manualDuration INTEGER,
        isActive INTEGER,
        type INTEGER,
        url TEXT,
        description TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activityId TEXT,
        timestamp TEXT,
        text TEXT,
        FOREIGN KEY(activityId) REFERENCES activities(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE recurring_schedules (
        id TEXT PRIMARY KEY,
        name TEXT,
        hour INTEGER,
        minute INTEGER,
        notifyHour INTEGER,
        notifyMinute INTEGER,
        repeatType INTEGER,
        daysOfWeek TEXT,
        dayOfMonth INTEGER,
        autoStart INTEGER,
        durationMinutes INTEGER,
        activityType INTEGER,
        url TEXT,
        lastTriggeredDate TEXT
      )
    ''');
  }

  Future<void> _ensureMigrations(Database db) async {
    // Create recurring_schedules if database existed before this feature
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_schedules (
        id TEXT PRIMARY KEY,
        name TEXT,
        hour INTEGER,
        minute INTEGER,
        notifyHour INTEGER,
        notifyMinute INTEGER,
        repeatType INTEGER,
        daysOfWeek TEXT,
        dayOfMonth INTEGER,
        autoStart INTEGER,
        durationMinutes INTEGER,
        activityType INTEGER,
        url TEXT,
        lastTriggeredDate TEXT
      )
    ''');
    // Add firstStartTime to activities if missing
    try {
      await db.execute('ALTER TABLE activities ADD COLUMN firstStartTime TEXT');
    } catch (_) {
      // ignore if already exists
    }
    // Add manualDuration column if missing
    try {
      await db.execute('ALTER TABLE activities ADD COLUMN manualDuration INTEGER');
    } catch (_) {
      // ignore if already exists
    }
    // Add url to recurring_schedules if missing
    try {
      await db.execute('ALTER TABLE recurring_schedules ADD COLUMN url TEXT');
    } catch (_) {
      // ignore if already exists
    }
  }

  Future<void> insertOrUpdateActivity(Activity a) async {
    final db = await database;
    await db.insert('activities', a.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    // replace logs: easiest approach delete existing logs for activity then insert current
    await db.delete('logs', where: 'activityId = ?', whereArgs: [a.id]);
    for (var l in a.logs) {
      await db.insert('logs', {
        'activityId': a.id,
        'timestamp': l.timestamp.toIso8601String(),
        'text': l.text,
      });
    }
  }

  Future<void> deleteActivity(String id) async {
    final db = await database;
    await db.delete('activities', where: 'id = ?', whereArgs: [id]);
    await db.delete('logs', where: 'activityId = ?', whereArgs: [id]);
  }

  Future<List<Activity>> loadAllActivities() async {
    final db = await database;
    final acts = await db.query('activities', orderBy: 'rowid DESC');
    final List<Activity> result = [];
    for (var m in acts) {
      final logs = await db.query('logs', where: 'activityId = ?', whereArgs: [m['id']]);
      final parsedLogs = logs.map((e) => ActivityLog.fromJson(e)).toList();
      result.add(Activity.fromJson(m, logs: parsedLogs));
    }
    return result;
  }

  // Recurring schedules CRUD
  Future<List<RecurringSchedule>> loadSchedules() async {
    final db = await database;
    final rows = await db.query('recurring_schedules', orderBy: 'name');
    return rows.map((e) => RecurringSchedule.fromJson(e)).toList();
  }

  Future<void> upsertSchedule(RecurringSchedule s) async {
    final db = await database;
    await db.insert('recurring_schedules', s.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSchedule(String id) async {
    final db = await database;
    await db.delete('recurring_schedules', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markScheduleTriggered(String id, DateTime date) async {
    final db = await database;
    final ds = '${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
    await db.update('recurring_schedules', {'lastTriggeredDate': ds}, where: 'id = ?', whereArgs: [id]);
  }
}
