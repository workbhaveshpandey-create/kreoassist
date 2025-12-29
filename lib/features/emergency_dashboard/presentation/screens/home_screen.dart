import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../features/emergency_dashboard/data/mesh_provider.dart';
import '../../../../features/emergency_dashboard/presentation/screens/chat_screen.dart';
import '../../../../features/emergency_dashboard/presentation/screens/mesh_screen.dart';
import '../../../../features/emergency_dashboard/presentation/screens/sos_dashboard.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/update_service.dart';
import '../../../../core/services/toast_service.dart';
import '../../../ai_assistant/data/local_ai_service_impl.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String username;
  final String userId;
  const HomeScreen({super.key, required this.username, required this.userId});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0; // Default to AI Assistant tab
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const ChatScreen(),
      MeshScreen(username: widget.username, userId: widget.userId),
      const SOSDashboard(),
    ];

    // Auto-start Mesh Services (Broadcast + Discover) if not disabled by user
    _initMeshServices();

    // Check for app updates (self-hosted OTA)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Delay update check to ensure smooth startup & no "loading slider" interference
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) UpdateService.checkForUpdates(context);
      });
    });
  }

  Future<void> _initMeshServices() async {
    final prefs = await SharedPreferences.getInstance();

    // Default is TRUE (enabled) unless user explicitly turned off
    final broadcastEnabled = prefs.getBool('mesh_broadcast_enabled') ?? true;
    final discoverEnabled = prefs.getBool('mesh_discover_enabled') ?? true;

    final notifier = ref.read(meshProvider.notifier);

    if (broadcastEnabled && !ref.read(meshProvider).isAdvertising) {
      notifier.startAdvertising(widget.username, widget.userId);
    }
    if (discoverEnabled && !ref.read(meshProvider).isDiscovering) {
      notifier.startDiscovery(widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFFF9933), // Saffron
              Colors.white, // White
              Color(0xFF138808), // Green
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text(
            "KreoAssist",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white, // Required for ShaderMask
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedIndex),
          child: _screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'AI Assistant',
          ),
          NavigationDestination(
            icon: Icon(Icons.wifi_tethering_off),
            selectedIcon: Icon(Icons.wifi_tethering),
            label: 'Mesh Network',
          ),
          NavigationDestination(
            icon: Icon(Icons.sos_outlined),
            selectedIcon: Icon(Icons.sos),
            label: 'SOS',
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const SettingsSheet(),
    );
  }
}

