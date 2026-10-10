import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Controls the Android-only Federal Bank SMS import receiver.
class SmsImportService {
  static const _channel = MethodChannel(
    'com.tracker.expense_tracker/sms_import',
  );

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> get isEnabled async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Returns true when SMS permission was granted and import was enabled.
  static Future<bool> enable() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('enable') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> disable() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('disable');
    } on PlatformException {
      // Keep the app usable if the platform channel is unavailable.
    }
  }
}
