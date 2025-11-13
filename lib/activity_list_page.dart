import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/services.dart';
import 'models/activity.dart';
import 'package:url_launcher/url_launcher.dart';
import 'data/activity_db.dart';
import 'recurring_schedules_page.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'models/recurring_schedule.dart';
import 'utils/desktop_popup.dart';

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
  final List<Activity> _activities = [];
  Timer? _uiTicker; // ticks every second to update on-screen timers
  StreamSubscription<void>? _svcSub;
  // hover flags removed (labels are clickable now)
  // Inline manual duration editor
  bool _editingManual = false;
  final TextEditingController _manualCtrl = TextEditingController();
  // Filter state: default to today; set to null for 'All'
  DateTime? _filterDate = DateTime.now();
  bool _filterWeek = false;
  DateTimeRange? _filterRange;
  final _notifManager = _NotificationOverlayManager();

  // no inline log controllers needed; logs are added via popup dialog
  // Filter state: default to today; set to null for 'All'
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
      if (mounted) setState(() {});
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
    _manualCtrl.dispose();
    _notifManager.dispose();
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
  DateTime? start = DateTime.now();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
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
              SizedBox(height: 8),
              // Start date/time picker (optional)
              Row(
                children: [
                  Expanded(
                    child: Text(start != null ? 'Start: ${_formatDateTime(start!)}' : 'Start: -',
                        style: TextStyle(fontSize: 14)),
                  ),
                  TextButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final pickedDate = await showDatePicker(
                        context: ctx,
                        initialDate: start ?? now,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate == null) return;
                      final pickedTime = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(start ?? now),
                      );
                      if (pickedTime == null) return;
                      setState(() {
                        start = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
                      });
                    },
                    child: Text('Pilih'),
                  ),
                  if (start != null)
                    IconButton(
                      icon: Icon(Icons.close, size: 18),
                      tooltip: 'Hapus Start',
                      onPressed: () => setState(() => start = null),
                    ),
                ],
              ),
              SizedBox(height: 4),
              Text('Catatan: Mengatur Start tidak otomatis menjalankan kegiatan.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
                  startTime: start,
                  endTime: null,
                  isActive: false, // do not auto-start even if startTime is set
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
        );
      }),
    );
  }

  List<int> _filteredIndexes() {
    if (_filterDate == null && !_filterWeek && _filterRange == null) {
      return List.generate(_activities.length, (i) => i);
    }
    final result = <int>[];
    bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    if (_filterRange != null) {
      final start = DateTime(_filterRange!.start.year, _filterRange!.start.month, _filterRange!.start.day);
      final end = DateTime(_filterRange!.end.year, _filterRange!.end.month, _filterRange!.end.day);
      for (var i = 0; i < _activities.length; i++) {
        final a = _activities[i];
        final basis = a.firstStartTime ?? a.startTime ?? a.endTime;
        if (basis != null) {
          final b = DateTime(basis.year, basis.month, basis.day);
          if (!b.isBefore(start) && !b.isAfter(end)) result.add(i);
        }
      }
      return result;
    }

    if (_filterWeek && _filterDate != null) {
      // compute start of week (Monday) and end of week
      final date = _filterDate!;
      final startOfWeek = DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      for (var i = 0; i < _activities.length; i++) {
        final a = _activities[i];
        final basis = a.firstStartTime ?? a.startTime ?? a.endTime;
        if (basis != null) {
          if (!basis.isBefore(startOfWeek) && !basis.isAfter(endOfWeek)) result.add(i);
        }
      }
      return result;
    }

    final target = DateTime(_filterDate!.year, _filterDate!.month, _filterDate!.day);
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
                  // Filter moved into the left panel header per UI update
                  
                  SizedBox(width: 8),
                  SizedBox(width: 8),
                ],
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Pengaturan',
                icon: Icon(Icons.settings, color: Colors.grey[700]),
                // offset the menu downward so it does not overlap the cog button
                offset: Offset(0, 48),
                onSelected: (value) async {
                  if (value == 'recurring') {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => RecurringSchedulesPage()));
                    await NotificationService().refreshNow();
                  } else if (value == 'toggle_theme') {
                    await ThemeService.toggle();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'recurring', child: Row(children: [Icon(Icons.event_repeat, size: 18), SizedBox(width: 8), Text('Jadwal Berulang')])),
                  PopupMenuItem(value: 'toggle_theme', child: Row(children: [Icon(Icons.brightness_6, size: 18), SizedBox(width: 8), Text('Ganti Tema')])),
                ],
              ),
            ],
          ),
          body: Row(
            children: [
              Container(
                width: 360,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left panel header (mock): larger title + filter moved here
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 12, 8),
                      child: Row(
                        children: [
                          // Left: title
                          Text(
                            'Kegiatan',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onPrimary),
                          ),

                          // Center: filter (centered using Expanded and Center)
                          Expanded(
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PopupMenuButton<String>(
                                    tooltip: 'Filter',
                                    // show menu below the icon/text so it doesn't overlap
                                    offset: Offset(0, 40),
                                    // make the whole area (icon + date) tappable to open menu
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.filter_list, color: Colors.grey[600]),
                                        const SizedBox(width: 6),
                                        Text(
                                          _filterLabel(),
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                    onSelected: (value) async {
                                      if (value == 'today') {
                                        setState(() {
                                          _filterWeek = false;
                                          _filterDate = DateTime.now();
                                        });
                                      } else if (value == 'week') {
                                        setState(() {
                                          _filterWeek = true;
                                          _filterDate = DateTime.now();
                                        });
                                      } else if (value == 'all') {
                                        setState(() {
                                          _filterWeek = false;
                                          _filterDate = null;
                                        });
                                      } else if (value == 'pick') {
                                        final initialStart = _filterRange?.start ?? _filterDate ?? DateTime.now();
                                        final initialEnd = _filterRange?.end ?? _filterDate ?? DateTime.now();
                                        final initialRange = DateTimeRange(start: initialStart, end: initialEnd);
                                        // use a custom popup dialog (smaller) that uses showDatePicker
                                        final picked = await _showDateRangeDialog(initialRange);
                                        if (picked != null) {
                                          setState(() {
                                            _filterWeek = false;
                                            _filterRange = picked;
                                            _filterDate = picked.start;
                                          });
                                        }
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      PopupMenuItem(value: 'today', child: Text('Hari ini')),
                                      PopupMenuItem(value: 'week', child: Text('Minggu ini')),
                                      PopupMenuItem(value: 'all', child: Text('Semua')),
                                      PopupMenuItem(value: 'pick', child: Text('Pilih range tanggal...')),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Right: add button styled like list action icons (compact)
                          IconButton(
                            iconSize: 18,
                            padding: const EdgeInsets.all(6),
                            splashRadius: 18,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            icon: Icon(Icons.add, color: Colors.grey[700]),
                            tooltip: 'Tambah',
                            onPressed: _addActivity,
                          ),
                          const SizedBox(width: 6),
                        ],
                      ),
                    ),
                    // Divider below header to separate from list
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Divider(color: Theme.of(context).dividerColor, height: 1),
                    ),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final filtered = _filteredIndexes();
                          return ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (ctx, i) => Divider(color: Theme.of(context).dividerColor, height: 1, indent: 8, endIndent: 8),
                            itemBuilder: (context, index) {
                    final globalIndex = filtered[index];
                    final activity = _activities[globalIndex];
                    final selected = _selectedIndex == globalIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIndex = globalIndex),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Stack(
                          children: [
                            // Card background
                              Container(
                                decoration: BoxDecoration(
                                  color: selected
                                      ? (Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFF2B2B2F)
                                          : Colors.white)
                                      : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: selected ? Border.all(color: Theme.of(context).dividerColor) : null,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          activity.name,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                                        ),
                                      ),
                                      // duration aligned to right-center area visually
                                      const SizedBox(width: 8),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    (activity.firstStartTime ?? activity.startTime) != null
                                        ? 'Mulai: ${_formatDateTime((activity.firstStartTime ?? activity.startTime)!)}'
                                        : 'Belum dimulai',
                                    style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      // left side remains text; put actions on the right
                                      const Spacer(),
                                      IconButton(
                                        onPressed: () => activity.isActive ? _pauseActivity(globalIndex) : _activateActivity(globalIndex),
                                        icon: Icon(activity.isActive ? Icons.pause : Icons.play_arrow, color: Colors.grey[700]),
                                        tooltip: activity.isActive ? 'Pause' : 'Start',
                                      ),
                                      IconButton(
                                        onPressed: activity.url != null ? () => _openUrl(activity.url!) : null,
                                        icon: Icon(Icons.link, color: activity.url != null ? Colors.grey[700] : Colors.grey[400]),
                                        tooltip: activity.url != null ? 'Open link' : 'No link',
                                      ),
                                      IconButton(
                                        onPressed: () => _editActivity(globalIndex),
                                        icon: Icon(Icons.edit, color: Colors.grey[700]),
                                        tooltip: 'Edit',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // small 'Aktif' label placed left of delete (top-right)
                            Positioned(
                              right: 56,
                              top: 6,
                              child: activity.isActive
                                  ? Chip(
                                      label: Text('Aktif', style: TextStyle(fontSize: 12)),
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            // delete button top-right
                            Positioned(
                              right: 6,
                              top: 6,
                              child: IconButton(
                                onPressed: () => _deleteActivity(globalIndex),
                                icon: Icon(Icons.close, color: Colors.grey[700]),
                                tooltip: 'Delete',
                                splashRadius: 20,
                              ),
                            ),

                            // duration below delete (right-center)
                            Positioned(
                              right: 10,
                              top: 44,
                              child: Text(
                                _formatDuration(activity.duration),
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey[800],
                                ),
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
                    ],
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
    const tabAccent = Color(0xFF6C4B8B);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Big centered title — tap the title to copy, with small action buttons on the right
          Row(
            children: [
              Expanded(
                child: Center(
                  child: Tooltip(
                    message: 'Click untuk menyalin',
                    preferBelow: true,
                    verticalOffset: 15,
                    child: GestureDetector(
                      onTap: () => _copyTitle(activity),
                      child: Text(
                        activity.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 40, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
              // action icons similar to left-panel: small and compact
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    iconSize: 18,
                    padding: const EdgeInsets.all(6),
                    splashRadius: 18,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(activity.isActive ? Icons.pause : Icons.play_arrow, color: Colors.grey[700], size: 18),
                    onPressed: () {
                      if (activity.isActive) {
                        _pauseActivity(index);
                      } else {
                        _activateActivity(index);
                      }
                    },
                  ),
                  IconButton(
                    iconSize: 18,
                    padding: const EdgeInsets.all(6),
                    splashRadius: 18,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(Icons.link, color: activity.url != null ? Colors.grey[700] : Colors.grey[400], size: 18),
                    onPressed: activity.url != null ? () => _openUrl(activity.url!) : null,
                    tooltip: activity.url != null ? 'Open link' : 'No link',
                  ),
                  IconButton(
                    iconSize: 18,
                    padding: const EdgeInsets.all(6),
                    splashRadius: 18,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(Icons.edit, color: Colors.grey[700], size: 18),
                    onPressed: () => _editActivity(index),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 10),

          // Start / End in same row (start left, end right) with hover-small copy buttons
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Tooltip(
                      message: 'Click untuk menyalin',
                      preferBelow: true,
                      verticalOffset: 10,
                      child: GestureDetector(
                        onTap: () => _copyStartDateTime(activity),
                        child: Text('Start : ${((activity.firstStartTime ?? activity.startTime) != null) ? _formatDateTime((activity.firstStartTime ?? activity.startTime)!) : '-'}'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: 'Click untuk menyalin',
                      preferBelow: true,
                      verticalOffset: 10,
                      child: GestureDetector(
                        onTap: () {
                          if (activity.endTime == null) {
                            _showSnack('Belum ada End untuk disalin');
                            return;
                          }
                          final text = _formatDateTime(activity.endTime!);
                          Clipboard.setData(ClipboardData(text: text));
                          _showSnack('End disalin: $text');
                        },
                        child: Text('End : ${activity.endTime != null ? _formatDateTime(activity.endTime!) : '-'}'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Durasi row (tap label to copy)
          Row(
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: Tooltip(
                  message: 'Click untuk menyalin',
                  preferBelow: true,
                  verticalOffset: 10,
                  waitDuration: Duration(milliseconds: 200),
                  showDuration: Duration(seconds: 2),
                  decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4)),
                  textStyle: TextStyle(color: Colors.white, fontSize: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          final s = _formatShortDuration(activity.duration);
                          Clipboard.setData(ClipboardData(text: s));
                          _showSnack('Durasi disalin: $s');
                        },
                        child: Text('Durasi : ${_formatDuration(activity.duration)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Manual Durasi: inline editable by double-click; keep label visible while editing
          Row(
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: Row(
                  children: [
                    // always show label
                    Text('Manual Durasi : ', style: Theme.of(context).textTheme.bodyMedium),
                    // value or editor
                    _editingManual
                        ? SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _manualCtrl,
                              decoration: InputDecoration(
                                hintText: 'e.g. 1h30m or 90m',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  splashRadius: 18,
                                  onPressed: () {
                                    setState(() => _editingManual = false);
                                  },
                                ),
                                filled: true,
                                fillColor: Theme.of(context).scaffoldBackgroundColor,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                              ),
                              onSubmitted: (v) {
                                final parsed = _parseDurationFromString(v);
                                setState(() {
                                  activity.manualDuration = parsed;
                                  _editingManual = false;
                                });
                                ActivityDb().insertOrUpdateActivity(activity);
                              },
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              final text = activity.manualDuration != null ? _formatShortDuration(activity.manualDuration!) : '';
                              if (text.isEmpty) {
                                _showSnack('Manual durasi kosong');
                                return;
                              }
                              Clipboard.setData(ClipboardData(text: text));
                              _showSnack('Manual durasi disalin: $text');
                            },
                            onDoubleTap: () {
                              setState(() {
                                _editingManual = true;
                                _manualCtrl.text = activity.manualDuration != null ? _formatShortDuration(activity.manualDuration!) : '';
                              });
                            },
                            child: Text(activity.manualDuration != null ? _formatShortDuration(activity.manualDuration!) : '-', style: Theme.of(context).textTheme.bodyMedium),
                          ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 12),

          // Logs tabbed area
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
                      child: TabBar(
                        labelColor: tabAccent,
                        unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        indicatorColor: tabAccent,
                        tabs: const [Tab(text: 'Log Kegiatan'), Tab(text: 'Description')],
                      ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Logs list with header actions
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                              child: Row(
                                children: [
                                  Text('Log Kegiatan', style: Theme.of(context).textTheme.titleMedium),
                                  const Spacer(),
                                  IconButton(
                                    // smaller, tighter icon like left-panel actions; remove tooltip to avoid large hover pop
                                    iconSize: 18,
                                    padding: const EdgeInsets.all(6),
                                    splashRadius: 18,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    icon: const Icon(Icons.copy, size: 18),
                                    onPressed: () => _copyTitle(activity),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    iconSize: 18,
                                    padding: const EdgeInsets.all(6),
                                    splashRadius: 18,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    onPressed: () => _showAddLogDialog(index),
                                    icon: const Icon(Icons.add, size: 18),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: activity.logs.isEmpty
                                  ? const Center(child: Text('Belum ada log untuk kegiatan ini'))
                                  : ListView.separated(
                                      itemCount: activity.logs.length,
                                      separatorBuilder: (_, __) => Divider(color: Theme.of(context).dividerColor),
                                      itemBuilder: (ctx, li) {
                                        final l = activity.logs[li];
                                        return ListTile(
                                          title: Text(l.text),
                                          subtitle: Text(_formatDateTime(l.timestamp)),
                                          trailing: IconButton(
                                            iconSize: 18,
                                            padding: const EdgeInsets.all(6),
                                            splashRadius: 18,
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                            onPressed: () => _deleteLog(index, li),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),

                        // Description tab
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: activity.description == null || activity.description!.isEmpty
                              ? const Text('Tidak ada deskripsi')
                              : SingleChildScrollView(child: Text(activity.description!)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // previously had a combined copy function; now split into smaller copy helpers

  void _copyTitle(Activity activity) {
    Clipboard.setData(ClipboardData(text: activity.name));
    _showSnack('Judul disalin');
  }

  String _formatShortDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }

  // Note: copy helpers for duration/logs removed; copying is done via label taps now.

  Duration? _parseDurationFromString(String input) {
    // very small parser: supports formats like '1h30m', '90m', '1:30:00', '3600s'
    final s = input.trim().toLowerCase();
    if (s.isEmpty) return null;
    try {
      if (s.contains(':')) {
        final parts = s.split(':').map((p) => int.tryParse(p) ?? 0).toList();
        if (parts.length == 3) return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
        if (parts.length == 2) return Duration(hours: 0, minutes: parts[0], seconds: parts[1]);
      }
      int hours = 0, minutes = 0, seconds = 0;
      final hMatch = RegExp(r'(\d+)h').firstMatch(s);
      final mMatch = RegExp(r'(\d+)m').firstMatch(s);
      final secMatch = RegExp(r'(\d+)s').firstMatch(s);
      if (hMatch != null) hours = int.parse(hMatch.group(1)!);
      if (mMatch != null) minutes = int.parse(mMatch.group(1)!);
      if (secMatch != null) seconds = int.parse(secMatch.group(1)!);
      if (hours == 0 && minutes == 0 && seconds == 0) {
        // maybe plain number means minutes
        final asNum = int.tryParse(s);
        if (asNum != null) minutes = asNum;
      }
      return Duration(hours: hours, minutes: minutes, seconds: seconds);
    } catch (e) {
      return null;
    }
  }

  void _copyStartDateTime(Activity activity) {
    final dt = activity.firstStartTime ?? activity.startTime;
    if (dt == null) {
      _showSnack('Belum ada Start untuk disalin');
      return;
    }
    final text = _formatDateTime(dt);
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('Start disalin: $text');
  }

  void _showSnack(String text) {
    // Delegate to overlay manager so notifications stack and appear immediately
    _notifManager.show(context, text, duration: const Duration(seconds: 2));
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

  String _formatDuration(Duration d) {
    final h = _two(d.inHours);
    final m = _two(d.inMinutes.remainder(60));
    final s = _two(d.inSeconds.remainder(60));
    return '$h:$m:$s';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';
  }

  String _formatDateOnly(DateTime dt) {
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
  }

  String _filterLabel() {
    if (_filterRange != null) {
      return '${_formatDateOnly(_filterRange!.start)} — ${_formatDateOnly(_filterRange!.end)}';
    }
    if (_filterWeek && _filterDate != null) {
      final date = _filterDate!;
      final startOfWeek = DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return '${_formatDateOnly(startOfWeek)} — ${_formatDateOnly(endOfWeek)}';
    }
    if (_filterDate != null) return _formatDateOnly(_filterDate!);
    return 'Semua';
  }

  Future<DateTimeRange?> _showDateRangeDialog(DateTimeRange initialRange) async {
    DateTime? start = initialRange.start;
    DateTime? end = initialRange.end;
    return showDialog<DateTimeRange>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (c, setState) {
          return AlertDialog(
            title: Text('Pilih rentang tanggal'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('Dari:'),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: start ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => start = picked);
                        },
                        child: Text(start != null ? _formatDateOnly(start!) : 'Pilih tanggal'),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text('Sampai:'),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: end ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => end = picked);
                        },
                        child: Text(end != null ? _formatDateOnly(end!) : 'Pilih tanggal'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal')),
              ElevatedButton(
                onPressed: () {
                  if (start != null && end != null) {
                    Navigator.pop(ctx, DateTimeRange(start: start!, end: end!));
                  } else {
                    Navigator.pop(ctx);
                  }
                },
                child: Text('Pilih'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _openUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      _showSnack('URL kosong');
      return;
    }

    // auto-prefix https if user omitted scheme
    var candidate = trimmed;
    if (!candidate.contains('://')) candidate = 'https://$candidate';

    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.isAbsolute || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      if (!mounted) return;
      _showSnack('URL tidak valid');
      return;
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (mounted) _showSnack('Tidak bisa membuka URL');
      }
    } catch (e) {
      if (mounted) _showSnack('Tidak bisa membuka URL');
    }
  }

}
// Lightweight overlay notification manager: center text, larger font, stack upward
class _NotificationOverlayManager {
  final List<String> _messages = [];
  final List<OverlayEntry> _entries = [];
  bool _disposed = false;

  void show(BuildContext context, String text, {Duration duration = const Duration(seconds: 2)}) {
    if (_disposed) return;
    final ctx = context;
    _messages.add(text);
    _rebuild(ctx);

    // Schedule removal after duration
    Future.delayed(duration, () {
      _removeMessage(ctx, text);
    });
  }

  void _rebuild(BuildContext context) {
    if (_disposed) return;
    // Prepare to remove existing entries and rebuild after the current frame.
    final removedEntries = List<OverlayEntry>.from(_entries);
    _entries.clear();

    const double notifHeight = 48.0;
    const double spacing = 6.0;
    const double baseOffset = 16.0; // distance from top

    // Prepare new entries and insert them after the current frame to avoid modifying the
    // render tree while the framework is performing layout. This prevents
    // re-entrant layout errors ('!_debugDoingThisLayout').
    final overlayEntries = <OverlayEntry>[];
    for (var i = 0; i < _messages.length; i++) {
      final topOffset = baseOffset + i * (notifHeight + spacing);
      final msg = _messages[i];
      final entry = OverlayEntry(builder: (ctx) {
        return Positioned(
          left: 24,
          right: 24,
          top: topOffset,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Container(
                height: notifHeight,
                constraints: const BoxConstraints(minWidth: 200, maxWidth: 800),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.black54, // semi-transparent background
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                ),
                alignment: Alignment.center,
                child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        );
      });
      overlayEntries.add(entry);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      final overlay = Overlay.of(context);

      // First remove previous entries from the overlay
      for (final e in removedEntries) {
        try {
          e.remove();
        } catch (_) {}
      }

      // Then insert new entries and track them
      for (final entry in overlayEntries) {
        _entries.add(entry);
        overlay.insert(entry);
      }
    });
  }

  void _removeMessage(BuildContext context, String text) {
    if (_disposed) return;
    final idx = _messages.indexOf(text);
    if (idx == -1) return;
    _messages.removeAt(idx);
    _rebuild(context);
  }

  void dispose() {
    _disposed = true;
    for (final e in _entries) {
      try {
        e.remove();
      } catch (_) {}
    }
    _entries.clear();
    _messages.clear();
  }
}

// Page helper methods moved into the State class below
