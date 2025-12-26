import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../domain/rag_manager.dart';

class RagManagerImpl implements RAGManager {
  File? _file;
  Map<String, String> _documents = {}; // Title -> Content

  RagManagerImpl() {
    _init();
  }

  Future<void> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/rag_knowledge.json');
    if (await _file!.exists()) {
      try {
        final content = await _file!.readAsString();
        final Map<String, dynamic> json = jsonDecode(content);
        _documents = json.map((key, value) => MapEntry(key, value.toString()));
      } catch (e) {
        print("Error loading RAG DB: $e");
      }
    }
  }

  Future<void> _save() async {
    if (_file == null) return;
    await _file!.writeAsString(jsonEncode(_documents));
  }

  @override
  Future<void> addDocument(String title, String content) async {
    await _init(); // Ensure loaded
    _documents[title] = content;
    await _save();
  }

  @override
  Future<void> clearAll() async {
    _documents.clear();
    await _save();
  }

  @override
  Future<String> retrieveContext(String query) async {
    await _init(); // Ensure loaded

    // Simple Keyword Matching (Offline)
    final keywords =
        query.toLowerCase().split(' ').where((w) => w.length > 3).toList();
    if (keywords.isEmpty) return "";

    final List<String> relevantChunks = [];

    _documents.forEach((title, content) {
      int score = 0;
      final lowerContent = content.toLowerCase();
      for (final word in keywords) {
        if (lowerContent.contains(word)) score++;
      }

      if (score > 0) {
        relevantChunks.add("Title: $title\nContent: $content\n");
      }
    });

    // Sort by simple score would be better, but just taking first 3 matches for now
    return relevantChunks.take(3).join("\n---\n");
  }
}
