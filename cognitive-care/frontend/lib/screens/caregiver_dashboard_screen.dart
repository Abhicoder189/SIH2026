
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CaregiverDashboardScreen extends StatefulWidget {
  final String token;

  const CaregiverDashboardScreen({
    super.key,
    required this.token,
  });

  @override
  State<CaregiverDashboardScreen> createState() =>
      _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState
    extends State<CaregiverDashboardScreen> {
  List<dynamic> patients = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result =
          await ApiService.caregiverPatients(widget.token);

      if (!mounted) return;

      setState(() {
        patients = result;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
      });
    } finally {
      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _loadAlerts(String patientId) async {
    try {
      return await ApiService.getAlerts(
        widget.token,
        patientId,
        caregiver: true,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caregiver Dashboard'),
        actions: [
          IconButton(
            onPressed: _loadPatients,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    if (patients.isEmpty) {
      return const Center(
        child: Text(
          'No linked patients yet.',
          style: TextStyle(fontSize: 20),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: patients.length,
      itemBuilder: (context, index) {
        final patient =
            Map<String, dynamic>.from(patients[index]);

        final patientId =
            (patient['patient_id'] ?? patient['id']).toString();

        final patientName =
            patient['name']?.toString() ?? 'Patient';

        final language =
            patient['language']?.toString() ??
                'Language not set';

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          child: ExpansionTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text(
              patientName,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(language),
            children: [
              FutureBuilder<Map<String, dynamic>?>(
                future: _loadAlerts(patientId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final data = snapshot.data;

                  final alerts =
                      (data?['alerts'] as List?) ?? [];

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alerts: ${alerts.length}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (alerts.isEmpty)
                          const Text(
                            'No current alerts.',
                            style: TextStyle(fontSize: 16),
                          ),
                        ...alerts.map(
                          (alert) {
                            final item =
                                Map<String, dynamic>.from(alert);

                            final severity =
                                item['severity']?.toString();

                            final icon = severity == 'high'
                                ? Icons.warning
                                : Icons.info_outline;

                            return ListTile(
                              contentPadding:
                                  EdgeInsets.zero,
                              leading: Icon(icon),
                              title: Text(
                                item['title']?.toString() ??
                                    'Attention',
                              ),
                              subtitle: Text(
                                item['message']?.toString() ??
                                    '',
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
