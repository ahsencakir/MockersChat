import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String senderId;
  final String text;
  final DateTime timestamp;

  Message({
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  // Firestore'dan veri çekme
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      senderId: json['senderId'],
      text: json['text'],
      timestamp: (json['timestamp'] as Timestamp).toDate(),
    );
  }

  // Firestore'a veri kaydetme
  Map<String, dynamic> toJson() {
    return {'senderId': senderId, 'text': text, 'timestamp': timestamp};
  }
}
