import 'package:flutter/material.dart';
import 'models/recurring_schedule.dart';
import 'data/activity_db.dart';

class RecurringSchedulesPage extends StatefulWidget {
  const RecurringSchedulesPage({super.key});
  @override
  State<RecurringSchedulesPage> createState() => _RecurringSchedulesPageState();
}

class _RecurringSchedulesPageState extends State<RecurringSchedulesPage> {
  List<RecurringSchedule> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await ActivityDb().loadSchedules();
    setState(() => _items = items);
  }

  Future<void> _addOrEdit({RecurringSchedule? item}) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final urlCtrl = TextEditingController(text: item?.url ?? '');
    TimeOfDay time = TimeOfDay(hour: item?.hour ?? 9, minute: item?.minute ?? 0);
    RepeatType repeat = item?.repeatType ?? RepeatType.daily;
    final days = {...(item?.daysOfWeek ?? [])};
    int? dom = item?.dayOfMonth;
    // New flags per spec
  bool sendNotification = true; // default checked
  TimeOfDay notifyTime = TimeOfDay(hour: item?.notifyHour ?? (item?.hour ?? time.hour), minute: item?.notifyMinute ?? (item?.minute ?? time.minute));
    bool autoStart = true; // default checked

    // Initialize from existing item
    if (item != null) {
      sendNotification = (item.notifyHour != null && item.notifyMinute != null);
      autoStart = item.autoStart;
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text(item == null ? 'Tambah Jadwal' : 'Edit Jadwal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nama Kegiatan
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Nama Kegiatan')),
                SizedBox(height: 8),
                TextField(controller: urlCtrl, decoration: InputDecoration(labelText: 'Link (opsional)'), keyboardType: TextInputType.url),
                SizedBox(height: 12),
                // Jenis Jadwal
                Text('Jenis Jadwal'),
                DropdownButton<RepeatType>(
                  value: repeat,
                  onChanged: (v) => setLocalState(() => repeat = v!),
                  items: const [
                    DropdownMenuItem(value: RepeatType.daily, child: Text('Daily')),
                    DropdownMenuItem(value: RepeatType.weekly, child: Text('Weekly')),
                    DropdownMenuItem(value: RepeatType.monthly, child: Text('Monthly')),
                  ],
                ),
                SizedBox(height: 12),
                // Jadwal (dinamis)
                Text('Jadwal'),
                SizedBox(height: 6),
                Row(children: [
                  Text('Waktu: '),
                  TextButton(
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: time);
                      if (picked != null) setLocalState(() {
                        time = picked;
                        // If notifications are enabled, keep notification time synced to schedule time
                        if (sendNotification) {
                          notifyTime = TimeOfDay(hour: picked.hour, minute: picked.minute);
                        }
                      });
                    },
                    child: Text(time.format(context)),
                  ),
                ]),
                if (repeat == RepeatType.weekly) ...[
                  SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: List.generate(7, (i) {
                      final label = ['Sen','Sel','Rab','Kam','Jum','Sab','Min'][i];
                      final code = i + 1; // 1..7
                      final selected = days.contains(code);
                      return FilterChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (v) => setLocalState(() {
                          if (v) days.add(code); else days.remove(code);
                        }),
                      );
                    }),
                  ),
                ],
                if (repeat == RepeatType.monthly) ...[
                  SizedBox(height: 6),
                  TextField(
                    decoration: InputDecoration(labelText: 'Tanggal (1-31)'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null) setLocalState(() => dom = n);
                    },
                  ),
                ],
                SizedBox(height: 12),
                // Checkbox Kirim Notifikasi
                Row(children: [
                  Checkbox(
                    value: sendNotification,
                    onChanged: (v) => setLocalState(() {
                      sendNotification = v ?? true;
                      if (sendNotification) {
                        // default notif time follows current activity time
                        notifyTime = TimeOfDay(hour: time.hour, minute: time.minute);
                      }
                    }),
                  ),
                  Text('Kirim Notifikasi'),
                ]),
                if (sendNotification) ...[
                  SizedBox(height: 6),
                  Row(children: [
                    Text('Waktu Notifikasi: '),
                    TextButton(
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: notifyTime);
                        if (picked != null) setLocalState(() => notifyTime = picked);
                      },
                      child: Text(notifyTime.format(context)),
                    ),
                  ]),
                ],
                // Checkbox Auto Start
                Row(children: [
                  Checkbox(
                    value: autoStart,
                    onChanged: (v) => setLocalState(() => autoStart = v ?? true),
                  ),
                  Text('Auto Start'),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final id = item?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
                final daysList = days.isEmpty ? null : (() { final l = days.toList(); l.sort(); return l; })();
                // Map sendNotification to notifyHour/notifyMinute (use same as schedule time)
                final notifyHour = sendNotification ? notifyTime.hour : null;
                final notifyMinute = sendNotification ? notifyTime.minute : null;
                final sched = RecurringSchedule(
                  id: id,
                  name: nameCtrl.text.trim(),
                  hour: time.hour,
                  minute: time.minute,
                  notifyHour: notifyHour,
                  notifyMinute: notifyMinute,
                  repeatType: repeat,
                  daysOfWeek: daysList,
                  dayOfMonth: dom,
                  autoStart: autoStart,
                  durationMinutes: item?.durationMinutes, // keep existing if any; not part of this UI now
                  activityType: item?.activityType ?? 0,
                  url: urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
                  // Reset trigger so changes can take effect immediately
                  lastTriggeredDate: null,
                );
                await ActivityDb().upsertSchedule(sched);
                if (mounted) {
                  Navigator.pop(ctx);
                  _load();
                }
              },
              child: Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(String id) async {
    await ActivityDb().deleteSchedule(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Jadwal Berulang'),
        actions: [
          IconButton(onPressed: ()=> _addOrEdit(), icon: Icon(Icons.add)),
        ],
      ),
      body: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (ctx, i){
          final s = _items[i];
          final time = TimeOfDay(hour: s.hour, minute: s.minute);
          final notif = (s.notifyHour!=null && s.notifyMinute!=null) ? TimeOfDay(hour: s.notifyHour!, minute: s.notifyMinute!) : null;
          return ListTile(
            title: Text(s.name),
            subtitle: Text('${s.repeatType.name} · ${time.format(context)}' + (notif!=null ? ' · notif ${notif.format(context)}' : '')),
            trailing: Row(mainAxisSize: MainAxisSize.min, children:[
              IconButton(icon: Icon(Icons.edit), onPressed: ()=> _addOrEdit(item: s)),
              IconButton(icon: Icon(Icons.delete, color: Colors.redAccent), onPressed: ()=> _delete(s.id)),
            ]),
          );
        },
      ),
    );
  }
}
