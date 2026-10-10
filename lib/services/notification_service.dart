import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../models/monthly_budget.dart';
import '../models/transaction.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  static bool _foregroundListenerRegistered = false;

  static void showBudgetAlert({required MonthlyBudget budget, required int threshold}) {
    final amount = budget.currency.symbol + budget.amount.toStringAsFixed(0);
    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(threshold == 100 ? 'Budget reached: $amount for ${budget.category?.displayName ?? 'this month'}.' : 'Budget alert: 80% of $amount used for ${budget.category?.displayName ?? 'this month'}.'), behavior: SnackBarBehavior.floating));
  }

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
