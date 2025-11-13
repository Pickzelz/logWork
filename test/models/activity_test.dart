import 'package:flutter_test/flutter_test.dart';
import 'package:log_work/models/activity.dart';

void main() {
  test('duration does not count elapsed when not active', () {
    final now = DateTime.now();
    final a = Activity(
      id: 't1',
      name: 'Test',
      accumulated: Duration.zero,
      startTime: now.subtract(Duration(minutes: 5)),
      isActive: false,
    );

    // When not active, duration should equal accumulated only
    expect(a.duration, Duration.zero);
  });

  test('duration counts elapsed when active', () {
    final now = DateTime.now();
    final a = Activity(
      id: 't2',
      name: 'Test2',
      accumulated: Duration.zero,
      startTime: now.subtract(Duration(seconds: 70)),
      isActive: true,
    );

    // Should be at least 70 seconds
    expect(a.duration.inSeconds >= 70, isTrue);
  });

  test('toJson/fromJson preserves fields', () {
    final a = Activity(
      id: 't3',
      name: 'Roundtrip',
      firstStartTime: DateTime.parse('2025-01-02T03:04:05Z'),
      startTime: DateTime.parse('2025-01-02T03:04:05Z'),
      endTime: DateTime.parse('2025-01-02T04:04:05Z'),
      accumulated: Duration(minutes: 10),
      manualDuration: Duration(minutes: 5),
      isActive: true,
      type: ActivityType.breakTime,
      url: 'https://example.test',
      description: 'desc',
    );

    final json = a.toJson();
    final restored = Activity.fromJson(json);

    expect(restored.id, a.id);
    expect(restored.name, a.name);
    expect(restored.isActive, a.isActive);
    expect(restored.type, a.type);
    expect(restored.url, a.url);
    expect(restored.description, a.description);
    expect(restored.manualDuration, isNotNull);
    expect(restored.manualDuration?.inMinutes, 5);
  });
}
