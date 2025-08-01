import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;

  MessageBubble({required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          isMe
              ? Alignment.centerRight
              : Alignment.centerLeft, // Kullanıcıya göre hizalama
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:
              isMe
                  ? Colors.blue
                  : Colors
                      .grey[300], // Kullanıcı mesajı ve karşı taraf mesajı farklı renk
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          text,
          style: TextStyle(color: isMe ? Colors.white : Colors.black),
        ),
      ),
    );
  }
}
