import 'dart:developer';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseNotificationService {
  late final FirebaseMessaging messaging;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // 🔹 Local Notification ayarlarını başlat
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: androidSettings);

    await _localNotificationsPlugin.initialize(initSettings);
  }

  // 🔹 Local Notification göster
  Future<void> _showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel', // AndroidManifest.xml’de tanımlı olmalı
      'Mockers Chat',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails =
    NotificationDetails(android: androidDetails);

    await _localNotificationsPlugin.show(
      message.notification.hashCode,
      message.notification?.title ?? 'Yeni Mesaj',
      message.notification?.body ?? '',
      platformDetails,
    );
  }

  // 🔹 Bildirim izinlerini ayarla
  Future<void> settingNotification() async {
    await messaging.requestPermission(
      alert: true,
      sound: true,
      badge: true,
    );
  }

  // 🔹 Bildirim servislerini başlat
  Future<void> connectNotification() async {
    await Firebase.initializeApp();
    messaging = FirebaseMessaging.instance;

    await settingNotification(); // izinleri al
    await _initializeLocalNotifications(); // local notification başlat

    messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      sound: true,
      badge: true,
    );

    // 🔹 ÖN PLANDA: Bildirim alındığında logla + göster
    FirebaseMessaging.onMessage.listen((RemoteMessage event) {
      log("📩 Gelen Bildirim: ${event.notification?.title}");
      _showNotification(event); // bildirimi göster
    });

    // 🔹 ARKA PLAN: Bildirim dinle
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 🔥 Firebase Token'ı Firestore'a kaydet
    messaging.getToken().then((value) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null && value != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'fcmToken': value,
        });
        log("✅ FCM Token Firestore'a kaydedildi: $value");
      } else {
        log("❌ Kullanıcı ID veya token yok.");
      }
    }).catchError((error) {
      log("⚠️ Token alınırken hata oluştu: $error");
    });
  }
}

// 🔹 Arka planda çalışan mesajları yakala
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  log("📩 (Background) Bildirim: ${message.notification?.title}");
}
