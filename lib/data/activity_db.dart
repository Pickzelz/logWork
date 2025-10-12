import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
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
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'log_work.db');
    final db = await openDatabase(path, version: 1, onCreate: _onCreate);
    await _ensureMigrations(db);
    return db;
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
        lastTriggeredDate TEXT
      )
    ''');
    // Add firstStartTime to activities if missing
    try {
      await db.execute('ALTER TABLE activities ADD COLUMN firstStartTime TEXT');
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
