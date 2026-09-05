import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';

class JourneyMapScreen extends StatefulWidget {
  final String token;
  final String journeyId;
  final String journeyName;

  const JourneyMapScreen({
    super.key,
    required this.token,
    required this.journeyId,
    required this.journeyName,
  });

  @override
  State<JourneyMapScreen> createState() => _JourneyMapScreenState();
}

class _JourneyMapScreenState extends State<JourneyMapScreen> {
  final MapController _mapController = MapController();
  Map<String, dynamic>? _journey;
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshSilent(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() { _loading = true; });
    }

    try {
      final result = await ApiService.getJourney(
        widget.token,
        widget.journeyId,
      );

      if (!mounted) return;

      final journey = result['journey'];
      setState(() {
        _journey = journey is Map ? Map<String, dynamic>.from(journey) : null;
        _loading = false;
      });

      _fitBounds();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; });
    }
  }

  Future<void> _refreshSilent() async {
    try {
      final result = await ApiService.getJourney(
        widget.token,
        widget.journeyId,
      );

      if (!mounted) return;

      final journey = result['journey'];
      if (journey is Map) {
        setState(() {
          _journey = Map<String, dynamic>.from(journey);
        });
      }
    } catch (_) {}
  }

  LatLng? _destinationLatLng() {
    if (_journey == null) return null;
    final lat = (_journey!['destination_latitude'] as num?)?.toDouble();
    final lng = (_journey!['destination_longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? _patientLatLng() {
    if (_journey == null) return null;
    final lat = (_journey!['last_latitude'] as num?)?.toDouble();
    final lng = (_journey!['last_longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  void _fitBounds() {
    final dest = _destinationLatLng();
    final patient = _patientLatLng();

    if (dest != null && patient != null) {
      final bounds = LatLngBounds.fromPoints([patient, dest]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(60),
        ),
      );
    } else if (dest != null) {
      _mapController.move(dest, 15);
    }
  }

  void _openExternal() {
    final dest = _destinationLatLng();
    final patient = _patientLatLng();

    if (patient != null && dest != null) {
      final url = Uri.parse(
        'https://www.openstreetmap.org/directions'
        '?from=${patient.latitude},${patient.longitude}'
        '&to=${dest.latitude},${dest.longitude}',
      );
      launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (dest != null) {
      final url = Uri.parse(
        'https://www.openstreetmap.org/?mlat=${dest.latitude}&mlon=${dest.longitude}#map=16/${dest.latitude}/${dest.longitude}',
      );
      launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.journeyName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _openExternal,
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in browser',
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _journey == null
              ? const Center(child: Text('Journey not found'))
              : _mapBody(),
    );
  }

  Widget _mapBody() {
    final dest = _destinationLatLng();
    final patient = _patientLatLng();
    final center = dest ?? const LatLng(30.08, 78.68);

    final destName = _journey!['destination_name']?.toString() ?? '';
    final status = _journey!['status']?.toString() ?? 'active';
    final dist = _journey!['distance_to_destination_m'];

    String distText = '';
    if (dist != null && dist is num) {
      final metres = dist.toInt();
      distText = metres < 1000 ? '$metres m' : '${(metres / 1000).toStringAsFixed(1)} km';
    }

    return Column(
      children: [
        Expanded(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sih.cognitivecare',
              ),
              MarkerLayer(
                markers: [
                  if (dest != null)
                    Marker(
                      point: dest,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  if (patient != null)
                    Marker(
                      point: patient,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.green,
                        size: 40,
                      ),
                    ),
                ],
              ),
              if (dest != null && patient != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [patient, dest],
                      color: Colors.blue.withValues(alpha: 0.6),
                      strokeWidth: 4,
                    ),
                  ],
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    status == 'arrived' ? Icons.check_circle : Icons.place,
                    color: status == 'arrived' ? Colors.green : Colors.red,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          destName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (distText.isNotEmpty)
                          Text(
                            'Distance: $distText',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (patient != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 10, color: Colors.green),
                          const SizedBox(width: 6),
                          Text(
                            'Live',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _fitBounds,
                      icon: const Icon(Icons.center_focus_strong),
                      label: const Text(
                        'CENTER',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openExternal,
                      icon: const Icon(Icons.directions),
                      label: const Text(
                        'DIRECTIONS',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
