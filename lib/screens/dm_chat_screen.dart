import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

class DmChatScreen extends StatefulWidget {
  final String currentUserId;
  final String friendId;
  final String friendName;
  final String? friendPhotoUrl;

  const DmChatScreen({
    Key? key,
    required this.currentUserId,
    required this.friendId,
    required this.friendName,
    this.friendPhotoUrl,
  }) : super(key: key);

  @override
  State<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends State<DmChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isFriend = false;
  bool _loadingFriendStatus = true;

  DateTime? _lastSeen;
  int? _firstUnreadIndex;
  int _unreadCount = 0;
  bool _scrolledToUnread = false;

  // Okunmamış mesaj sayısını canlı olarak döndüren stream
  Stream<int> unreadMessageCountStream(String chatId, String userId) {
    final lastSeenDocStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('lastSeen')
        .doc(userId)
        .snapshots();

    final messagesStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
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

  @override
  void initState() {
    super.initState();
    _checkFriendStatus();
    _fetchLastSeen();
    _scrollController.addListener(_handleScroll);
  }

  void _checkFriendStatus() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('friends')
        .doc(widget.friendId)
        .get();
    setState(() {
      _isFriend = doc.exists;
      _loadingFriendStatus = false;
    });
  }

  Future<void> _fetchLastSeen() async {
    final doc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('lastSeen')
        .doc(widget.currentUserId)
        .get();
    if (doc.exists && doc.data()?['lastSeen'] != null) {
      setState(() {
        _lastSeen = (doc.data()!['lastSeen'] as Timestamp).toDate();
      });
    }
  }

  String get chatId {
    // Her iki UID'yi alfabetik sırala, birleştir
    final ids = [widget.currentUserId, widget.friendId]..sort();
    return ids.join('_');
  }

