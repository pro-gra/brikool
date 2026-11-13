import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background: ${message.notification?.title}');
}

const _vapidKey = 'BAksInzGik5fyRrJefHVhoqVZz9RYxfq14r06BLHGTHNwnncw4VQH_o9qv3rTL7nxqpPfUsKEwG7Wf4crO8viAc';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  factory NotificationService() => instance;

  final _messaging = FirebaseMessaging.instance;
  bool _initialized = false;
  bool _navigationWired = false;
  String? _initializedUid;

  final Map<String, Widget Function(String requestId)> _routes = {};

  void registerRoute(String type, Widget Function(String requestId) builder) {
    _routes[type] = builder;
  }

Future<void> init({
  required String uid,
  required String collection,
}) async {
  // ← زيد هاد
  if (kIsWeb && !kReleaseMode) {
    debugPrint('[FCM] Skipping on Web debug/localhost');
    return;
  }
  
  // ← إلا uid مختلف — reset كامل
  if (_initializedUid != null && _initializedUid != uid) {
    debugPrint('[FCM] New uid detected — resetting');
    _initializedUid = null;
    _initialized = false;
  }
  
  // ... باقي الكود

    try {
      // Step 1: request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] ❌ Permission DENIED');
        return;
      }

      // Step 2: get token
      // على الـ Web نستعمل VAPID key، على mobile بدونو
      String? token;
      try {
        token = kIsWeb
            ? await _messaging.getToken(vapidKey: _vapidKey)
            : await _messaging.getToken();
      } catch (e) {
        debugPrint('[FCM] ❌ getToken() failed: $e');
        // على الـ Web إلا فشل — ما نوقفوش
        if (!kIsWeb) return;
      }

      if (token != null) {
        debugPrint('[FCM] ✅ Token: ...${token.substring(token.length - 16)}');
        await _saveToken(
          token: token,
          uid: uid,
          collection: collection,
          platform: kIsWeb ? 'web' : 'mobile',
        );

        // Refresh token
        _messaging.onTokenRefresh.listen((newToken) async {
          debugPrint('[FCM] Token refreshed');
          await _saveToken(
            token: newToken,
            uid: uid,
            collection: collection,
            platform: kIsWeb ? 'web' : 'mobile',
          );
        });
      }

      // Step 3: foreground handler (once globally)
      if (!_initialized) {
        _initialized = true;
        FirebaseMessaging.onMessage.listen((message) {
          debugPrint('[FCM] Foreground: ${message.notification?.title}');
          _showSnackbar(message);
        });

        // على الـ Web — كيخلي الـ tab active
        if (kIsWeb) {
          await _messaging.setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
        }
      }

      // Step 4: navigation
      _wireNavigation();
      _initializedUid = uid;

    } catch (e, stack) {
      debugPrint('[FCM] ❌ init() error: $e\n$stack');
    }
  }

Future<void> _saveToken({
  required String token,
  required String uid,
  required String collection,
  required String platform,
}) async {
  try {
    debugPrint('[FCM] Attempting save to $collection/$uid/private/notifications');
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(uid)
        .collection('private')
        .doc('notifications')
        .set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
      'platform': platform,
    }, SetOptions(merge: true));
    debugPrint('[FCM] ✅ Token saved to $collection/$uid/private/notifications ($platform)');
  } catch (e, stack) {
    debugPrint('[FCM] ❌ _saveToken error: $e');
    debugPrint('[FCM] ❌ Stack: $stack');
  }
}

  void _showSnackbar(RemoteMessage message) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    final title = message.notification?.title ?? 'Brikol.ma';
    final body = message.notification?.body ?? '';
    final data = message.data;

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0c1c13),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF0e8050),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                  if (body.isNotEmpty) Text(body,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            if (data.isNotEmpty)
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
                  _navigate(data);
                },
                child: const Text('Voir',
                    style: TextStyle(color: Color(0xFF7cf2ae), fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
      ),
    );
  }

  void _wireNavigation() {
    if (_navigationWired) return;
    _navigationWired = true;

    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      debugPrint('[FCM] Tapped (background): ${m.data}');
      _navigate(m.data);
    });

    _messaging.getInitialMessage().then((m) {
      if (m == null) return;
      debugPrint('[FCM] Tapped (terminated): ${m.data}');
      Future.delayed(const Duration(milliseconds: 800), () => _navigate(m.data));
    });
  }

  void _navigate(Map<String, dynamic> data) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    final type = data['type'] as String? ?? '';
    final requestId = data['requestId'] as String? ?? '';
    final builder = _routes[type];
    if (builder != null && requestId.isNotEmpty) {
      Navigator.of(ctx, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => builder(requestId)),
      );
    }
  }

  Future<void> clearToken(String collection, String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(uid)
          .collection('private')
          .doc('notifications')
          .set({'fcmToken': FieldValue.delete()}, SetOptions(merge: true));
      debugPrint('[FCM] Token cleared from $collection/$uid/private/notifications');
    } catch (e) {
      debugPrint('[FCM] clearToken error: $e');
    } finally {
      _initializedUid = null;
    }
  }
}