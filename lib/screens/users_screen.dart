import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: Text('Kullanıcılar')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            ); // 🔄 Yükleme göstergesi
          }
          if (snapshot.hasError) {
            return Center(
              child: Text("⚠️ Kullanıcılar yüklenirken hata oluştu."),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("📭 Hiç kullanıcı bulunamadı."));
          }

          return ListView(
            children:
                snapshot.data!.docs.map((doc) {
                  if (doc.id == currentUserId)
                    return Container(); // 🛑 Kendi profilini gösterme

                  return Card(
                    elevation: 2,
                    margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(Icons.person),
                        backgroundColor: Colors.blueAccent,
                      ),
                      title: Text(
                        doc['nickname'] ?? doc['email'],
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(doc['email']),
                      trailing: IconButton(
                        icon: Icon(Icons.person_add, color: Colors.green),
                        onPressed: () {
                          _sendFriendRequest(context, currentUserId, doc.id);
                        },
                      ),
                    ),
                  );
                }).toList(),
          );
        },
      ),
    );
  }

  void _sendFriendRequest(
    BuildContext context,
    String fromUserId,
    String toUserId,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('friend_requests').add({
        'from': fromUserId,
        'to': toUserId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Arkadaşlık isteği gönderildi!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Hata: İstek gönderilemedi!")));
    }
  }
}
