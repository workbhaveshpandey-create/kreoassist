import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../../mesh_network/domain/mesh_network_service.dart';
import '../../data/mesh_provider.dart';
import 'mesh_chat_screen.dart';
import 'mesh_chat_list_screen.dart';

class MeshScreen extends ConsumerStatefulWidget {
  final String username;
  final String userId;
  const MeshScreen({super.key, required this.username, required this.userId});

  @override
  ConsumerState<MeshScreen> createState() => _MeshScreenState();
}

class _MeshScreenState extends ConsumerState<MeshScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  List<String> _recentChatPeers = [];
  String? _openedPeerId; // Track open chat

  // Custom Feedback Toast State
  String? _feedbackMessage;
  Timer? _feedbackTimer;

  // Cache for peer names (UserId -> Name)
  Map<String, String> _cachedPeerNames = {};

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _loadRecentChats();
    _loadRecentChats();
    _loadCachedNames(); // Load names

    // Auto-Start Broadcast & Scan (Always On Strategy)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(meshProvider);
      final notifier = ref.read(meshProvider.notifier);
      bool started = false;

      if (!state.isAdvertising) {
        notifier.startAdvertising(widget.username, widget.userId);
        started = true;
      }
      if (!state.isDiscovering) {
        notifier.startDiscovery(widget.userId);
        started = true;
      }

      if (state.isAdvertising || state.isDiscovering || started) {
        _radarController.repeat();
      }

      if (started) {
        _showFeedback("Mesh Network Auto-Started 📡");
      }
    });
  }

  void _showFeedback(String message) {
    setState(() {
      _feedbackMessage = message;
    });
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _feedbackMessage = null);
    });
  }

  Future<void> _loadCachedNames() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('peer_name_'));
    final cache = <String, String>{};
    for (final k in keys) {
      final userId = k.replaceFirst('peer_name_', '');
      final name = prefs.getString(k);
      if (name != null) cache[userId] = name;
    }
    setState(() => _cachedPeerNames = cache);
  }

  Future<void> _loadRecentChats() async {
    final prefs = await SharedPreferences.getInstance();
    final keys =
        prefs.getKeys().where((k) => k.startsWith('mesh_chat_')).toList();
    final peers = keys.map((k) => k.replaceFirst('mesh_chat_', '')).toList();
    setState(() => _recentChatPeers = peers);
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  void _toggleAdvertising() async {
    final notifier = ref.read(meshProvider.notifier);
    final state = ref.read(meshProvider);
    final prefs = await SharedPreferences.getInstance();

    if (state.isAdvertising) {
      notifier.stopAdvertising();
      await prefs.setBool('mesh_broadcast_enabled', false);
    } else {
      notifier.startAdvertising(widget.username, widget.userId);
      await prefs.setBool('mesh_broadcast_enabled', true);
    }
  }

  void _toggleDiscovery() async {
    final notifier = ref.read(meshProvider.notifier);
    final state = ref.read(meshProvider);
    final prefs = await SharedPreferences.getInstance();

    if (state.isDiscovering) {
      notifier.stopDiscovery();
      await prefs.setBool('mesh_discover_enabled', false);
    } else {
      notifier.startDiscovery(widget.userId);
      await prefs.setBool('mesh_discover_enabled', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meshState = ref.watch(meshProvider);
    final isAdvertising = meshState.isAdvertising;
    final isDiscovering = meshState.isDiscovering;
    final status = meshState.status;
    final connectedEndpoints = meshState.connectedEndpoints;
    final isActive = isAdvertising || isDiscovering;

    // Sync animation with state
    if (isActive && !_radarController.isAnimating) {
      _radarController.repeat();
    } else if (!isActive && _radarController.isAnimating) {
      _radarController.stop();
    }

    // Note: _openedPeerId field is used to suppress notifications for open chats

    // Listen for new peers to add to "Recent Chats" (Contacts)
    ref.listen<Map<String, String>>(
        meshProvider.select((s) => s.endpointToUserId), (prev, next) async {
      final prefs = await SharedPreferences.getInstance();
      bool changed = false;

      for (final newId in next.values) {
        if (!_recentChatPeers.contains(newId)) {
          _recentChatPeers.insert(0, newId); // Add to top

          // Persist empty chat to ensure it stays in list
          if (!prefs.containsKey('mesh_chat_$newId')) {
            await prefs.setStringList('mesh_chat_$newId', []);
          }
          changed = true;
        }
      }

      if (changed) {
        setState(() {});
      }
    });

    // FIX: Listen to incoming messages globally (even if chat closed)
    ref.listen<List<MeshMessage>>(
        meshProvider.select((s) => s.incomingMessages), (prev, next) async {
      // Diff strategy: Only process NEW messages
      final oldList = prev ?? [];
      final newMsgs = next.where((m) => !oldList.contains(m)).toList();

      if (newMsgs.isEmpty) return;

      final messagesByPeer = <String, List<MeshMessage>>{};
      for (final msg in newMsgs) {
        messagesByPeer.putIfAbsent(msg.senderId, () => []).add(msg);
      }

      final prefs = await SharedPreferences.getInstance();
      bool listChanged = false;

      for (final entry in messagesByPeer.entries) {
        final peerId = entry.key;
        final msgs = entry.value;

        // 1. Add peer to recent list if missing
        if (!_recentChatPeers.contains(peerId)) {
          _recentChatPeers.insert(0, peerId);
          listChanged = true;
        } else {
          // Move to top
          _recentChatPeers.remove(peerId);
          _recentChatPeers.insert(0, peerId);
          listChanged = true;
        }

        // 2. Persist messages
        final key = 'mesh_chat_$peerId';
        final history = prefs.getStringList(key) ?? [];
        for (final msg in msgs) {
          final formatted = "${msg.senderId}: ${msg.message}";
          history.add(formatted);
        }
        await prefs.setStringList(key, history);

        // 3. DO NOT CLEAR HERE.
        // Clearing removes the badge. ChatScreen will clear (consume) when opened.
      }

      if (listChanged) setState(() {});
      if (listChanged) setState(() {});
    });

    // FIX: Listen to Peer Names updates to cache them
    ref.listen<Map<String, String>>(meshProvider.select((s) => s.peerNames),
        (prev, next) async {
      final state = ref.read(meshProvider);
      final prefs = await SharedPreferences.getInstance();
      bool changed = false;

      for (final entry in next.entries) {
        final endpoint = entry.key;
        final name = entry.value;
        final userId = state.endpointToUserId[endpoint];

        if (userId != null && name != "Unknown") {
          if (_cachedPeerNames[userId] != name) {
            _cachedPeerNames[userId] = name;
            await prefs.setString('peer_name_$userId', name);
            changed = true;
          }
        }
      }
      if (changed) setState(() {});
    });

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            // Radar Area (Main Focus)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Radar
                      Center(
                        child: _RadarWithPeers(
                          controller: _radarController,
                          color: _getRadarColor(isAdvertising, isDiscovering),
                          peers: connectedEndpoints,
                          peerNames: meshState.peerNames,
                          isActive: isActive,
                          onPeerTap: (endpoint) {
                            final stableId =
                                meshState.endpointToUserId[endpoint] ??
                                    endpoint;
                            final name =
                                meshState.peerNames[endpoint] ?? "Unknown";
                            _openChat(stableId, name);
                          },
                        ),
                      ),

                      // Center "You"
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: _getRadarColor(
                                    isAdvertising, isDiscovering),
                                width: 2),
                          ),
                          child: const Icon(Icons.person,
                              color: Colors.white, size: 28),
                        ),
                      ),

                      // Peers Count (Top Left)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.people,
                                  color: Colors.white70, size: 16),
                              const SizedBox(width: 6),
                              Text("${connectedEndpoints.length}",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),

                      // Status (Top Right)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getRadarColor(isAdvertising, isDiscovering)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: _getRadarColor(
                                        isAdvertising, isDiscovering),
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isAdvertising && isDiscovering
                                    ? "Active"
                                    : isAdvertising
                                        ? "Broadcast"
                                        : isDiscovering
                                            ? "Scan"
                                            : "Off",
                                style: TextStyle(
                                    color: _getRadarColor(
                                        isAdvertising, isDiscovering),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Feedback Toast
                      if (_feedbackMessage != null)
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(_feedbackMessage!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                                textAlign: TextAlign.center),
                          ).animate().fade().slideY(begin: 0.5, end: 0),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // View All Chats Button with Unread Badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openChatList,
                      icon: const Icon(Icons.chat_bubble_outline, size: 20),
                      label: const Text("View All Chats"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF3A3A3A)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  // Unread Badge
                  if (meshState.incomingMessages.isNotEmpty)
                    Positioned(
                      right: 12,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${meshState.incomingMessages.length}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Control Buttons (Broadcast / Discover)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                children: [
                  // Broadcast Button
                  Expanded(
                    child: GestureDetector(
                      onTap: _toggleAdvertising,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isAdvertising
                              ? const Color(0xFF00BCD4).withOpacity(0.15)
                              : const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isAdvertising
                                  ? const Color(0xFF00BCD4)
                                  : const Color(0xFF3A3A3A)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.cell_tower,
                                color: isAdvertising
                                    ? const Color(0xFF00BCD4)
                                    : Colors.white54,
                                size: 28),
                            const SizedBox(height: 6),
                            Text("Broadcast",
                                style: TextStyle(
                                    color: isAdvertising
                                        ? const Color(0xFF00BCD4)
                                        : Colors.white54,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Discover Button
                  Expanded(
                    child: GestureDetector(
                      onTap: _toggleDiscovery,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isDiscovering
                              ? const Color(0xFF4CAF50).withOpacity(0.15)
                              : const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isDiscovering
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFF3A3A3A)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.radar,
                                color: isDiscovering
                                    ? const Color(0xFF4CAF50)
                                    : Colors.white54,
                                size: 28),
                            const SizedBox(height: 6),
                            Text("Discover",
                                style: TextStyle(
                                    color: isDiscovering
                                        ? const Color(0xFF4CAF50)
                                        : Colors.white54,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ).animate().fadeIn(duration: 300.ms),
      ),
    );
  }

  // Radar Color Helper - uses actual boolean state
  Color _getRadarColor(bool isAdvertising, bool isDiscovering) {
    if (isAdvertising && isDiscovering)
      return const Color(0xFFFFCA28); // Yellow for both
    if (isAdvertising) return const Color(0xFF00BCD4); // Cyan
    if (isDiscovering) return const Color(0xFF4CAF50); // Green
    return const Color(0xFF757575); // Grey for offline
  }

  Widget _buildHeader(MeshConnectionStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.hub, color: Color(0xFFFF6B35), size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            "Mesh Network",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          _buildStatusChip(status),
        ],
      ),
    );
  }

  Widget _buildStatusChip(MeshConnectionStatus status) {
    Color color;
    String text;
    switch (status) {
      case MeshConnectionStatus.advertising:
        color = const Color(0xFF00BCD4);
        text = "Broadcasting";
        break;
      case MeshConnectionStatus.discovering:
        color = const Color(0xFF4CAF50);
        text = "Scanning";
        break;
      case MeshConnectionStatus.connected:
        color = const Color(0xFF2196F3);
        text = "Connected";
        break;
      case MeshConnectionStatus.disconnected:
        color = Colors.grey;
        text = "Offline";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentChatsPanel() {
    final meshState = ref.watch(meshProvider);
    final onlineUserIds = meshState.endpointToUserId.values.toSet();

    return Container(
      height: 90,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Active & Recent",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _openChatList,
                child: Row(
                  children: [
                    const Text("View All Chats",
                        style:
                            TextStyle(color: Color(0xFF00BCD4), fontSize: 12)),
                    const Icon(Icons.chevron_right,
                        color: Color(0xFF00BCD4), size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recentChatPeers.length,
              itemBuilder: (context, index) {
                final peerId = _recentChatPeers[index];
                // Check if online via UserID map OR raw EndpointID list
                final isOnline = onlineUserIds.contains(peerId) ||
                    meshState.connectedEndpoints.contains(peerId);

                // Get unread count
                final incomingMessages =
                    ref.watch(meshProvider.select((s) => s.incomingMessages));
                final unreadCount =
                    incomingMessages.where((m) => m.senderId == peerId).length;

                // Resolve Name
                final displayName = _cachedPeerNames[peerId] ?? "Unknown";

                return GestureDetector(
                  onTap: () => _openChat(peerId, displayName),
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isOnline
                                      ? const Color(0xFF4CAF50).withOpacity(0.5)
                                      : const Color(0xFFFF5252)
                                          .withOpacity(0.3),
                                  width: isOnline ? 2 : 1,
                                ),
                              ),
                              child: Icon(
                                Icons.person,
                                color: isOnline
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFFF5252),
                                size: 24,
                              ),
                            ),
                            // Status Dot
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFFF5252),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.black, width: 2),
                                ),
                              ),
                            ),
                            // Notification Badge
                            if (unreadCount > 0)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  child: Center(
                                    child: Text(
                                      unreadCount > 9 ? '9+' : '$unreadCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Name & Signal
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isOnline)
                              const Padding(
                                padding: EdgeInsets.only(right: 2),
                                child: Icon(Icons.signal_cellular_alt,
                                    color: Color(0xFF4CAF50), size: 10),
                              ),
                            Flexible(
                              child: Text(
                                (displayName != "Unknown")
                                    ? displayName
                                    : (peerId.length > 5
                                        ? '${peerId.substring(0, 4)}..'
                                        : peerId),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isOnline
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(bool isAdvertising, bool isDiscovering) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildControlButton(
              icon: Icons.cell_tower,
              label: "Broadcast",
              isActive: isAdvertising,
              onTap: _toggleAdvertising,
              activeColor: const Color(0xFF00BCD4),
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.white.withOpacity(0.1),
          ),
          Expanded(
            child: _buildControlButton(
              icon: Icons.radar,
              label: "Scan",
              isActive: isDiscovering,
              onTap: _toggleDiscovery,
              activeColor: const Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  isActive ? activeColor.withOpacity(0.2) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? activeColor : Colors.white24,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : Colors.white54,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : Colors.white54,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyBroadcastPanel() {
    final meshState = ref.watch(meshProvider);
    final myStatus = meshState.myStatus;

    // 2x2 Grid Data
    final items = [
      {
        's': EmergencyStatus.safe,
        'l': 'Safe',
        'e': '✅',
        'c': const Color(0xFF4CAF50)
      },
      {
        's': EmergencyStatus.needHelp,
        'l': 'Help',
        'e': '🆘',
        'c': const Color(0xFFFF5252)
      },
      {
        's': EmergencyStatus.needWater,
        'l': 'Water',
        'e': '💧',
        'c': const Color(0xFF2196F3)
      },
      {
        's': EmergencyStatus.trapped,
        'l': 'Trapped',
        'e': '🚨',
        'c': const Color(0xFFFF9800)
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.broadcast_on_personal,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                "BROADCAST STATUS",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Symmetrical Grid (2 Rows)
          Row(
            children: [
              Expanded(child: _buildStatusCard(items[0], myStatus)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatusCard(items[1], myStatus)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatusCard(items[2], myStatus)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatusCard(items[3], myStatus)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
      Map<String, dynamic> item, EmergencyStatus? currentStatus) {
    final status = item['s'] as EmergencyStatus;
    final label = item['l'] as String;
    final emoji = item['e'] as String;
    final color = item['c'] as Color;
    final isSelected = currentStatus == status;

    return _SpringButton(
      onTap: () {
        HapticFeedback.heavyImpact();
        if (isSelected) {
          // Toggle Off? Or Broadcast Safe?
          // User likely wants to update.
          // If already Safe, maybe nothing.
        }
        ref.read(meshProvider.notifier).broadcastEmergencyStatus(status);
        _showFeedback("$emoji Broadcast: $label");
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        height: 70, // Fixed height for symmetry
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.05),
            width: isSelected ? 2 : 1,
          ),
          gradient: isSelected
              ? LinearGradient(
                  colors: [color.withOpacity(0.25), color.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(EmergencyStatus status) {
    switch (status) {
      case EmergencyStatus.safe:
        return const Color(0xFF4CAF50);
      case EmergencyStatus.needHelp:
        return const Color(0xFFFF5722);
      case EmergencyStatus.needWater:
        return const Color(0xFF2196F3);
      case EmergencyStatus.trapped:
        return const Color(0xFFE91E63);
      case EmergencyStatus.unknown:
        return Colors.grey;
    }
  }

  void _openChat(String peerId, [String? peerName]) async {
    // Cache name if valid
    if (peerName != null && peerName != "Unknown") {
      if (_cachedPeerNames[peerId] != peerName) {
        // Optimistic update
        _cachedPeerNames[peerId] = peerName;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('peer_name_$peerId', peerName);
      }
    }

    setState(() => _openedPeerId =
        peerId); // Mark open to suppress background notifications for this peer

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeshChatScreen(
          peerId: peerId,
          peerName: peerName ?? _cachedPeerNames[peerId] ?? "Unknown",
        ),
      ),
    );

    setState(() {
      _openedPeerId = null; // Mark closed
      _loadRecentChats(); // Refresh recent list
    });
  }

  void _openChatList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MeshChatListScreen(),
      ),
    ).then((_) => _loadRecentChats());
  }
}

// Radar with Peer Dots
class _RadarWithPeers extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final List<String> peers;
  final Map<String, String> peerNames;
  final bool isActive;
  final void Function(String) onPeerTap;

  const _RadarWithPeers({
    required this.controller,
    required this.color,
    required this.peers,
    required this.peerNames,
    required this.isActive,
    required this.onPeerTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.8;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          if (isActive)
            AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                return CustomPaint(
                  painter:
                      _RadarPainter(progress: controller.value, color: color),
                  size: Size(size, size),
                );
              },
            ),
          if (!isActive)
            CustomPaint(
              painter: _RadarPainter(
                  progress: 0, color: Colors.grey.withOpacity(0.3)),
              size: Size(size, size),
            ),
          ...peers.asMap().entries.map((entry) {
            final endpointId = entry.value;
            return _buildPeerDot(endpointId, size);
          }),
        ],
      ),
    );
  }

  Widget _buildPeerDot(String endpointId, double radarSize) {
    final hash = endpointId.hashCode;
    final random = math.Random(hash);

    final distance = 0.35 + random.nextDouble() * 0.45;
    final angle = random.nextDouble() * 2 * math.pi;

    final center = radarSize / 2;
    final radius = center * distance;
    final x = center + radius * math.cos(angle) - 24;
    final y = center + radius * math.sin(angle) - 24;

    final name = peerNames[endpointId] ?? endpointId;

    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onTap: () => onPeerTap(endpointId),
        child: _PulsingPeerDot(label: name),
      ),
    );
  }
}

