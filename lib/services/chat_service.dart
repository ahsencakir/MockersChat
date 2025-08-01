import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:googleapis_auth/auth_io.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🔹 Mesaj gönderme + Bildirim gönderme
  Future<void> sendMessage({
    required String message,
    required String senderId,
    required String receiverId,
  }) async {
    // 🔥 Mesajı Firestore'a kaydet
    await _firestore.collection('messages').add({
      'text': message,
      'sender': senderId,
      'receiver': receiverId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 🔔 Bildirim gönder
    await sendPushNotification(receiverId, message);
  }

  /// 🔔 Push bildirimi gönder (FCM V1 API ile)
  Future<void> sendPushNotification(String receiverId, String messageText) async {
    // 1️⃣ Alıcının FCM tokenını Firestore'dan çek
    final userDoc =
    await _firestore.collection('users').doc(receiverId).get();

    if (!userDoc.exists) {
      print('❌ Kullanıcı bulunamadı: $receiverId');
      return;
    }

    final fcmToken = userDoc.data()?['fcmToken'];
    if (fcmToken == null) {
      print('❌ Kullanıcının FCM tokenı yok.');
      return;
    }

    // 2️⃣ Bildirimi gönder
    await sendFCMV1Notification(
      receiverToken: fcmToken,
      messageBody: messageText,
      serviceAccountJsonPath: 'C:/Users/Ahsen/Downloads/balikmezhebi.json', // BURAYA KENDİ JSON DOSYANI KOY
    );
  }

  /// 🔥 FCM V1 API Bildirim gönderme
  Future<void> sendFCMV1Notification({
    required String receiverToken,
    required String messageBody,
    required String serviceAccountJsonPath,
  }) async {
    // JSON dosyasını oku
    final jsonKey = ServiceAccountCredentials.fromJson(
        json.decode(File(serviceAccountJsonPath).readAsStringSync()));

    // Google Cloud Messaging scope
    const scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

    // Auth client al
    final client = await clientViaServiceAccount(jsonKey, scopes);

    final url = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/balikmezhebi/messages:send');

    final body = {
      'message': {
        'token': receiverToken,
        'notification': {
          'title': 'Yeni Mesaj',
          'body': messageBody,
        },
      }
    };

    final response = await client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      print('✅ Bildirim gönderildi!');
    } else {
      print('❌ Bildirim hatası: ${response.body}');
    }

    client.close();
  }
}
