import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../mesh_network/data/mesh_network_service_impl.dart';
import '../../mesh_network/domain/mesh_network_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/services/notification_service.dart';
import 'package:uuid/uuid.dart'; // For unique packet IDs

// Emergency Status Types
enum EmergencyStatus {
  safe,
  needHelp,
  needWater,
  trapped,
  unknown,
}

extension EmergencyStatusExtension on EmergencyStatus {
  String get label {
    switch (this) {
      case EmergencyStatus.safe:
        return 'Safe';
      case EmergencyStatus.needHelp:
        return 'Need Help';
      case EmergencyStatus.needWater:
        return 'Need Water';
      case EmergencyStatus.trapped:
        return 'Trapped';
      case EmergencyStatus.unknown:
        return 'Unknown';
    }
  }

  String get emoji {
    switch (this) {
      case EmergencyStatus.safe:
        return '✅';
      case EmergencyStatus.needHelp:
        return '🆘';
      case EmergencyStatus.needWater:
        return '💧';
      case EmergencyStatus.trapped:
        return '🚨';
      case EmergencyStatus.unknown:
        return '❓';
    }
  }

  static EmergencyStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'safe':
        return EmergencyStatus.safe;
      case 'need_help':
      case 'needhelp':
        return EmergencyStatus.needHelp;
      case 'need_water':
      case 'needwater':
        return EmergencyStatus.needWater;
      case 'trapped':
        return EmergencyStatus.trapped;
      default:
        return EmergencyStatus.unknown;
    }
  }
}

// Message model for mesh chat
class MeshMessage {
  final String senderId;
  final String senderName; // Added for UI
  final String message;
  final DateTime timestamp;

