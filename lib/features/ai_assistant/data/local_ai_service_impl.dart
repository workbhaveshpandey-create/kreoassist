import 'dart:async';
import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_llama/flutter_llama.dart';
import '../domain/local_ai_service.dart';

class LocalAIServiceImpl implements LocalAIService {
  // Gemma-2-2B-IT - Excellent multilingual support (Hindi, English, many languages)
  // Good balance of speed and quality
  static const String MODEL_URL =
      "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf";

  static const String MODEL_FILENAME = "gemma-2-2b-it-Q4_K_M.gguf";

  // Approximate model size in MB for UI display
  static const int MODEL_SIZE_MB = 1500; // ~1.5 GB

  bool _isLoaded = false;
  dynamic _llama;

  @override
  bool get isModelLoaded => _isLoaded;

  @override
  Future<bool> get isModelDownloaded async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$MODEL_FILENAME');
    final exists = await file.exists();
    print("Checking model existence at ${file.path}: $exists");
    return exists;
  }

  @override
  Stream<double> downloadModel() async* {
    print("Starting PARALLEL model download from $MODEL_URL...");
    final dir = await getApplicationDocumentsDirectory();
    final savePath = "${dir.path}/$MODEL_FILENAME";

    final controller = StreamController<double>();

    final task = DownloadTask(
      url: MODEL_URL,
      filename: MODEL_FILENAME,
      directory: dir.path,
      baseDirectory: BaseDirectory.root,
      updates: Updates.statusAndProgress,
      retries: 3,
      allowPause: true,
    );

    FileDownloader().download(
      task,
      onProgress: (progress) {
        controller.add(progress);
        print("Download progress: ${(progress * 100).toStringAsFixed(1)}%");
      },
      onStatus: (status) {
        print("Download status: $status");
        if (status == TaskStatus.complete) {
          controller.close();
          _isLoaded = false;
        } else if (status == TaskStatus.failed) {
          controller.addError("Download failed");
          controller.close();
        }
      },
    );

    yield* controller.stream;

    if (await File(savePath).exists()) {
      print("Model download complete: $savePath");
    }
  }

  @override
  Future<bool> loadModel(String path) async {
    try {
      print("Loading Gemma model from $path...");

      _llama = FlutterLlama.instance;
      // HIGH PERFORMANCE config - Full GPU usage
      await _llama.loadModel(
        LlamaConfig(
          modelPath: path,
          nThreads: 4, // Use more CPU threads
          nGpuLayers: 99, // Offload ALL layers to GPU for max speed
          contextSize: 2048, // Full context
          batchSize: 512, // Larger batches for GPU
          useGpu: true,
        ),
      );

      _isLoaded = true;
      print("Model loaded successfully.");
      return true;
    } catch (e) {
      print("Error loading model: $e");
      _isLoaded = false;
      return false;
    }
  }

  @override
  Stream<String> generateResponse(String prompt, {String? context}) async* {
    if (!_isLoaded || _llama == null) {
      yield "Error: Model not loaded.";
      return;
    }

    String effectiveContext = context ?? "";
    // System prompt for multilingual responses
    final fullSystemPrompt = effectiveContext.isNotEmpty
        ? "Context:\n$effectiveContext\n\nYou are a helpful emergency assistant. Reply in the SAME LANGUAGE the user writes in. Be brief (2-3 sentences)."
        : "You are a helpful emergency assistant. Reply in the SAME LANGUAGE the user writes in. If user writes Hindi, reply in Hindi. Be brief (2-3 sentences),if user write hinglish use hinglish.";

    // Gemma 2 prompt format
    final formattedPrompt =
        "<start_of_turn>user\n$fullSystemPrompt\n\n$prompt<end_of_turn>\n<start_of_turn>model\n";

    try {
      // Params with repetition penalty to avoid repetitive output
      final params = GenerationParams(
        prompt: formattedPrompt,
        maxTokens: 128,
        temperature: 0.7,
        topP: 0.9,
        repeatPenalty: 1.2,
      );

      final response = await _llama!.generate(params);
      yield response.text ?? "";
    } catch (e) {
      yield "Error generating response: $e";
    }
  }
}
