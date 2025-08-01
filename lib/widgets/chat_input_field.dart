import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatInputField extends StatefulWidget {
  final Function(String) onSendMessage;

  const ChatInputField({Key? key, required this.onSendMessage}) : super(key: key);

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  final TextEditingController _controller = TextEditingController();
  FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          bool isShiftPressed = event.isShiftPressed;
          bool isEnterPressed = event.logicalKey == LogicalKeyboardKey.enter;

          if (isEnterPressed) {
            if (isShiftPressed) {
              // Shift+Enter: Alt satıra geç
              _controller.text += '\n';
              _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: _controller.text.length),
              );
            } else {
              // Enter: Mesajı gönder
              String message = _controller.text.trim();
              if (message.isNotEmpty) {
                widget.onSendMessage(message);
                _controller.clear();
              }
            }
          }
        }
      },
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: null, // Çok satırlı mesaj yazmayı sağlar
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline, // Mobilde Enter ile alt satıra geçmesini sağlar
        decoration: InputDecoration(
          hintText: "Mesajınızı yazın...",
          suffixIcon: IconButton(
            icon: Icon(Icons.send),
            onPressed: () {
              String message = _controller.text.trim();
              if (message.isNotEmpty) {
                widget.onSendMessage(message);
                _controller.clear();
              }
            },
          ),
        ),
      ),
    );
  }
}
