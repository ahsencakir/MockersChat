import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockers_chat/services/firebase_service.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  ChatScreen({required this.groupId, required this.groupName});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  String? _currentNickname;

  // Kullanıcı foto URL cache
  final Map<String, String?> _userPhotoCache = {};

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchUserNickname();
  }

  /// 🔥 Kullanıcının takma adını Firestore'dan al
  void _fetchUserNickname() async {
    if (_currentUser == null) return;

    try {
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (mounted && userDoc.exists && userDoc.data() != null) {
        setState(() {
          _currentNickname = userDoc['nickname'] ?? _currentUser!.email;
        });
      }
    } catch (e) {
      print("⚠️ Nickname alınırken hata oluştu: $e");
    }
  }

  /// ✅ Mesaj Gönderme
  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    if (_currentUser == null) {
      print("❌ Kullanıcı bulunamadı!");
      return;
    }

    try {
      await _firebaseService.sendMessage(
        widget.groupId,
        _messageController.text.trim(),
      );
      _messageController.clear();
    } catch (e) {
      print("🔥 Hata oluştu: $e");
    }
  }

  /// 📅 Tarihi formatla ("Bugün", "Dün", tam tarih)
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "";
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();

    if (DateFormat('yyyy-MM-dd').format(date) ==
        DateFormat('yyyy-MM-dd').format(now)) {
      return "Bugün";
    } else if (DateFormat('yyyy-MM-dd').format(date) ==
        DateFormat('yyyy-MM-dd')
            .format(now.subtract(Duration(days: 1)))) {
      return "Dün";
    } else {
      return DateFormat('dd MMM yyyy', 'tr_TR').format(date);
    }
  }

  /// 🕒 Saat formatını düzenleme
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "";
    DateTime date = timestamp.toDate();
    return DateFormat('HH:mm').format(date);
  }

  /// 🖼 Kullanıcının profil fotoğrafını getir (cache'li)
  Future<String?> _getUserPhoto(String userId) async {
    if (_userPhotoCache.containsKey(userId)) {
      return _userPhotoCache[userId];
    }
    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    String? photoUrl = doc.data()?['photoUrl'];
    _userPhotoCache[userId] = photoUrl;
    return photoUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${widget.groupName} (${_currentNickname ?? "Bilinmiyor"})",
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firebaseService.getMessages(widget.groupId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("⚠️ Hata: ${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("Henüz mesaj yok."));
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var messageData = messages[index].data() as Map<String, dynamic>? ?? {};
                    String sender = messageData['senderNickname'] ?? 'Bilinmeyen Kullanıcı';
                    String text = messageData['messageText'] ?? '';
                    String time = _formatTime(messageData['timestamp']);
                    String date = _formatDate(messageData['timestamp']);

                    String senderId = messageData['senderId'] ?? '';

                    // Önceki mesajın tarihi
                    String? previousDate;
                    if (index < messages.length - 1) {
                      var previousTimestamp =
                      messages[index + 1]['timestamp'] as Timestamp?;
                      previousDate = previousTimestamp != null
                          ? _formatDate(previousTimestamp)
                          : null;
                    }

                    bool showDateHeader = previousDate != date;

                    return FutureBuilder<String?>(
                      future: _getUserPhoto(senderId),
                      builder: (context, snapshot) {
                        String? photoUrl = snapshot.data;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDateHeader)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Center(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      date,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Row(
                              mainAxisAlignment:
                              messageData['senderId'] == _currentUser?.uid
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (messageData['senderId'] !=
                                    _currentUser?.uid)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 8.0, right: 5),
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundImage: photoUrl != null
                                          ? NetworkImage(photoUrl)
                                          : null,
                                      child: photoUrl == null
                                          ? Icon(Icons.person)
                                          : null,
                                    ),
                                  ),
                                Flexible(
                                  child: Container(
                                    margin: EdgeInsets.symmetric(
                                        vertical: 5, horizontal: 5),
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: messageData['senderId'] ==
                                          _currentUser?.uid
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
                                      messageData['senderId'] ==
                                          _currentUser?.uid
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sender,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: messageData['senderId'] ==
                                                _currentUser?.uid
                                                ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                                : Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                          text,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                          time,
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
            padding: const EdgeInsets.all(10.0),
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
                  radius: 25,
                  backgroundColor: Colors.blue,
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
  }
}
