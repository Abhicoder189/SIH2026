import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'journey_map_screen.dart';

class CaregiverJourneyScreen extends StatefulWidget {
  final String token;
  final String patientId;
  final String patientName;

  const CaregiverJourneyScreen({
    super.key,
    required this.token,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<CaregiverJourneyScreen> createState() =>
      _CaregiverJourneyScreenState();
}

class _CaregiverJourneyScreenState
    extends State<CaregiverJourneyScreen> {
  Map<String, dynamic>? _journey;
  bool _loading = true;
  String? _error;
  bool _creating = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshSilent(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshSilent() async {
    try {
      final result = await ApiService.getActiveJourney(
        widget.token,
        patientId: widget.patientId,
      );

      if (!mounted) return;

      final journey = result['journey'];
      final newJourney = journey is Map
          ? Map<String, dynamic>.from(journey)
          : null;

      final oldStatus = _journey?['status']?.toString();
      final newStatus = newJourney?['status']?.toString();

      setState(() {
        _journey = newJourney;
      });

      if (oldStatus != newStatus && newStatus == 'arrived') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient has arrived at the destination!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {
      // Silent fail for auto-refresh
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await ApiService.getActiveJourney(
        widget.token,
        patientId: widget.patientId,
      );

      if (!mounted) return;

      final journey = result['journey'];

      setState(() {
        _journey = journey is Map
            ? Map<String, dynamic>.from(journey)
            : null;
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

  Future<void> _createJourney() async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final purposeController = TextEditingController();
    final durationController = TextEditingController(text: '45');
    final latController = TextEditingController(text: '30.08');
    final lngController = TextEditingController(text: '78.68');

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Create Journey',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Help ${widget.patientName} get to their destination.',
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(fontSize: 20),
                      decoration: const InputDecoration(
                        labelText: 'Destination name',
                        hintText: 'e.g. Apollo Pharmacy',
                        prefixIcon: Icon(Icons.place),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: addressController,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        labelText: 'Address (optional)',
                        hintText: 'e.g. 123 Main Street',
                        prefixIcon: Icon(Icons.home),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: purposeController,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        labelText: 'Purpose',
                        hintText: 'e.g. Buy medicines',
                        prefixIcon: Icon(Icons.task_alt),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: durationController,
                      style: const TextStyle(fontSize: 18),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Expected duration (minutes)',
                        hintText: '45',
                        prefixIcon: Icon(Icons.timer),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: latController,
                            style: const TextStyle(fontSize: 16),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: lngController,
                            style: const TextStyle(fontSize: 16),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the map button to use current location, or enter coordinates.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
                        const SnackBar(content: Text('Please enter a destination name.')),
                      );
                      return;
                    }
                    if (purposeController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a purpose.')),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('START JOURNEY', style: TextStyle(fontSize: 16)),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true) return;

    final name = nameController.text.trim();
    final address = addressController.text.trim();
    final purpose = purposeController.text.trim();
    final duration = int.tryParse(durationController.text.trim()) ?? 45;
    final lat = double.tryParse(latController.text.trim()) ?? 30.08;
    final lng = double.tryParse(lngController.text.trim()) ?? 78.68;

    if (mounted) {
      setState(() { _creating = true; });
    }

    try {
      await ApiService.createJourney(
        token: widget.token,
        patientId: widget.patientId,
        destinationName: name,
        destinationAddress: address,
        destinationLatitude: lat,
        destinationLongitude: lng,
        purpose: purpose,
        expectedDurationMinutes: duration,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journey started!')),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() { _creating = false; });
      }
    }
  }

  Future<void> _cancelJourney() async {
    if (_journey == null) return;

    final journeyId = _journey!['id']?.toString();
    if (journeyId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Journey'),
        content: Text('Cancel the journey to ${_journey!['destination_name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CANCEL JOURNEY'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.cancelJourney(widget.token, journeyId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journey cancelled.')),
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
          '${widget.patientName}\'s Journey',
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
              : _journey == null
                  ? _emptyBody()
                  : _activeJourneyBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : _createJourney,
        icon: _creating
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add),
        label: Text(
          _creating ? 'CREATING...' : 'NEW JOURNEY',
          style: const TextStyle(fontWeight: FontWeight.bold),
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
            const Text('Unable to load journey.', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
            Icon(Icons.explore, size: 90, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            const Text('No active journey', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'Create a journey to help ${widget.patientName} '
              'get to their destination with confidence.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeJourneyBody() {
    final dest = _journey!['destination_name']?.toString() ?? '';
    final purpose = _journey!['purpose']?.toString() ?? '';
    final status = _journey!['status']?.toString() ?? 'active';
    final address = _journey!['destination_address']?.toString() ?? '';
    final dist = _journey!['distance_to_destination_m'];
    final startedAt = _journey!['started_at']?.toString();
    final expectedMinutes = _journey!['expected_duration_minutes'];
    final lastLat = _journey!['last_latitude'];
    final lastLng = _journey!['last_longitude'];
    final lastLocAt = _journey!['last_location_at']?.toString();

    String distText = 'Unknown';
    if (dist != null && dist is num) {
      final metres = dist.toInt();
      distText = metres < 1000 ? '$metres m' : '${(metres / 1000).toStringAsFixed(1)} km';
    }

    String timeText = '';
    if (startedAt != null) {
      try {
        final started = DateTime.parse(startedAt);
        final elapsed = DateTime.now().difference(started);
        final mins = elapsed.inMinutes;
        if (mins < 60) {
          timeText = '${mins}m ago';
        } else {
          timeText = '${elapsed.inHours}h ${mins % 60}m ago';
        }
      } catch (_) {}
    }

    String expectedText = '';
    if (expectedMinutes != null) {
      expectedText = 'Expected: ${expectedMinutes}min';
    }

    bool hasLocation = lastLat != null && lastLng != null &&
        lastLat is num && lastLng is num;

    String locationAge = '';
    if (lastLocAt != null) {
      try {
        final locTime = DateTime.parse(lastLocAt);
        final ago = DateTime.now().difference(locTime);
        if (ago.inSeconds < 60) {
          locationAge = '${ago.inSeconds}s ago';
        } else if (ago.inMinutes < 60) {
          locationAge = '${ago.inMinutes}m ago';
        } else {
          locationAge = '${ago.inHours}h ago';
        }
      } catch (_) {}
    }

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'arrived':
        statusColor = Colors.green;
        statusLabel = 'Arrived';
        break;
      case 'near_destination':
        statusColor = Colors.orange;
        statusLabel = 'Near destination';
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusLabel = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusLabel = 'Cancelled';
        break;
      default:
        statusColor = Colors.blue;
        statusLabel = 'On the way';
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place, size: 30, color: Colors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dest, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            if (address.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(address, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.task_alt, size: 24, color: Colors.green),
                      const SizedBox(width: 10),
                      Text(purpose, style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 16, color: statusColor),
                      const SizedBox(width: 10),
                      Text(statusLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('Distance: $distText', style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 24, color: Colors.grey),
                  const SizedBox(width: 10),
                  if (timeText.isNotEmpty)
                    Text('Started $timeText', style: const TextStyle(fontSize: 16)),
                  if (timeText.isNotEmpty && expectedText.isNotEmpty)
                    const Text('  |  ', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  if (expectedText.isNotEmpty)
                    Text(expectedText, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                  if (timeText.isEmpty && expectedText.isEmpty)
                    Text('Time data unavailable', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place, size: 24, color: Colors.blue.shade700),
                      const SizedBox(width: 10),
                      Text(
                        'Destination',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(dest, style: const TextStyle(fontSize: 16)),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(address, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JourneyMapScreen(
                              token: widget.token,
                              journeyId: _journey!['id'].toString(),
                              journeyName: dest,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map, size: 22),
                      label: const Text(
                        'VIEW ON MAP',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: hasLocation ? Colors.green.shade50 : Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.my_location,
                        size: 24,
                        color: hasLocation ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hasLocation ? 'Patient Location' : 'Waiting for patient location...',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: hasLocation ? Colors.green.shade800 : Colors.grey,
                          ),
                        ),
                      ),
                      if (locationAge.isNotEmpty)
                        Text(
                          locationAge,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                  if (hasLocation) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Lat: ${lastLat.toDouble().toStringAsFixed(6)}  |  Lng: ${lastLng.toDouble().toStringAsFixed(6)}',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => JourneyMapScreen(
                                token: widget.token,
                                journeyId: _journey!['id'].toString(),
                                journeyName: dest,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.directions_walk, size: 22),
                        label: const Text(
                          'VIEW PATIENT ON MAP',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'Waiting for patient location data...',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (status == 'active' || status == 'near_destination') ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _cancelJourney,
                icon: const Icon(Icons.cancel),
                label: const Text('CANCEL JOURNEY', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
