import 'dart:convert';

import 'package:flutter/services.dart';

class SmsMessage {
  final int id;
  final String address;
  final String body;
  final DateTime date;
  final bool read;

  SmsMessage({
    required this.id,
    required this.address,
    required this.body,
    required this.date,
    required this.read,
  });

  factory SmsMessage.fromMap(Map<String, dynamic> map) {
    return SmsMessage(
      id: map['id'] is int ? map['id'] : int.tryParse('${map['id']}') ?? 0,
      address: map['address']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(
        map['date'] is int ? map['date'] : int.tryParse('${map['date']}') ?? 0,
      ),
      read: map['read'] == true,
    );
  }
}

class SmsReaderService {
  static const MethodChannel _channel =
      MethodChannel('com.smiriti.sarthi/sms_reader');

  static final SmsReaderService _instance = SmsReaderService._();
  factory SmsReaderService() => _instance;
  SmsReaderService._();

  Future<bool> hasPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasSmsPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      await _channel.invokeMethod('requestSmsPermission');
      await Future.delayed(const Duration(seconds: 2));
      return await hasPermission();
    } on PlatformException {
      return false;
    }
  }

  Future<List<SmsMessage>> readAllSms({int limit = 200}) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'readAllSms',
        {'limit': limit},
      );

      if (result == null || result.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(result);
      return jsonList
          .map((item) => SmsMessage.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } on PlatformException {
      return [];
    }
  }
}
