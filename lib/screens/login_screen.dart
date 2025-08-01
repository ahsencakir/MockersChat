import 'package:flutter/material.dart';
import 'package:mockers_chat/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void login() async {
    String? error = await _authService.loginUser(
      emailController.text,
      passwordController.text,
    );

    if (error == null) {
      // ✅ Giriş başarılı, kullanıcı profilini kontrol et
      User? user = _auth.currentUser;
      if (user != null) {
        await _checkAndCreateUserProfile(user);
      }

      // ✅ HomeScreen'e yönlendir
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } else {
      // ❌ Hata mesajı göster
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  // 🔹 Kullanıcı profilini Firestore'da kontrol et ve oluştur
  Future<void> _checkAndCreateUserProfile(User user) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'nickname': user.email, // Varsayılan olarak e-posta atanır
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print("Kullanıcı profili kontrol edilirken hata oluştu: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Giriş Yap")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: "Şifre"),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(onPressed: login, child: Text("Giriş Yap")),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterScreen()),
                );
              },
              child: Text("Hesabın yok mu? Kayıt ol"),
            ),
            TextButton(
              onPressed: () async {
                if (emailController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Lütfen e-posta adresinizi girin.")),
                  );
                } else {
                  try {
                    await _auth.sendPasswordResetEmail(
                        email: emailController.text.trim());
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              "Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.")),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Hata: ${e.toString()}")),
                    );
                  }
                }
              },
              child: Text("Şifremi unuttum"),
            ),
          ],
        ),
      ),
    );
  }

}
