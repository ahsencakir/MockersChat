import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Kullanıcı Kaydı (Email/Şifre)
  Future<String?> registerUser(String email, String password) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;
      if (user != null) {
        await _createUserProfile(user); // ✅ Kullanıcıyı Firestore'a ekle
      }

      return null; // Başarılı kayıt
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code); // 🔹 Türkçe hata mesajı
    } catch (e) {
      return 'Bilinmeyen bir hata oluştu, lütfen tekrar deneyin.';
    }
  }

  // ✅ Kullanıcı Girişi (Email/Şifre)
  Future<String?> loginUser(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _checkAndCreateUserProfile(); // ✅ Kullanıcı profili kontrol et
      return null;
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code); // 🔹 Türkçe hata mesajı
    } catch (e) {
      return 'Bilinmeyen bir hata oluştu, lütfen tekrar deneyin.';
    }
  }

  // ✅ Kullanıcı Çıkışı
  Future<void> logoutUser() async {
    await UserService().setUserOffline(); // Kullanıcıyı offline yap
    await _auth.signOut();
    await FirebaseAuth.instance.signOut();
  }

  // 🔹 Kullanıcının UID'sini döndüren metot
  String getCurrentUserId() {
    return _auth.currentUser?.uid ?? '';
  }

  // 🔹 Kullanıcı profili kontrolü ve Firestore'a ekleme
  Future<void> _checkAndCreateUserProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
      await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'nickname': user.email!.split('@')[0], // Varsayılan nickname
          'email': user.email,
        });
      }
    }
  }

  // 🔹 Kullanıcıyı Firestore'a kaydet
  Future<void> _createUserProfile(User user) async {
    await _firestore.collection('users').doc(user.uid).set({
      'email': user.email,
      'nickname': user.email, // Varsayılan olarak e-posta
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ✅ Firebase hata kodlarını Türkçeye çeviren fonksiyon
  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'invalid-credential':
        return 'Girilen kimlik bilgisi yanlış veya süresi dolmuş.';
      case 'user-not-found':
        return 'Bu e-posta adresine kayıtlı bir hesap bulunamadı.';
      case 'wrong-password':
        return 'Hatalı şifre girdiniz. Lütfen tekrar deneyin.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanılıyor.';
      case 'weak-password':
        return 'Şifreniz çok zayıf. Daha güçlü bir şifre belirleyin.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'İnternet bağlantınızı kontrol edin.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi girdiniz.';
      default:
        return 'Bilinmeyen bir hata oluştu. Lütfen tekrar deneyin.';
    }
  }

  // ✅ Kullanıcı oturum durumunu dinleyen metot
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
