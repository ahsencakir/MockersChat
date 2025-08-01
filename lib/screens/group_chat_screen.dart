import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'group_details_screen.dart';
import 'package:intl/intl.dart';
import '../services/user_service.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final UserService _userService = UserService();

  String? groupPhotoUrl;

  // 🖼 Profil fotoğrafı cache
  final Map<String, String?> _userPhotoCache = {};

  bool _navigatedToHome = false;

  DateTime? _lastSeen;
  int? _firstUnreadIndex;
  int _unreadCount = 0;
  bool _scrolledToUnread = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _userService.setUserOnline();
    _listenForGroupDeletion();
    _fetchGroupPhoto();
    _scrollController.addListener(_handleScroll);
    _fetchLastSeen();
  }

  void _updateLastSeen() async {
    String userId = _auth.currentUser!.uid;
    await _db
        .collection('groups')
        .doc(widget.groupId)
        .collection('lastSeen')
        .doc(userId)
        .set({'lastSeen': FieldValue.serverTimestamp()});
  }

  void _fetchGroupPhoto() async {
    var groupDoc = await _db.collection('groups').doc(widget.groupId).get();
    setState(() {
      groupPhotoUrl = groupDoc.data()?['photoUrl'];
    });
  }

  void _handleScroll() {
    // En sona scroll edildiyse lastSeen güncelle
    if (_scrollController.offset <= _scrollController.position.minScrollExtent + 20 &&
        !_scrollController.position.outOfRange) {
      _updateLastSeen();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _userService.setUserOnline();
    } else {
      _userService.setUserOffline();
    }
  }

  void _listenForGroupDeletion() {
    _db
        .collection('groups')
        .doc(widget.groupId)
        .snapshots()
        .listen((snapshot) {
      if (_navigatedToHome) return;
      if (!snapshot.exists) {
        Future.microtask(() {
          if (context.mounted && !_navigatedToHome) {
            _navigatedToHome = true;
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          }
        });
      } else {
        // Kullanıcı gruptan çıkarıldıysa da ana ekrana dön
        var members = snapshot.data()?['members'] as List<dynamic>?;
        String userId = _auth.currentUser!.uid;
        if (members != null && !members.contains(userId)) {
          Future.microtask(() {
            if (context.mounted && !_navigatedToHome) {
              _navigatedToHome = true;
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            }
          });
        }
      }
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    String userId = _auth.currentUser!.uid;
    String userName = await _getUserName(userId);

    await _db
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .add({
      'senderId': userId,
      'senderName': userName,
      'text': _messageController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
        _updateLastSeen();
      }
    });
  }

  Future<String> _getUserName(String userId) async {
    var userDoc = await _db.collection('users').doc(userId).get();
    return userDoc.exists
        ? (userDoc['nickname'] ?? 'Bilinmeyen Kullanıcı')
        : 'Bilinmeyen Kullanıcı';
  }

  Future<String?> _getUserPhoto(String userId) async {
    if (_userPhotoCache.containsKey(userId)) {
      return _userPhotoCache[userId];
    }
    var doc = await _db.collection('users').doc(userId).get();
    String? photoUrl = doc.data()?['photoUrl'];
    _userPhotoCache[userId] = photoUrl;
    return photoUrl;
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "";
    var date = timestamp.toDate();
    var now = DateTime.now();
    if (DateFormat('yyyy-MM-dd').format(date) ==
        DateFormat('yyyy-MM-dd').format(now)) {
      return "Bugün";
    } else if (DateFormat('yyyy-MM-dd').format(date) ==
        DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: 1)))) {
      return "Dün";
    } else {
      return DateFormat('dd MMM yyyy', 'tr_TR').format(date);
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  void _showOnlineUsersModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('groups').doc(widget.groupId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

            var onlineMembers = List<String>.from(snapshot.data!['onlineMembers'] ?? []);

            if (onlineMembers.isEmpty) {
              return Center(child: Text("Şu an aktif kullanıcı yok."));
            }

            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _getUserDetails(onlineMembers),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return Center(child: CircularProgressIndicator());

                var users = userSnapshot.data!;
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    var user = users[index];
                    return ListTile(
                      leading: Icon(Icons.circle, color: Colors.green, size: 12),
                      title: Text(user['nickname'] ?? "Bilinmeyen Kullanıcı"),
                      subtitle: Text("Çevrimiçi"),
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

  Future<List<Map<String, dynamic>>> _getUserDetails(List<String> userIds) async {
    var users = <Map<String, dynamic>>[];
    for (var userId in userIds) {
      var userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        users.add(userDoc.data()!);
      }
    }
    return users;
  }

  Future<void> _fetchLastSeen() async {
    final userId = _auth.currentUser!.uid;
    final doc = await _db
        .collection('groups')
        .doc(widget.groupId)
        .collection('lastSeen')
        .doc(userId)
        .get();
    if (doc.exists && doc.data()?['lastSeen'] != null) {
      setState(() {
        _lastSeen = (doc.data()!['lastSeen'] as Timestamp).toDate();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('groups').doc(widget.groupId).snapshots(),
      builder: (context, groupSnapshot) {
        if (!groupSnapshot.hasData) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                if (groupPhotoUrl != null)
                  CircleAvatar(
                    backgroundImage: NetworkImage(groupPhotoUrl!),
                    radius: 16,
                  ),
                if (groupPhotoUrl != null) SizedBox(width: 8),
                Text(widget.groupName),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.people),
                onPressed: _showOnlineUsersModal,
              ),
              IconButton(
                icon: Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupDetailsScreen(
                        groupId: widget.groupId,
                        groupName: widget.groupName,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _db
                      .collection('groups')
                      .doc(widget.groupId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                    var messages = snapshot.data!.docs;

                    // İlk okunmamış mesajı bul (sadece başkalarının mesajları için)
                    _firstUnreadIndex = null;
                    _unreadCount = 0;
                    if (_lastSeen != null) {
                      for (int i = messages.length - 1; i >= 0; i--) {
                        var ts = messages[i]['timestamp'] as Timestamp?;
                        var senderId = messages[i]['senderId'];
                        if (ts != null && ts.toDate().isAfter(_lastSeen!) && senderId != _auth.currentUser!.uid) {
                          _firstUnreadIndex = i;
                          _unreadCount++;
                        }
                      }
                    }

                    // Otomatik scroll (sadece ilk build sonrası bir kez)
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_scrolledToUnread && _firstUnreadIndex != null && _scrollController.hasClients) {
                        final pos = messages.length - 1 - _firstUnreadIndex!;
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent - pos * 80.0,
                        );
                        _scrolledToUnread = true;
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      reverse: true,
                      itemBuilder: (context, index) {
                        var message = messages[index];
                        bool isMe = message['senderId'] == _auth.currentUser!.uid;
                        String senderId = message['senderId'];
                        String senderName = message['senderName'] ?? "Bilinmeyen";
                        String messageText = message['text'] ?? "Mesaj yok";

                        var timestamp = message['timestamp'] as Timestamp?;
                        String timeString = timestamp != null ? _formatTime(timestamp.toDate()) : '';
                        String date = timestamp != null ? _formatDate(timestamp) : '';

                        String? previousDate;
                        if (index < messages.length - 1) {
                          var prevTimestamp = messages[index + 1]['timestamp'] as Timestamp?;
                          previousDate = prevTimestamp != null ? _formatDate(prevTimestamp) : null;
                        }

                        bool showDateHeader = previousDate != date;

                        // X yeni mesaj etiketi (sadece başkalarının mesajları için)
                        bool showUnreadLabel = (_firstUnreadIndex != null && index == _firstUnreadIndex && message['senderId'] != _auth.currentUser!.uid);

                        return FutureBuilder<String?>(
                          future: _getUserPhoto(senderId),
                          builder: (context, photoSnapshot) {
                            String? photoUrl = photoSnapshot.data;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (showDateHeader)
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text(
                                        date,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (showUnreadLabel)
                                  Center(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 8),
                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '$_unreadCount yeni mesaj',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                Row(
                                  mainAxisAlignment: isMe
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8.0, right: 5),
                                        child: CircleAvatar(
                                          radius: 20,
                                          backgroundImage: photoUrl != null
                                              ? NetworkImage(photoUrl)
                                              : null,
                                          child: photoUrl == null ? Icon(Icons.person) : null,
                                        ),
                                      ),
                                    Flexible(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 5, horizontal: 5),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.3)
                                              : Theme.of(context)
                                              .colorScheme
                                              .secondary
                                              .withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              senderName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isMe
                                                    ? Theme.of(context).colorScheme.primary
                                                    : Theme.of(context).colorScheme.onSurface,
                                              ),
                                            ),
                                            SizedBox(height: 5),
                                            Text(messageText),
                                            SizedBox(height: 5),
                                            Text(
                                              timeString,
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          labelText: "Mesajınızı yazın...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: IconButton(
                        icon: Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