class _PulsingPeerDot extends StatefulWidget {
  final String label;
  const _PulsingPeerDot({required this.label});

  @override
  State<_PulsingPeerDot> createState() => _PulsingPeerDotState();
}

class _PulsingPeerDotState extends State<_PulsingPeerDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + (_controller.value * 0.2);
        return Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF4CAF50),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF4CAF50),
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.label.length > 10
                      ? '${widget.label.substring(0, 10)}...'
                      : widget.label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, radius * 0.3, paint);
    canvas.drawCircle(center, radius * 0.5, paint);
    canvas.drawCircle(center, radius * 0.7, paint);
    canvas.drawCircle(center, radius * 0.9, paint);

    final linePaint = Paint()
      ..color = color.withOpacity(0.1)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      linePaint,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      linePaint,
    );

    if (progress > 0) {
      final sweepPaint = Paint()
        ..shader = SweepGradient(
          colors: [color.withOpacity(0.0), color.withOpacity(0.4)],
          stops: const [0.0, 1.0],
          startAngle: 0,
          endAngle: math.pi / 2,
          transform: GradientRotation(progress * 2 * math.pi),
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawCircle(
          center, radius * 0.9, Paint()..shader = sweepPaint.shader);
    }

    final centerDotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 6, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final step = size.width / 8;

    // Draw Grid Lines
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw Corners
    final cornerPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    double cornerSize = 20;

    // Top Left
    canvas.drawPath(
        Path()
          ..moveTo(0, cornerSize)
          ..lineTo(0, 0)
          ..lineTo(cornerSize, 0),
        cornerPaint);
    // Top Right
    canvas.drawPath(
        Path()
          ..moveTo(size.width - cornerSize, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, cornerSize),
        cornerPaint);
    // Bottom Left
    canvas.drawPath(
        Path()
          ..moveTo(0, size.height - cornerSize)
          ..lineTo(0, size.height)
          ..lineTo(cornerSize, size.height),
        cornerPaint);
    // Bottom Right
    canvas.drawPath(
        Path()
          ..moveTo(size.width - cornerSize, size.height)
          ..lineTo(size.width, size.height)
          ..lineTo(size.width, size.height - cornerSize),
        cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

/// Physics-based spring button with organic bounce animation
class _SpringButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _SpringButton({required this.child, required this.onTap});

  @override
  State<_SpringButton> createState() => _SpringButtonState();
}

class _SpringButtonState extends State<_SpringButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  // Spring physics configuration
  static const SpringDescription _spring = SpringDescription(
    mass: 1.0,
    stiffness: 400.0,
    damping: 15.0,
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    // Use spring simulation for organic bounce back
    final simulation = SpringSimulation(_spring, _controller.value, 0.0, 0.0);
    _controller.animateWith(simulation);
    widget.onTap();
  }

  void _onTapCancel() {
    final simulation = SpringSimulation(_spring, _controller.value, 0.0, 0.0);
    _controller.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
