import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/emergency_dashboard/data/mesh_provider.dart';
import '../../../../features/emergency_dashboard/presentation/screens/chat_screen.dart';
import '../../../../features/emergency_dashboard/presentation/screens/mesh_screen.dart';
import '../../../../features/emergency_dashboard/presentation/screens/sos_dashboard.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/update_service.dart';

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
      UpdateService.checkForUpdates(context);
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

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? "Unknown User";
    });
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
          const Text("APP INFO").animate().fadeIn(delay: 400.ms),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline),
            title: Text("Version"),
            trailing: Text("1.0.0 (Prototype)"),
          ).animate().fadeIn(delay: 500.ms),
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
