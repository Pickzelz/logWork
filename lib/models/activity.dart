class Activity {
  final String id;
  String name;
  // The first time this activity ever started (never changes after first start)
  DateTime? firstStartTime;
  DateTime? startTime;
  DateTime? endTime;
  // accumulated time from previous sessions (used when starting/pausing multiple times)
  Duration accumulated;
  bool isActive;
  ActivityType type;
  String? url;
  String? description;
  List<ActivityLog> logs;

  Activity({
    required this.id,
    required this.name,
    this.firstStartTime,
    this.startTime,
    this.endTime,
    this.accumulated = Duration.zero,
    this.isActive = false,
    this.type = ActivityType.work,
    this.url,
    this.description,
    List<ActivityLog>? logs,
  }) : logs = logs ?? <ActivityLog>[];

  Duration get duration {
    // If currently running, add elapsed since start to accumulated
    if (startTime != null) {
      return accumulated + DateTime.now().difference(startTime!);
    }
    // If not running, return accumulated (endTime may be present for display)
    return accumulated;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'firstStartTime': firstStartTime?.toIso8601String(),
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'accumulated': accumulated.inMilliseconds,
      'isActive': isActive ? 1 : 0,
      'type': type.index,
      'url': url,
      'description': description,
    };
  }

  static Activity fromJson(Map<String, dynamic> m, {List<ActivityLog>? logs}) {
    return Activity(
      id: m['id'].toString(),
      name: m['name'] ?? '',
      firstStartTime: m['firstStartTime'] != null ? DateTime.parse(m['firstStartTime']) : null,
      startTime: m['startTime'] != null ? DateTime.parse(m['startTime']) : null,
      endTime: m['endTime'] != null ? DateTime.parse(m['endTime']) : null,
      accumulated: Duration(milliseconds: (m['accumulated'] ?? 0)),
      isActive: (m['isActive'] ?? 0) == 1,
      type: ActivityType.values[(m['type'] ?? 0)],
      url: m['url'],
      description: m['description'],
      logs: logs,
    );
  }
}

class ActivityLog {
  DateTime timestamp;
  String text;
  ActivityLog({required this.timestamp, required this.text});

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'text': text,
      };

  static ActivityLog fromJson(Map<String, dynamic> m) => ActivityLog(
        timestamp: DateTime.parse(m['timestamp']),
        text: m['text'] ?? '',
      );
}

enum ActivityType {
  work,
  breakTime,
}
