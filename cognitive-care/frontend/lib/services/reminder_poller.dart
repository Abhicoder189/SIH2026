import 'dart:async';

import '../services/api_service.dart';

class ReminderPoller {
  Timer? _timer;

  final String token;
  final String patientId;

  ReminderPoller({
    required this.token,
    required this.patientId,
  });

  void start({
    Duration interval = const Duration(minutes: 1),
    required void Function(Map<String, dynamic> data) onUpdate,
    void Function(Object error)? onError,
  }) {
    stop();

    Future<void> check() async {
      try {
        final data = await ApiService.getNotificationFeed(
          token,
          patientId,
        );

        onUpdate(data);
      } catch (error) {
        onError?.call(error);
      }
    }

    check();

    _timer = Timer.periodic(interval, (_) {
      check();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
  }
}