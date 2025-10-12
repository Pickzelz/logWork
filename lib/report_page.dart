import 'package:flutter/material.dart';
import 'models/activity.dart';

class ReportPage extends StatelessWidget {
  final List<Activity> activities;

  const ReportPage({Key? key, required this.activities}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    // Kelompokkan per nama activity dan hitung total durasi hari ini
    final Map<String, Duration> totals = {};
    for (var a in activities) {
      // hanya ambil yang mulai hari ini
      if (a.startTime == null) continue;
      if (a.startTime!.year == today.year && a.startTime!.month == today.month && a.startTime!.day == today.day) {
        totals[a.name] = (totals[a.name] ?? Duration.zero) + a.duration;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('Laporan Harian')),
      body: ListView(
        children: totals.entries.map((e) {
          final minutes = e.value.inMinutes;
          return ListTile(
            title: Text(e.key),
            trailing: Text('${minutes} menit'),
          );
        }).toList(),
      ),
    );
  }
}
