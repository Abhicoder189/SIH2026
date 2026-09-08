import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';

class JourneyAssistScreen extends StatefulWidget {
  final String token;
  final String patientId;

  const JourneyAssistScreen({
    super.key,
    required this.token,
    required this.patientId,
  });

  @override
  State<JourneyAssistScreen> createState() =>
      _JourneyAssistScreenState();
}

class _JourneyAssistScreenState
    extends State<JourneyAssistScreen> {
  Map<String, dynamic>? _journey;
  Map<String, dynamic>? _context;
  bool _loading = true;
  String? _error;
  bool _speaking = false;
  bool _locationTracking = false;
  Timer? _locationTimer;

  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  // ============================================================
  // LOCATION TRACKING
  // ============================================================

  Future<void> _startLocationTracking() async {
    if (_locationTracking) return;

    bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location services are disabled.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    LocationPermission permission =
        await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission denied.',
              ),
            ),
          );
        }
        return;
      }
    }

    if (permission ==
        LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission permanently denied.',
            ),
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _locationTracking = true;
      });
    }

    _sendLocationUpdate();

    _locationTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _sendLocationUpdate(),
    );
  }

  void _stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    if (mounted) {
      setState(() {
        _locationTracking = false;
      });
    }
  }

  Future<void> _sendLocationUpdate() async {
    if (_journey == null) return;

    final journeyId =
        _journey!['id']?.toString() ??
        _journey!['_id']?.toString();
    final status =
        _journey!['status']?.toString();
    if (journeyId == null) return;
    if (status != 'active' &&
        status != 'near_destination') {
      _stopLocationTracking();
      return;
    }

    try {
      final position =
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );

      if (!mounted) return;

      final result =
          await ApiService.updateJourneyLocation(
            token: widget.token,
            journeyId: journeyId,
            latitude: position.latitude,
            longitude: position.longitude,
          );

      final updatedJourney = result['journey'];
      if (updatedJourney is Map && mounted) {
        setState(() {
          _journey = Map<String, dynamic>.from(
            updatedJourney,
          );
        });

        final newStatus =
            _journey!['status']?.toString();
        if (newStatus == 'arrived' ||
            newStatus == 'completed') {
          _stopLocationTracking();
          if (newStatus == 'arrived') {
            _loadContextAndSpeak(
              'ARRIVAL_GREETING',
              position.latitude,
              position.longitude,
              position.accuracy,
            );
          }
        }
      }

      _loadContextSilent(
        position.latitude,
        position.longitude,
        position.accuracy,
      );
    } catch (_) {
      // Silent fail for location updates
    }
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result =
          await ApiService.getActiveJourney(
            widget.token,
          );

      if (!mounted) return;

      final journey = result['journey'];

      setState(() {
        _journey = journey is Map
            ? Map<String, dynamic>.from(journey)
            : null;
        _loading = false;
      });

      final status =
          _journey?['status']?.toString();
      if (status == 'active' ||
          status == 'near_destination') {
        _startLocationTracking();
      }

      if (_journey != null) {
        _loadContextSilent(null, null, null);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e
            .toString()
            .replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadContextSilent(
    double? lat,
    double? lng,
    double? accuracy,
  ) async {
    if (_journey == null) return;
    final journeyId =
        _journey!['id']?.toString() ??
        _journey!['_id']?.toString();
    if (journeyId == null) return;

    try {
      final ctx =
          await ApiService.getJourneyContext(
            widget.token,
            journeyId,
            latitude: lat,
            longitude: lng,
            gpsAccuracy: accuracy,
          );
      if (mounted) {
        setState(() {
          _context = ctx;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadContextAndSpeak(
    String queryType,
    double? lat,
    double? lng,
    double? accuracy,
  ) async {
    if (_journey == null) return;
    final journeyId =
        _journey!['id']?.toString() ??
        _journey!['_id']?.toString();
    if (journeyId == null) return;

    try {
      final ctx =
          await ApiService.getJourneyContext(
            widget.token,
            journeyId,
            latitude: lat,
            longitude: lng,
            gpsAccuracy: accuracy,
          );

      if (mounted) {
        setState(() {
          _context = ctx;
        });
      }

      final responses =
          ctx['responses'] as Map<String, dynamic>?;
      final responseText =
          responses?[queryType.toLowerCase()]
              ?.toString();

      if (responseText != null &&
          responseText.isNotEmpty) {
        await _speak(responseText);
      }
    } catch (_) {
      await _speak(
        'I could not load your journey information.',
      );
    }
  }

  Future<void> _logInteraction(
    String interactionType,
  ) async {
    if (_journey == null) return;
    final journeyId =
        _journey!['id']?.toString() ??
        _journey!['_id']?.toString();
    if (journeyId == null) return;

    try {
      final result =
          await ApiService.logJourneyInteraction(
            token: widget.token,
            journeyId: journeyId,
            interactionType: interactionType,
          );

      final response =
          result['response']?.toString();
      if (response != null && response.isNotEmpty) {
        await _speak(response);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response ?? 'Done.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      await _speak(
        'I could not process that right now.',
      );
    }
  }

  // ============================================================
  // TTS
  // ============================================================

  Future<void> _speak(String text) async {
    if (_speaking) return;

    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    if (mounted) {
      setState(() {
        _speaking = true;
      });
    }

    await _tts.speak(text);

    if (mounted) {
      setState(() {
        _speaking = false;
      });
    }
  }

  // ============================================================
  // CONTEXT-AWARE ACTIONS
  // ============================================================

  void _whyAmIHere() {
    _logInteraction('WHY_AM_I_HERE');
    _showContextDialog(
      'Why am I here?',
      _context?['responses']?['why_am_i_here']
              ?.toString() ??
          'You are on a journey.',
      Icons.help_outline,
    );
  }

  void _whereAmI() {
    _logInteraction('WHERE_AM_I');
    _showContextDialog(
      'Where am I?',
      _context?['responses']?['where_am_i']
              ?.toString() ??
          'You are on a journey.',
      Icons.my_location,
    );
  }

  void _whatNext() {
    _logInteraction('WHAT_NEXT');
    _showContextDialog(
      'What should I do next?',
      _context?['responses']?['what_next']
              ?.toString() ??
          'Please continue on your journey.',
      Icons.arrow_forward,
    );
  }

  void _imConfused() {
    _logInteraction('IM_CONFUSED');

    final response =
        _context?['responses']?['im_confused']
            ?.toString() ??
        'You are safe.';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.favorite,
              color: Colors.pink,
              size: 30,
            ),
            SizedBox(width: 10),
            Text(
              'You are safe',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              response,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 16),
            Text(
              'Your caregiver has been notified.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showMeTheWay();
              },
              icon: const Icon(
                Icons.directions,
                size: 22,
              ),
              label: const Text(
                'SHOW ME THE WAY',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _callCaregiver();
              },
              icon: const Icon(
                Icons.phone,
                size: 22,
              ),
              label: const Text(
                'CALL CAREGIVER',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () =>
                  Navigator.pop(context),
              child: const Text(
                "I'M OK",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContextDialog(
    String title,
    String message,
    IconData icon,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 20),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _speak(message);
            },
            icon: const Icon(
              Icons.volume_up,
              size: 24,
            ),
            label: const Text(
              'LISTEN',
              style: TextStyle(fontSize: 18),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _showMeTheWay() {
    if (_journey == null) return;

    final lat =
        _journey!['destination_latitude'];
    final lng =
        _journey!['destination_longitude'];
    final name =
        _journey!['destination_name']
            ?.toString() ??
        'destination';

    if (lat == null || lng == null) return;

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$name',
    );

    launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _callCaregiver() async {
    if (_journey == null) return;

    try {
      final patient =
          await ApiService.getMyPatient(
            widget.token,
          );
      final name =
          patient['name']?.toString() ??
          'Patient';
      final dest =
          _journey!['destination_name']
              ?.toString() ??
          'unknown';
      final purpose =
          _journey!['purpose']?.toString() ??
          '';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Alert sent to caregiver. $name needs help near $dest. $purpose',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to contact caregiver right now.',
          ),
        ),
      );
    }
  }

  Future<void> _completeJourney() async {
    if (_journey == null) return;

    final journeyId =
        _journey!['id']?.toString() ??
        _journey!['_id']?.toString();
    if (journeyId == null) return;

    _stopLocationTracking();

    try {
      await ApiService.completeJourney(
        widget.token,
        journeyId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Journey completed. Well done!',
          ),
        ),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e
                .toString()
                .replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'On the way';
      case 'near_destination':
        return 'Near your destination';
      case 'arrived':
        return 'You have arrived';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String? _timeCheck() {
    if (_journey == null) return null;

    final status =
        _journey!['status']?.toString();
    if (status != 'active' &&
        status != 'near_destination') {
      return null;
    }

    final startedAt =
        _journey!['started_at']?.toString();
    final expectedMinutes =
        _journey!['expected_duration_minutes'];

    if (startedAt == null ||
        expectedMinutes == null) {
      return null;
    }

    try {
      final started = DateTime.parse(startedAt);
      final elapsed = DateTime.now()
          .difference(started)
          .inMinutes;
      final expected = expectedMinutes is int
          ? expectedMinutes
          : 45;

      if (elapsed > expected * 1.5) {
        return "You've been travelling for a while. "
            'If you need help, press the button below.';
      } else if (elapsed > expected) {
        return "Taking a bit longer than expected. "
            "That's perfectly fine. You're doing well.";
      }
    } catch (_) {}

    return null;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text(
          'Journey',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed:
                _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _error != null
              ? _errorBody()
              : _journey == null
                  ? _emptyBody()
                  : _journeyBody(),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Please try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text(
                'TRY AGAIN',
                style: TextStyle(fontSize: 18),
              ),
            ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore,
              size: 80,
              color: Colors.blue.shade200,
            ),
            const SizedBox(height: 20),
            const Text(
              'No active journey',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your caregiver can create a journey for you. '
              'It will appear here when you need to go somewhere.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _journeyBody() {
    final dest =
        _journey!['destination_name']
            ?.toString() ??
        '';
    final purpose =
        _journey!['purpose']?.toString() ?? '';
    final instruction =
        _journey!['instruction']
            ?.toString() ??
        '';
    final status =
        _journey!['status']?.toString() ??
        'active';
    final address =
        _journey!['destination_address']
            ?.toString() ??
        '';
    final dist =
        _journey!['distance_to_destination_m'];
    final steps =
        _journey!['steps'] as List? ?? [];
    final currentStep =
        _journey!['current_step'] ?? 0;
    final hint =
        _journey!['internal_location_hint']
            ?.toString() ??
        '';

    String distText = '';
    if (dist != null && dist is num) {
      final metres = dist.toInt();
      if (metres < 1000) {
        distText = '$metres m away';
      } else {
        distText =
            '${(metres / 1000).toStringAsFixed(1)} km away';
      }
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 10),

          Center(
            child: Icon(
              Icons.explore,
              size: 50,
              color: Colors.blue.shade400,
            ),
          ),

          const SizedBox(height: 16),

          Center(
            child: Text(
              "TODAY'S JOURNEY",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
                letterSpacing: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ============================================================
          // CONTEXT CARD — Main destination info
          // ============================================================

          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.place,
                        size: 30,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          dest,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding:
                          const EdgeInsets.only(
                            left: 40,
                          ),
                      child: Text(
                        address,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors
                              .grey.shade600,
                        ),
                      ),
                    ),
                  ],
                  if (purpose.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(
                          Icons.task_alt,
                          size: 26,
                          color: Colors.green,
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: Text(
                            'You are here to $purpose',
                            style:
                                const TextStyle(
                                  fontSize: 20,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (instruction.isNotEmpty &&
                      instruction != purpose) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding:
                          const EdgeInsets.only(
                            left: 36,
                          ),
                      child: Text(
                        instruction,
                        style: TextStyle(
                          fontSize: 15,
                          color:
                              Colors.grey.shade700,
                          fontStyle:
                              FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ============================================================
          // STATUS CARD
          // ============================================================

          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    status == 'arrived'
                        ? Icons.check_circle
                        : status ==
                                'near_destination'
                            ? Icons.near_me
                            : Icons
                                .directions_walk,
                    size: 28,
                    color: status == 'arrived'
                        ? Colors.green
                        : status ==
                                'near_destination'
                            ? Colors.orange
                            : Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusLabel(status),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        if (distText.isNotEmpty) ...[
                          const SizedBox(
                            height: 2,
                          ),
                          Text(
                            distText,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors
                                  .grey.shade600,
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

          // ============================================================
          // TASK STEPS (if available)
          // ============================================================

          if (steps.isNotEmpty) ...[
            const SizedBox(height: 14),
            Card(
              elevation: 0,
              color:
                  Colors.indigo.shade50,
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TASK STEPS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.bold,
                        letterSpacing: 1,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...steps
                        .asMap()
                        .entries
                        .map(
                          (entry) {
                            final idx =
                                entry.key;
                            final step =
                                entry.value
                                    .toString();
                            final isCompleted =
                                idx < currentStep;
                            final isCurrent =
                                idx == currentStep;

                            return Padding(
                              padding:
                                  const EdgeInsets
                                      .only(
                                        bottom: 6,
                                      ),
                              child: Row(
                                children: [
                                  Icon(
                                    isCompleted
                                        ? Icons
                                            .check_circle
                                        : isCurrent
                                            ? Icons
                                                .radio_button_checked
                                            : Icons
                                                .radio_button_unchecked,
                                    size: 22,
                                    color:
                                        isCompleted
                                            ? Colors
                                                .green
                                            : isCurrent
                                                ? Colors
                                                    .indigo
                                                : Colors
                                                    .grey,
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  Expanded(
                                    child: Text(
                                      step,
                                      style:
                                          TextStyle(
                                            fontSize: 16,
                                            fontWeight:
                                                isCurrent
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                            color:
                                                isCompleted
                                                    ? Colors.grey
                                                    : Colors.black87,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  ],
                ),
              ),
            ),
          ],

          // ============================================================
          // INTERNAL LOCATION HINT
          // ============================================================

          if (hint.isNotEmpty &&
              status == 'arrived') ...[
            const SizedBox(height: 14),
            Card(
              elevation: 0,
              color: Colors.green.shade50,
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      size: 26,
                      color:
                          Colors.green.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Look for: $hint',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                          color: Colors
                              .green.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (_timeCheck() != null) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: Colors.amber.shade50,
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 26,
                      color:
                          Colors.amber.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _timeCheck()!,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors
                              .amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ============================================================
          // MAIN ACTION BUTTONS
          // ============================================================

          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: _whyAmIHere,
              icon: const Icon(
                Icons.help_outline,
                size: 26,
              ),
              label: const Text(
                'WHY AM I HERE?',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _whereAmI,
              icon: const Icon(
                Icons.my_location,
                size: 24,
              ),
              label: const Text(
                'WHERE AM I?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _whatNext,
              icon: const Icon(
                Icons.arrow_forward,
                size: 24,
              ),
              label: const Text(
                'WHAT DO I DO NEXT?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _imConfused,
              icon: const Icon(
                Icons.favorite,
                size: 24,
              ),
              label: const Text(
                "I'M CONFUSED",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.pink.shade400,
                foregroundColor: Colors.white,
              ),
            ),
          ),

          if (status == 'arrived') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _completeJourney,
                icon: const Icon(
                  Icons.check_circle,
                  size: 24,
                ),
                label: const Text(
                  "I'M DONE",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style:
                    ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.green,
                      foregroundColor:
                          Colors.white,
                    ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          Card(
            elevation: 0,
            child: Padding(
              padding:
                  const EdgeInsets.all(16),
              child: Text(
                "This journey was created by your caregiver "
                "to help you. You're doing great.",
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
