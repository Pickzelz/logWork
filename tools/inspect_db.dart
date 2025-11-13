import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final path = args.isNotEmpty ? args[0] : r"C:\Users\pickz\AppData\Roaming\com.example\log_work\log_work.db";
  print('Opening DB: $path');
  final file = File(path);
  if (!file.existsSync()) {
    print('DB not found');
    exit(2);
  }
  try {
    final db = sqlite3.open(path);
    print('Tables:');
    final tables = db.select("SELECT name FROM sqlite_master WHERE type='table'");
    for (final row in tables) {
      print(' - ${row['name']}');
    }
    try {
      final rows = db.select('SELECT COUNT(*) as c FROM recurring_schedules');
      final c = rows.isNotEmpty ? rows.first['c'] : 0;
      print('recurring_schedules count: $c');
    } catch (e) {
      print('Could not query recurring_schedules: $e');
    }
    try {
      final rows = db.select('SELECT * FROM recurring_schedules LIMIT 5');
      print('Sample rows (up to 5):');
      for (final r in rows) print(r);
    } catch (_) {}
    db.dispose();
  } catch (e) {
    print('Error opening DB: $e');
    exit(3);
  }
}
