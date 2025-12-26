import 'package:flutter/material.dart';

import '../../../ai_assistant/data/hybrid_ai_service.dart';

class FirstAidScreen extends StatefulWidget {
  const FirstAidScreen({super.key});

  @override
  State<FirstAidScreen> createState() => _FirstAidScreenState();
}

class _FirstAidScreenState extends State<FirstAidScreen> {
  final HybridAIService _aiService = HybridAIService();
  String? _selectedTopic;
  bool _isLoading = false;
  String _aiResponse = '';
  final TextEditingController _symptomController = TextEditingController();

  // Offline First Aid Data
  static const Map<String, FirstAidTopic> topics = {
    'cpr': FirstAidTopic(
      title: 'CPR (Cardiopulmonary Resuscitation)',
      icon: Icons.favorite,
      color: Color(0xFFE53935),
      steps: [
        'Check if the person is responsive - tap their shoulder and shout',
        'Call emergency services (112) or ask someone to call',
        'Place the person on their back on a firm surface',
        'Put the heel of your hand on center of chest, interlock fingers',
        'Press hard and fast - 5-6 cm deep, 100-120 compressions/min',
        'Give 2 rescue breaths after every 30 compressions',
        'Continue until help arrives or person starts breathing',
      ],
    ),
    'burns': FirstAidTopic(
      title: 'Burns Treatment',
      icon: Icons.whatshot,
      color: Color(0xFFFF6B35),
      steps: [
        'Cool the burn under cool running water for 20 minutes',
        'Remove jewelry or tight clothing near the burn',
        'Do NOT use ice, butter, or toothpaste',
        'Cover with clean, non-fluffy material (cling film works well)',
        'Do NOT burst any blisters',
        'Take paracetamol for pain if needed',
        'Seek medical help for burns larger than hand size',
      ],
    ),
    'bleeding': FirstAidTopic(
      title: 'Severe Bleeding',
      icon: Icons.water_drop,
      color: Color(0xFFD32F2F),
      steps: [
        'Apply direct pressure to wound with clean cloth',
        'Press firmly and continuously for at least 10 minutes',
        'If blood soaks through, add more cloth on top',
        'Elevate the injured limb above heart level if possible',
        'Do NOT remove any objects stuck in the wound',
        'Keep the person calm and lying down',
        'Call emergency services (112) for severe bleeding',
      ],
    ),
    'fractures': FirstAidTopic(
      title: 'Fractures & Broken Bones',
      icon: Icons.accessibility_new,
      color: Color(0xFF7B1FA2),
      steps: [
        'Keep the injured area still - do NOT move it',
        'Control any bleeding by applying gentle pressure',
        'Apply ice wrapped in cloth to reduce swelling',
        'Do NOT try to straighten or realign the bone',
        'Immobilize with splint using sticks, magazines, or rolled cloth',
        'Support the limb in the position you find it',
        'Get medical help immediately - call 112',
      ],
    ),
    'choking': FirstAidTopic(
      title: 'Choking',
      icon: Icons.air,
      color: Color(0xFF1976D2),
      steps: [
        'Ask "Are you choking?" - if they can speak, encourage coughing',
        'If they cannot speak, give 5 back blows between shoulder blades',
        'Check mouth for dislodged object after each blow',
        'If unsuccessful, give 5 abdominal thrusts (Heimlich)',
        'Stand behind person, make fist above navel',
        'Pull sharply inward and upward',
        'Alternate 5 back blows and 5 thrusts until cleared',
      ],
    ),
  };

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    // Set API key and initialize hybrid service
    // _aiService.setGoogleApiKey('...'); // Not needed for Pollinations AI
    await _aiService.initialize();
  }

  void _askAI() async {
    if (_symptomController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _aiResponse = '';
    });

    final prompt =
        "First aid for: ${_symptomController.text}. Give brief step-by-step instructions.";

    String fullResponse = '';
    await for (final chunk in _aiService.generateResponse(prompt)) {
      if (!mounted) return; // Prevent setState after dispose
      fullResponse += chunk;
      setState(() {
        _aiResponse = fullResponse;
      });
    }

    if (!mounted) return; // Prevent setState after dispose
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('First Aid Guide'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _selectedTopic == null ? _buildTopicGrid() : _buildTopicDetail(),
    );
  }

  Widget _buildTopicGrid() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Symptom Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFFFF6B35)),
                    SizedBox(width: 8),
                    Text('AI Symptom Helper',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        )),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _symptomController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Describe symptoms (e.g., "child has fever")...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                    filled: true,
                    fillColor: Colors.black,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send, color: Color(0xFFFF6B35)),
                      onPressed: _isLoading ? null : _askAI,
                    ),
                  ),
                  onSubmitted: (_) => _askAI(),
                ),
                if (_aiResponse.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_aiResponse,
                        style: const TextStyle(color: Colors.white70)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Emergency Guides',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 12),
          // Topic Cards Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: topics.entries
                .map((e) => _buildTopicCard(e.key, e.value))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(String key, FirstAidTopic topic) {
    return GestureDetector(
      onTap: () => setState(() => _selectedTopic = key),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: topic.color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: topic.color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(topic.icon, color: topic.color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              topic.title.split('(')[0].trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicDetail() {
    final topic = topics[_selectedTopic]!;
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: topic.color.withOpacity(0.1),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _selectedTopic = null),
              ),
              const SizedBox(width: 8),
              Icon(topic.icon, color: topic.color, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(topic.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ],
          ),
        ),
        // Steps
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: topic.steps.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: topic.color.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: topic.color,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                          child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      )),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                      topic.steps[index],
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, height: 1.4),
                    )),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class FirstAidTopic {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> steps;

  const FirstAidTopic({
    required this.title,
    required this.icon,
    required this.color,
    required this.steps,
  });
}
