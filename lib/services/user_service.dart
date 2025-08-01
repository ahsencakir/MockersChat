import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class UserService with WidgetsBindingObserver {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSubscription;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  UserService._internal() {
    _authSubscription = _auth.authStateChanges().listen(_handleAuthChange);
    WidgetsBinding.instance.addObserver(this);
    listenForTokenChanges(); // ✅ Token değişimlerini dinle
  }

  /// 🔐 Kullanıcının FCM Token'ını Firestore'a kaydet
  Future<void> saveUserToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      String? userId = _auth.currentUser?.uid;

      if (token != null && userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
        });
        print("✅ FCM Token kaydedildi: $token");
      } else {
        print("❗ Kullanıcı veya token bulunamadı.");
      }
    } catch (e) {
      print("🔥 Token kaydederken hata: $e");
    }
  }

  /// 🔄 Token değişirse güncelle
  void listenForTokenChanges() {
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      String? userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': newToken,
        });
        print("🔄 Yeni FCM Token kaydedildi: $newToken");
      }
    });
  }

  /// 🔛 Kullanıcıyı çevrimiçi yap
  Future<void> setUserOnline() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': true,
      });
      await saveUserToken(); // ✅ Token güncelle
      await _updateUserStatusInGroups(user.uid, online: true);
    } catch (e) {
      print("🔥 Çevrimiçi yaparken hata: $e");
    }
  }

  /// 🔕 Kullanıcıyı çevrimdışı yap — TOKEN ARTIK SİLİNMİYOR!!!
  Future<void> setUserOffline() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        print("⚠ Kullanıcı zaten çıkış yapmış.");
        return;
      }

      print("🔄 ${user.uid} çevrimdışı yapılıyor...");

      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      await _updateUserStatusInGroups(user.uid, online: false);

      print("✅ ${user.uid} başarıyla çevrimdışı yapıldı.");
    } catch (e) {
      print("🔥 Çevrimdışı yaparken hata: $e");
    }
  }

  /// 🔥 ÇIKIŞ YAPILIRSA TOKEN'I SİL
  Future<void> signOut() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      print("🧹 Kullanıcı çıkış yaptı. Token silindi.");
    }
    await _auth.signOut();
  }

  /// 🔄 Kullanıcının grup bilgilerini güncelle
  Future<void> _updateUserStatusInGroups(String userId, {required bool online}) async {
    try {
      var groupsSnapshot = await _firestore
          .collection('groups')
          .where('members', arrayContains: userId)
          .get();

      for (var group in groupsSnapshot.docs) {
        await group.reference.update({
          'onlineMembers': online
              ? FieldValue.arrayUnion([userId])
              : FieldValue.arrayRemove([userId]),
        });
      }
    } catch (e) {
      print("🔥 Grup durumu güncellenirken hata: $e");
    }
  }

  /// Girişte online yap, çıkışta offline yap
  void _handleAuthChange(User? user) {
    if (user == null) {
      // çıkış yapınca zaten signOut çağırılacak
    } else {
      setUserOnline();
    }
  }

  /// 🔁 Uygulama durumu değiştiğinde çevrim durumu güncelle
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setUserOnline();
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      setUserOffline();
    }
  }

  /// ⏳ İnaktif kullanıcıları temizle
  Future<void> clearInactiveUsers() async {
    try {
      QuerySnapshot users = await _firestore.collection('users').get();

      for (var user in users.docs) {
        var userData = user.data() as Map<String, dynamic>?;

        if (userData == null) continue;

        bool isOnline = userData.containsKey('isOnline') ? userData['isOnline'] ?? false : false;
        Timestamp? lastSeen = userData.containsKey('lastSeen') ? userData['lastSeen'] : null;

        if (isOnline && lastSeen != null) {
          DateTime lastSeenTime = lastSeen.toDate();
          if (DateTime.now().difference(lastSeenTime).inMinutes > 10) {
            await user.reference.update({'isOnline': false});
            print("🔥 ${user.id} kullanıcısı 10+ dakika inaktif, offline yapıldı.");
          }
        }
      }
    } catch (e) {
      print("🔥 Eski kullanıcıları temizlerken hata: $e");
    }
  }

  /// 📦 Dinleyicileri kaldır
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
  }
}
