import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔹 Kullanıcı profilini getirme (ID + customID)
  Future<Map<String, dynamic>?> getUserProfile() async {
    User? user = _auth.currentUser;
    if (user == null) return null;

    DocumentSnapshot doc =
        await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    Map<String, dynamic> userData = doc.data() as Map<String, dynamic>? ?? {};

    return {
      'uid': user.uid, // 🔹 Firebase UID
      'customID':
          userData['customID'] ?? "Belirtilmemiş", // 🔹 Kullanıcının özel ID'si
      'displayName': userData['displayName'] ?? "Bilinmeyen Kullanıcı",
    };
  }

  // 🔹 Profil güncelleme (İsim + Custom ID)
  Future<void> updateProfile(String displayName, String customID) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'displayName': displayName,
      'customID': customID,
    });
  }
}
