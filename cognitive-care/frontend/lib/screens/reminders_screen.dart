import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({
    super.key,
    required this.token,
    required this.patientId,
  });

  final String token;
  final String patientId;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<dynamic>? reminders;
  String? error;
  bool loading = true;
  bool adding = false;

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
      final result = await ApiService.reminders(widget.token);

      if (!mounted) return;

      setState(() {
        reminders = result;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _add() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    String type = 'activity';
    String repeat = 'daily';

    DateTime scheduledTime = DateTime.now().add(
      const Duration(hours: 1),
    );

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'New Reminder',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      style: const TextStyle(fontSize: 20),
                      decoration: const InputDecoration(
                        labelText: 'What should we remind you about?',
                        labelStyle: TextStyle(fontSize: 17),
                        prefixIcon: Icon(Icons.edit),
                      ),
                    ),

                    const SizedBox(height: 18),

                    TextField(
                      controller: messageController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        labelText: 'Additional message',
                        labelStyle: TextStyle(fontSize: 17),
                        prefixIcon: Icon(Icons.message),
                      ),
                    ),

                    const SizedBox(height: 20),

                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(
                        labelText: 'Reminder type',
                        prefixIcon: Icon(Icons.category),
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'medicine',
                          child: Text('💊 Medicine'),
                        ),
                        DropdownMenuItem(
                          value: 'hydration',
                          child: Text('💧 Hydration'),
                        ),
                        DropdownMenuItem(
                          value: 'meal',
                          child: Text('🍽️ Meal'),
                        ),
                        DropdownMenuItem(
                          value: 'exercise',
                          child: Text('🚶 Exercise'),
                        ),
                        DropdownMenuItem(
                          value: 'appointment',
                          child: Text('🩺 Appointment'),
                        ),
                        DropdownMenuItem(
                          value: 'activity',
                          child: Text('🏠 Daily Activity'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          type = value;
                        });
                      },
                    ),

                    const SizedBox(height: 18),

                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: scheduledTime,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );

                        if (pickedDate == null) return;

                        setDialogState(() {
                          scheduledTime = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            scheduledTime.hour,
                            scheduledTime.minute,
                          );
                        });
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _formatDate(scheduledTime),
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    InkWell(
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            scheduledTime,
                          ),
                        );

                        if (pickedTime == null) return;

                        setDialogState(() {
                          scheduledTime = DateTime(
                            scheduledTime.year,
                            scheduledTime.month,
                            scheduledTime.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Time',
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(
                          _formatTime(scheduledTime),
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    DropdownButtonFormField<String>(
                      initialValue: repeat,
                      decoration: const InputDecoration(
                        labelText: 'Repeat',
                        prefixIcon: Icon(Icons.repeat),
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'once',
                          child: Text('Once'),
                        ),
                        DropdownMenuItem(
                          value: 'daily',
                          child: Text('Every day'),
                        ),
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Every week'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          repeat = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(fontSize: 17),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter what you want to be reminded about.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text(
                    'SAVE',
                    style: TextStyle(fontSize: 17),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (created != true) {
      titleController.dispose();
      messageController.dispose();
      return;
    }

    try {
      if (mounted) {
        setState(() {
          adding = true;
        });
      }

      await ApiService.createReminder(
        widget.token,
        {
          'patient_id': widget.patientId,
          'title': titleController.text.trim(),
          'message': messageController.text.trim(),
          'type': type,
          'scheduled_time': scheduledTime.toUtc().toIso8601String(),
          'repeat': repeat,
        },
      );

      titleController.dispose();
      messageController.dispose();

      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder created successfully.'),
        ),
      );
    } catch (e) {
      titleController.dispose();
      messageController.dispose();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          adding = false;
        });
      }
    }
  }

  Future<void> _completeReminder(
    Map<String, dynamic> reminder,
  ) async {
    final reminderId = _reminderId(reminder);

    if (reminderId == null) {
      _showMessage('Reminder ID is missing.');
      return;
    }

    try {
      await ApiService.updateReminder(
        widget.token,
        reminderId,
        {
          'completed': true,
        },
      );

      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder completed.'),
        ),
      );
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _snoozeReminder(
    Map<String, dynamic> reminder,
  ) async {
    final reminderId = _reminderId(reminder);

    if (reminderId == null) {
      _showMessage('Reminder ID is missing.');
      return;
    }

    final minutes = await showDialog<int>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text(
            'Snooze Reminder',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 10),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  '10 minutes',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 30),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  '30 minutes',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 60),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  '1 hour',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (minutes == null) return;

    try {
      await ApiService.updateReminder(
        widget.token,
        reminderId,
        {
          'snooze_minutes': minutes,
        },
      );

      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reminder snoozed for $minutes minutes.',
          ),
        ),
      );
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _deleteReminder(
    Map<String, dynamic> reminder,
  ) async {
    final reminderId = _reminderId(reminder);

    if (reminderId == null) {
      _showMessage('Reminder ID is missing.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Reminder?',
            style: TextStyle(fontSize: 24),
          ),
          content: const Text(
            'This reminder will be permanently removed.',
            style: TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'CANCEL',
                style: TextStyle(fontSize: 17),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'DELETE',
                style: TextStyle(fontSize: 17),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteReminder(
        widget.token,
        reminderId,
      );

      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder deleted.'),
        ),
      );
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  String? _reminderId(Map<String, dynamic> reminder) {
    final value = reminder['id'] ?? reminder['reminder_id'];

    if (value == null) return null;

    final id = value.toString().trim();

    if (id.isEmpty) return null;

    return id;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  String _formatScheduledTime(dynamic value) {
    if (value == null) {
      return 'Time not specified';
    }

    final parsed = DateTime.tryParse(value.toString());

    if (parsed == null) {
      return value.toString();
    }

    final local = parsed.toLocal();

    return '${_formatDate(local)} at ${_formatTime(local)}';
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'medicine':
        return 'Medicine';
      case 'hydration':
        return 'Hydration';
      case 'meal':
        return 'Meal';
      case 'exercise':
        return 'Exercise';
      case 'appointment':
        return 'Appointment';
      case 'activity':
        return 'Daily Activity';
      default:
        return 'Reminder';
    }
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'medicine':
        return Icons.medication;
      case 'hydration':
        return Icons.water_drop;
      case 'meal':
        return Icons.restaurant;
      case 'exercise':
        return Icons.directions_walk;
      case 'appointment':
        return Icons.local_hospital;
      case 'activity':
        return Icons.home;
      default:
        return Icons.notifications_active;
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'medicine':
        return const Color(0xFF7A43B6);
      case 'hydration':
        return const Color(0xFF2773B9);
      case 'meal':
        return const Color(0xFFE46C27);
      case 'exercise':
        return const Color(0xFF168B76);
      case 'appointment':
        return const Color(0xFFD14B4B);
      case 'activity':
        return const Color(0xFF4B4FC7);
      default:
        return const Color(0xFF555A64);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 90,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            const Text(
              'No reminders yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add a reminder for medicine, water, meals, activities or appointments.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text(
                'ADD REMINDER',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 70,
            ),
            const SizedBox(height: 18),
            const Text(
              'Could not load reminders',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _load,
              child: const Text(
                'TRY AGAIN',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reminderCard(Map<String, dynamic> reminder) {
    final completed = reminder['completed'] == true;

    final title =
        reminder['title']?.toString() ?? 'Reminder';

    final message =
        reminder['message']?.toString() ?? '';

    final type =
        reminder['type']?.toString() ?? 'activity';

    final repeat =
        reminder['repeat']?.toString() ?? 'once';

    final color = _typeColor(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    completed
                        ? Icons.check_circle
                        : _typeIcon(type),
                    size: 32,
                    color: completed
                        ? Colors.green
                        : color,
                  ),
                ),

                const SizedBox(width: 15),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          decoration: completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        _typeLabel(type),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        completed
                            ? 'Completed'
                            : _formatScheduledTime(
                                reminder['scheduled_time'],
                              ),
                        style: TextStyle(
                          fontSize: 16,
                          color: completed
                              ? Colors.green
                              : Colors.grey.shade700,
                        ),
                      ),

                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          message,
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ],

                      if (repeat != 'once') ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.repeat,
                              size: 17,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              repeat == 'daily'
                                  ? 'Every day'
                                  : 'Every week',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'snooze') {
                      _snoozeReminder(reminder);
                    } else if (value == 'delete') {
                      _deleteReminder(reminder);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'snooze',
                      child: Row(
                        children: [
                          Icon(Icons.snooze),
                          SizedBox(width: 10),
                          Text(
                            'Snooze',
                            style: TextStyle(fontSize: 17),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline),
                          SizedBox(width: 10),
                          Text(
                            'Delete',
                            style: TextStyle(fontSize: 17),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (!completed) ...[
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _completeReminder(reminder),
                  icon: const Icon(
                    Icons.check,
                    size: 25,
                  ),
                  label: const Text(
                    'MARK AS DONE',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),

      appBar: AppBar(
        title: const Text(
          'Reminders',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: adding ? null : _add,
        icon: adding
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.add),
        label: Text(
          adding ? 'ADDING...' : 'ADD REMINDER',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : error != null
              ? _errorState()
              : reminders == null || reminders!.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          18,
                          16,
                          100,
                        ),
                        children: [
                          const Text(
                            'Today\'s Reminders',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            'Stay on track with your daily routine.',
                            style: TextStyle(
                              fontSize: 17,
                              color: Colors.grey.shade700,
                            ),
                          ),

                          const SizedBox(height: 18),

                          ...reminders!.map(
                            (item) {
                              final reminder =
                                  Map<String, dynamic>.from(
                                item as Map,
                              );

                              return _reminderCard(
                                reminder,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
    );
  }
}