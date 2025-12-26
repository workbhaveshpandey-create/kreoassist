import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../ai_assistant/data/local_ai_service_impl.dart';
import '../../../ai_assistant/data/rag_manager_impl.dart';
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

  @override
  void initState() {
    super.initState();
    _checkInitialization();
  }

  Future<void> _checkInitialization() async {
    // 0. Request Permissions (Robust Check)
    if (Platform.isAndroid || Platform.isIOS) {
      // User requested "always ask" / ensure access for nearby search
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
      ].request();

      bool allGranted = statuses.values.every((status) => status.isGranted);
      if (!allGranted) {
        print(
            "Warning: Some permissions denied: ${statuses.entries.where((e) => !e.value.isGranted).map((e) => e.key).toList()}");
      }

      // Check and prompt to enable Bluetooth & WiFi
      await _checkAndEnableRadios();
    } else {
      print("Skipping permissions on Desktop/Web");
    }

    // 1. Check Username
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('username');

    if (name == null || name.isEmpty) {
      setState(() {
        _needsName = true;
        _status = "Welcome! Please enter your name.";
      });
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

    // 3. Check AI Model
    bool exists = await _aiService.isModelDownloaded;
    if (exists) {
      // Show smooth 5-second loading for better experience
      _showSmoothLoading();
    } else {
      _startDownload();
    }
  }

  void _showSmoothLoading() {
    setState(() {
      _downloading = true;
      _status = "Hi $_username! Getting everything ready...";
    });

    // Animate progress from 0 to 1 over 5 seconds
    const duration = 5;
    const interval = 50; // Update every 50ms
    const steps = (duration * 1000) ~/ interval;
    int currentStep = 0;

    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: interval));
      currentStep++;
      if (mounted) {
        setState(() {
          _progress = currentStep / steps;
        });
      }
      if (currentStep >= steps) {
        _navigateToHome();
        return false;
      }
      return true;
    });
  }

  Future<void> _checkAndEnableRadios() async {
    // Check if Bluetooth is enabled
    final bluetoothStatus = await Permission.bluetooth.serviceStatus;
    final bool btEnabled = bluetoothStatus == ServiceStatus.enabled;

    // Show dialog to enable radios if needed
    if (!btEnabled && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF121212),
          title: const Row(
            children: [
              Icon(Icons.wifi_tethering, color: Color(0xFFFF6B35)),
              SizedBox(width: 12),
              Text("Enable Connectivity",
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            "KreoAssist needs Bluetooth and WiFi enabled for the Mesh Network to work in disaster conditions.\n\nPlease enable them in Settings.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Later", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings(); // Opens device settings
              },
              icon: const Icon(Icons.settings),
              label: const Text("Open Settings"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
              ),
            ),
          ],
        ),
      );
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
          _status = "Error downloading model. Retry?";
          _downloading = false;
        });
      },
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (_) => HomeScreen(username: _username ?? "User")),
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
                Image.asset(
                  'assets/images/app_logo.png',
                  width: 150,
                  height: 150,
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
                    width: 250,
                    child: Column(
                      children: [
                        _BeautifulSlider(value: _progress),
                        const SizedBox(height: 12),
                        Text(
                          "${(_progress * 100).toInt()}%",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
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
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: constraints.maxWidth * value,
                height: 8,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Colors.deepPurple,
                      Colors.purpleAccent,
                      Colors.blue
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
