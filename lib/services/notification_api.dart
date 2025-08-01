import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> sendNotification(String receiverId, String message) async {
  final url = Uri.parse('https://mockers-chat.onrender.com'); // kendi URL'ini yaz

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'receiverId': receiverId,
      'message': message,
    }),
  );

  if (response.statusCode == 200) {
    print("✅ Bildirim gönderildi!");
  } else {
    print("❌ Bildirim gönderme hatası: ${response.body}");
  }
}