  void _updateLastSeen() async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('lastSeen')
        .doc(widget.currentUserId)
        .set({'lastSeen': FieldValue.serverTimestamp()});
  }

  void _handleScroll() {
    // En sona scroll edildiyse lastSeen güncelle
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 20 &&
        !_scrollController.position.outOfRange) {
      _updateLastSeen();
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': widget.currentUserId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _controller.clear();
    _scrollToBottom();
    _updateLastSeen();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (widget.friendPhotoUrl != null)
              CircleAvatar(
                backgroundImage: NetworkImage(widget.friendPhotoUrl!),
                radius: 16,
              ),
            if (widget.friendPhotoUrl != null) SizedBox(width: 8),
            Text(widget.friendName),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FriendDetailScreen(friendId: widget.friendId),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('DM Sil'),
                  content: Text('Bu DM sadece sizde silinecek. Devam edilsin mi?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text('İptal')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Sil', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true) {
                await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.currentUserId)
                  .collection('friends')
                  .doc(widget.friendId)
                  .delete();
                if (mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                final messages = snapshot.data!.docs;
                if (messages.isEmpty) {
                  return Center(child: Text('Henüz mesaj yok.'));
                }
                // İlk okunmamış mesajı bul (sadece başkalarının mesajları için)
                _firstUnreadIndex = null;
                _unreadCount = 0;
                if (_lastSeen != null) {
                  for (int i = 0; i < messages.length; i++) {
                    var ts = messages[i]['timestamp'] as Timestamp?;
                    var senderId = messages[i]['senderId'];
                    if (ts != null && ts.toDate().isAfter(_lastSeen!) && senderId != widget.currentUserId) {
                      _firstUnreadIndex = i;
                      // Sadece başkasının mesajlarını say
                      _unreadCount = messages.where((msg) {
                        var ts2 = msg['timestamp'] as Timestamp?;
                        var senderId2 = msg['senderId'];
                        return ts2 != null && ts2.toDate().isAfter(_lastSeen!) && senderId2 != widget.currentUserId;
                      }).length;
                      break;
                    }
                  }
                }

                // Otomatik scroll (ilk girişte ve yeni mesaj geldiğinde bir kez)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // İlk okunmamışa scroll veya en alta scroll
                  if (!_scrolledToUnread && _firstUnreadIndex != null && _scrollController.hasClients) {
                    _scrollController.jumpTo(_firstUnreadIndex! * 80.0);
                    _scrolledToUnread = true;
                  } else if (_scrollController.hasClients && messages.isNotEmpty) {
                    // DM ekranına her girişte ve yeni mesajda en alta scroll
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                  if (_scrolledToUnread && _scrollController.hasClients && messages.isNotEmpty) {
                    if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 20) {
                      _updateLastSeen();
                    }
                  }
                });

                List<Widget> messageWidgets = [];
                String? lastDateLabel;
                for (int i = 0; i < messages.length; i++) {
                  var msg = messages[i];
                  bool isMe = msg['senderId'] == widget.currentUserId;
                  String text = msg['text'] ?? '';
                  Timestamp? ts = msg['timestamp'] as Timestamp?;
                  DateTime? date = ts?.toDate();
                  String time = date != null ? DateFormat('HH:mm').format(date) : '';
                  String dateLabel = '';
                  if (date != null) {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final msgDay = DateTime(date.year, date.month, date.day);
                    if (msgDay == today) {
                      dateLabel = 'Bugün';
                    } else if (msgDay == today.subtract(Duration(days: 1))) {
                      dateLabel = 'Dün';
                    } else {
                      dateLabel = DateFormat('d MMM y', 'tr').format(date);
                    }
                  }
                  // Tarih başlığı ekle
                  if (dateLabel.isNotEmpty && dateLabel != lastDateLabel) {
                    messageWidgets.add(
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Center(
                          child: Text(
                            dateLabel,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    );
                    lastDateLabel = dateLabel;
                  }
                  // X yeni mesaj etiketi (sadece başkalarının mesajları için)
                  bool showUnreadLabel = (_firstUnreadIndex != null && i == _firstUnreadIndex && msg['senderId'] != widget.currentUserId);
                  if (showUnreadLabel) {
                    messageWidgets.add(
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
                    );
                  }
                  // Mesaj balonu
                  messageWidgets.add(
                    Row(
                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Padding(
                            padding: const EdgeInsets.only(right: 6.0, top: 2.0),
                            child: widget.friendPhotoUrl != null
                                ? CircleAvatar(
                                    radius: 18,
                                    backgroundImage: NetworkImage(widget.friendPhotoUrl!),
                                  )
                                : CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    child: Icon(Icons.person, color: Theme.of(context).colorScheme.onPrimary),
                                  ),
                          ),
                        Flexible(
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                                  : Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isMe ? 'Sen' : widget.friendName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isMe
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  text,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
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
                  );
                }
                return ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  children: messageWidgets,
                );
              },
            ),
          ),
          if (_loadingFriendStatus)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!_isFriend)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Sadece arkadaşlar mesajlaşabilir',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
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
                    backgroundColor: Colors.deepPurple,
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white),
                      onPressed: _isFriend ? _sendMessage : null,
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

// Kullanıcı detay ekranı (gelişmiş)
class FriendDetailScreen extends StatelessWidget {
  final String friendId;
  const FriendDetailScreen({Key? key, required this.friendId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Kullanıcı Detayı')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Kullanıcı bulunamadı.'));
          }
          var userData = snapshot.data!.data() as Map<String, dynamic>;
          String nickname = userData['nickname'] ?? userData['email'] ?? 'Bilinmeyen';
          String? photoUrl = userData['photoUrl'];
          Timestamp? lastSeen = userData['lastSeen'];
          String lastSeenText = 'Bilinmiyor';
          if (lastSeen != null) {
            final date = lastSeen.toDate();
            lastSeenText = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}' ;
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null ? Icon(Icons.person, size: 48) : null,
                ),
                SizedBox(height: 16),
                Text(nickname, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Son çevrimiçi: $lastSeenText', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        },
      ),
    );
  }
} 