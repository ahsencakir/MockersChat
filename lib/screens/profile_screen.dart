import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../theme_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _photoUrlController = TextEditingController();

  User? _user;
  String? _nickname;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  void _getUserData() async {
    _user = _auth.currentUser;
    if (_user != null) {
      DocumentSnapshot userDoc =
      await _firestore.collection('users').doc(_user!.uid).get();
      if (!mounted) return;
      setState(() {
        _nickname = userDoc['nickname'] ?? "Bilinmeyen";
        _nicknameController.text = _nickname!;
        _photoUrl = userDoc['photoUrl'];
        _photoUrlController.text = _photoUrl ?? "";
      });
      // 🔥 BURAYA EKLE
      print("Profil fotoğrafı URL'si: $_photoUrl");
    }
  }

  /// 📌 Fotoğraf değiştirme seçenekleri (mobil için)
  void _changeProfilePhoto() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Galeriden Seç'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Kamera ile Çek'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile =
    await picker.pickImage(source: source, imageQuality: 50);

    if (pickedFile != null && _user != null) {
      print("Dosya yolu: ${pickedFile.path}");

      final ref = _storage
          .ref()
          .child('profile_photos')
          .child('${_user!.uid}.jpg');

      if (kIsWeb) {
        // Web için: bytes olarak oku
        final bytes = await pickedFile.readAsBytes();
        print("Web için yükleme başlıyor...");
        await ref.putData(bytes);
      } else {
        // Mobil için: file kullan
        File file = File(pickedFile.path);
        print("Mobil için yükleme başlıyor...");
        await ref.putFile(file);
      }

      print("Yükleme başarılı!");

      final downloadUrl = await ref.getDownloadURL();
      await _firestore
          .collection('users')
          .doc(_user!.uid)
          .update({'photoUrl': downloadUrl});
      setState(() {
        _photoUrl = downloadUrl;
        _photoUrlController.text = downloadUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Profil fotoğrafı güncellendi!")));
    }
  }


  Future<void> _updatePhotoFromUrl() async {
    final url = _photoUrlController.text.trim();
    if (url.isNotEmpty && _user != null) {
      await _firestore
          .collection('users')
          .doc(_user!.uid)
          .update({'photoUrl': url});
      setState(() {
        _photoUrl = url;
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fotoğraf URL’si güncellendi!")));
    }
  }

  void _updateNickname() async {
    if (_nicknameController.text.isNotEmpty && _user != null) {
      await _firestore.collection('users').doc(_user!.uid).set({
        'nickname': _nicknameController.text,
      }, SetOptions(merge: true));
      setState(() {
        _nickname = _nicknameController.text;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Profil güncellendi!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Profil")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: GestureDetector(
                onTap: _changeProfilePhoto,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: _photoUrl != null && _photoUrl!.isNotEmpty
                      ? ClipOval(
                    child: Image.network(
                      _photoUrl!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return CircularProgressIndicator();
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print('Hata oluştu: $error');  // 🔥 Hata logu
                        return CircleAvatar(
                          radius: 50,
                          child: Icon(Icons.person, size: 50),
                        );
                      },
                    ),
                  )
                      : CircleAvatar(
                    radius: 50,
                    child: Icon(Icons.person, size: 50),
                  ),
                ),
              ),
            ),


            Center(child: Text("Fotoğrafa tıklayarak değiştir")),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _photoUrlController,
                      decoration: InputDecoration(hintText: "Fotoğraf URL'si"),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _updatePhotoFromUrl,
                    child: Text("URL'den Güncelle"),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _nicknameController,
              decoration: InputDecoration(labelText: "Takma Ad"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateNickname,
              child: Text("Güncelle"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                ThemeManager.toggleTheme();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Tema değiştirildi!")),
                );
              },
              child: Text("Tema Değiştir"),
            ),
          ],
        ),
      ),
    );
  }
}
