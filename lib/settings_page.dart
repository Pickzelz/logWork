import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  TimeOfDay _breakStart = TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _breakEnd = TimeOfDay(hour: 13, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final startH = prefs.getInt('breakStartH') ?? 12;
    final startM = prefs.getInt('breakStartM') ?? 0;
    final endH = prefs.getInt('breakEndH') ?? 13;
    final endM = prefs.getInt('breakEndM') ?? 0;
    setState(() {
      _breakStart = TimeOfDay(hour: startH, minute: startM);
      _breakEnd = TimeOfDay(hour: endH, minute: endM);
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('breakStartH', _breakStart.hour);
    await prefs.setInt('breakStartM', _breakStart.minute);
    await prefs.setInt('breakEndH', _breakEnd.hour);
    await prefs.setInt('breakEndM', _breakEnd.minute);
  }

  Future<void> _pickStart() async {
    final res = await showTimePicker(context: context, initialTime: _breakStart);
    if (res != null) {
      setState(() => _breakStart = res);
      await _save();
    }
  }

  Future<void> _pickEnd() async {
    final res = await showTimePicker(context: context, initialTime: _breakEnd);
    if (res != null) {
      setState(() => _breakEnd = res);
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              title: Text('Break Start'),
              subtitle: Text(_breakStart.format(context)),
              trailing: TextButton(onPressed: _pickStart, child: Text('Ubah')),
            ),
            ListTile(
              title: Text('Break End'),
              subtitle: Text(_breakEnd.format(context)),
              trailing: TextButton(onPressed: _pickEnd, child: Text('Ubah')),
            ),
          ],
        ),
      ),
    );
  }
}
