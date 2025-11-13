import 'package:flutter_test/flutter_test.dart';
import 'package:log_work/models/recurring_schedule.dart';

void main() {
  test('daily isDue always true', () {
    final s = RecurringSchedule(id: 'r1', name: 'd', hour: 0, minute: 0, repeatType: RepeatType.daily);
    expect(s.isDue(DateTime.now()), isTrue);
  });

  test('weekly isDue respects daysOfWeek', () {
    final now = DateTime(2025, 1, 6); // Monday
    final s = RecurringSchedule(id: 'r2', name: 'w', hour: 0, minute: 0, repeatType: RepeatType.weekly, daysOfWeek: [1, 3]);
    expect(s.isDue(now), isTrue);
    final tuesday = DateTime(2025, 1, 7);
    expect(s.isDue(tuesday), isFalse);
  });

  test('monthly isDue respects dayOfMonth', () {
    final now = DateTime(2025, 2, 14);
    final s = RecurringSchedule(id: 'r3', name: 'm', hour: 0, minute: 0, repeatType: RepeatType.monthly, dayOfMonth: 14);
    expect(s.isDue(now), isTrue);
    final other = DateTime(2025, 2, 15);
    expect(s.isDue(other), isFalse);
  });

  test('timeMatches matches exact hour and minute', () {
    final now = DateTime(2025, 3, 4, 9, 30);
    final s = RecurringSchedule(id: 'r4', name: 't', hour: 9, minute: 30);
    expect(s.timeMatches(now), isTrue);
    final later = DateTime(2025, 3, 4, 9, 31);
    expect(s.timeMatches(later), isFalse);
  });

  test('notifyTimeMatches respects grace window', () {
    final target = DateTime(2025, 3, 4, 8, 0);
    final s = RecurringSchedule(id: 'r5', name: 'n', hour: 8, minute: 0, notifyHour: 8, notifyMinute: 0);
    // exact
    expect(s.notifyTimeMatches(target), isTrue);
    // +2 minutes still true
    expect(s.notifyTimeMatches(target.add(Duration(minutes: 2))), isTrue);
    // +3 minutes false
    expect(s.notifyTimeMatches(target.add(Duration(minutes: 3))), isFalse);
    // if notify not set, false
    final s2 = RecurringSchedule(id: 'r6', name: 'n2', hour: 8, minute: 0);
    expect(s2.notifyTimeMatches(target), isFalse);
  });
}
