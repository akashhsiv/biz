import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../network/api_client.dart';

/// Best-effort FCM device-token registration, scaffolded ahead of an actual Firebase project being
/// wired up. Call once after a successful login (see AuthController.login) - never awaited by
/// anything that would block sign-in, and wrapped so nothing here can crash the app or surface an
/// error to the user.
///
/// Firebase.initializeApp() will throw today: there's no google-services.json (Android) or
/// GoogleService-Info.plist (iOS)/firebase_options.dart configured yet. That's expected until a real
/// Firebase project is created - this silently no-ops in that case rather than failing login.
Future<void> registerDeviceTokenForPush(ApiClient api) async {
  try {
    await Firebase.initializeApp();

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[PushRegistration] FirebaseMessaging.getToken() returned null - skipping device-token registration.');
      return;
    }

    final platform = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'windows');

    final result = await api.post<void>(
      '/api/notifications/device-tokens',
      (_) {},
      body: {'token': token, 'platform': platform},
    );
    debugPrint('[PushRegistration] device-token registration result: $result');
  } catch (e) {
    // Expected until Firebase is actually configured (no google-services.json/GoogleService-
    // Info.plist/firebase_options.dart) - never let this block or crash login.
    debugPrint('[PushRegistration] skipped (Firebase not configured or unavailable): $e');
  }
}
