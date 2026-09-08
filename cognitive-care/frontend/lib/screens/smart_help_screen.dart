import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/sms_reader_service.dart';

class SmartHelpScreen extends StatefulWidget {
  const SmartHelpScreen({super.key});

  @override
  State<SmartHelpScreen> createState() => _SmartHelpScreenState();
}

class _SmartHelpScreenState extends State<SmartHelpScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;
  bool _analyzing = false;
  bool _scanning = false;
  int _scanProgress = 0;
  int _scanTotal = 0;
  int _relevantFound = 0;
  final _messageController = TextEditingController();
  String? _token;
  String? _patientId;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _patientId = prefs.getString('user_id');

    if (_token == null || _patientId == null) {
      setState(() {
        _error = 'Please log in first.';
        _loading = false;
      });
      return;
    }

    await _loadEvents();
  }

  Future<void> _loadEvents() async {
    if (_token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getSmartEvents(token: _token!);
      final events = (data['events'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];

      if (mounted) {
        setState(() {
          _events = events;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load messages.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _scanAllSms() async {
    if (_token == null) return;

    final smsReader = SmsReaderService();

    bool hasPerm = await smsReader.hasPermission();
    if (!hasPerm) {
      hasPerm = await smsReader.requestPermission();
    }

    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'SMS permission is needed to scan messages. Please allow it in Settings.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _scanning = true;
      _scanProgress = 0;
      _scanTotal = 0;
      _relevantFound = 0;
    });

    try {
      final allSms = await smsReader.readAllSms(limit: 500);

      if (allSms.isEmpty) {
        if (mounted) {
          setState(() => _scanning = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No SMS messages found on this phone.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      setState(() => _scanTotal = allSms.length);

      int relevant = 0;
      for (int i = 0; i < allSms.length; i++) {
        final sms = allSms[i];

        if (sms.body.length < 10) {
          setState(() => _scanProgress = i + 1);
          continue;
        }

        try {
          final result = await ApiService.analyzeSmartMessage(
            token: _token!,
            message: sms.body,
            source: 'sms',
            sender: sms.address,
          );

          final status = result['status'] as String? ?? '';
          if (status == 'created') {
            relevant++;
          }
        } catch (_) {}

        if (mounted) {
          setState(() => _scanProgress = i + 1);
        }
      }

      if (mounted) {
        setState(() {
          _relevantFound = relevant;
          _scanning = false;
        });

        await _loadEvents();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              relevant > 0
                  ? 'Found $relevant important messages from ${allSms.length} SMS!'
                  : 'Scanned ${allSms.length} messages. No important messages found.',
            ),
            backgroundColor: relevant > 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning SMS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _analyzeMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _token == null) return;

    setState(() => _analyzing = true);

    try {
      final result = await ApiService.analyzeSmartMessage(
        token: _token!,
        message: message,
      );

      _messageController.clear();

      if (!mounted) return;

      final status = result['status'] as String? ?? '';
      final friendlyMsg = result['message'] as String? ?? '';

      if (status == 'irrelevant') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyMsg.isNotEmpty
                  ? friendlyMsg
                  : 'This message does not seem important.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (status == 'duplicate') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyMsg.isNotEmpty ? friendlyMsg : 'Already processed.'),
            backgroundColor: Colors.blueGrey,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyMsg.isNotEmpty ? friendlyMsg : 'Message understood!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadEvents();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not analyze message. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _analyzing = false);
      }
    }
  }

  Future<void> _confirmEvent(String eventId) async {
    if (_token == null) return;

    try {
      await ApiService.confirmSmartEvent(token: _token!, eventId: eventId);
      await _loadEvents();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event confirmed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not confirm event.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createReminder(String eventId) async {
    if (_token == null) return;

    try {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final scheduledTime = tomorrow.toUtc().toIso8601String();

      await ApiService.createSmartEventReminder(
        token: _token!,
        eventId: eventId,
        scheduledTime: scheduledTime,
      );
      await _loadEvents();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder set for tomorrow!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not create reminder.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _dismissEvent(String eventId) async {
    if (_token == null) return;

    try {
      await ApiService.dismissSmartEvent(token: _token!, eventId: eventId);
      await _loadEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not dismiss event.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPasteDialog() {
    final pasteController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Paste Message',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Paste an important message below and SmritiSarthi will understand it for you.',
                  style: TextStyle(fontSize: 16, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pasteController,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    hintText: 'Paste message here...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL', style: TextStyle(fontSize: 17)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final text = pasteController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  _messageController.text = text;
                  _analyzeMessage();
                }
              },
              icon: const Icon(Icons.send),
              label: const Text('UNDERSTAND', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Smart Help',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 28),
            onPressed: _loadEvents,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.teal.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          hintText: 'Type or paste a message...',
                          prefixIcon: const Icon(Icons.message, size: 26),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          suffixIcon: _analyzing
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.send, size: 26),
                                  onPressed: _analyzing ? null : _analyzeMessage,
                                ),
                        ),
                        onSubmitted: (_) => _analyzeMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.content_paste, size: 28),
                      onPressed: _showPasteDialog,
                      tooltip: 'Paste message',
                      color: Colors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _scanning ? null : _scanAllSms,
                    icon: _scanning
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              value: _scanTotal > 0
                                  ? _scanProgress / _scanTotal
                                  : null,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.sms, size: 24),
                    label: Text(
                      _scanning
                          ? 'Scanning $_scanProgress/$_scanTotal...'
                          : 'SCAN ALL SMS',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_relevantFound > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.green.shade50,
              child: Text(
                'Found $_relevantFound important messages!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
            ),
          Expanded(
            child: _buildEventList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEvents,
              child: const Text('Retry', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.smart_toy_outlined, size: 80, color: Colors.teal.shade200),
              const SizedBox(height: 20),
              const Text(
                'No smart messages yet',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Scan your SMS to automatically find important messages about bills, appointments, medicines, and more.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, height: 1.4, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _scanning ? null : _scanAllSms,
                icon: const Icon(Icons.sms, size: 24),
                label: const Text('SCAN ALL SMS', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final event = _events[index];
          return _SmartEventCard(
            event: event,
            onConfirm: () => _confirmEvent(event['id']),
            onRemind: () => _createReminder(event['id']),
            onDismiss: () => _dismissEvent(event['id']),
          );
        },
      ),
    );
  }
}

class _SmartEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onConfirm;
  final VoidCallback onRemind;
  final VoidCallback onDismiss;

  const _SmartEventCard({
    required this.event,
    required this.onConfirm,
    required this.onRemind,
    required this.onDismiss,
  });

  IconData _categoryIcon() {
    switch (event['category']) {
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
      case 'FAMILY_INSTRUCTION':
        return Icons.family_restroom;
      case 'REMINDER':
        return Icons.alarm;
      case 'EVENT':
        return Icons.event;
      default:
        return Icons.message;
    }
  }

  Color _categoryColor() {
    switch (event['category']) {
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
      case 'SHOPPING':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  String _statusText() {
    switch (event['status']) {
      case 'confirmed':
        return 'Confirmed';
      case 'reminder_set':
        return 'Reminder Set';
      case 'journey_created':
        return 'Journey Planned';
      case 'completed':
        return 'Done';
      default:
        return 'New';
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _categoryColor();
    final status = event['status'] as String? ?? 'new';
    final confidence = (event['confidence'] as num?)?.toDouble() ?? 0.5;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(
                      categoryColor.r.toInt(),
                      categoryColor.g.toInt(),
                      categoryColor.b.toInt(),
                      0.1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_categoryIcon(), color: categoryColor, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event['title'] ?? 'Message',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _statusText(),
                        style: TextStyle(
                          fontSize: 14,
                          color: categoryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (confidence >= 0.7)
                  Icon(Icons.verified, color: Colors.green.shade400, size: 22)
                else if (confidence >= 0.5)
                  Icon(Icons.help_outline, color: Colors.orange, size: 22),
              ],
            ),
            if (event['purpose'] != null &&
                (event['purpose'] as String).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                event['purpose'],
                style: const TextStyle(fontSize: 17, height: 1.3),
              ),
            ],
            if (event['amount'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Amount: ${event['currency'] == 'INR' ? 'Rs.' : ''}${event['amount']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
            ],
            if (event['due_date'] != null &&
                (event['due_date'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Colors.red),
                  const SizedBox(width: 6),
                  Text(
                    'Due: ${event['due_date']}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
            if (event['location_name'] != null &&
                (event['location_name'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.place, size: 18, color: Colors.teal.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event['location_name'],
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (status == 'new' || status == 'confirmed') ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (status == 'new')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onConfirm,
                        icon: const Icon(Icons.check, size: 20),
                        label: const Text('YES, CORRECT', style: TextStyle(fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (status == 'new') const SizedBox(width: 8),
                  if (event['category'] != 'OTHER')
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onRemind,
                        icon: const Icon(Icons.alarm_add, size: 20),
                        label: const Text('REMIND ME', style: TextStyle(fontSize: 15)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close, size: 22),
                    color: Colors.grey,
                    tooltip: 'Dismiss',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
