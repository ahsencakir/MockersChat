import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/home_drawer.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'home_screen.dart' show HomeTab;

class GroupInvitesScreen extends StatefulWidget {
  @override
  State<GroupInvitesScreen> createState() => _GroupInvitesScreenState();
}

class _GroupInvitesScreenState extends State<GroupInvitesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _nickname;
  String? _email;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  Future<void> _fetchUserInfo() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _nickname = doc['nickname'] ?? 'Kullanıcı';
        _email = doc['email'] ?? user.email ?? '';
        _photoUrl = doc.data().toString().contains('photoUrl') ? doc['photoUrl'] : null;
      });
    }
  }

  void _openGlobalChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          groupId: "global_chat",
          groupName: "Global Chat",
        ),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => ProfileScreen()));
  }

  void _logout(BuildContext context) async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    return Scaffold(
      drawer: HomeDrawer(
        nickname: _nickname ?? "Kullanıcı",
        email: _email ?? "",
        photoUrl: _photoUrl,
        selectedTab: HomeTab.groupInvites,
        onTabSelected: (tab) {
          Navigator.pop(context);
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
            arguments: tab,
          );
        },
      ),
      appBar: AppBar(
        title: Text('Grup Davetleri'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Gelen Grup Davetleri", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('users').doc(user!.uid).collection('groupInvites').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text("Davet yok."));
                  }
                  var invites = snapshot.data!.docs;
                  return ListView.separated(
                    itemCount: invites.length,
                    separatorBuilder: (_, __) => Divider(),
                    itemBuilder: (context, index) {
                      var invite = invites[index];
                      String groupId = invite['groupId'];
                      String groupName = invite['groupName'] ?? 'Bilinmeyen Grup';
                      return ListTile(
                        leading: Icon(Icons.group, color: Colors.deepPurple),
                        title: Text(groupName),
                        subtitle: Text('Grup ID: $groupId'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.check, color: Colors.green),
                              tooltip: 'Kabul Et',
                              onPressed: () => _acceptGroupInvite(invite.id, groupId),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.red),
                              tooltip: 'Reddet',
                              onPressed: () => _rejectGroupInvite(invite.id),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _acceptGroupInvite(String inviteDocId, String groupId) async {
    final userId = _auth.currentUser!.uid;
    try {
      // Kullanıcıyı gruba ekle
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([userId])
      });
      // Daveti sil
      await _firestore.collection('users').doc(userId).collection('groupInvites').doc(inviteDocId).delete();
      _showModernSnackbar(context, "Gruba katıldın!", color: Colors.green);
    } catch (e) {
      _showModernSnackbar(context, "Bir hata oluştu!", color: Colors.red);
    }
  }

  void _rejectGroupInvite(String inviteDocId) async {
    final userId = _auth.currentUser!.uid;
    try {
      await _firestore.collection('users').doc(userId).collection('groupInvites').doc(inviteDocId).delete();
      _showModernSnackbar(context, "Davet reddedildi.", color: Colors.orange);
    } catch (e) {
      _showModernSnackbar(context, "Bir hata oluştu!", color: Colors.red);
    }
  }

  void _showModernSnackbar(BuildContext context, String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: 16)),
        backgroundColor: color ?? Colors.deepPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        duration: Duration(seconds: 2),
      ),
    );
  }
} 