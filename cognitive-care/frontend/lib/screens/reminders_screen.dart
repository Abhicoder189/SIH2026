import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key, required this.token, required this.patientId});
  final String token;
  final String patientId;
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<dynamic>? reminders;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { final result = await ApiService.reminders(widget.token); if (mounted) setState(() => reminders = result); }
  Future<void> _add() async {
    final title = TextEditingController();
    final created = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('New reminder'), content: TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'What should we remind you about?')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')), TextButton(onPressed: () => Navigator.pop(context, title.text.trim().isNotEmpty), child: const Text('SAVE'))]));
    if (created == true) { await ApiService.createReminder(widget.token, {'patient_id': widget.patientId, 'title': title.text.trim(), 'message': '', 'type': 'activity', 'scheduled_time': DateTime.now().add(const Duration(hours: 1)).toUtc().toIso8601String(), 'repeat': 'daily'}); await _load(); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Reminders')), floatingActionButton: FloatingActionButton.extended(onPressed: _add, label: const Text('ADD'), icon: const Icon(Icons.add)), body: reminders == null ? const Center(child: CircularProgressIndicator()) : reminders!.isEmpty ? const Center(child: Text('No reminders yet.', style: TextStyle(fontSize: 22))) : ListView(padding: const EdgeInsets.all(16), children: reminders!.map((item) { final reminder = Map<String, dynamic>.from(item as Map); final done = reminder['completed'] == true; return Card(child: ListTile(contentPadding: const EdgeInsets.all(14), leading: Icon(done ? Icons.check_circle : Icons.notifications_active, size: 34), title: Text(reminder['title'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), subtitle: Text(done ? 'Completed' : 'Scheduled: ${reminder['scheduled_time']}', style: const TextStyle(fontSize: 16)), trailing: done ? null : TextButton(onPressed: () async { await ApiService.updateReminder(widget.token, reminder['id'] as String, {'completed': true}); await _load(); }, child: const Text('DONE', style: TextStyle(fontSize: 17))))); }).toList()));
}
