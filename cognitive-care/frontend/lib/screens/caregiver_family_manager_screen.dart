import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

class CaregiverFamilyManagerScreen extends StatefulWidget {
  final String token;
  final String patientId;
  final String patientName;

  const CaregiverFamilyManagerScreen({
    super.key,
    required this.token,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<CaregiverFamilyManagerScreen> createState() =>
      _CaregiverFamilyManagerScreenState();
}

class _CaregiverFamilyManagerScreenState
    extends State<CaregiverFamilyManagerScreen> {
  List<dynamic> _members = [];
  bool _loading = true;
  String? _error;

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
      final result = await ApiService.listFamilyMembers(
        widget.token,
        patientId: widget.patientId,
      );

      if (!mounted) return;

      final members = result['family_members'];

      setState(() {
        _members = members is List
            ? members.map((m) => Map<String, dynamic>.from(m)).toList()
            : [];
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

  Future<void> _addOrEdit({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?['name']?.toString() ?? '');
    final relationshipController = TextEditingController(text: existing?['relationship']?.toString() ?? '');
    final descriptionController = TextEditingController(text: existing?['description']?.toString() ?? '');
    final voiceDescController = TextEditingController(text: existing?['voice_description']?.toString() ?? '');
    final nicknamesController = TextEditingController(
      text: (existing?['nicknames'] as List?)?.join(', ') ?? '',
    );
    final howYouKnowController = TextEditingController(text: existing?['how_you_know_them']?.toString() ?? '');
    final funFactController = TextEditingController(text: existing?['fun_fact']?.toString() ?? '');
    String? photoBase64 = existing?['photo_url']?.toString();
    final picker = ImagePicker();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isEdit ? 'Edit Family Member' : 'Add Family Member',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picked = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 400,
                          maxHeight: 400,
                          imageQuality: 70,
                        );
                        if (picked != null) {
                          final bytes = await File(picked.path).readAsBytes();
                          setDialogState(() {
                            photoBase64 = base64Encode(bytes);
                          });
                        }
                      },
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: photoBase64 != null && photoBase64!.isNotEmpty
                            ? MemoryImage(base64Decode(photoBase64!))
                            : null,
                        child: photoBase64 == null || photoBase64!.isEmpty
                            ? Icon(Icons.camera_alt, size: 30, color: Colors.grey.shade500)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap to add photo',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(fontSize: 20),
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g. Rajesh Kumar',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: relationshipController,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        labelText: 'Relationship',
                        hintText: 'e.g. Son, Daughter, Grandchild',
                        prefixIcon: Icon(Icons.family_restroom),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      style: const TextStyle(fontSize: 18),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'e.g. Lives in Delhi, visits every Sunday',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: voiceDescController,
                      style: const TextStyle(fontSize: 18),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Voice description (what patient hears)',
                        hintText: 'e.g. This is your son Rajesh. He takes care of you.',
                        prefixIcon: Icon(Icons.record_voice_over),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nicknamesController,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        labelText: 'Nicknames (comma separated)',
                        hintText: 'e.g. Raju, Raj',
                        prefixIcon: Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: howYouKnowController,
                      style: const TextStyle(fontSize: 18),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'How you know them',
                        hintText: 'e.g. He comes to visit you every Sunday afternoon',
                        prefixIcon: Icon(Icons.history_edu),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: funFactController,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        labelText: 'Fun fact (optional)',
                        hintText: 'e.g. He always brings your favourite sweets',
                        prefixIcon: Icon(Icons.celebration),
                        border: OutlineInputBorder(),
                      ),
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
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a name.')),
                      );
                      return;
                    }
                    if (relationshipController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a relationship.')),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  icon: const Icon(Icons.save),
                  label: Text(isEdit ? 'UPDATE' : 'ADD', style: const TextStyle(fontSize: 16)),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true) return;

    final name = nameController.text.trim();
    final relationship = relationshipController.text.trim();
    final description = descriptionController.text.trim();
    final voiceDesc = voiceDescController.text.trim();
    final nicknames = nicknamesController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final howYouKnow = howYouKnowController.text.trim();
    final funFact = funFactController.text.trim();

    try {
      if (isEdit) {
        await ApiService.updateFamilyMember(
          token: widget.token,
          memberId: existing['id'].toString(),
          name: name,
          relationship: relationship,
          description: description,
          voiceDescription: voiceDesc,
          photoUrl: photoBase64 ?? '',
          nicknames: nicknames,
          howYouKnowThem: howYouKnow,
          funFact: funFact,
        );
      } else {
        await ApiService.createFamilyMember(
          token: widget.token,
          patientId: widget.patientId,
          name: name,
          relationship: relationship,
          description: description,
          voiceDescription: voiceDesc,
          photoUrl: photoBase64 ?? '',
          nicknames: nicknames,
          howYouKnowThem: howYouKnow,
          funFact: funFact,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? 'Updated!' : 'Added!')),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Family Member'),
        content: Text('Remove ${member['name']} from the list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteFamilyMember(
        widget.token,
        member['id'].toString(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed.')),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.patientName}\'s Family',
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorBody()
              : _members.isEmpty
                  ? _emptyBody()
                  : _listBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.person_add),
        label: const Text(
          'ADD MEMBER',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56),
            const SizedBox(height: 16),
            const Text('Unable to load.', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Try Again')),
          ],
        ),
      ),
    );
  }

  Widget _emptyBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 90, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            const Text('No family members yet', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'Add family members so ${widget.patientName} can recognise them. '
              'Include their photo, name, relationship, and a description.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listBody() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _members.length,
        itemBuilder: (context, index) {
          final member = _members[index];
          return _memberCard(member);
        },
      ),
    );
  }

  Widget _memberCard(Map<String, dynamic> member) {
    final name = member['name']?.toString() ?? '';
    final relationship = member['relationship']?.toString() ?? '';
    final description = member['description']?.toString() ?? '';
    final photoUrl = member['photo_url']?.toString() ?? '';
    final nicknames = member['nicknames'];
    final funFact = member['fun_fact']?.toString() ?? '';

    bool hasPhoto = photoUrl.isNotEmpty;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _addOrEdit(existing: member),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.teal.shade50,
                backgroundImage: hasPhoto
                    ? MemoryImage(base64Decode(photoUrl))
                    : null,
                child: !hasPhoto
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      relationship,
                      style: TextStyle(fontSize: 15, color: Colors.teal.shade700),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (nicknames is List && nicknames.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: nicknames.map((n) => Chip(
                          label: Text(n.toString(), style: const TextStyle(fontSize: 12)),
                          backgroundColor: Colors.orange.shade50,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                      ),
                    ],
                    if (funFact.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.celebration, size: 14, color: Colors.amber.shade700),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              funFact,
                              style: TextStyle(fontSize: 13, color: Colors.amber.shade800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _delete(member),
                icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
                tooltip: 'Remove',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
