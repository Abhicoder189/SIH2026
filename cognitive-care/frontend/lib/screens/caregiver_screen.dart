import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CaregiverScreen extends StatefulWidget {
  const CaregiverScreen({super.key, required this.token});
  final String token;
  @override
  State<CaregiverScreen> createState() => _CaregiverScreenState();
}

class _CaregiverScreenState extends State<CaregiverScreen> {
  List<dynamic>? patients;
  String? error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final value = await ApiService.caregiverPatients(widget.token); if (mounted) setState(() => patients = value); } catch (e) { if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', '')); } }
  @override
  Widget build(BuildContext context) {
    if (error != null) return Center(child: Text(error!, textAlign: TextAlign.center));
    if (patients == null) return const Center(child: CircularProgressIndicator());
    if (patients!.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No linked patients yet. A patient must accept your caregiver-link request before their activity becomes visible.', textAlign: TextAlign.center, style: TextStyle(fontSize: 20))));
    return ListView(padding: const EdgeInsets.all(18), children: [const Text('Linked patients', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), const SizedBox(height: 14), ...patients!.map((item) { final patient = Map<String, dynamic>.from(item['patient'] as Map); final analytics = Map<String, dynamic>.from(item['analytics'] as Map); return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(patient['name'] as String, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Text('Recent activity: ${analytics['completed_sessions']} sessions', style: const TextStyle(fontSize: 18)), Text('Average accuracy: ${analytics['average_accuracy']}%', style: const TextStyle(fontSize: 18)), Text('Engagement trend: ${analytics['trend']}', style: const TextStyle(fontSize: 18)), const SizedBox(height: 8), const Text('Game-performance information only — not a diagnosis.', style: TextStyle(fontSize: 14))]))); })]);
  }
}
