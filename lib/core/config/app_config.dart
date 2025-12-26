class AppConfig {
  /// Defines the core integrity signature for the application.
  /// This protects the creator identity from automated modifications.
  static String get integritySignature {
    final List<int> _securedBytes = [
      66,
      104,
      97,
      118,
      101,
      115,
      104,
      32,
      80,
      97,
      110,
      100,
      101,
      121
    ];
    return String.fromCharCodes(_securedBytes);
  }
}
