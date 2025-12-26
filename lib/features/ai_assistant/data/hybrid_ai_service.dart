import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'local_ai_service_impl.dart';
import 'google_ai_service.dart';

import 'package:flutter/foundation.dart';

/// Hybrid AI Service that automatically switches between:
/// - Google Gemini API (online) for faster, more powerful responses
/// - Local Gemma model (offline) when network is unavailable
class HybridAIService {
  final LocalAIServiceImpl _localService = LocalAIServiceImpl();
  bool _localModelLoaded = false;
  bool _useOnlineByDefault = true;

  /// Notifies listeners about the loading state (true = loading, false = ready)
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);

  /// Set Google API key for online mode
  void setGoogleApiKey(String key) {
    GoogleAIService.setApiKey(key);
  }

  /// Check if Google API is configured
  bool get hasOnlineCapability => GoogleAIService.hasApiKey;

  /// Toggle to prefer offline mode even when online
  void setPreferOffline(bool preferOffline) {
    _useOnlineByDefault = !preferOffline;
  }

  /// Initialize the hybrid service
  Future<void> initialize() async {
    isLoadingNotifier.value = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelPath = "${dir.path}/${LocalAIServiceImpl.MODEL_FILENAME}";
      _localModelLoaded = await _localService.loadModel(modelPath);
      print("[HybridAI] Local model loaded: $_localModelLoaded");
    } catch (e) {
      print("[HybridAI] Error loading local model: $e");
      _localModelLoaded = false;
    } finally {
      // Ensure we notify that loading is finished, success or fail
      isLoadingNotifier.value = false;
    }
  }

  /// Check if local model is available
  bool get isLocalModelReady => _localModelLoaded;

  /// Check if local model file exists
  Future<bool> get isLocalModelDownloaded => _localService.isModelDownloaded;

  /// Download local model for offline use
  Stream<double> downloadLocalModel() => _localService.downloadModel();

  /// Generate AI response with automatic online/offline switching
  Stream<String> generateResponse(String prompt, {String? context}) async* {
    bool hasNetwork = await GoogleAIService.hasNetworkConnection();
    bool useOnline =
        hasNetwork && GoogleAIService.hasApiKey && _useOnlineByDefault;

    print("[HybridAI] ===============================");
    print("[HybridAI] Network: $hasNetwork");
    print("[HybridAI] Has API Key: ${GoogleAIService.hasApiKey}");
    print("[HybridAI] Use Online Default: $_useOnlineByDefault");
    print("[HybridAI] Decision: ${useOnline ? 'ONLINE' : 'OFFLINE'}");
    print("[HybridAI] ===============================");

    if (useOnline) {
      // Try online first with streaming
      try {
        yield "🌐 "; // Indicator for online mode
        print("[HybridAI] Calling Google Gemini API...");
        await for (final chunk in GoogleAIService.generateResponseStream(prompt,
            context: context)) {
          print("[HybridAI] Got chunk: ${chunk.length} chars");
          yield chunk;
        }
        print("[HybridAI] Online response complete!");
        return;
      } catch (e) {
        print("[HybridAI] ❌ Online FAILED: $e");
        yield "\n⚠️ Online failed, using offline...\n";
        // Fall through to offline
      }
    }

    // Use offline local model
    if (_localModelLoaded) {
      yield "📱 "; // Indicator for offline mode
      print("[HybridAI] Using offline local model...");
      try {
        // Add timeout because native crashes don't throw Dart exceptions
        bool gotResponse = false;
        await for (final chunk in _localService
            .generateResponse(prompt, context: context)
            .timeout(const Duration(seconds: 30))) {
          gotResponse = true;
          yield chunk;
        }
        if (!gotResponse) {
          yield "⚠️ Local AI did not respond. Please connect to WiFi for online AI.";
        }
        print("[HybridAI] Offline response complete!");
      } catch (e) {
        print("[HybridAI] ❌ Local AI generation CRASHED: $e");
        yield "\n⚠️ Local AI error: Please connect to WiFi to use online AI mode.";
      }
    } else {
      yield "⚠️ AI loading... Please wait 10-20 seconds for local model to initialize, or connect to WiFi.";
    }
  }

  /// Get current mode description
  Future<String> getCurrentMode() async {
    bool hasNetwork = await GoogleAIService.hasNetworkConnection();
    if (hasNetwork && GoogleAIService.hasApiKey && _useOnlineByDefault) {
      return "Online";
    } else if (_localModelLoaded) {
      return "Offline";
    } else {
      return "Unavailable";
    }
  }
}
