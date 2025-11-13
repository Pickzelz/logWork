enum RepeatType { daily, weekly, monthly }

class RecurringSchedule {
  final String id;
  String name;
  int hour; // 0-23
  int minute; // 0-59
  int? notifyHour; // default: same as hour if null
  int? notifyMinute;
  RepeatType repeatType;
  // For weekly: list of weekday ints 1=Mon ... 7=Sun
  List<int>? daysOfWeek;
  // For monthly: 1..31
  int? dayOfMonth;
  // Optional
  bool autoStart;
  int? durationMinutes; // if provided and autoStart true, auto-stop after duration
  int activityType; // 0 work, 1 break
  String? url; // optional link to attach to created activities
  String? lastTriggeredDate; // yyyy-MM-dd to prevent duplicate trigger per period

  RecurringSchedule({
    required this.id,
    required this.name,
    required this.hour,
    required this.minute,
    this.notifyHour,
    this.notifyMinute,
    this.repeatType = RepeatType.daily,
    this.daysOfWeek,
    this.dayOfMonth,
    this.autoStart = false,
    this.durationMinutes,
    this.activityType = 0,
    this.url,
    this.lastTriggeredDate,
  });

  bool isDue(DateTime now) {
    // Check repeat rule for 'now'
    switch (repeatType) {
      case RepeatType.daily:
        return true;
      case RepeatType.weekly:
        final dow = now.weekday; // 1..7 (Mon..Sun)
        return (daysOfWeek ?? []).contains(dow);
      case RepeatType.monthly:
        return dayOfMonth == now.day;
    }
  }

  bool timeMatches(DateTime now) => now.hour == hour && now.minute == minute;
  bool notifyTimeMatches(DateTime now) {
    // If notification disabled, don't match any time
    if (notifyHour == null || notifyMinute == null) return false;
    // Allow a small grace window (±2 minutes) so we don't miss due to timer drift or app resume
    final target = DateTime(now.year, now.month, now.day, notifyHour!, notifyMinute!);
    final diff = now.difference(target).inMinutes;
    // Only trigger at the scheduled minute or up to 2 minutes after (no early trigger)
    return diff >= 0 && diff <= 2;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'hour': hour,
        'minute': minute,
        'notifyHour': notifyHour,
        'notifyMinute': notifyMinute,
        'repeatType': repeatType.index,
    'daysOfWeek': (daysOfWeek ?? []).join(','),
        'dayOfMonth': dayOfMonth,
        'autoStart': autoStart ? 1 : 0,
        'durationMinutes': durationMinutes,
        'activityType': activityType,
    'url': url,
    'lastTriggeredDate': lastTriggeredDate,
      };

  static RecurringSchedule fromJson(Map<String, dynamic> m) => RecurringSchedule(
        id: m['id'].toString(),
        name: m['name'] ?? '',
        hour: m['hour'] ?? 0,
        minute: m['minute'] ?? 0,
        notifyHour: m['notifyHour'],
        notifyMinute: m['notifyMinute'],
        repeatType: RepeatType.values[(m['repeatType'] ?? 0)],
        daysOfWeek: (m['daysOfWeek'] as String?)?.split(',').where((e) => e.isNotEmpty).map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList(),
        dayOfMonth: m['dayOfMonth'],
        autoStart: (m['autoStart'] ?? 0) == 1,
        durationMinutes: m['durationMinutes'],
        activityType: m['activityType'] ?? 0,
        url: m['url'],
        lastTriggeredDate: m['lastTriggeredDate'],
      );
}
