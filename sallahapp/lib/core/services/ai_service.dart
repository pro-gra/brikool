import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Talks to the local FastAPI AI backend (ai_backend.py).
/// Must be running at http://localhost:8001 for these calls to work.
class AiService {
  static const _baseUrl = 'http://localhost:8001';

  /// Sends the conversation so far + a new message, gets the AI's reply.
  Future<String> sendSupportMessage({
    required List<Map<String, String>> history,
    required String message,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/support-chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'history': history, 'message': message}),
    );
    if (response.statusCode != 200) {
      throw Exception('AI service error ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['reply'] as String;
  }

  /// Uploads a photo (+ optional description) and gets back a structured
  /// diagnosis: category, estimated price range, urgency.
  Future<PhotoDiagnosis> diagnosePhoto({
    required Uint8List imageBytes,
    String description = '',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/diagnose-photo'),
    );
    request.fields['description'] = description;
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: 'photo.jpg',
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      throw Exception('AI service error ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return PhotoDiagnosis.fromMap(data);
  }
}

class PhotoDiagnosis {
  const PhotoDiagnosis({
    required this.category,
    required this.problemSummary,
    required this.estimatedPriceMin,
    required this.estimatedPriceMax,
    required this.urgency,
    required this.confidenceNote,
  });

  final String category;
  final String problemSummary;
  final double estimatedPriceMin;
  final double estimatedPriceMax;
  final String urgency; // faible | moyenne | élevée
  final String confidenceNote;

  factory PhotoDiagnosis.fromMap(Map<String, dynamic> map) {
    return PhotoDiagnosis(
      category: map['category'] as String? ?? 'Non identifié',
      problemSummary: map['problem_summary'] as String? ?? '',
      estimatedPriceMin: (map['estimated_price_min'] as num?)?.toDouble() ?? 0,
      estimatedPriceMax: (map['estimated_price_max'] as num?)?.toDouble() ?? 0,
      urgency: map['urgency'] as String? ?? 'moyenne',
      confidenceNote: map['confidence_note'] as String? ?? '',
    );
  }
}