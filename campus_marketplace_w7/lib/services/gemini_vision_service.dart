import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GeminiVisionService {
  final String apiKey;

  GeminiVisionService({required this.apiKey});

  Future<Map<String, dynamic>> analyzeProductImage(
    File imageFile,
    String promptText,
  ) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );

    final List<int> imageBytes = await imageFile.readAsBytes();
    final String base64Image = base64Encode(imageBytes);

    final requestBody = {
      "contents": [
        {
          "parts": [
            {"text": promptText},
            {
              "inline_data": {
                "mime_type": _getMimeType(imageFile.path),
                "data": base64Image,
              },
            },
          ],
        },
      ],
      "generationConfig": {
        "response_mime_type": "application/json",
        "response_schema": {
          "type": "OBJECT",
          "properties": {
            "title": {"type": "STRING"},
            "category": {"type": "STRING"},
            "description": {"type": "STRING"},
          },
          "required": ["title", "category", "description"],
        },
      },
    };

    int maxRetries = 3;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // 1. ตรวจสอบว่ามี candidates ตอบกลับมาหรือไม่
        final candidates = responseData['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          throw Exception(
            'AI ไม่สามารถวิเคราะห์ภาพนี้ได้ อาจเข้าข่ายเนื้อหาที่ไม่เหมาะสม ลองใช้ภาพอื่น',
          );
        }

        final candidate = candidates[0];

        // 2. ตรวจสอบว่าโดนระบบความปลอดภัย (SAFETY) บล็อกหรือไม่
        if (candidate['finishReason'] == 'SAFETY') {
          throw Exception(
            'เนื้อหาที่วิเคราะห์เข้าข่ายไม่ปลอดภัยตามนโยบายของ Gemini กรุณาใช้ภาพอื่น',
          );
        }

        // อ่านค่าผลลัพธ์ปกติ
        final String rawJsonText = candidate['content']['parts'][0]['text'];
        return jsonDecode(rawJsonText);
      } else if (response.statusCode == 503 && attempt < maxRetries - 1) {
        await Future.delayed(const Duration(seconds: 2));
        continue;
      } else {
        throw Exception(
          'Failed to analyze image: ${response.statusCode} - ${response.body}',
        );
      }
    }

    throw Exception('Failed to connect to Gemini API after multiple retries.');
  }

  String _getMimeType(String path) {
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    if (path.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
