import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import '../domain/mesh_network_service.dart';

class MeshNetworkServiceImpl implements MeshNetworkService {
  final Strategy _strategy = Strategy.P2P_CLUSTER;
  final StreamController<MeshConnectionStatus> _statusController =
      StreamController.broadcast();

  // Track connected endpoints
  final Map<String, String> _connectedEndpoints = {}; // ID -> Name

  // Dedup Cache for Relay (PacketId -> Timestamp)
  final Map<String, int> _seenPacketIds = {};
  static const int _dedupWindow = 30000; // 30 seconds ttl

  String? _localUsername;
  String? _localUserId;
  bool _isAdvertising = false;
  bool _isDiscovering = false;

  @override
  Stream<MeshConnectionStatus> get statusStream => _statusController.stream;

  @override
  List<String> get connectedEndpoints => _connectedEndpoints.keys.toList();

  @override
  Future<void> startAdvertising(String username, String userId) async {
    _localUsername = username;
    _localUserId = userId;
    _isAdvertising = true;
    _checkDebugClients();

    if (!Platform.isAndroid && !Platform.isIOS) {
      print("Mesh networking is only supported on Android and iOS.");
      return;
    }
    try {
      _statusController.add(MeshConnectionStatus.advertising);

      if (await Permission.location.serviceStatus.isDisabled) {
        print("Warning: Location service is disabled. Discovery may fail.");
      }
      if (await Permission.bluetooth.serviceStatus.isDisabled) {
        print("Warning: Bluetooth service is disabled. Discovery may fail.");
      }

      bool success = await Nearby().startAdvertising(
        username,
        _strategy,
        serviceId: "com.kreoassist",
        onConnectionInitiated: (String id, ConnectionInfo info) {
          _onConnectionInitiated(id, info);
        },
        onConnectionResult: (String id, Status status) {
          _onConnectionResult(id, status);
        },
        onDisconnected: (String id) {
          _onDisconnected(id);
        },
      );
      if (!success) {
        _statusController.add(MeshConnectionStatus.disconnected);
        print("Failed to start advertising");
      }
    } catch (e) {
      _statusController.add(MeshConnectionStatus.disconnected);
      print("Error advertising: $e");
    }
  }

  @override
  Future<void> startDiscovery(String userId) async {
    _localUserId = userId; // Store for handshake
    _isDiscovering = true;
    _checkDebugClients();

    if (!Platform.isAndroid && !Platform.isIOS) {
      print("Mesh networking is only supported on Android and iOS.");
      return;
    }
    try {
      _statusController.add(MeshConnectionStatus.discovering);

      if (await Permission.location.serviceStatus.isDisabled) {
        print("Warning: Location service is disabled. Discovery may fail.");
      }
      if (await Permission.bluetooth.serviceStatus.isDisabled) {
        print("Warning: Bluetooth service is disabled. Discovery may fail.");
      }

      bool success = await Nearby().startDiscovery(
        "User-Discoverer",
        _strategy,
        serviceId: "com.kreoassist",
        onEndpointFound: (String id, String userName, String serviceId) {
          Nearby().requestConnection(
            userName,
            id,
            onConnectionInitiated: (id, info) =>
                _onConnectionInitiated(id, info),
            onConnectionResult: (id, status) => _onConnectionResult(id, status),
            onDisconnected: (id) => _onDisconnected(id),
          );
        },
        onEndpointLost: (String? id) {
          if (id != null) _onDisconnected(id);
        },
      );
      if (!success) {
        _statusController.add(MeshConnectionStatus.disconnected);
        print("Failed to start discovery");
      }
    } catch (e) {
      _statusController.add(MeshConnectionStatus.disconnected);
      print("Error discovering: $e");
    }
  }

  @override
  Future<void> stopAdvertising() async {
    _isAdvertising = false;
    if (Platform.isAndroid || Platform.isIOS) {
      await Nearby().stopAdvertising();
    }
    // Update status based on remaining state
    if (_isDiscovering) {
      _statusController.add(MeshConnectionStatus.discovering);
    } else {
      _statusController.add(MeshConnectionStatus.disconnected);
    }
  }

