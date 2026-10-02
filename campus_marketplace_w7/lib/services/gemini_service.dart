import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  // ดึง API Key จากไฟล์ .env โดยใช้คีย์ GEMINI_API_KEY ตามเดิม
  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  Future<String> generateText(String prompt) async {
    if (_apiKey.isEmpty) {
      throw Exception('ไม่พบ GEMINI_API_KEY ในไฟล์ .env');
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey',
    );

    final Map<String, dynamic> requestBody = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
          ],
        },
      ],
    };

    try {
      // ส่ง HTTP POST Request พร้อมกำหนด .timeout()
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('การเชื่อมต่อหมดเวลา (Timeout 30 วินาที)');
            },
          );

      // ตรวจสอบ Status Code
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // ตรวจสอบว่า candidates มีข้อมูลจริงหรือไม่
        if (responseData.containsKey('candidates') &&
            (responseData['candidates'] as List).isNotEmpty) {
          final candidate = responseData['candidates'][0];

          if (candidate.containsKey('content') &&
              candidate['content'].containsKey('parts') &&
              (candidate['content']['parts'] as List).isNotEmpty) {
            return candidate['content']['parts'][0]['text'] ?? '';
          }
        }

        throw Exception('ไม่พบข้อมูลคำตอบในโครงสร้าง Response (candidates)');
      } else {
        throw Exception(
          'การเรียกใช้งาน Gemini API ล้มเหลว (Status Code: ${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}
