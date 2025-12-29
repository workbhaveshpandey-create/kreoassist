import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> submitFeedback({
    required int rating,
    required String category,
    required String message,
    required String userId,
    String? username,
  }) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = "${packageInfo.version}+${packageInfo.buildNumber}";

      await _firestore.collection('feedback').add({
        'rating': rating,
        'category': category,
        'message': message,
        'userId': userId,
        'username': username ?? 'Anonymous',
        'timestamp': FieldValue.serverTimestamp(),
        'appVersion': version,
        'platform':
            'flutter_app', // You can refine this using Platform.isAndroid etc.
      });
    } catch (e) {
      throw Exception('Failed to submit feedback: $e');
    }
  }
}
