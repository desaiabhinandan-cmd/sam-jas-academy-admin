import 'dart:convert';
import 'package:flutter/material.dart'; 
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:googleapis_auth/auth_io.dart' as auth;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    print("🔔 NOTIFICATION SERVICE: Initializing...");
    
    tz.initializeTimeZones();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    String? token = await FirebaseMessaging.instance.getToken();
    print("🚀 FCM DEVICE TOKEN: $token");

    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick(initialMessage.data['screen']);
    }

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message.data['screen']);
    });

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings();
    
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _handleNotificationClick(response.payload!);
        }
      },
    );

    // Android Notification Channel setup for High Importance
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'admin_channel', // CRITICAL: This ID must stay consistent
      'Admin Updates',
      description: 'Notifications from Academy Admin',
      importance: Importance.max, 
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Foreground listening logic
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      
      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id, // Links to 'admin_channel'
              channel.name,
              channelDescription: channel.description,
              importance: Importance.max,
              priority: Priority.high,
              ticker: 'ticker',
              // Ensured launcher icon is used for popup
              icon: '@mipmap/launcher_icon', 
            ),
          ),
          payload: message.data['screen'], 
        );
      }
    });

    await FirebaseMessaging.instance.subscribeToTopic('all_students');
  }

  static void _handleNotificationClick(String? payload) {
    if (payload == null) return;
    if (payload == 'cart_screen') {
      navigatorKey.currentState?.pushNamed('/cart');
    } else if (payload == 'course_list') {
      navigatorKey.currentState?.pushNamed('/courses');
    } else if (payload == 'dashboard_screen') {
      navigatorKey.currentState?.pushNamed('/dashboard');
    }
  }

  static Future<String> _getAccessToken() async {
    final String response = await rootBundle.loadString('assets/service-account.json');
    final data = json.decode(response);
    final credentials = auth.ServiceAccountCredentials.fromJson(data);
    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    final client = await auth.clientViaServiceAccount(credentials, scopes);
    final authCredentials = await auth.obtainAccessCredentialsViaServiceAccount(credentials, scopes, client);
    client.close();
    return authCredentials.accessToken.data;
  }

  static Future<void> sendDirectMessage({
    required String token, 
    required String title, 
    required String body, 
    String? payload
  }) async {
    try {
      final String accessToken = await _getAccessToken();
      final String responseAsset = await rootBundle.loadString('assets/service-account.json');
      final String projectId = json.decode(responseAsset)['project_id'];
      final url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': token,
            'notification': {'title': title, 'body': body},
            'data': {'screen': payload ?? 'home'},
            'android': {
              'priority': 'high',
              'notification': {'channel_id': 'admin_channel'},
            },
          },
        }),
      );
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  static Future<void> sendBroadcast({
    required String title, 
    required String body, 
    String? topic, 
    String? screenPayload
  }) async {
    try {
      final String accessToken = await _getAccessToken();
      final String responseAsset = await rootBundle.loadString('assets/service-account.json');
      final String projectId = json.decode(responseAsset)['project_id'];
      final url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'topic': topic ?? 'all_students', 
            'notification': {'title': title, 'body': body},
            'data': {
              'screen': screenPayload ?? 'home',
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            },
            'android': {
              'priority': 'high',
              'notification': {
                'channel_id': 'admin_channel',
                'sound': 'default', 
              },
            },
          },
        }),
      );
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  static Future<void> scheduleCartReminder() async {
    await _localNotifications.zonedSchedule(
      0,
      'Your Cart is Waiting! ✨',
      'Finish your enrollment today.',
      tz.TZDateTime.now(tz.local).add(const Duration(hours: 24)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'cart_reminders', 
          'Cart Reminders', 
          importance: Importance.max, 
          priority: Priority.high,
        ),
      ),
      payload: 'cart_screen', 
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}