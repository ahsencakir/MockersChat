import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';
import 'profile_screen.dart';
import 'group_chat_screen.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/firebase_service.dart';
import 'package:rxdart/rxdart.dart';
import '../widgets/home_drawer.dart';
import 'dm_chat_screen.dart';


class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

enum HomeTab { groups, dms, friends, groupInvites }

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final FirebaseService _firebaseService = FirebaseService();

  User? _currentUser;
  String? _nickname;
  String? _photoUrl;
  bool _isOnline = false;
  HomeTab _selectedTab = HomeTab.groups;

  @override
  void initState() {
    super.initState();
    if (FirebaseAuth.instance.currentUser == null) {
      // Kullanıcı çıkış yapmış, login ekranına yönlendir
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
    } else {
      WidgetsBinding.instance.addObserver(this);
      _initializeUser();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is HomeTab && args != _selectedTab) {
      setState(() {
        _selectedTab = args;
      });
    }
  }

  Future<int> getUnreadMessageCount(String groupId) async {
    String userId = FirebaseAuth.instance.currentUser!.uid;

    DocumentSnapshot lastSeenDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('lastSeen')
        .doc(userId)
        .get();

    Timestamp? lastSeen = lastSeenDoc.exists
        ? lastSeenDoc['lastSeen'] as Timestamp?
        : null;

    print('🕵 Grup $groupId için lastSeen: $lastSeen');

    if (lastSeen != null) {
      QuerySnapshot newMessages = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .where('timestamp', isGreaterThan: lastSeen)
          .get();

      print('🕵 Yeni mesaj sayısı: [32m${newMessages.docs.length}[0m');
      return newMessages.docs.length;
    } else {
      // Kullanıcı hiç bakmadıysa, tüm mesajlar okunmamış sayılır
      QuerySnapshot allMessages = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .get();
      print('🕵 Tüm mesajlar okunmamış: [31m${allMessages.docs.length}[0m');
      return allMessages.docs.length;
    }
  }

  // Okunmamış mesaj sayısını canlı olarak döndüren stream (rxdart ile)
  Stream<int> unreadMessageCountStream(String groupId, String userId) {
    final lastSeenDocStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('lastSeen')
        .doc(userId)
        .snapshots();

    final messagesStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .snapshots();

    return Rx.combineLatest2(
      lastSeenDocStream,
      messagesStream,
      (DocumentSnapshot lastSeenDoc, QuerySnapshot messagesSnapshot) {
        Timestamp? lastSeen = lastSeenDoc.exists
            ? lastSeenDoc['lastSeen'] as Timestamp?
            : null;

        if (lastSeen != null) {
          final newMessages = messagesSnapshot.docs.where((doc) {
            final ts = doc['timestamp'];
            return ts != null && ts is Timestamp && ts.compareTo(lastSeen) > 0;
          }).toList();
          return newMessages.length;
        } else {
          return messagesSnapshot.docs.length;
        }
      },
    );
  }

  Future<void> _initializeUser() async {
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      await _userService.setUserOnline();
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      setState(() {
        _nickname = userDoc['nickname'] ?? "Bilinmeyen Kullanıcı";
        _photoUrl = userDoc.data().toString().contains('photoUrl') ? userDoc['photoUrl'] : null;
        _isOnline = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_currentUser == null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _userService.setUserOffline();
      setState(() {
        _isOnline = false;
      });
    } else if (state == AppLifecycleState.resumed) {
      _initializeUser();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedTab == HomeTab.groups ? "Gruplar" : "DM'ler",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
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
      drawer: HomeDrawer(
        nickname: _nickname ?? "Kullanıcı",
        email: _currentUser?.email ?? "",
        photoUrl: _photoUrl,
        selectedTab: _selectedTab,
        onTabSelected: (tab) {
          setState(() {
            _selectedTab = tab;
          });
          Navigator.pop(context);
        },
      ),
      body: _selectedTab == HomeTab.groups
          ? _buildGroupList()
          : _selectedTab == HomeTab.dms
              ? _buildDmList()
              : _selectedTab == HomeTab.friends
                  ? _buildFriendsList()
                  : _buildGroupInvitesList(),
      floatingActionButton: _selectedTab == HomeTab.groups
          ? FloatingActionButton(
              heroTag: "create_group",
              child: Icon(Icons.add),
              onPressed: () => _openCreateGroup(context),
            )
          : null,
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

  void _openCreateGroup(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => CreateGroupScreen()));
  }

  Future<void> _logout(BuildContext context) async {
    await _userService.setUserOffline();
    await _authService.logoutUser();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Widget _buildGroupList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('groups')
          .where('members', arrayContains: _auth.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("⚠️ Veri yüklenirken hata oluştu!"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_off, size: 80, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  "📭 Henüz grubun yok!",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Text(
                  "Yeni bir grup oluştur veya davet bekle.",
                  style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        var groups = snapshot.data!.docs;
        return ListView.separated(
          padding: EdgeInsets.all(8),
          itemCount: groups.length,
          separatorBuilder: (_, __) => Divider(),
          itemBuilder: (context, index) {
            var group = groups[index];
            String groupId = group.id;
            String groupName = group['name'] ?? "Bilinmeyen Grup";
            List<dynamic> members = group['members'] ?? [];
            String? groupPhotoUrl = group.data().toString().contains('photoUrl')
                ? group['photoUrl']
                : null;

            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('groups')
                  .doc(groupId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, messageSnapshot) {
                String lastMessage = '';
                String lastMessageTime = '';
                String senderName = '';
                if (messageSnapshot.hasData && messageSnapshot.data!.docs.isNotEmpty) {
                  var msg = messageSnapshot.data!.docs.first;
                  lastMessage = msg['text'] ?? '';
                  senderName = msg['senderName'] ?? '';
                  var ts = msg['timestamp'];
                  if (ts != null && ts is Timestamp) {
                    final date = ts.toDate();
                    lastMessageTime = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                  }
                }
                return StreamBuilder<int>(
                  stream: unreadMessageCountStream(groupId, _auth.currentUser!.uid),
                  builder: (context, snapshot) {
                    int unreadCount = snapshot.data ?? 0;
                    print('Grup: $groupName, unreadCount: $unreadCount');
                    return ListTile(
                      title: Text(
                        groupName,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: lastMessage.isNotEmpty
                          ? Text(
                              senderName.isNotEmpty
                                  ? '$senderName: $lastMessage  $lastMessageTime'
                                  : '$lastMessage  $lastMessageTime',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            )
                          : Text('Üyeler: ${members.length} kişi'),
                      leading: CircleAvatar(
                        backgroundColor: Colors.green,
                        backgroundImage:
                            groupPhotoUrl != null ? NetworkImage(groupPhotoUrl) : null,
                        child: groupPhotoUrl == null
                            ? Icon(Icons.group, color: Colors.white)
                            : null,
                      ),
                      trailing: unreadCount > 0
                          ? Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                      onTap: () => _openGroupChat(context, groupId, groupName),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _openGroupChat(BuildContext context, String groupId, String groupName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupChatScreen(
          groupId: groupId,
          groupName: groupName,
        ),
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

  Future<int> getUnreadDmCount(String chatId, String myUid) async {
    final lastSeenDoc = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('lastSeen')
        .doc(myUid)
        .get();
    DateTime? lastSeen;
    if (lastSeenDoc.exists && lastSeenDoc.data() != null && lastSeenDoc['lastSeen'] != null) {
      lastSeen = (lastSeenDoc['lastSeen'] as Timestamp).toDate();
    }
    final unreadSnap = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('timestamp', isGreaterThan: lastSeen ?? DateTime(1970))
        .where('senderId', isNotEqualTo: myUid)
        .get();
    return unreadSnap.docs.length;
  }

  Stream<int> unreadDmCountStream(String chatId, String myUid) {
    final lastSeenDocStream = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('lastSeen')
        .doc(myUid)
        .snapshots();
    final messagesStream = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .snapshots();
    return Rx.combineLatest2(
      lastSeenDocStream,
      messagesStream,
      (DocumentSnapshot lastSeenDoc, QuerySnapshot messagesSnapshot) {
        DateTime? lastSeen;
        if (lastSeenDoc.exists && lastSeenDoc.data() != null && lastSeenDoc['lastSeen'] != null) {
          lastSeen = (lastSeenDoc['lastSeen'] as Timestamp).toDate();
        }
        final newMessages = messagesSnapshot.docs.where((doc) {
          final ts = doc['timestamp'];
          final senderId = doc['senderId'];
          return ts != null && ts is Timestamp && (lastSeen == null || ts.toDate().isAfter(lastSeen)) && senderId != myUid;
        }).toList();
        return newMessages.length;
      },
    );
  }

  Widget _buildDmList() {
    if (_currentUser == null) {
      return Center(child: CircularProgressIndicator());
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').doc(_currentUser!.uid).collection('friends').snapshots(),
      builder: (context, friendsSnapshot) {
        if (friendsSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (friendsSnapshot.hasError) {
          return Center(child: Text('Bir hata oluştu: \\${friendsSnapshot.error}'));
        }
        if (!friendsSnapshot.hasData || friendsSnapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  "📭 Henüz DM yok!",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Text(
                  "Arkadaş ekleyip sohbet başlatabilirsin.",
                  style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }
        var friends = friendsSnapshot.data!.docs;
        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            String friendId = friends[index].id;
            final ids = [_currentUser!.uid, friendId]..sort();
            String chatId = ids.join('_');
            return StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('chats').doc(chatId).collection('messages').orderBy('timestamp', descending: true).limit(1).snapshots(),
              builder: (context, messageSnapshot) {
                String lastMessage = '';
                Timestamp? lastMessageTime;
                if (messageSnapshot.hasData && messageSnapshot.data!.docs.isNotEmpty) {
                  lastMessage = messageSnapshot.data!.docs.first['text'] ?? '';
                  lastMessageTime = messageSnapshot.data!.docs.first['timestamp'] as Timestamp?;
                }
                return StreamBuilder<int>(
                  stream: unreadDmCountStream(chatId, _currentUser!.uid),
                  builder: (context, unreadSnapshot) {
                    int unreadCount = unreadSnapshot.data ?? 0;
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(friendId).get(),
                      builder: (context, userSnapshot) {
                        String? photoUrl;
                        String nickname = "Yükleniyor...";
                        if (userSnapshot.hasData && userSnapshot.data!.exists) {
                          var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                          photoUrl = userData['photoUrl'];
                          nickname = userData['nickname'] ?? userData['email'] ?? friendId;
                        }
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                            child: photoUrl == null ? Icon(Icons.person) : null,
                          ),
                          title: Text(nickname),
                          subtitle: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lastMessage.isNotEmpty ? lastMessage : 'Henüz mesaj yok',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (lastMessageTime != null)
                                Text(
                                  _formatTime(lastMessageTime),
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                            ],
                          ),
                          trailing: unreadCount > 0
                              ? Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                )
                              : null,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DmChatScreen(
                                  currentUserId: _currentUser!.uid,
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
            );
          },
        );
      },
    );
  }

  Widget _buildFriendsList() {
    // Implement the logic to build the friends list
    return Text("Friends List");
  }

  Widget _buildGroupInvitesList() {
    // Implement the logic to build the group invites list
    return Text("Group Invites List");
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