  @override
  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    if (Platform.isAndroid || Platform.isIOS) {
      await Nearby().stopDiscovery();
    }
    // Update status
    if (_isAdvertising) {
      _statusController.add(MeshConnectionStatus.advertising);
    } else {
      _statusController.add(MeshConnectionStatus.disconnected);
    }
  }

  @override
  Future<void> stopAll() async {
    _isAdvertising = false;
    _isDiscovering = false;

    // Disconnect Simulators from "Mesh View" (but keep socket open?)
    // User wants "visible only when scanning".
    // If we stop scanning, do we disconnect?
    // Standard Nearby: `stopDiscovery` does NOT disconnect peers.
    // `stopAllEndpoints` DOES disconnect.

    if (Platform.isAndroid || Platform.isIOS) {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
    }

    // Clear simulator endpoints
    _connectedEndpoints
        .removeWhere((key, value) => key.startsWith("simulator-"));
    _connectedEndpoints.clear();
    _statusController.add(MeshConnectionStatus.disconnected);
  }

  final StreamController<Map<String, dynamic>> _payloadController =
      StreamController.broadcast();

  @override
  Stream<Map<String, dynamic>> get payloadStream => _payloadController.stream;

  // ... (previous code)

  ServerSocket? _debugServer;
  final List<Socket> _debugClients = [];

  MeshNetworkServiceImpl() {
    _startDebugServer();
  }

  Future<void> _startDebugServer() async {
    try {
      // Listen on all interfaces so laptop can connect via Wi-Fi IP
      _debugServer = await ServerSocket.bind(InternetAddress.anyIPv4, 4545);
      print('🚀 Debug Mesh Server running on port 4545');

      _debugServer!.listen((Socket client) {
        print(
            '💻 Simulation Client Connected: ${client.remoteAddress.address}');
        _debugClients.add(client);

        // Don't add to connectedEndpoints yet. Wait for Handshake.

        client.listen((Uint8List data) {
          final String message = String.fromCharCodes(data).trim();
          if (message.isEmpty) return;

          // Identify Client Logic
          // We need to parse the packet to know WHO this is.
          // Simulator sends: { packetId, originId, data: { ... } }

          try {
            final json = jsonDecode(message);

            // 1. Extract Identity
            String? senderId = json['originId']; // From MeshPacket structure
            if (senderId == null && json.containsKey('senderId')) {
              senderId = json['senderId']; // Fallback
            }

            // If we don't know this sender yet, treat this as Handshake/Discovery
            if (senderId != null) {
              // Check if we need to "Connect" (Discovery Phase)
              if (!_connectedEndpoints.containsKey(senderId)) {
                // Only accept if we are Scanning/Advertising OR if it's a reconnection?
                // User wants "Visible only on scan", but "Persistent".
                // If we are scanning, we accept.

                if (_isAdvertising || _isDiscovering) {
                  // Look for username in payload data
                  String name = "Simulator";
                  if (json['data'] != null &&
                      json['data']['username'] != null) {
                    name = json['data']['username'];
                  }

                  _connectedEndpoints[senderId] = name;
                  _statusController.add(MeshConnectionStatus.connected);
                  print("✅ Simulator Identify Verified: $senderId ($name)");

                  // SEND SERVER IDENTITY BACK
                  final serverHandshake = {
                    'packetId':
                        'server-handshake-${DateTime.now().millisecondsSinceEpoch}',
                    // Use a distinct origin for the Phone
                    'originId': _localUserId ?? 'phone-host',
                    'data': {
                      'type': 'handshake',
                      'username': _localUsername ?? "Phone Host",
                      'senderId': _localUserId ?? 'phone-host'
                    }
                  };
                  try {
                    client.write(jsonEncode(serverHandshake) + "\n");
                  } catch (e) {
                    print("Error sending handshake: $e");
                  }
                } else {
                  // Ignore if not scanning
                  print("⚠️ Simulator $senderId ignored (Not Scanning)");
                  return;
                }
              }

              // 2. Process Payload
              if (_connectedEndpoints.containsKey(senderId)) {
                print("📥 Received from Simulator ($senderId): $json");
                // The app expects `senderId` at top level for some logic,
                // or `MeshProvider` handles `MeshPacket` unpacking.
                // Our Simulator sends `MeshPacket`. `MeshProvider` handles `MeshPacket`?
                // Let's check MeshProvider later. For now, ensure we pass it.
                // NOTE: If the app expects raw {message: "hi"}, we might need to unwrap if Sim sends {packet...}
                // But previous implementation passed `json` directly.

                // Just forward.
                _payloadController.add(json);
              }
            }
          } catch (e) {
            print("Error parsing simulator message: $e");
          }
        }, onDone: () {
          print("Simulator disconnected");
          _debugClients.remove(client);
          // We don't easily know WHICH ID this socket was unless we map it.
          // For now, iterate and remove if we can, or just wait for timeout.
          // Ideally we should map Socket -> ID.
          // Limitation: If we don't remove, it stays "Connected" in UI?
          // User wants persistence. Staying connected in UI is fine until explicit disconnect?
          // But if they reconnect, we just update map.
        }, onError: (e) {
          _debugClients.remove(client);
        });
      });
    } catch (e) {
      print("⚠️ Failed to start Debug Server: $e");
    }
  }

  // Remove _checkDebugClients as we now do it "On Data" (Handshake)
  void _checkDebugClients() {
    // No-op or trigger handshake request?
    // Simulators send handshake on connect.
    // If we start scanning AFTER connect, we might miss it.
    // We can ask clients to identify?
    // For now, relying on User restarting Sim or Sim sending heartbeats is safer.
    // Or we send "WHOAREYOU" to all debug clients.
    if (_isAdvertising || _isDiscovering) {
      _requestIdentityFromSimulators();
    }
  }

  void _requestIdentityFromSimulators() {
    for (final client in _debugClients) {
      try {
        client.write(jsonEncode({'type': 'identity_request'}) + "\n");
      } catch (e) {}
    }
  }

  // Helper callbacks
  void _onConnectionInitiated(String id, ConnectionInfo info) {
    // Auto-accept connection from trusted sources or all for now
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endpointId, payload) {
        if (payload.type == PayloadType.BYTES) {
          final String str = utf8.decode(payload.bytes!);
          final Map<String, dynamic> data = jsonDecode(str);

          // 1. Dedup Check (Prevent loops)
          String? packetId = data['packetId'] ?? data['id'];
          if (packetId != null) {
            final now = DateTime.now().millisecondsSinceEpoch;
            if (_seenPacketIds.containsKey(packetId)) {
              // Already processed this packet. Ignore.
              return;
            }
            _seenPacketIds[packetId] = now;

            // Clean old IDs occasionally
            if (_seenPacketIds.length > 500) {
              _seenPacketIds
                  .removeWhere((_, time) => now - time > _dedupWindow);
            }
          }

          // 2. Add sender ID to data so UI knows who sent it (Last Hop)
          data['senderId'] = endpointId;
          // data['originId'] should be preserved from original sender

          print("Received payload from $endpointId: $data");
          _payloadController.add(data);

          // 3. RELAY (Multi-Hop)
          // Forward to everyone else (except sender)
          _relayPayload(data, excludeEndpoint: endpointId);

          // Forward to Simulators
          _forwardToDebugClients(data);
        }
      },
    );
  }

  void _forwardToDebugClients(Map<String, dynamic> payload) {
    print("📤 Forwarding to ${_debugClients.length} debug clients");
    if (_debugClients.isEmpty) {
      print("⚠️ No debug clients connected!");
      return;
    }
    final jsonStr = jsonEncode(payload);
    final deadClients = <Socket>[];

    for (final client in _debugClients) {
      try {
        client.write(jsonStr + "\n");
        print("✅ Sent to simulator: ${client.remoteAddress.address}");
      } catch (e) {
        print("Error forwarding to simulator (removing): $e");
        deadClients.add(client);
      }
    }

    // Remove dead clients
    for (final dead in deadClients) {
      _debugClients.remove(dead);
    }
  }

  void _onConnectionResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      _connectedEndpoints[id] = "Unknown"; // Update with real name if available
      _statusController.add(MeshConnectionStatus.connected);
    } else {
      _connectedEndpoints.remove(id);
    }
  }

  void _onDisconnected(String id) {
    _connectedEndpoints.remove(id);
    if (_connectedEndpoints.isEmpty) {
      _statusController
          .add(MeshConnectionStatus.disconnected); // Or kept "advertising"
    }
  }

  // Update broadcast to also send to simulators
  @override
  Future<void> broadcastPayload(Map<String, dynamic> payload) async {
    print(
        "📡 Broadcasting payload to ${_connectedEndpoints.length} endpoints and ${_debugClients.length} simulators");

    final String jsonString = jsonEncode(payload);
    final bytes = Uint8List.fromList(utf8.encode(jsonString));

    // 1. Send to physical peers
    for (final endpointId in _connectedEndpoints.keys) {
      if (!endpointId.startsWith("simulator-") &&
          !endpointId.startsWith("laptop-")) {
        print("📤 Sending to physical peer: $endpointId");
        await Nearby().sendBytesPayload(endpointId, bytes);
      }
    }

    // 2. Send to simulators
    // 2. Send to simulators
    _forwardToDebugClients(payload);
  }

  // Relay helper
  Future<void> _relayPayload(Map<String, dynamic> payload,
      {required String excludeEndpoint}) async {
    final String jsonString = jsonEncode(payload);
    final bytes = Uint8List.fromList(utf8.encode(jsonString));

    for (final endpointId in _connectedEndpoints.keys) {
      if (endpointId != excludeEndpoint &&
          !endpointId.startsWith("simulator-") &&
          !endpointId.startsWith("laptop-")) {
        print("🔁 Relaying packet to $endpointId");
        try {
          await Nearby().sendBytesPayload(endpointId, bytes);
        } catch (e) {
          print("Relay failed to $endpointId: $e");
        }
      }
    }
  }

  @override
  Future<void> sendPayload(
      String endpointId, Map<String, dynamic> payload) async {
    // Check if target is simulator
    if (endpointId.startsWith("simulator-")) {
      _forwardToDebugClients(payload); // Broadcast to all sims for simplicity
      return;
    }

    final String jsonString = jsonEncode(payload);
    await Nearby().sendBytesPayload(
        endpointId, Uint8List.fromList(utf8.encode(jsonString)));
  }
}
