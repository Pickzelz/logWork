import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/services.dart';
import 'models/activity.dart';
import 'package:url_launcher/url_launcher.dart';
import 'data/activity_db.dart';
import 'recurring_schedules_page.dart';
import 'services/notification_service.dart';
import 'models/recurring_schedule.dart';
import 'utils/desktop_popup.dart';
import 'utils/windows_startup.dart';

class ActivityListPage extends StatefulWidget {
  const ActivityListPage({Key? key}) : super(key: key);

  @override
  State<ActivityListPage> createState() => _ActivityListPageState();
}

class AddIntent extends Intent {
  const AddIntent();
}

class ToggleIntent extends Intent {
  const ToggleIntent();
}

class DeleteIntent extends Intent {
  const DeleteIntent();
}

class _ActivityListPageState extends State<ActivityListPage> {
  int? _selectedIndex;
  // in-memory activities and simple id counter
  final List<Activity> _activities = [];
  Timer? _uiTicker; // ticks every second to update on-screen timers
  StreamSubscription<void>? _svcSub;
  // no inline log controllers needed; logs are added via popup dialog
  // Filter state: default to today; set to null for 'All'
  DateTime? _filterDate = DateTime.now();
  // Recurring schedules handled by NotificationService; no local state
  // Pending starts removed; handled globally if needed

