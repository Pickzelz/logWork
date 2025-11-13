import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/activity_db.dart';
import '../models/recurring_schedule.dart';
import '../models/activity.dart';
import '../utils/desktop_popup.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Timer? _timer;
  int _lastCheckedMinute = -1;
  List<RecurringSchedule> _schedules = [];
  final StreamController<void> _dataChangedController = StreamController<void>.broadcast();
  bool _checking = false; // prevent re-entrant checks
  final Set<String> _prompting = <String>{}; // schedules currently showing a popup

  // Emits whenever activities are modified by the service (e.g., a schedule starts)
  Stream<void> get onDataChanged => _dataChangedController.stream;

  bool get isRunning => _timer != null;

  Future<void> start() async {
    await _reloadSchedules();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final now = DateTime.now();
      if (_lastCheckedMinute != now.minute) {
        _lastCheckedMinute = now.minute;
        await _checkRecurringSchedules(now);
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _reloadSchedules() async {
    try {
      _schedules = await ActivityDb().loadSchedules();
    } catch (_) {}
  }

  Future<void> refreshNow() async {
    await _reloadSchedules();
    await _checkRecurringSchedules(DateTime.now());
  }

  Future<void> _checkRecurringSchedules(DateTime now) async {
    if (_checking) return; // skip if a previous check is running (e.g., dialog open)
    _checking = true;
    try {
    if (_schedules.isEmpty) return;
    for (final s in _schedules) {
      // Avoid opening duplicate dialogs for the same schedule
      if (_prompting.contains(s.id)) {
        if (!kReleaseMode) debugPrint('[BG] ${s.name}: already prompting, skip');
        continue;
      }
      if (!s.isDue(now)) {
        if (!kReleaseMode) debugPrint('[BG] ${s.name}: not due');
        continue;
      }
      if (!s.notifyTimeMatches(now)) {
        if (!kReleaseMode) debugPrint('[BG] ${s.name}: notify mismatch');
        continue;
      }
      final today = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (s.lastTriggeredDate == today) {
        if (!kReleaseMode) debugPrint('[BG] ${s.name}: already triggered');
        continue;
      }

      _prompting.add(s.id);
      try {
        // Auto-start the activity immediately to avoid timing drift if user ignores popup
        if (!kReleaseMode) debugPrint('[BG] ${s.name}: auto-starting activity');
        await _startScheduledActivity(s);

        // Show a dismiss-only popup to inform the user
        DesktopPopup.showInfo('Pengingat Jadwal', 'Sudah waktunya: ${s.name}');

        // Mark triggered for today to avoid re-prompting
        s.lastTriggeredDate = today;
        await ActivityDb().markScheduleTriggered(s.id, now);
      } finally {
        _prompting.remove(s.id);
      }
    }
    } finally {
      _checking = false;
    }
  }

  Future<void> _startScheduledActivity(RecurringSchedule s) async {
    // Load all activities, pause any active, insert new activity
    final acts = await ActivityDb().loadAllActivities();
    for (final a in acts) {
      if (a.isActive) {
        a.accumulated = a.duration;
        a.isActive = false;
        a.startTime = null;
        a.endTime = DateTime.now();
        await ActivityDb().insertOrUpdateActivity(a);
      }
    }
    final type = s.activityType == 1 ? ActivityType.breakTime : ActivityType.work;
    final newActivity = Activity(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: s.name,
      firstStartTime: DateTime.now(),
      startTime: DateTime.now(),
      endTime: null,
      isActive: true,
      type: type,
      url: s.url,
    );
    await ActivityDb().insertOrUpdateActivity(newActivity);
    // Notify listeners (UI) that data has changed
    if (!_dataChangedController.isClosed) {
      _dataChangedController.add(null);
    }
  }
}
