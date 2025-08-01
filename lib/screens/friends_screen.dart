import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dm_chat_screen.dart';
import '../widgets/home_drawer.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'home_screen.dart' show HomeTab;

class FriendsScreen extends StatefulWidget {
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
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

  void _showAddFriendDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Kullanıcılar", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                    SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('users').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                        var users = snapshot.data!.docs.where((doc) => doc.id != _auth.currentUser!.uid).toList();
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            var user = users[index];
                            var userData = user.data() as Map<String, dynamic>;
                            String nickname = userData['nickname'] ?? userData['email'] ?? 'Bilinmeyen';
                            String? photoUrl = userData['photoUrl'];
                            String userId = user.id;
                            return FutureBuilder<DocumentSnapshot>(
                              future: _firestore.collection('users').doc(_auth.currentUser!.uid).collection('friends').doc(userId).get(),
                              builder: (context, friendSnap) {
                                bool alreadyFriend = friendSnap.hasData && friendSnap.data!.exists;
                                return FutureBuilder<DocumentSnapshot>(
                                  future: _firestore.collection('users').doc(userId).collection('friendRequests').doc(_auth.currentUser!.uid).get(),
                                  builder: (context, reqSnap) {
                                    bool alreadyRequested = reqSnap.hasData && reqSnap.data!.exists;
                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.deepPurple,
                                        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                        child: photoUrl == null ? Text(nickname.isNotEmpty ? nickname[0].toUpperCase() : '?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)) : null,
                                      ),
                                      title: Text(nickname, overflow: TextOverflow.ellipsis),
                                      trailing: alreadyFriend
                                          ? ElevatedButton(
                                              onPressed: null,
                                              child: Text("Arkadaşsınız"),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.grey,
                                                foregroundColor: Colors.white,
                                              ),
                                            )
                                          : alreadyRequested
                                              ? ElevatedButton(
                                                  onPressed: null,
                                                  child: Text("İstek Gönderildi"),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.orange,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                )
                                              : ElevatedButton(
                                                  onPressed: () async {
                                                    await _firestore
                                                        .collection('users')
                                                        .doc(userId)
                                                        .collection('friendRequests')
                                                        .doc(_auth.currentUser!.uid)
                                                        .set({'timestamp': FieldValue.serverTimestamp(), 'from': _auth.currentUser!.uid});
                                                    _showModernSnackbar(context, "Arkadaşlık isteği gönderildi!", color: Colors.green);
                                                  },
                                                  child: Text("İstek Gönder"),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.deepPurple,
                                                    foregroundColor: Colors.white,
                                                    minimumSize: Size(90, 32),
                                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    textStyle: TextStyle(fontSize: 13),
                                                  ),
                                                ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
    return Scaffold(
      drawer: HomeDrawer(
        nickname: _nickname ?? "Kullanıcı",
        email: _email ?? "",
        photoUrl: _photoUrl,
        selectedTab: HomeTab.friends,
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
        title: Text('Arkadaşlar'),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: Icon(Icons.public),
            color: Theme.of(context).iconTheme.color,
            tooltip: "Global Chat",
            onPressed: () => _openGlobalChat(context),
          ),
          IconButton(
            icon: Icon(Icons.person),
            color: Theme.of(context).iconTheme.color,
            tooltip: "Profil",
            onPressed: () => _openProfile(context),
          ),
          IconButton(
            icon: Icon(Icons.exit_to_app, color: Colors.red),
            tooltip: "Çıkış Yap",
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 32, left: 16, right: 16, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Arkadaşlar",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.person_add, color: Colors.white),
                  label: Text("Arkadaş Ekle", style: TextStyle(color: Colors.white)),
                  onPressed: () => _showAddFriendDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Text(
              "Arkadaşlık İstekleri",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 120,
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(_auth.currentUser!.uid)
                  .collection('friendRequests')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("İstek yok."));
                }
                var requests = snapshot.data!.docs;
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    var req = requests[index];
                    String fromId = req['from'];
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(fromId).get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                          return SizedBox();
                        }
                        var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                        String nickname = userData['nickname'] ?? userData['email'] ?? 'Bilinmeyen';
                        String? photoUrl = userData['photoUrl'];
                        return Container(
                          width: 220,
                          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                            child: SizedBox(
                              height: 64,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                      child: photoUrl == null ? Text(nickname.isNotEmpty ? nickname[0].toUpperCase() : '?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.onPrimary)) : null,
                                      radius: 20,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(child: Text(nickname, style: TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                    SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(Icons.check, color: Colors.green, size: 22),
                                      tooltip: "Kabul et",
                                      onPressed: () async {
                                        await _firestore.collection('users').doc(_auth.currentUser!.uid).collection('friends').doc(fromId).set({'since': FieldValue.serverTimestamp()});
                                        await _firestore.collection('users').doc(fromId).collection('friends').doc(_auth.currentUser!.uid).set({'since': FieldValue.serverTimestamp()});
                                        await _firestore.collection('users').doc(_auth.currentUser!.uid).collection('friendRequests').doc(fromId).delete();
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Arkadaş eklendi!"), backgroundColor: Colors.green));
                                      },
                                      padding: EdgeInsets.zero,
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.close, color: Colors.red, size: 22),
                                      tooltip: "Reddet",
                                      onPressed: () async {
                                        await _firestore.collection('users').doc(_auth.currentUser!.uid).collection('friendRequests').doc(fromId).delete();
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("İstek reddedildi."), backgroundColor: Colors.red));
                                      },
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Text(
              "Arkadaş Listesi",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(_auth.currentUser!.uid)
                  .collection('friends')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("Hiç arkadaşın yok."));
                }
                var friends = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    String friendId = friends[index].id;
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(friendId).get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState == ConnectionState.waiting) {
                          return ListTile(title: Text("Yükleniyor..."));
                        }
                        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                          return SizedBox.shrink();
                        }
                        var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                        String nickname = userData['nickname'] ?? userData['email'] ?? 'Bilinmeyen';
                        String? photoUrl = userData['photoUrl'];
                        bool isOnline = userData['isOnline'] ?? false;
                        return ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.deepPurple,
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
                            tooltip: "Arkadaşı Sil",
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Arkadaşı Sil'),
                                  content: Text('Bu kişiyi arkadaş listesinden çıkarmak istediğine emin misin?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text('İptal')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Sil', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _firestore.collection('users').doc(_auth.currentUser!.uid).collection('friends').doc(friendId).delete();
                                await _firestore.collection('users').doc(friendId).collection('friends').doc(_auth.currentUser!.uid).delete();
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Arkadaş silindi!"), backgroundColor: Colors.red));
                              }
                            },
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DmChatScreen(
                                  currentUserId: _auth.currentUser!.uid,
                                  friendId: friendId,
                                  friendName: nickname,
                                  friendPhotoUrl: photoUrl,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
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