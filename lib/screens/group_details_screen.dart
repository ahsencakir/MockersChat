import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';


class GroupDetailsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  _GroupDetailsScreenState createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _photoUrlController = TextEditingController();

  String? currentUserId;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    currentUserId = _auth.currentUser?.uid;
  }

  Stream<DocumentSnapshot> _getGroupDetails() {
    return _db.collection('groups').doc(widget.groupId).snapshots();
  }

  Future<String> _getUserName(String userId) async {
    try {
      DocumentSnapshot userDoc = await _db.collection('users').doc(userId).get();
      return userDoc.exists ? (userDoc['nickname'] ?? userDoc['email']) : 'Bilinmeyen Kullanıcı';
    } catch (e) {
      return 'Bilinmeyen Kullanıcı';
    }
  }

  Future<String?> _getUserIdFromEmail(String email) async {
    try {
      QuerySnapshot querySnapshot = await _db.collection('users')
          .where('email', isEqualTo: email).limit(1).get();
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 📌 Fotoğraf değiştirme seçenekleri
  void _changeGroupPhoto() async {
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
    if (kIsWeb) {
      // Web için FilePicker kullan
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.single.bytes != null) {
        final ref = _storage.ref().child('group_photos/${widget.groupId}.jpg');
        await ref.putData(result.files.single.bytes!);
        final url = await ref.getDownloadURL();

        await _db.collection('groups').doc(widget.groupId).update({
          'photoUrl': url,
        });

        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Grup fotoğrafı güncellendi.')));
        }
      }
    } else {
      // Mobil için ImagePicker
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 50);

      if (pickedFile != null) {
        final File file = File(pickedFile.path);
        final ref = _storage.ref().child('group_photos/${widget.groupId}.jpg');
        await ref.putFile(file);
        final url = await ref.getDownloadURL();

        await _db.collection('groups').doc(widget.groupId).update({
          'photoUrl': url,
        });

        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Grup fotoğrafı güncellendi.')));
        }
      }
    }
  }


  /// 📌 Manuel URL güncelle
  Future<void> _changeGroupPhotoFromUrl() async {
    final url = _photoUrlController.text.trim();
    if (url.isNotEmpty) {
      await _db.collection('groups').doc(widget.groupId).update({
        'photoUrl': url,
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fotoğraf URL güncellendi.')));
    }
  }

  void _modifyGroupMembers(String userId, bool add) async {
    try {
      DocumentReference groupRef = _db.collection('groups').doc(widget.groupId);
      if (add) {
        await _db.collection('users').doc(userId).collection('groupInvites').add({
          'groupId': widget.groupId,
          'groupName': widget.groupName,
          'invitedBy': currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Kullanıcıya davetiye gönderildi!')),
          );
        }
      } else {
        await groupRef.update({
          'members': FieldValue.arrayRemove([userId]),
        });
        DocumentSnapshot groupDoc = await groupRef.get();
        List<dynamic> updatedMembers = groupDoc['members'] ?? [];
        if (updatedMembers.isEmpty) {
          await groupRef.delete();
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          }
        } else if (userId == currentUserId) {
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşlem sırasında hata oluştu!')));
      }
    }
  }

  void _addUserToGroup() async {
    String input = _userIdController.text.trim();
    if (input.isEmpty) return;

    String? userId = input.contains('@') ? await _getUserIdFromEmail(input) : input;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Kullanıcı bulunamadı!")));
      return;
    }

    DocumentReference groupRef = _db.collection('groups').doc(widget.groupId);
    DocumentSnapshot groupDoc = await groupRef.get();
    List<dynamic> members = groupDoc['members'] ?? [];

    if (members.contains(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Kullanıcı zaten grupta!")));
      return;
    }

    _modifyGroupMembers(userId, true);
    _userIdController.clear();
  }

  void _deleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Grubu Sil'),
        content: Text('Grubu silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      DocumentReference groupRef = _db.collection('groups').doc(widget.groupId);
      DocumentSnapshot groupDoc = await groupRef.get();
      List<dynamic> members = groupDoc['members'] ?? [];
      for (var member in members) {
        await groupRef.update({
          'members': FieldValue.arrayRemove([member]),
        });
      }
      await groupRef.delete();
      if (!_navigated && context.mounted) {
        _navigated = true;
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Grup silinirken hata oluştu!')));
      }
    }
  }

  void _showUserSelectionDialog(List<dynamic> groupMembers) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Kullanıcı Ekle"),
          content: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
              var allUsers = snapshot.data!.docs;
              var nonGroupUsers = allUsers
                  .where((doc) => !groupMembers.contains(doc.id))
                  .toList();
              if (nonGroupUsers.isEmpty) {
                return Center(child: Text("Eklenebilecek kullanıcı yok."));
              }
              return SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: nonGroupUsers.map((doc) {
                    String userId = doc.id;
                    String userName = doc['nickname'] ?? doc['email'];
                    return ListTile(
                      title: Text(userName),
                      trailing: IconButton(
                        icon: Icon(Icons.person_add, color: Colors.green),
                        onPressed: () {
                          _modifyGroupMembers(userId, true);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Kullanıcıya davetiye gönderildi!')),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteGroup,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _getGroupDetails(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            Future.microtask(() {
              if (!_navigated && context.mounted) {
                _navigated = true;
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/home', (route) => false);
              }
            });
            return Center(child: CircularProgressIndicator());
          }

          var groupData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          List<dynamic> groupMembers = groupData['members'] ?? [];
          String? photoUrl = groupData['photoUrl'];
          print('groupMembers: $groupMembers, currentUserId: $currentUserId');
          if (!groupMembers.contains(currentUserId)) {
            Future.microtask(() {
              if (!_navigated && context.mounted) {
                _navigated = true;
                Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
              }
            });
            return SizedBox();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👇 Grup fotoğrafı (tıklayınca değiştir)
              Center(
                child: GestureDetector(
                  onTap: _changeGroupPhoto,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: photoUrl != null
                        ? CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(photoUrl),
                    )
                        : CircleAvatar(
                      radius: 50,
                      child: Icon(Icons.group, size: 50),
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
                      onPressed: _changeGroupPhotoFromUrl,
                      child: Text("URL'den Güncelle"),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text("Üyeler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _userIdController,
                        decoration: InputDecoration(
                          hintText: "Email girin",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _addUserToGroup,
                      child: Text("Ekle"),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: groupMembers.length,
                  itemBuilder: (context, index) {
                    String memberId = groupMembers[index];
                    return FutureBuilder<DocumentSnapshot>(
                      future: _db.collection('users').doc(memberId).get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState == ConnectionState.waiting) {
                          return ListTile(title: Text("Yükleniyor..."));
                        }
                        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                          return ListTile(title: Text("Bilinmeyen Kullanıcı"));
                        }
                        var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                        String nickname = userData['nickname'] ?? userData['email'] ?? 'Bilinmeyen';
                        String? photoUrl = userData['photoUrl'];
                        bool isOnline = userData['isOnline'] ?? false;
                        return ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                child: photoUrl == null ? Text(nickname.isNotEmpty ? nickname[0].toUpperCase() : '?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)) : null,
                              ),
                              if (isOnline)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(nickname),
                          trailing: IconButton(
                            icon: Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () => _modifyGroupMembers(memberId, false),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: () => _showUserSelectionDialog(groupMembers),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text("Üye Ekle", style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
