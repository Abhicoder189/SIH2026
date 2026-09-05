import 'package:flutter/material.dart';

import '../services/api_service.dart';

class CaregiverMemoryManagerScreen extends StatefulWidget {
  final String token;
  final String patientId;
  final String patientName;

  const CaregiverMemoryManagerScreen({
    super.key,
    required this.token,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<CaregiverMemoryManagerScreen> createState() =>
      _CaregiverMemoryManagerScreenState();
}

class _CaregiverMemoryManagerScreenState
    extends State<CaregiverMemoryManagerScreen> {
  List<dynamic>? _memories;
  bool _loading = true;
  String? _error;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await ApiService.listMemories(
        widget.token,
        widget.patientId,
      );

      if (!mounted) return;

      setState(() {
        _memories = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _addMemory() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final peopleController = TextEditingController();
    final placeController = TextEditingController();
    final yearController = TextEditingController();

    int priority = 0;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'New Memory',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Create a memory moment for the patient. '
                      'This will appear as a gentle reminder of important people and events.',
                      style: TextStyle(fontSize: 15, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(fontSize: 20),
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g. Family Trip to Rishikesh',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descriptionController,
                      style: const TextStyle(fontSize: 18),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Story',
                        hintText: 'e.g. You went there with Priya and Rahul.',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: peopleController,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        labelText: 'People (comma-separated)',
                        hintText: 'e.g. Priya, Rahul',
                        prefixIcon: Icon(Icons.people),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: placeController,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        labelText: 'Place',
                        hintText: 'e.g. Rishikesh',
                        prefixIcon: Icon(Icons.place),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: yearController,
                      style: const TextStyle(fontSize: 18),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Year (optional)',
                        hintText: 'e.g. 2019',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.star_outline, size: 28),
                        const SizedBox(width: 10),
                        const Text(
                          'Priority: ',
                          style: TextStyle(fontSize: 17),
                        ),
                        const SizedBox(width: 8),
                        ...List.generate(4, (i) {
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                priority = i;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: priority == i
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$i',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: priority == i
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('CANCEL', style: TextStyle(fontSize: 17)),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a title.'),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text(
                    'CREATE',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true) return;

    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final people = peopleController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final place = placeController.text.trim();
    final year = int.tryParse(yearController.text.trim());

    if (mounted) {
      setState(() {
        _adding = true;
      });
    }

    try {
      await ApiService.createMemory(
        token: widget.token,
        patientId: widget.patientId,
        title: title,
        description: description,
        people: people,
        place: place,
        year: year,
        priority: priority,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Memory created successfully.'),
        ),
      );

      await _load();
    } catch (e) {
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
          _adding = false;
        });
      }
    }
  }

  Future<void> _deleteMemory(
    String memoryId,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Memory'),
          content: Text(
            'Remove "$title" from the patient\'s memory moments?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('REMOVE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteMemory(widget.token, memoryId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Memory removed.'),
        ),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.patientName}\'s Memories',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adding ? null : _addMemory,
        icon: _adding
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(
          _adding ? 'CREATING...' : 'NEW MEMORY',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Unable to load memories.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_memories == null || _memories!.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        itemCount: _memories!.length,
        itemBuilder: (context, index) {
          final memory = Map<String, dynamic>.from(_memories![index]);
          return _memoryCard(memory);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 90,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            const Text(
              'No memories yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create memory moments to help the patient '
              'remember important people, places, and events.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _adding ? null : _addMemory,
              icon: const Icon(Icons.add),
              label: const Text(
                'CREATE FIRST MEMORY',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memoryCard(Map<String, dynamic> memory) {
    final id = memory['id']?.toString() ?? '';
    final title = memory['title']?.toString() ?? 'Memory';
    final description = memory['description']?.toString() ?? '';
    final place = memory['place']?.toString() ?? '';
    final year = memory['year'];
    final people = memory['people'];
    final priority = memory['priority'] ?? 0;
    final active = memory['active'] ?? true;

    final peopleList = people is List
        ? people.map((p) => p.toString()).toList()
        : <String>[];

    final subtitleParts = <String>[];
    if (place.isNotEmpty) subtitleParts.add(place);
    if (year != null) subtitleParts.add('$year');
    if (peopleList.isNotEmpty) {
      subtitleParts.add(peopleList.join(', '));
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: active
                      ? Colors.pink.shade50
                      : Colors.grey.shade200,
                  child: Icon(
                    Icons.favorite,
                    color: active ? Colors.pink : Colors.grey,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitleParts.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitleParts.join(' · '),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (priority > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(
                          '$priority',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteMemory(id, title);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Remove'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            ],
            if (peopleList.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: peopleList.map((person) {
                  return Chip(
                    avatar: const Icon(Icons.person, size: 16),
                    label: Text(
                      person,
                      style: const TextStyle(fontSize: 13),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
