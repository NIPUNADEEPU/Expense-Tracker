import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  static bool _foregroundListenerRegistered = false;

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.subscribeToTopic('spending-reminders');
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (!_foregroundListenerRegistered) {
      _foregroundListenerRegistered = true;
      FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification == null) return;
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              notification.body == null
                  ? notification.title ?? 'New SpendSense reminder'
                  : '${notification.title ?? 'SpendSense'}: ${notification.body}',
            ),
          ),
        );
      });
    }
  }

  static Future<void> registerCurrentUserDevice() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(uid, token);
    }
    _messaging.onTokenRefresh.listen((token) => _saveToken(uid, token));
  }

  static Future<void> _saveToken(String uid, String token) {
    return FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmToken': token,
      'notificationsEnabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
