import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'smart_help_screen.dart';

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

class _NotificationFeedScreenState extends State<NotificationFeedScreen> {
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

      if (!mounted) return;
      setState(() { data = result; });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString(); });
    }

    if (!mounted) return;
    setState(() { loading = false; });
  }

  Future<void> _markAllRead() async {
    try {
      await ApiService.markAllNotificationsRead(token: widget.token);
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final items = (data?['items'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _markAllRead,
            icon: const Icon(Icons.done_all, size: 26),
            tooltip: 'Mark all read',
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, size: 26)),
        ],
      ),
      body: _buildBody(items),
    );
  }

  Widget _buildBody(List items) {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: const Text('TRY AGAIN', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 80,
              color: Colors.teal.shade200,
            ),
            const SizedBox(height: 16),
            const Text(
              'No notifications yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Important messages and reminders will appear here.',
              style: TextStyle(fontSize: 17, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = Map<String, dynamic>.from(items[index]);
          return _NotificationCard(
            item: item,
            token: widget.token,
            onRefresh: _load,
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String token;
  final VoidCallback onRefresh;

  const _NotificationCard({
    required this.item,
    required this.token,
    required this.onRefresh,
  });

  IconData _typeIcon() {
    final source = item['source'] as String? ?? '';
    if (source == 'smart_event') {
      switch (item['type']) {
        case 'BILL':
          return Icons.receipt_long;
        case 'MEDICINE':
          return Icons.medication;
        case 'HEALTHCARE_APPOINTMENT':
          return Icons.local_hospital;
        case 'TRAVEL':
          return Icons.train;
        case 'DELIVERY':
          return Icons.local_shipping;
        case 'SHOPPING':
          return Icons.shopping_cart;
        default:
          return Icons.smart_toy;
      }
    }
    switch (item['type']) {
      case 'medicine':
        return Icons.medication;
      case 'appointment':
        return Icons.local_hospital;
      case 'exercise':
        return Icons.fitness_center;
      case 'hydration':
        return Icons.water_drop;
      case 'meal':
        return Icons.restaurant;
      case 'game':
        return Icons.games;
      default:
        return Icons.alarm;
    }
  }

  Color _typeColor() {
    final source = item['source'] as String? ?? '';
    if (source == 'smart_event') {
      switch (item['type']) {
        case 'BILL':
          return Colors.orange;
        case 'MEDICINE':
          return Colors.red;
        case 'HEALTHCARE_APPOINTMENT':
          return Colors.blue;
        case 'TRAVEL':
          return Colors.purple;
        case 'DELIVERY':
          return Colors.teal;
        default:
          return Colors.indigo;
      }
    }
    return Colors.teal;
  }

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString() ?? 'Notification';
    final message = item['message']?.toString() ?? '';
    final source = item['source'] as String? ?? '';
    final isSmartEvent = source == 'smart_event';
    final due = item['due'] as bool? ?? false;
    final icon = _typeIcon();
    final color = _typeColor();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isSmartEvent ? () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SmartHelpScreen()),
          );
        } : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(
                    color.r.toInt(),
                    color.g.toInt(),
                    color.b.toInt(),
                    0.12,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isSmartEvent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Smart',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.indigo,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: const TextStyle(fontSize: 16, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (due) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'DUE NOW',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
