import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

/// Pollinations AI Service for online AI responses
/// Free API, no key required
class GoogleAIService {
  static String? _apiKey; // Kept for interface compatibility

  // Pollinations API endpoint
  static const String _baseUrl = 'https://text.pollinations.ai';

  static void setApiKey(String key) {
    _apiKey = key; // Not needed for Pollinations but kept for interface
    print("[PollinationsAI] API key set (not required for Pollinations)");
  }

  // Always has API "key" since Pollinations doesn't need one
  static bool get hasApiKey => true;

  /// Check if device has network connectivity
  static Future<bool> hasNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      final hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      print("[PollinationsAI] Network check: $hasInternet");
      return hasInternet;
    } on SocketException catch (e) {
      print("[PollinationsAI] Network check failed: $e");
      return false;
    }
  }

  /// Generate response using Pollinations AI (streaming simulation)
  static Stream<String> generateResponseStream(String prompt,
      {String? context}) async* {
    final systemPrompt = context != null
        ? "Context:\n$context\n\nYou are a helpful assistant. Be brief (2-3 sentences)."
        : "You are a helpful ai assistant. Be brief (2-3 sentences).";

    final fullPrompt = "$systemPrompt\n\nUser: $prompt";

    // URL encode the prompt
    final encodedPrompt = Uri.encodeComponent(fullPrompt);
    final url = '$_baseUrl/$encodedPrompt';

    print("[PollinationsAI] Calling API...");

    try {
      final response = await http
          .get(
            Uri.parse(url),
          )
          .timeout(const Duration(seconds: 30));

      print("[PollinationsAI] Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final text = response.body;
        print("[PollinationsAI] Got response: ${text.length} chars");

        // Yield in chunks for streaming effect
        final words = text.split(' ');
        String buffer = '';
        for (int i = 0; i < words.length; i++) {
          buffer += (i > 0 ? ' ' : '') + words[i];
          if (i % 3 == 2 || i == words.length - 1) {
            yield buffer;
            buffer = '';
            await Future.delayed(const Duration(milliseconds: 20));
          }
        }
      } else {
        print("[PollinationsAI] API Error: ${response.statusCode}");
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print("[PollinationsAI] Exception: $e");
      throw Exception('Failed to get response: $e');
    }
  }

  /// Generate response (non-streaming fallback)
  static Future<String> generateResponse(String prompt,
      {String? context}) async {
    final systemPrompt = context != null
        ? "Context:\n$context\n\nYou are a helpful emergency assistant. Reply in the SAME LANGUAGE the user writes in. Be brief (2-3 sentences)."
        : "You are a helpful emergency assistant. Reply in the SAME LANGUAGE the user writes in. Be brief (2-3 sentences).";

    final fullPrompt = "$systemPrompt\n\nUser: $prompt";
    final encodedPrompt = Uri.encodeComponent(fullPrompt);
    final url = '$_baseUrl/$encodedPrompt';

    try {
      final response = await http
          .get(
            Uri.parse(url),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.body.trim();
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get response: $e');
    }
  }
}
