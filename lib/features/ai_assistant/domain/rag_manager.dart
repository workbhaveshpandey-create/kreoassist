abstract class RAGManager {
  /// Adds a document to the knowledge base.
  Future<void> addDocument(String title, String content);

  /// Retrieves relevant context for the given [query].
  /// Returns a concatenated string of the most relevant chunks.
  Future<String> retrieveContext(String query);

  /// Clears all knowledge.
  Future<void> clearAll();
}