  MeshMessage({
    required this.senderId,
    this.senderName = "Unknown",
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'senderId': senderId,
        'senderName': senderName,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };

  factory MeshMessage.fromJson(Map<String, dynamic> json) => MeshMessage(
        senderId: json['senderId'] as String,
        senderName: json['senderName'] as String? ?? "Unknown",
        message: json['message'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

// State class to hold immutable state
class MeshState {
  final bool isAdvertising;
  final bool isDiscovering;
  final MeshConnectionStatus status;
  final List<String> connectedEndpoints;
  final List<String> logs;
  final List<MeshMessage> incomingMessages;
  final Map<String, String> peerNames; // endpointId -> DisplayName
  final Map<String, String> endpointToUserId; // endpointId -> Stable UserId
  final Map<String, EmergencyStatus> peerStatuses; // userId -> EmergencyStatus
  final EmergencyStatus? myStatus; // Current user's broadcasted status

  const MeshState({
    this.isAdvertising = false,
    this.isDiscovering = false,
    this.status = MeshConnectionStatus.disconnected,
    this.connectedEndpoints = const [],
    this.logs = const [],
    this.incomingMessages = const [],
    this.peerNames = const {},
    this.endpointToUserId = const {},
    this.peerStatuses = const {},
    this.myStatus,
    this.backgroundMode = false,
  });

  // State Props
  final bool backgroundMode;

  MeshState copyWith({
    bool? isAdvertising,
    bool? isDiscovering,
    MeshConnectionStatus? status,
    List<String>? connectedEndpoints,
    List<String>? logs,
    List<MeshMessage>? incomingMessages,
    Map<String, String>? peerNames,
    Map<String, String>? endpointToUserId,
    Map<String, EmergencyStatus>? peerStatuses,
    EmergencyStatus? myStatus,
    bool? backgroundMode,
  }) {
    return MeshState(
      isAdvertising: isAdvertising ?? this.isAdvertising,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      status: status ?? this.status,
      connectedEndpoints: connectedEndpoints ?? this.connectedEndpoints,
      logs: logs ?? this.logs,
      incomingMessages: incomingMessages ?? this.incomingMessages,
      peerNames: peerNames ?? this.peerNames,
      endpointToUserId: endpointToUserId ?? this.endpointToUserId,
      peerStatuses: peerStatuses ?? this.peerStatuses,
      myStatus: myStatus ?? this.myStatus,
      backgroundMode: backgroundMode ?? this.backgroundMode,
    );
  }
}

// Ensure the service is a singleton
final meshNetworkServiceProvider = Provider<MeshNetworkServiceImpl>((ref) {
  return MeshNetworkServiceImpl();
});

final meshProvider = StateNotifierProvider<MeshNotifier, MeshState>((ref) {
  final meshService = ref.watch(meshNetworkServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return MeshNotifier(meshService, notificationService); // Pass services
});

class MeshNotifier extends StateNotifier<MeshState> {
  final MeshNetworkServiceImpl _meshService;
  final NotificationService _notificationService;

  // Local Notifications for Background Mode
  final _localNotifications = FlutterLocalNotificationsPlugin();

  StreamSubscription? _statusSub;
  StreamSubscription? _payloadSub;

  String _myUsername = "Unknown";
  String _myUserId = "unknown";

  // Maps for stable identity
  final Map<String, String> _endpointToUserId = {};
  final Map<String, String> _userIdToName = {};
  final Map<String, String> _userIdToEndpoint = {}; // Added for routing

  // Multi-Hop: Deduplication Cache
  final Set<String> _seenPacketIds = {};
  final _uuid = const Uuid();
  static const int MAX_TTL = 3; // Max hops

  MeshNotifier(this._meshService, this._notificationService)
      : super(const MeshState()) {
    _initListeners();
    _initBackgroundMode();
  }

  Future<void> _initBackgroundMode() async {
    // Init Plugin
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);

    // Load Pref
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('bg_mode') ?? false;
    state = state.copyWith(backgroundMode: enabled);

    if (enabled) _showStickyNotification();
  }

  Future<void> toggleBackgroundMode(bool value) async {
    state = state.copyWith(backgroundMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bg_mode', value);

    if (value) {
      await _showStickyNotification();
      // Request Battery Exemption for Simulator stability
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } else {
      await _localNotifications.cancel(888);
    }
  }

  Future<void> _showStickyNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'mesh_service_channel',
      'Mesh Network Service',
      channelDescription: 'Keeps mesh network active in background',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
    );
    const details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      888,
      'KreoAssist Mesh Active',
      'Scanning & Broadcasting in background...',
      details,
    );
  }

  void _initListeners() {
    _statusSub = _meshService.statusStream.listen((status) {
      if (status == MeshConnectionStatus.connected) {
        // Connected! Broadcast our stable identity (Handshake)
        _broadcastHandshake();

        if (state.status != MeshConnectionStatus.connected) {
          _notificationService.showNotification(
            id: 1,
            title: 'Mesh Network Connected',
            body: 'Connected to a peer. Exchanging identities...',
          );
        }
      }
      state = state.copyWith(status: status);
      state =
          state.copyWith(connectedEndpoints: _meshService.connectedEndpoints);

      // Cleanup disconnected endpoints from maps
      final connected = _meshService.connectedEndpoints;

      // 1. Clean local caches
      _endpointToUserId.removeWhere((k, v) => !connected.contains(k));
      _userIdToEndpoint.removeWhere((k, v) => !connected.contains(v));

      // 2. Clean State Maps (Crucial for UI)
      final newEndpointMap = Map<String, String>.from(state.endpointToUserId);
      newEndpointMap.removeWhere((k, v) => !connected.contains(k));

      final newPeerNames = Map<String, String>.from(state.peerNames);
      newPeerNames.removeWhere((k, v) => !connected.contains(k));

      state = state.copyWith(
        endpointToUserId: newEndpointMap,
        peerNames: newPeerNames,
      );
    });

    _payloadSub = _meshService.payloadStream.listen((data) {
      // Support both 'senderId' (legacy) and 'originId' (new packet format)
      final senderEndpoint =
          (data['senderId'] ?? data['originId'] ?? 'unknown') as String;

      // 1. Packet Processing & Relaying (Multi-Hop)
      _processIncomingPacket(data, senderEndpoint);
    });
  }

  void _processIncomingPacket(
      Map<String, dynamic> packet, String senderEndpoint) {
    // Legacy support (if packet doesn't have ID, treat as connected peer message)
    if (!packet.containsKey('packetId')) {
      _handleLegacyPayload(packet, senderEndpoint);
      return;
    }

    final packetId = packet['packetId'] as String;
    // DEDUPLICATION: Drop if seen
    if (_seenPacketIds.contains(packetId)) return;

    // Mark as seen
    _seenPacketIds.add(packetId);
    if (_seenPacketIds.length > 500)
      _seenPacketIds.remove(_seenPacketIds.first); // Cap size

    // RELAY LOGIC (Flood)
    int ttl = packet['ttl'] as int? ?? 0;
    if (ttl > 0) {
      final relayedPacket = Map<String, dynamic>.from(packet);
      relayedPacket['ttl'] = ttl - 1;
      // Re-broadcast to ALL connected peers EXCEPT the sender
      _meshService.broadcastPayload(relayedPacket);
    }

    // PROCESS LOCALLY
    // Check if it's meant for us
    final targetId = packet['targetId'] as String?;
    if (targetId != null && targetId != _myUserId) {
      // Not for us. We already relayed it above (if TTL > 0).
      return;
    }

    final originId = packet['originId'] as String?; // The original author
    final payload = packet['data'] as Map<String, dynamic>;

    _handlePayloadData(payload, senderEndpoint, originId);
  }

  void _handlePayloadData(
      Map<String, dynamic> data, String senderEndpoint, String? originId) {
    // HANDSHAKE HANDLING
    if (data['type'] == 'handshake') {
      final peerUserId = data['userId'] as String;
      final peerName = data['username'] as String;

      _userIdToName[peerUserId] = peerName;
      // Also map endpoint for direct lookups if needed,
      // though Multi-Hop relies strictly on UserId for chat.
      _endpointToUserId[senderEndpoint] = peerUserId;
      _userIdToEndpoint[peerUserId] = senderEndpoint;

      // Update State for UI
      final newPeerNames = Map<String, String>.from(state.peerNames);
      newPeerNames[senderEndpoint] = peerName;

      final newEndpointMap = Map<String, String>.from(state.endpointToUserId);
      newEndpointMap[senderEndpoint] = peerUserId;

      state = state.copyWith(
        peerNames: newPeerNames,
        endpointToUserId: newEndpointMap,
      );

      print("🤝 Handshake received from $peerName ($peerUserId)");
      return;
    }

    // EMERGENCY STATUS HANDLING
    if (data['type'] == 'emergency_status') {
      final senderId = originId ?? senderEndpoint;
      final statusString = data['status'] as String;
      final emergencyStatus = EmergencyStatusExtension.fromString(statusString);
      final peerName = _userIdToName[senderId] ?? "A Peer";

      // Update peer status map
      final newStatuses = Map<String, EmergencyStatus>.from(state.peerStatuses);
      newStatuses[senderId] = emergencyStatus;
      state = state.copyWith(peerStatuses: newStatuses);

      // Show notification
      _notificationService.showNotification(
        id: 3,
        title: '${emergencyStatus.emoji} Emergency Alert',
        body: '$peerName is now: ${emergencyStatus.label}',
      );

      print("🚨 Emergency Status from $peerName: ${emergencyStatus.label}");
      return;
    }

    if (data.containsKey('message')) {
      // Resolve sender identity using ORIGIN ID from packet
      final senderId = originId ?? "Unknown";
      final peerName = _userIdToName[senderId] ?? "Unknown Peer";

      // Create a new MeshMessage from incoming data
      final newMessage = MeshMessage(
        senderId: senderId, // Use Protocol Origin ID
        senderName: peerName,
        message: data['message'] as String,
        timestamp: DateTime.now(),
      );

      // Add to incoming messages list
      state = state.copyWith(
        incomingMessages: [...state.incomingMessages, newMessage],
      );

      _notificationService.showNotification(
        id: 2,
        title: 'Message from $peerName',
        body: data['message'],
      );
    }
  }

  void _handleLegacyPayload(Map<String, dynamic> data, String senderEndpoint) {
    // Legacy assumed direct connection
    _handlePayloadData(data, senderEndpoint, null);
  }

  void _broadcastHandshake() {
    final payload = {
      'type': 'handshake',
      'userId': _myUserId,
      'username': _myUsername,
      // Include current emergency status in handshake
      if (state.myStatus != null)
        'emergencyStatus': state.myStatus!.name.toLowerCase(),
    };

    final packet = {
      'packetId': _uuid.v4(),
      'originId': _myUserId,
      'ttl': MAX_TTL,
      'data': payload
    };

    // Add to seen so we don't process our own loopback
    _seenPacketIds.add(packet['packetId'] as String);

    _meshService.broadcastPayload(packet);
  }

  void startAdvertising(String username, String userId) {
    if (state.isAdvertising) return;
    _myUsername = username;
    _myUserId = userId;
    _meshService.startAdvertising(username, userId);
    state = state.copyWith(isAdvertising: true);
  }

  void startDiscovery(String userId) {
    if (state.isDiscovering) return;
    _myUserId = userId; // Ensure we track this
    _meshService.startDiscovery(userId);
    state = state.copyWith(isDiscovering: true);
  }

  void stopAdvertising() {
    _meshService.stopAdvertising();
    state = state.copyWith(isAdvertising: false);
  }

  void stopDiscovery() {
    _meshService.stopDiscovery();
    state = state.copyWith(isDiscovering: false);
  }

  void stopAll() {
    _meshService.stopAll();
    state = state.copyWith(isAdvertising: false, isDiscovering: false);
  }

  void sendMessage(String peerId, String message) {
    final payload = {'message': message};

    final packet = {
      'packetId': _uuid.v4(),
      'originId': _myUserId,
      'targetId': peerId, // Add target!
      'ttl': MAX_TTL,
      'data': payload
    };

    _seenPacketIds.add(packet['packetId'] as String);
    _meshService.broadcastPayload(packet); // Flood it!
  }

  /// Broadcast emergency status to ALL connected peers
  void broadcastEmergencyStatus(EmergencyStatus status) {
    final statusString = status.name.toLowerCase();

    final payload = {
      'type': 'emergency_status',
      'status': statusString,
      'username': _myUsername,
    };

    final packet = {
      'packetId': _uuid.v4(),
      'originId': _myUserId,
      'ttl': MAX_TTL,
      'data': payload
    };

    _seenPacketIds.add(packet['packetId'] as String);
    _meshService.broadcastPayload(packet);

    // Update local state
    state = state.copyWith(myStatus: status);
  }

  /// Remove consumed messages for a specific peer
  void clearMessagesFromPeer(String peerId) {
    state = state.copyWith(
      incomingMessages:
          state.incomingMessages.where((m) => m.senderId != peerId).toList(),
    );
  }

  /// Get messages for a specific peer and mark them as consumed
  List<MeshMessage> consumeMessagesForPeer(String peerId) {
    final messages =
        state.incomingMessages.where((m) => m.senderId == peerId).toList();
    clearMessagesFromPeer(peerId);
    return messages;
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _payloadSub?.cancel();
    super.dispose();
  }
}
