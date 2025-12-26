import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/mesh_provider.dart';
import 'mesh_chat_screen.dart';

class MeshChatListScreen extends ConsumerStatefulWidget {
  const MeshChatListScreen({super.key});

  @override
  ConsumerState<MeshChatListScreen> createState() => _MeshChatListScreenState();
}

class _MeshChatListScreenState extends ConsumerState<MeshChatListScreen> {
  List<String> _chatPeers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    final prefs = await SharedPreferences.getInstance();
    final keys =
        prefs.getKeys().where((k) => k.startsWith('mesh_chat_')).toList();

    // Sort? Ideally by last modified, but we don't track timestamps in keys.
    // We just list them.
    setState(() {
      _chatPeers = keys.map((k) => k.replaceFirst('mesh_chat_', '')).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final meshState = ref.watch(meshProvider);
    final peerNames = meshState.peerNames;
    final onlinePeers = meshState.endpointToUserId.values;
    final connectedEndpoints = meshState.connectedEndpoints;
    final incomingMessages = meshState.incomingMessages;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Mesh Chats"),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _isLoading
            ? const Center(
                key: ValueKey('loading'), child: CircularProgressIndicator())
            : _chatPeers.isEmpty
                ? Container(
                    key: const ValueKey('empty'), child: _buildEmptyState())
                : ListView.builder(
                    key: const ValueKey('list'),
                    itemCount: _chatPeers.length,
                    itemBuilder: (context, index) {
                      final peerId = _chatPeers[index];

                      // Check if online (via UserID map OR raw EndpointID list)
                      final isOnline = onlinePeers.contains(peerId) ||
                          connectedEndpoints.contains(peerId);

                      // Unread count
                      final unreadCount = incomingMessages
                          .where((m) => m.senderId == peerId)
                          .length;

                      // Hack to find name from ANY connected endpoint that maps to this ID
                      String displayName = "User ${peerId.substring(0, 4)}";
                      final endpoints = ref
                          .read(meshProvider)
                          .endpointToUserId
                          .entries
                          .where((e) => e.value == peerId)
                          .map((e) => e.key);

                      if (endpoints.isNotEmpty) {
                        final ep = endpoints.first;
                        if (peerNames.containsKey(ep)) {
                          displayName = peerNames[ep]!;
                        }
                      } else if (peerNames.containsKey(peerId)) {
                        // Fallback: If peerId is actually an endpoint ID
                        displayName = peerNames[peerId]!;
                      }

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF2C2C2C),
                              radius: 24,
                              child: const Icon(Icons.person,
                                  color: Colors.white70),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? const Color(0xFF00E676)
                                      : const Color(0xFFFF5252),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.black, width: 2),
                                ),
                              ),
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isOnline) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.signal_cellular_alt,
                                  color: Color(0xFF00E676), size: 16),
                            ]
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              isOnline
                                  ? "Signal: Strong • < 10m"
                                  : "Offline", // Pseudo-distance based on active connection
                              style: TextStyle(
                                  color: isOnline
                                      ? const Color(0xFF00E676)
                                      : Colors.white38,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: Colors.white24),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MeshChatScreen(
                                peerId: peerId,
                                peerName: displayName,
                              ),
                            ),
                          ).then((_) => _loadChats()); // Refresh on return
                        },
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_outlined, size: 60, color: Colors.white24),
          const SizedBox(height: 16),
          const Text("No chat history",
              style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}
