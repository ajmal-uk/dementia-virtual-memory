// lib/utils/notification_helper.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

Future<void> sendNotification(List<String> playerIds, String content) async {
  if (playerIds.isEmpty) return;

  const appId = '73673a14-2de9-44c4-a9c5-dd531da39b59';
  const apiKey = 'os_v2_app_onttufbn5fcmjkof3vjr3i43lhrirnuaeujum3mksb5gtjrhjnq7fj2wbm4rjwmg3kyo4ikoqvmiyv5rm5pxgqjx46gd37w3fvc2yey';

  try {
    final response = await http.post(
      Uri.parse('https://onesignal.com/api/v1/notifications'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Basic $apiKey',
      },
      body: jsonEncode({
        'app_id': appId,
        'include_player_ids': playerIds,
        'contents': {'en': content},
        'priority': 10,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      print('Failed to send notification: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print('Error sending notification: $e');
  }
}

Future<void> scheduleNotification(List<String> playerIds, String content, DateTime scheduledTime) async {
  if (playerIds.isEmpty) return;

  const appId = '73673a14-2de9-44c4-a9c5-dd531da39b59';
  const apiKey = 'os_v2_app_onttufbn5fcmjkof3vjr3i43lhrirnuaeujum3mksb5gtjrhjnq7fj2wbm4rjwmg3kyo4ikoqvmiyv5rm5pxgqjx46gd37w3fvc2yey';

  final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(scheduledTime.toUtc()) + ' UTC';

  try {
    final response = await http.post(
      Uri.parse('https://onesignal.com/api/v1/notifications'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Basic $apiKey',
      },
      body: jsonEncode({
        'app_id': appId,
        'include_player_ids': playerIds,
        'contents': {'en': content},
        'send_after': formattedTime,
        'priority': 10,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      print('Failed to schedule notification: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print('Error scheduling notification: $e');
  }
}