abstract class LocalAIService {
  /// Loads the AI model from the specified [path].
  /// Returns true if successful.
  Future<bool> loadModel(String path);

  /// Generates a response based on the [prompt] and retrieved [context].
  /// Returns a stream of generated text tokens.
  Stream<String> generateResponse(String prompt, {String? context});

  /// Checks if the model is currently loaded.
  bool get isModelLoaded;

  /// Checks if the model file exists locally.
  Future<bool> get isModelDownloaded;

  /// Downloads the model from a remote source.
  /// Returns a stream of progress (0.0 to 1.0).
  Stream<double> downloadModel();
}
