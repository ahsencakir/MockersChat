import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateGroupScreen extends StatefulWidget {
  @override
  _CreateGroupScreenState createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false; // 🔵 Yüklenme durumu

  void _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true; // 🔵 Butonu kilitle
    });

    String groupName = _groupNameController.text.trim();
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      // Kullanıcı UID'sini Firestore'a kaydettiğimizden emin olalım
      DocumentReference groupRef = await _firestore.collection('groups').add({
        'name': groupName,
        'admin': user.uid, // 🔥 UID kullan
        'members': [user.uid], // 🔥 UID ile kayıt et
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$groupName grubu oluşturuldu!")),
        );

        Navigator.pop(context, groupRef.id); // 🔥 Grup ID'sini geri döndür
      }
    } catch (e) {
      print("Grup oluşturma hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Grup oluşturulurken hata oluştu!")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // 🔵 Yüklenme tamamlandı, butonu aç
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Grup Oluştur")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(labelText: "Grup Adı"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed:
                  _isLoading
                      ? null
                      : _createGroup, // 🔵 Yüklenirken buton devre dışı
              child:
                  _isLoading
                      ? CircularProgressIndicator(
                        color: Colors.white,
                      ) // 🔵 Yüklenme göstergesi
                      : Text("Grubu Oluştur"),
            ),
          ],
        ),
      ),
    );
  }
}
