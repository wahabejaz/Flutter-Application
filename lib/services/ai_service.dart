import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:developer' as developer;

/// AI Service for generating medicine explanations using OpenRouter with DeepSeek Chat model
///
/// SETUP INSTRUCTIONS:
/// 1. Get an OpenRouter API key from https://openrouter.ai/keys
/// 2. Add it to `.env` as OPENROUTER_API_KEY=your_key_here
/// 3. Ensure `dotenv.load()` is called in `main()` before using this service
/// 4. This service calls OpenRouter's chat/completions endpoint on demand (button taps only)
class AIService {
  // Use OpenRouter chat completions endpoint with DeepSeek Chat model
  // NOTE: Do not call this service from a widget's build() method — call from event handlers (button taps) instead.
  static const String _apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const String _model = 'deepseek/deepseek-chat';

  late final String _apiKey;

  AIService() {
    // Ensure dotenv is loaded before accessing env
    if (!dotenv.isInitialized) {
      throw Exception('Environment variables not loaded. Please ensure dotenv.load() is called in main().');
    }

    // Read OpenRouter API key from .env (OPENROUTER_API_KEY)
    final apiKey = dotenv.env['OPENROUTER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'YOUR_OPENROUTER_API_KEY_HERE') {
      throw Exception('OPENROUTER_API_KEY not found in .env file. Please add your OpenRouter API key to enable AI features.');
    }

    // Do not attempt to validate provider-specific prefixes here — just ensure a non-empty key is provided.
    _apiKey = apiKey;
  }

  /// Generate a brief explanation of what a medicine is commonly used for
  /// Returns a short paragraph explaining the medicine's general purpose
  Future<String> generateMedicineExplanation({
    required String name,
    required String dosage,
    required String frequency,
  }) async {
    try {
      // Prepare prompt and OpenRouter chat-completions payload.
      // Remove unnecessary braces from simple interpolations.
      final prompt = 'What is $name ($dosage, taken $frequency) used for in medicine? Provide a brief, clear explanation of its medical purposes. Keep it to 2-3 sentences.';

      final url = Uri.parse(_apiUrl);

      // OpenRouter requires Authorization header with Bearer token and Content-Type header
      final headers = {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      };

      final body = jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.3,
        'max_tokens': 200
      });

      final response = await http.post(url, headers: headers, body: body).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('AI service took too long to respond'),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // OpenRouter may include an error field; check it first.
        if (data['error'] != null) {
          final errorMsg = data['error']['message'] ?? data['error'].toString();
          developer.log('API returned error object: $errorMsg', name: 'AIService');
          final fallback = _localFallback(name);
          if (fallback != null) return '$fallback\n\n(Note: AI unavailable — $errorMsg)';
          throw Exception('API Error: $errorMsg');
        }

        // Try parsing common chat-completion response shapes (OpenAI-like / OpenRouter)
        String text = '';

        // Standard OpenAI-like "choices" with message.content
        if (data['choices'] != null && data['choices'] is List && data['choices'].isNotEmpty) {
          final choice = data['choices'][0];
          try {
            if (choice['message'] != null) {
              final msg = choice['message'];
              if (msg is Map && msg['content'] != null) {
                text = (msg['content'] as String).trim();
              }
            } else if (choice['text'] != null) {
              text = (choice['text'] as String).trim();
            }
          } catch (_) {}
        }

        // fallback to other possible structures (mirrors of older endpoints)
        if (text.isEmpty && data['output'] != null && data['output'] is List && data['output'].isNotEmpty) {
          try {
            text = (data['output'][0]['content'][0]['text'] ?? '').toString().trim();
          } catch (_) {}
        }

        if (text.isEmpty && data['content'] != null && data['content']['parts'] != null) {
          try {
            text = (data['content']['parts'][0]['text'] ?? '').toString().trim();
          } catch (_) {}
        }

        if (text.isEmpty) {
          final fallback = _localFallback(name);
          if (fallback != null) {
            developer.log('Using local fallback for $name', name: 'AIService');
            return '$fallback\n\n(Note: AI response empty — using fallback)';
          }
          throw Exception('No content in API response');
        }

        return text;
      } else if (response.statusCode == 400) {
        developer.log('400 - ${response.body}', name: 'AIService');
        final fallback = _localFallback(name);
        if (fallback != null) return '$fallback\n\n(Note: Invalid request — using fallback)';
        throw Exception('Invalid request: ${response.body}');
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        developer.log('Unauthorized (401/403) - ${response.body}', name: 'AIService');
        final fallback = _localFallback(name);
        if (fallback != null) return '$fallback\n\n(Note: API key invalid or unauthorized — using fallback)';
        throw Exception('API key is invalid or unauthorized. Please check your OpenRouter API key.');
      } else if (response.statusCode == 404) {
        developer.log('404 Not Found - endpoint or model may be invalid', name: 'AIService');
        final fallback = _localFallback(name);
        if (fallback != null) return '$fallback\n\n(Note: API model not found — using fallback)';
        throw Exception('API endpoint or model not found (404).');
      } else if (response.statusCode == 429) {
        developer.log('Rate limit (429) - ${response.body}', name: 'AIService');
        final fallback = _localFallback(name);
        if (fallback != null) return '$fallback\n\n(Note: Rate limit exceeded — using fallback)';
        throw Exception('Rate limit exceeded. Please try again later.');
      } else {
        developer.log('Unexpected status ${response.statusCode} - ${response.body}', name: 'AIService');
        final fallback = _localFallback(name);
        if (fallback != null) return '$fallback\n\n(Note: API error ${response.statusCode} — using fallback)';
        throw Exception('API returned status ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException catch (e) {
      developer.log('Timeout - ${e.message}', name: 'AIService');
      final fallback = _localFallback(name);
      if (fallback != null) return '$fallback\n\n(Note: Connection timeout — using fallback)';
      throw Exception('Connection timeout: ${e.message}. Please check your internet connection.');
    } catch (e) {
      developer.log('Exception - $e', name: 'AIService');
      final fallback = _localFallback(name);
      if (fallback != null) return '$fallback\n\n(Note: AI service unavailable — using fallback)';
      rethrow;
    }
  }

  // Local fallback explanations for common medicines to avoid total failure when API is unavailable
  String? _localFallback(String name) {
    final key = name.trim().toLowerCase();
    final map = <String, String>{
      'paracetamol': 'Paracetamol (also known as acetaminophen) is commonly used to relieve pain and reduce fever.',
      'acetaminophen': 'Acetaminophen (paracetamol) is commonly used to relieve pain and reduce fever.',
      'panadol': 'Panadol is a brand of paracetamol used for pain relief and fever reduction.',
      'ibuprofen': 'Ibuprofen is a nonsteroidal anti-inflammatory drug (NSAID) commonly used for pain, inflammation, and fever.',
      'amoxicillin': 'Amoxicillin is an antibiotic used to treat bacterial infections such as respiratory or ear infections.',
      'lisinopril': 'Lisinopril is commonly prescribed to treat high blood pressure and heart failure.',
      'metformin': 'Metformin is commonly used to help control blood sugar levels in people with type 2 diabetes.'
    };

    // simple contains matching for brand names
    if (map.containsKey(key)) return map[key];
    for (final entry in map.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return null;
  }
}