  @override
  void initState() {
    super.initState();
  // Timer moved to global NotificationService
    _loadActivities();
    // Removed local schedules loader (NotificationService manages schedules)
    // Listen for background changes (e.g., schedule started) to refresh list
    _svcSub = NotificationService().onDataChanged.listen((_) async {
      if (!mounted) return;
      await _loadActivities();
      setState(() {});
    });
    // UI ticker: repaint durations every second
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadActivities() async {
    try {
      final loaded = await ActivityDb().loadAllActivities();
      setState(() {
        _activities.clear();
        _activities.addAll(loaded);
      });
    } catch (e) {
      // ignore DB errors for now
    }
  }

  // Timer moved to NotificationService; keep only UI updates as needed

  @override
  void dispose() {
    _uiTicker?.cancel();
    _svcSub?.cancel();
    super.dispose();
  }

  // Auto-break logic removed (was page-local); consider re-implementing globally if needed

  // Recurring schedule checks are handled by NotificationService globally

  

  void _startScheduledActivity(RecurringSchedule s) async {
    // Pause any currently active activity and persist the state
    for (var i = 0; i < _activities.length; i++) {
      final other = _activities[i];
      if (other.isActive) {
        other.accumulated = other.duration;
        other.isActive = false;
        other.startTime = null;
        other.endTime = DateTime.now();
        await ActivityDb().insertOrUpdateActivity(other);
      }
    }

    final now = DateTime.now();
    final activity = Activity(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: s.name,
      startTime: now,
      endTime: null,
      isActive: true,
      type: s.activityType == 1 ? ActivityType.breakTime : ActivityType.work,
      url: null,
    );
    // Preserve the very first start time
    activity.firstStartTime = now;

    setState(() {
      _activities.add(activity);
      _selectedIndex = _activities.length - 1;
    });
    await ActivityDb().insertOrUpdateActivity(activity);
  }

  void _addActivity() {
    String name = '';
    String? url;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tambah Kegiatan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(labelText: 'Nama kegiatan'),
              onChanged: (v) => name = v,
            ),
            SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(labelText: 'Link (opsional)'),
              onChanged: (v) => url = v.trim().isEmpty ? null : v.trim(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (name.trim().isEmpty) return;
              final a = Activity(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                name: name.trim(),
                startTime: null,
                endTime: null,
                isActive: false,
                type: ActivityType.work,
                url: url,
              );
              setState(() {
                _activities.add(a);
                _selectedIndex = _activities.length - 1;
              });
              await ActivityDb().insertOrUpdateActivity(a);
              if (mounted) Navigator.pop(ctx);
            },
            child: Text('Tambah'),
          ),
        ],
      ),
    );
  }

  List<int> _filteredIndexes() {
    if (_filterDate == null) {
      return List.generate(_activities.length, (i) => i);
    }
    bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    final target = DateTime(_filterDate!.year, _filterDate!.month, _filterDate!.day);
    final result = <int>[];
    for (var i = 0; i < _activities.length; i++) {
      final a = _activities[i];
      final basis = a.firstStartTime ?? a.startTime ?? a.endTime;
      if (basis != null && sameDay(basis, target)) result.add(i);
    }
    return result;
  }

  void _activateActivity(int index) {
    setState(() {
      for (var i = 0; i < _activities.length; i++) {
        if (i == index) {
          final a = _activities[i];
          a.isActive = true;
          // if not running, start now
          if (a.startTime == null) {
            final now = DateTime.now();
            a.startTime = now;
            // keep the very first start time forever
            a.firstStartTime ??= now;
          }
        } else {
          final other = _activities[i];
          if (other.isActive) {
            // pause other activities and accumulate
            other.accumulated = other.duration;
            other.isActive = false;
            other.startTime = null;
            other.endTime = DateTime.now();
            ActivityDb().insertOrUpdateActivity(other);
          }
        }
      }
      ActivityDb().insertOrUpdateActivity(_activities[index]);
    });
  }

  // stopActivity removed (use _pauseActivity for pause behavior)

  void _pauseActivity(int index) {
    setState(() {
      final a = _activities[index];
      if (a.isActive) {
        // accumulate elapsed time and stop
        a.accumulated = a.duration;
        a.isActive = false;
        a.endTime = DateTime.now();
        a.startTime = null;
        ActivityDb().insertOrUpdateActivity(a);
      }
    });
  }

  void _deleteActivity(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Konfirmasi'),
        content: Text('Hapus kegiatan ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final idToDelete = _activities[index].id;
              setState(() {
                _activities.removeAt(index);
                if (_selectedIndex != null) _selectedIndex = null;
              });
              ActivityDb().deleteActivity(idToDelete);
              Navigator.pop(ctx);
            },
            child: Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // _addLog removed; use popup dialog (_showAddLogDialog) instead

  void _deleteLog(int activityIndex, int logIndex) {
    setState(() {
      _activities[activityIndex].logs.removeAt(logIndex);
    });
    ActivityDb().insertOrUpdateActivity(_activities[activityIndex]);
  }

  void _editActivity(int index) {
    final a = _activities[index];
    String name = a.name;
    String? url = a.url;
    String? description = a.description;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Kegiatan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: name),
                decoration: InputDecoration(labelText: 'Nama'),
                onChanged: (v) => name = v,
              ),
              SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: url),
                decoration: InputDecoration(labelText: 'Link (opsional)'),
                onChanged: (v) => url = v.trim().isEmpty ? null : v.trim(),
              ),
              SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: description),
                decoration: InputDecoration(labelText: 'Deskripsi (opsional)'),
                maxLines: 4,
                onChanged: (v) => description = v.trim().isEmpty ? null : v.trim(),
              ),
              // Untuk demo cepat, hanya allow edit name. Waktu manual bisa ditambahkan nanti.
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Batal')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  a.name = name.trim();
                  a.url = url;
                  a.description = description;
                });
                  ActivityDb().insertOrUpdateActivity(a);
                  Navigator.pop(context);
              },
              child: Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Shortcuts: Ctrl+N add, Space toggle active on selected, Delete remove selected
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const AddIntent(),
        LogicalKeySet(LogicalKeyboardKey.space): const ToggleIntent(),
        LogicalKeySet(LogicalKeyboardKey.delete): const DeleteIntent(),
      },
        child: Actions(
        actions: <Type, Action<Intent>>{
          AddIntent: CallbackAction<AddIntent>(onInvoke: (_) => _addActivity()),
          ToggleIntent: CallbackAction<ToggleIntent>(onInvoke: (_) {
            // If an EditableText (TextField) has focus, ignore the global space shortcut
            final focus = FocusManager.instance.primaryFocus;
            if (focus?.context?.widget is EditableText) return null;
            if (_selectedIndex != null) _activateActivity(_selectedIndex!);
            return null;
          }),
          DeleteIntent: CallbackAction<DeleteIntent>(onInvoke: (_) {
            // If an EditableText (TextField) has focus, ignore the delete shortcut
            final focus = FocusManager.instance.primaryFocus;
            if (focus?.context?.widget is EditableText) return null;
            if (_selectedIndex != null) _deleteActivity(_selectedIndex!);
            return null;
          }),
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            titleSpacing: 12,
            title: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Daftar Kegiatan', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(width: 12),
                  if (!kReleaseMode)
                    IconButton(
                      icon: Icon(Icons.bug_report),
                      tooltip: 'Test Notifikasi',
                      onPressed: _sendTestNotification,
                    ),
                  if (!kReleaseMode)
                    IconButton(
                      icon: Icon(Icons.notifications_active),
                      tooltip: 'Cek Jadwal Sekarang',
                      onPressed: () => NotificationService().refreshNow(),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'Filter',
                    icon: Icon(Icons.filter_list),
                    onSelected: (value) async {
                      if (value == 'today') {
                        setState(() => _filterDate = DateTime.now());
                      } else if (value == 'all') {
                        setState(() => _filterDate = null);
                      } else if (value == 'pick') {
                        final initial = _filterDate ?? DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _filterDate = picked);
                        }
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(value: 'today', child: Text('Hari ini')),
                      PopupMenuItem(value: 'all', child: Text('Semua')),
                      PopupMenuItem(value: 'pick', child: Text('Pilih tanggal...')),
                    ],
                  ),
                  SizedBox(width: 6),
                  Text(
                    _filterDate == null
                        ? 'Semua'
                        : '${_filterDate!.year}-${_two(_filterDate!.month)}-${_two(_filterDate!.day)}',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _addActivity,
                    icon: Icon(Icons.add, color: Colors.white),
                    label: Text('Tambah', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Color(0xFF2D2D2D),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.event_repeat),
                    tooltip: 'Jadwal Berulang',
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => RecurringSchedulesPage()));
                      await NotificationService().refreshNow();
                    },
                  ),
                  SizedBox(width: 8),
                  FutureBuilder<bool>(
                    future: WindowsStartup.isEnabled(),
                    builder: (context, snapshot) {
                      final enabled = snapshot.data == true;
                      return Tooltip(
                        message: enabled ? 'Nonaktifkan Startup' : 'Aktifkan Startup',
                        child: IconButton(
                          icon: Icon(enabled ? Icons.toggle_on : Icons.toggle_off),
                          onPressed: () async {
                            if (enabled) {
                              await WindowsStartup.disable();
                            } else {
                              await WindowsStartup.enable();
                            }
                            if (mounted) setState(() {});
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: const [],
          ),
          body: Row(
            children: [
              Container(
                width: 360,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Builder(
                  builder: (context) {
                    final filtered = _filteredIndexes();
                    return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final globalIndex = filtered[index];
                    final activity = _activities[globalIndex];
                    final selected = _selectedIndex == globalIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIndex = globalIndex),
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? Theme.of(context).colorScheme.surfaceContainerHighest : Theme.of(context).colorScheme.surface,
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          activity.name,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                            // live timer removed from row to avoid overlap with delete button; rendered as Positioned below
                                    ],
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    (activity.firstStartTime ?? activity.startTime) != null
                                        ? 'Mulai: ${_formatDateTime((activity.firstStartTime ?? activity.startTime)!)}'
                                        : 'Belum dimulai',
                                    style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color),
                                  ),
                                  SizedBox(height: 8),
                                  // action buttons inside the card (Start, Pause, Edit)
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () => _activateActivity(globalIndex),
                                        icon: Icon(Icons.play_arrow, color: Colors.white),
                                        tooltip: 'Start',
                                      ),
                                      if (activity.url != null)
                                        IconButton(
                                          onPressed: () => _openUrl(activity.url!),
                                          icon: Icon(Icons.link, color: Colors.lightBlueAccent),
                                          tooltip: 'Open link',
                                        ),
                                      IconButton(
                                        onPressed: () => _pauseActivity(globalIndex),
                                        icon: Icon(Icons.pause, color: Colors.white),
                                        tooltip: 'Pause',
                                      ),
                                      IconButton(
                                        onPressed: () => _editActivity(globalIndex),
                                        icon: Icon(Icons.edit, color: Colors.white),
                                        tooltip: 'Edit',
                                      ),
                                      Spacer(),
                                      activity.isActive ? Chip(label: Text('Aktif')) : SizedBox.shrink(),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // timer positioned near top-right (left of delete)
                            Positioned(
                              right: 44,
                              top: 8,
                              child: Text(
                                _formatDuration(activity.duration),
                                style: TextStyle(fontFamily: 'monospace', fontSize: 14),
                              ),
                            ),
                            // Delete button positioned top-right
                            Positioned(
                              right: 4,
                              top: 4,
                              child: IconButton(
                                onPressed: () => _deleteActivity(globalIndex),
                                icon: Icon(Icons.close, color: Colors.white),
                                tooltip: 'Delete',
                                splashRadius: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
                  },
                ),
              ),
              Expanded(
                child: _selectedIndex == null
                    ? Center(child: Text('Pilih kegiatan di kiri untuk melihat detail'))
                    : _buildDetailPanel(_activities[_selectedIndex!], _selectedIndex!),
              ),
            ],
          ),
          
        ),
      ),
    );
  }

  void _sendTestNotification() async {
    final add = await DesktopPopup.confirmCustomButtons(
      'Pengingat Jadwal',
      'Sudah waktunya: Notifikasi Testing',
      positive: 'Tambah Kegiatan',
      negative: 'Tutup Tanpa Tambah Kegiatan',
      context: context,
    );
    if (add) {
      final now = DateTime.now();
      final mock = RecurringSchedule(
        id: 'test-${now.microsecondsSinceEpoch}',
        name: 'Testing',
        hour: now.hour,
        minute: now.minute,
        repeatType: RepeatType.daily,
        autoStart: true,
        activityType: 0,
      );
      _startScheduledActivity(mock);
    }
  }

  Widget _buildDetailPanel(Activity activity, int index) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: Text(activity.name, style: Theme.of(context).textTheme.headlineSmall)),
              SizedBox(width: 8),
              IconButton(
                tooltip: 'Copy Judul',
                icon: Icon(Icons.copy),
                onPressed: () => _copyTitle(activity),
                splashRadius: 18,
              ),
              Spacer(),
            ],
          ),
          SizedBox(height: 8),
          Text('Type: ${activity.type == ActivityType.work ? 'Work' : 'Break'}'),
          if (activity.description != null) ...[
            SizedBox(height: 8),
            Text(activity.description!),
          ],
          SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: Text(
                  'Start: ${(activity.firstStartTime ?? activity.startTime) != null ? _formatDateTime((activity.firstStartTime ?? activity.startTime)!) : '-'}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                tooltip: 'Copy Start',
                icon: Icon(Icons.copy),
                onPressed: () => _copyStartDateTime(activity),
                splashRadius: 18,
              ),
              IconButton(
                tooltip: 'Ubah Start',
                icon: Icon(Icons.edit_calendar),
                onPressed: () => _editStartTime(index),
                splashRadius: 18,
              ),
            ],
          ),
          Text('End: ${activity.endTime != null ? _formatDateTime(activity.endTime!) : '-'}'),
          SizedBox(height: 12),
          Row(
            children: [
              Text('Durasi: ${activity.duration.inMinutes} menit'),
              SizedBox(width: 8),
              IconButton(
                tooltip: 'Copy Durasi',
                icon: Icon(Icons.copy),
                onPressed: () => _copyShortDuration(activity),
                splashRadius: 18,
              ),
            ],
          ),
          SizedBox(height: 16),
          // Logs section
          Row(
            children: [
              Text('Log Kegiatan', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(width: 8),
              IconButton(
                tooltip: 'Copy Logs',
                icon: Icon(Icons.note),
                onPressed: () => _copyLogs(activity),
              ),
              SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showAddLogDialog(index),
                icon: Icon(Icons.add_comment),
                label: Text('Tambah log'),
              ),
            ],
          ),
          SizedBox(height: 8),
          Expanded(
            child: activity.logs.isEmpty
                ? Text('Belum ada log untuk kegiatan ini')
                : ListView.builder(
                    itemCount: activity.logs.length,
                    itemBuilder: (ctx, li) {
                      final l = activity.logs[li];
                      return ListTile(
                        dense: true,
                        title: Text(l.text),
                        subtitle: Text(_formatDateTime(l.timestamp)),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _deleteLog(index, li),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  // previously had a combined copy function; now split into smaller copy helpers

  void _copyTitle(Activity activity) {
    Clipboard.setData(ClipboardData(text: activity.name));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Judul disalin')));
  }

  String _formatShortDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }

  void _copyShortDuration(Activity activity) {
    final s = _formatShortDuration(activity.duration);
    Clipboard.setData(ClipboardData(text: s));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Durasi disalin: $s')));
  }

  void _copyLogs(Activity activity) {
    if (activity.logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tidak ada log untuk disalin')));
      return;
    }
    final buffer = StringBuffer();
    for (var l in activity.logs) {
      final lines = l.text.split(RegExp(r'\r?\n'));
      for (var line in lines) {
        final t = line.trim();
        if (t.isNotEmpty) buffer.writeln('- $t');
      }
    }
    final text = buffer.toString().trim();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Log disalin ke clipboard')));
  }

  void _copyStartDateTime(Activity activity) {
    final dt = activity.firstStartTime ?? activity.startTime;
    if (dt == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Belum ada Start untuk disalin')));
      return;
    }
    final text = _formatDateTime(dt);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Start disalin: $text')));
  }

  void _showAddLogDialog(int index) {
    String text = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tambah Log'),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(hintText: 'Tulis log singkat Anda di sini'),
          maxLines: 4,
          onChanged: (v) => text = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final trimmed = text.trim();
              if (trimmed.isNotEmpty) {
                setState(() {
                  _activities[index].logs.add(ActivityLog(timestamp: DateTime.now(), text: trimmed));
                });
                ActivityDb().insertOrUpdateActivity(_activities[index]);
              }
              Navigator.pop(ctx);
            },
            child: Text('Tambah'),
          ),
        ],
      ),
    );
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  Future<void> _editStartTime(int index) async {
    final a = _activities[index];
    final initial = a.firstStartTime ?? a.startTime ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (pickedTime == null) return;
    final newStart = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (a.isActive && newStart.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Start tidak boleh melebihi waktu sekarang')));
      return;
    }

    setState(() {
      if (a.isActive) {
        // Adjust current running start to the chosen time
        a.startTime = newStart;
      } else {
        // If not active, adjust accumulated based on new start and current end (if any)
        final end = a.endTime;
        if (end != null) {
          a.accumulated = end.isAfter(newStart)
              ? end.difference(newStart)
              : Duration.zero;
        }
      }
      // Update the displayed immutable start as requested
      a.firstStartTime = newStart;
    });
    await ActivityDb().insertOrUpdateActivity(a);
  }

  // Removed edit end time per request

  String _formatDuration(Duration d) {
    final h = _two(d.inHours);
    final m = _two(d.inMinutes.remainder(60));
    final s = _two(d.inSeconds.remainder(60));
    return '$h:$m:$s';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';
  }

  Future<void> _openUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('URL kosong')));
      return;
    }

    // auto-prefix https if user omitted scheme
    var candidate = trimmed;
    if (!candidate.contains('://')) candidate = 'https://$candidate';

    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.isAbsolute || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('URL tidak valid')));
      return;
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tidak bisa membuka URL')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tidak bisa membuka URL')));
    }
  }
}
