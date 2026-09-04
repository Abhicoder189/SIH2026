import 'package:flutter/material.dart';

import '../services/api_service.dart';

class NotificationFeedScreen extends StatefulWidget {
  final String token;
  final String patientId;

  const NotificationFeedScreen({
    super.key,
    required this.token,
    required this.patientId,
  });

  @override
  State<NotificationFeedScreen> createState() =>
      _NotificationFeedScreenState();
}

class _NotificationFeedScreenState
    extends State<NotificationFeedScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final result = await ApiService.getNotificationFeed(
        widget.token,
        widget.patientId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        data = result;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        error = e.toString();
      });
    }

    if (!mounted) {
      return;
    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = (data?['items'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(items),
    );
  }

  Widget _buildBody(List items) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 60,
              ),
              const SizedBox(height: 16),
              Text(
                error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: const Text('TRY AGAIN'),
              ),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No new notifications.',
          style: TextStyle(
            fontSize: 20,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      separatorBuilder: (context, index) {
        return const SizedBox(height: 10);
      },
      itemBuilder: (context, index) {
        final item = Map<String, dynamic>.from(
          items[index],
        );

        final title =
            item['title']?.toString() ?? 'Reminder';

        final message =
            item['message']?.toString() ?? '';

        final type =
            item['type']?.toString() ?? '';

        return Card(
          child: ListTile(
            isThreeLine: true,
            contentPadding: const EdgeInsets.all(16),
            leading: const Icon(
              Icons.notifications_active,
              size: 32,
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ),
            trailing: type.isEmpty
                ? null
                : Text(
                    type,
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
          ),
        );
      },
    );
  }
}