import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/toast_service.dart';
import '../../../../core/services/feedback_service.dart';

class FeedbackSheet extends ConsumerStatefulWidget {
  const FeedbackSheet({super.key});

  @override
  ConsumerState<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<FeedbackSheet> {
  double _rating = 0;
  String _category = 'General';
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _isClosing = false; // Controls exit animation

  final List<String> _categories = [
    'General',
    'Bug Report',
    'Feature Request',
    'Other'
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_rating == 0) {
      ToastService.showError("Please rate your experience.");
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      ToastService.showError("Please briefly describe your thoughts.");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? 'unknown_user';
      final username = prefs.getString('username') ?? 'Anonymous';

      final service = FeedbackService();
      await service.submitFeedback(
        rating: _rating.toInt(),
        category: _category,
        message: _commentController.text.trim(),
        userId: userId,
        username: username,
      );

      await prefs.setBool('has_submitted_feedback', true);

      if (mounted) {
        setState(() {
          _isClosing = true;
          _isSubmitting = false;
        });

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ToastService.showError("Submission failed. Please try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeIn,
          opacity: _isClosing ? 0.0 : 1.0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeIn,
            offset: _isClosing ? const Offset(0, 0.1) : Offset.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header Row
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const Text(
                        "Review",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      TextButton(
                        onPressed: _isSubmitting || _isClosing
                            ? null
                            : _submitFeedback,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF00BCD4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          backgroundColor:
                              const Color(0xFF00BCD4).withOpacity(0.1),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF00BCD4)))
                            : const Text("Post",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Text(
                            "How would you rate KreoAssist?",
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: RatingBar.builder(
                            initialRating: _rating,
                            minRating: 1,
                            direction: Axis.horizontal,
                            allowHalfRating: false,
                            itemCount: 5,
                            itemPadding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            itemBuilder: (context, _) => const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFD700),
                            ),
                            onRatingUpdate: (rating) {
                              setState(() => _rating = rating);
                            },
                            unratedColor: Colors.white12,
                            glow: false,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          "Topic",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _categories.map((cat) {
                            final isSelected = _category == cat;
                            return GestureDetector(
                              onTap: () => setState(() => _category = cat),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF00BCD4)
                                      : Colors.white10,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF00BCD4)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Details",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            controller: _commentController,
                            maxLines: 6,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Share your experience...",
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).padding.bottom + 20),
                      ]
                          .animate(interval: 50.ms)
                          .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                          .slideY(
                              begin: 0.1,
                              end: 0,
                              duration: 400.ms,
                              curve: Curves.easeOut),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
