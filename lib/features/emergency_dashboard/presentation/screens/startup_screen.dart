import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/services/toast_service.dart';
import '../../../ai_assistant/data/local_ai_service_impl.dart';
import '../../../ai_assistant/data/rag_manager_impl.dart';
// import '../../../../core/services/update_service.dart'; // Moved to Home
import 'home_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final _aiService = LocalAIServiceImpl();
  final _nameController = TextEditingController();

  double _progress = 0.0;
  String _status = "Checking system...";
  bool _downloading = false;
  bool _needsName = false;
  String? _username;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _checkInitialization();
  }

  Future<void> _checkInitialization() async {
    // 0. Request Permissions with timeout (non-blocking)
    // This ensures app loads even if WiFi/Bluetooth are disabled
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await Future.wait([
          _requestPermissionsWithTimeout(),
          _checkAndEnableRadios(),
        ]).timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            print('⚠️ Permission/radio check timed out, proceeding anyway');
            return [];
          },
        );
      } catch (e) {
        print('⚠️ Permission check error: $e, proceeding anyway');
      }
    } else {
      print("Skipping permissions on Desktop/Web");
    }

    // 1. Check Username & User ID (Stable Identity)
    final prefs = await SharedPreferences.getInstance();

    // Generate UUID if missing (for stable mesh identity)
    if (!prefs.containsKey('userId')) {
      await prefs.setString('userId', const Uuid().v4());
    }
    _userId = prefs.getString('userId');

    final name = prefs.getString('username');

    if (name == null || name.isEmpty) {
      if (mounted) {
        setState(() {
          _needsName = true;
        });
      }
      return;
    }
    _username = name;

    // 2. Seed RAG Data (Prototype)
    final rag = RagManagerImpl();
    await rag.addDocument("Burns Treatment",
        "To treat a burn, immediately cool the burn with cool or lukewarm running water for 20 minutes. Do not use ice, iced water, or any creams or greasy substances like butter.");
    await rag.addDocument("Fracture First Aid",
        "Stop any bleeding. Apply pressure to the wound with a sterile bandage, a clean cloth or a clean piece of clothing. Immobilize the injured area. Don't try to realign the bone or push a bone that's sticking out back in.");
    await rag.addDocument("CPR Guide",
        "Place the heel of your hand on the centre of the person's chest, then place the other hand on top and press down by 5 to 6cm (2 to 2.5 inches) at a steady rate of 100 to 120 compressions a minute.");

    // 3. Check for Updates (Moved to HomeScreen for background check)
    // if (mounted) {
    //   await UpdateService.checkForUpdates(context);
    // }

    // 4. Check AI Model
    bool exists = await _aiService.isModelDownloaded;
    if (exists) {
      // Show smooth 5-second loading for better experience
      _showSmoothLoading();
    } else {
      // Model not downloaded - ask user if they want to download
      _showModelChoiceDialog();
    }
  }

  /// Show dialog asking user whether to download offline AI model
  Future<void> _showModelChoiceDialog() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if user already made a choice (for returning users)
    final previousChoice = prefs.getString('offline_model_choice');
    if (previousChoice == 'skip') {
      // User previously skipped, but still show smooth loading for consistent experience
      _showSmoothLoading();
      return;
    }

    if (!mounted) return;

    final sizeMB = LocalAIServiceImpl.MODEL_SIZE_MB;
    final sizeDisplay = sizeMB >= 1000
        ? "${(sizeMB / 1000).toStringAsFixed(1)} GB"
        : "$sizeMB MB";

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.download_rounded, color: Colors.deepOrange),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Download Offline AI?',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The offline AI model allows you to use AI features without internet connection.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storage, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Download Size: $sizeDisplay',
                    style: const TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '• You can always download later from Settings\n• Online AI will work without this download',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                Text('Skip for Now', style: TextStyle(color: Colors.grey[400])),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
            child: Text('Download ($sizeDisplay)'),
          ),
        ],
      ),
    );

    if (result == true) {
      // User chose to download
      await prefs.setString('offline_model_choice', 'download');
      _startDownload();
    } else {
      // User chose to skip
      await prefs.setString('offline_model_choice', 'skip');
      _showSmoothLoading();
    }
  }

  void _showSmoothLoading() {
    setState(() {
      _downloading = true;
      _status = "Hi $_username! Getting everything ready...";
    });

    // Animate progress from 0 to 1 over 3 seconds (faster but complete)
    const duration = 3;
    const interval = 30; // Update every 30ms for smoothness
    const steps = (duration * 1000) ~/ interval;
    int currentStep = 0;

    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: interval));
      currentStep++;

      if (mounted) {
        setState(() {
          _progress = (currentStep / steps).clamp(0.0, 1.0);
        });
      }

      if (currentStep >= steps) {
        // Ensure visual 100%
        if (mounted) {
          setState(() {
            _progress = 1.0;
            _status = "Welcome, $_username!";
          });
        }

        // Wait for user to see 100%
        await Future.delayed(const Duration(milliseconds: 500));

        _navigateToHome();
        return false;
      }
      return true;
    });
  }

  /// Request permissions with timeout and error handling
  Future<void> _requestPermissionsWithTimeout() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location, // Required for BLE/WiFi on older Android
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.nearbyWifiDevices, // Critical for Wifi Direct / Local Only
        Permission.microphone, // Added for STT feature
        Permission.sms, // For emergency SMS
        Permission.phone, // For emergency calls
        Permission
            .notification, // For persistent background scanning notification
      ].request();

      bool allGranted = statuses.values.every((status) => status.isGranted);
      if (!allGranted) {
        print(
            "Warning: Some permissions denied: ${statuses.entries.where((e) => !e.value.isGranted).map((e) => e.key).toList()}");
      }
    } catch (e) {
      print('⚠️ Permission request error: $e');
    }
  }

  Future<void> _checkAndEnableRadios() async {
    // Check if Bluetooth is enabled
    final bluetoothStatus = await Permission.bluetooth.serviceStatus;
    final bool btEnabled = bluetoothStatus == ServiceStatus.enabled;

    // Show non-blocking prompt if radios are off
    if (!btEnabled && mounted) {
      // Show non-blocking prompt if radios are off
      if (!btEnabled && mounted) {
        ToastService.showWarning(
            "Please enable Bluetooth & WiFi for Mesh Network");
      }
    }
  }

  Future<void> _saveName() async {
    final text = _nameController.text.trim();
    if (text.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', text);

    setState(() {
      _needsName = false;
      _username = text;
    });

    // Resume checks
    _checkInitialization();
  }

  void _startDownload() {
    final sizeMB = LocalAIServiceImpl.MODEL_SIZE_MB;
    final sizeDisplay = sizeMB >= 1000
        ? "${(sizeMB / 1000).toStringAsFixed(2)} GB"
        : "$sizeMB MB";

    setState(() {
      _downloading = true;
      _status = "Hi $_username! Downloading AI Brain (~$sizeDisplay)...";
    });

    _aiService.downloadModel().listen(
      (progress) {
        setState(() {
          _progress = progress;
        });
      },
      onDone: () {
        setState(() {
          _status = "Initialization Complete.";
        });
        Future.delayed(const Duration(seconds: 1), _navigateToHome);
      },
      onError: (e) {
        setState(() {
          _status = "Download failed. Please close and reopen app to retry.";
          _downloading = false;
        });
      },
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (_) => HomeScreen(
                username: _username ?? "User",
                userId: _userId ?? "unknown_id",
              )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_needsName) ...[
                const Icon(Icons.person_pin,
                    size: 64, color: Colors.deepOrange),
                const SizedBox(height: 24),
                Text(
                  "Who are you?",
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Your Name / Call Sign",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saveName,
                  child: const Text("Continue"),
                )
              ] else ...[
                // App Logo with Animation
                ClipOval(
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                )
                    .animate()
                    .fade(duration: 800.ms)
                    .saturate(duration: 2.seconds)
                    .shimmer(delay: 500.ms, duration: 2.seconds),

                const SizedBox(height: 24),
                Text(
                  "KREOASSIST",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                ).animate().fadeIn(delay: 300.ms).moveY(begin: 10, end: 0),

                const SizedBox(height: 8),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                ).animate().fadeIn(delay: 500.ms),

                const SizedBox(height: 40),

                // Beautiful Loading Slider
                if (_downloading)
                  SizedBox(
                    width: 280,
                    child: _BeautifulSlider(value: _progress),
                  ).animate().fadeIn()
                else if (!_needsName)
                  const SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(strokeWidth: 3))
                      .animate()
                      .scale(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BeautifulSlider extends StatelessWidget {
  final double value;

  const _BeautifulSlider({required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main Progress Bar
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Stack(
            children: [
              // Animated Progress Fill
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: constraints.maxWidth * value,
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF9933), // Saffron
                          Color(0xFFFFFFFF), // White
                          Color(0xFF138808), // Green
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9933).withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Progress Percentage with Glow
        Text(
          "${(_progress * 100).toInt()}%",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 1,
            shadows: [
              Shadow(
                color: const Color(0xFFFF9933).withOpacity(0.5),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }

  double get _progress => value;
}
