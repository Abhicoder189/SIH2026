import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Timer? _pollTimer;
  int _lastUnreadCount = 0;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      try {
        jsonDecode(payload);
      } catch (_) {}
    }
  }

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'smriti_sarthi_main',
      'SmritiSarthi Notifications',
      channelDescription: 'Notifications from SmritiSarthi',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  Future<void> showSmartEventNotification({
    required String eventId,
    required String title,
    required String message,
  }) async {
    final payload = jsonEncode({
      'type': 'smart_event',
      'event_id': eventId,
    });

    await showLocalNotification(
      id: eventId.hashCode,
      title: title,
      body: message,
      payload: payload,
    );
  }

  Future<void> showReminderNotification({
    required String reminderId,
    required String title,
    required String message,
  }) async {
    final payload = jsonEncode({
      'type': 'reminder',
      'reminder_id': reminderId,
    });

    await showLocalNotification(
      id: reminderId.hashCode,
      title: title,
      body: message,
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  void startPolling({
    required String token,
    required String patientId,
    Duration interval = const Duration(minutes: 2),
  }) {
    stopPolling();

    _checkUnreadCount(token, patientId);

    _pollTimer = Timer.periodic(interval, (_) {
      _checkUnreadCount(token, patientId);
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _checkUnreadCount(String token, String patientId) async {
    try {
      final result = await ApiService.getUnreadNotificationCount(
        token: token,
      );

      final count = result['unread_count'] as int? ?? 0;

      if (count > _lastUnreadCount && _lastUnreadCount > 0) {
        final newCount = count - _lastUnreadCount;
        await showLocalNotification(
          id: 0,
          title: 'SmritiSarthi',
          body: newCount == 1
              ? 'You have a new notification'
              : 'You have $newCount new notifications',
        );
      }

      _lastUnreadCount = count;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('unread_notification_count', count);
    } catch (_) {}
  }

  Future<int> getUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('unread_notification_count') ?? 0;
  }

  void dispose() {
    stopPolling();
  }
}
