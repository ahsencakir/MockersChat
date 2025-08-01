import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:developer';

class FirebaseService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;


  /// 📌 Firestore'a token kaydet (Kullanıcı varsa)
  Future<void> _saveTokenToFirestore() async {
    try {
      String? userId = _auth.currentUser?.uid;
      String? token = await _firebaseMessaging.getToken();
      if (userId != null && token != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
        });
        log("✅ FCM token Firestore'a kaydedildi: $token");
      } else {
        log("❌ Kullanıcı yok veya token alınamadı.");
      }
    } catch (e) {
      log("🔥 Token kaydetme hatası: $e");
    }
  }

  /// 📌 Token değişimlerini dinle ve güncelle
  void setupFCMListeners() {
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      String? userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': newToken,
        });
        log("🔄 Yeni FCM token kaydedildi: $newToken");
      }
    });
  }

  /// 📌 Kullanıcı giriş yapınca token kaydet + listener başlat
  Future<User?> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      await _saveTokenToFirestore(); // 🔥 Token kaydet
      setupFCMListeners(); // 🔥 Listener başlat
      return result.user;
    } catch (e) {
      log("❌ Giriş hatası: $e");
      return null;
    }
  }

  /// 📌 Kayıt olunca token kaydet + listener başlat
  Future<User?> register(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await _saveTokenToFirestore(); // 🔥 Token kaydet
      setupFCMListeners(); // 🔥 Listener başlat
      return result.user;
    } catch (e) {
      log("❌ Kayıt hatası: $e");
      return null;
    }
  }

  /// 📌 Grup Oluşturma
  Future<String?> createGroup(String groupName) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return null;

      DocumentReference groupRef = await _firestore.collection('groups').add({
        'name': groupName,
        'admin': user.uid,
        'members': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
      });

      return groupRef.id;
    } catch (e) {
      log("🔥 Grup oluşturma hatası: $e");
      return null;
    }
  }

  /// 📌 Gruba Üye Ekleme (Admin)
  Future<void> addMemberToGroup(String groupId, String userId) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      DocumentSnapshot groupDoc =
      await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return;

      Map<String, dynamic> groupData =
      groupDoc.data() as Map<String, dynamic>;
      if (groupData['admin'] != user.uid) {
        log("❌ Yalnızca admin üye ekleyebilir.");
        return;
      }

      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([userId]),
      });

      log("✅ Kullanıcı gruba eklendi!");
    } catch (e) {
      log("🔥 Üye ekleme hatası: $e");
    }
  }

  /// 📌 Grubu Silme (Admin)
  Future<void> deleteGroup(String groupId) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      DocumentSnapshot groupDoc =
      await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return;

      Map<String, dynamic> groupData =
      groupDoc.data() as Map<String, dynamic>;
      if (groupData['admin'] != user.uid) {
        log("❌ Yalnızca admin grubu silebilir.");
        return;
      }

      var messages = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .get();
      for (var doc in messages.docs) {
        await doc.reference.delete();
      }

      await _firestore.collection('groups').doc(groupId).delete();
      log("✅ Grup başarıyla silindi!");
    } catch (e) {
      log("🔥 Grup silme hatası: $e");
    }
  }

  /// 📌 Gruba Üye Çıkarma (Admin)
  Future<void> removeMemberFromGroup(String groupId, String userId) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      DocumentSnapshot groupDoc =
      await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return;

      Map<String, dynamic> groupData =
      groupDoc.data() as Map<String, dynamic>;
      if (groupData['admin'] != user.uid) {
        log("❌ Yalnızca admin kullanıcı çıkarabilir.");
        return;
      }

      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayRemove([userId]),
      });

      log("✅ Kullanıcı gruptan çıkarıldı!");
    } catch (e) {
      log("🔥 Üye çıkarma hatası: $e");
    }
  }

  /// 📌 Mesaj Gönderme
  Future<void> sendMessage(String groupId, String messageText) async {
    if (messageText.trim().isEmpty) return;

    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      DocumentSnapshot userDoc =
      await _firestore.collection('users').doc(user.uid).get();
      String senderNickname = userDoc.exists
          ? (userDoc['nickname'] ?? "Bilinmeyen Kullanıcı")
          : "Bilinmeyen Kullanıcı";

      CollectionReference messageCollection = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages');

      await messageCollection.add({
        'senderId': user.uid,
        'senderNickname': senderNickname,
        'messageText': messageText,
        'timestamp': FieldValue.serverTimestamp(),
      });

      log("✅ Mesaj başarıyla gönderildi!");
    } catch (e) {
      log("🔥 Mesaj gönderme hatası: $e");
    }
  }

  /// 📌 Mesajları Çekme
  Stream<QuerySnapshot> getMessages(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
/// 📌 Belirli bir grup için okunmamış mesaj sayısını döndürür
Future<int> getUnreadMessageCount(String groupId) async {
  String userId = FirebaseAuth.instance.currentUser!.uid;

  // Kullanıcının bu grup için lastSeen tarihi
  DocumentSnapshot lastSeenDoc = await FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .collection('lastSeen')
      .doc(userId)
      .get();

  Timestamp? lastSeen;
  if (lastSeenDoc.exists) {
    lastSeen = (lastSeenDoc.data() as Map<String, dynamic>)['lastSeen'];
  } else {
    // Eğer lastSeen yoksa kullanıcı hiç bakmamış demektir → Tüm mesajlar okunmamış
    lastSeen = null;
  }

  Query query = FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .collection('messages');

  if (lastSeen != null) {
    query = query.where('timestamp', isGreaterThan: lastSeen);
  }

  QuerySnapshot newMessages = await query.get();

  return newMessages.docs.length;
}