class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  String _username = "Loading...";
  String _currentVersion = "Loading...";
  bool _checkingUpdate = false;

  // Offline AI Model state
  bool _modelDownloaded = false;
  bool _downloadingModel = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadVersion();
    _checkModelStatus();
  }

  Future<void> _checkModelStatus() async {
    final service = LocalAIServiceImpl();
    final downloaded = await service.isModelDownloaded;
    if (mounted) {
      setState(() => _modelDownloaded = downloaded);
    }
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? "Unknown User";
    });
  }

  Future<void> _loadVersion() async {
    try {
      // Use package_info_plus to get actual version
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _currentVersion =
              "${packageInfo.version} (Build ${packageInfo.buildNumber})";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentVersion = "1.0.0";
        });
      }
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdate = true);

    try {
      await UpdateService.checkForUpdates(context);
      // If no update dialog was shown, show "up to date" feedback
      if (mounted) {
        ToastService.showSuccess("You're using the latest version!");
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError("Failed to check for updates: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _checkingUpdate = false);
      }
    }
  }

  void _startModelDownload() {
    setState(() {
      _downloadingModel = true;
      _downloadProgress = 0.0;
    });

    final service = LocalAIServiceImpl();
    service.downloadModel().listen(
      (progress) {
        if (mounted) {
          setState(() => _downloadProgress = progress);
        }
      },
      onDone: () async {
        if (mounted) {
          setState(() {
            _downloadingModel = false;
            _modelDownloaded = true;
          });
          // Reset the choice preference so startup doesn't auto-skip
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('offline_model_choice', 'download');

          // Show restart dialog
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check_circle,
                          color: Color(0xFF4CAF50)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Download Complete!',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                  ],
                ),
                content: const Text(
                  'Offline AI Model has been downloaded successfully.\n\nPlease restart the app to enable offline AI features.',
                  style: TextStyle(color: Colors.grey),
                ),
                actions: [
                  FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop(); // Close settings sheet
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50)),
                    child: const Text('Got it'),
                  ),
                ],
              ),
            );
          }
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _downloadingModel = false);
          ToastService.showError("Download failed: $e");
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 24,
          right: 24,
          top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings, size: 28),
              const SizedBox(width: 12),
              Text("Settings",
                  style: Theme.of(context).textTheme.headlineSmall),
            ],
          ).animate().fadeIn().moveX(),
          const Divider(height: 32),
          const Text("USER PROFILE").animate().fadeIn(delay: 200.ms),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                  _username.isNotEmpty ? _username[0].toUpperCase() : "?",
                  style: const TextStyle(color: Colors.white)),
            ),
            title: Text(
              _username,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: const Text("This name is visible to peers"),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 20),
          const Text("MESH NETWORK").animate().fadeIn(delay: 350.ms),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary:
                const Icon(Icons.shield_outlined, color: Color(0xFF00BCD4)),
            title: const Text("Background Mode",
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Keep scanning when app is closed"),
            value: ref.watch(meshProvider).backgroundMode,
            activeColor: const Color(0xFF00BCD4),
            onChanged: (val) {
              ref.read(meshProvider.notifier).toggleBackgroundMode(val);
            },
          ).animate().fadeIn(delay: 350.ms),
          const SizedBox(height: 20),
          const Text("OFFLINE AI MODEL").animate().fadeIn(delay: 375.ms),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    (_modelDownloaded ? const Color(0xFF4CAF50) : Colors.orange)
                        .withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _modelDownloaded
                    ? Icons.check_circle
                    : Icons.cloud_download_outlined,
                color:
                    _modelDownloaded ? const Color(0xFF4CAF50) : Colors.orange,
                size: 24,
              ),
            ),
            title: Text(
              _modelDownloaded ? "Model Downloaded" : "Model Not Downloaded",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _modelDownloaded
                  ? "Offline AI is ready to use"
                  : "Download ~1.5 GB for offline AI",
            ),
            trailing: _downloadingModel
                ? Container(
                    width: 90,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Colors.deepOrange.withOpacity(0.3)),
                    ),
                    child: Stack(
                      children: [
                        // Progress fill
                        LayoutBuilder(
                          builder: (context, constraints) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: constraints.maxWidth * _downloadProgress,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF5722), Color(0xFFFF9800)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.deepOrange.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Percentage text
                        Center(
                          child: Text(
                            "${(_downloadProgress * 100).toInt()}%",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : _modelDownloaded
                    ? const Icon(Icons.check, color: Color(0xFF4CAF50))
                    : TextButton(
                        onPressed: _startModelDownload,
                        child: const Text("Download",
                            style: TextStyle(color: Colors.deepOrange)),
                      ),
          ).animate().fadeIn(delay: 375.ms),
          const SizedBox(height: 20),
          const Text("APP UPDATES").animate().fadeIn(delay: 400.ms),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.system_update_outlined,
                  color: Color(0xFF4CAF50), size: 24),
            ),
            title: const Text("Check for Updates",
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Current: $_currentVersion"),
            trailing: _checkingUpdate
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF4CAF50),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF4CAF50)),
                    onPressed: _checkForUpdates,
                  ),
          ).animate().fadeIn(delay: 450.ms),
          const SizedBox(height: 20),
          const Text("APP INFO").animate().fadeIn(delay: 500.ms),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text("Version"),
            trailing: Text(_currentVersion),
          ).animate().fadeIn(delay: 550.ms),
          const SizedBox(height: 20),
          Center(
            child: Text(
              "Created by ${AppConfig.integritySignature}",
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ).animate().fadeIn(delay: 600.ms),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
