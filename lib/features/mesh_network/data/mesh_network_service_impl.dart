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

  @override
  Stream<MeshConnectionStatus> get statusStream => _statusController.stream;

  @override
  List<String> get connectedEndpoints => _connectedEndpoints.keys.toList();

  @override
  Future<void> startAdvertising(String username) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      print("Mesh networking is only supported on Android and iOS.");
      return;
    }
    try {
      _statusController.add(MeshConnectionStatus.advertising);

      // Check if services are enabled (User reported missing prompts)
      if (await Permission.location.serviceStatus.isDisabled) {
        print("Warning: Location service is disabled. Discovery may fail.");
      }
      if (await Permission.bluetooth.serviceStatus.isDisabled) {
        print("Warning: Bluetooth service is disabled. Discovery may fail.");
      }

      bool success = await Nearby().startAdvertising(
        username,
        _strategy,
        serviceId: "com.kreoassist", // Required for P2P_CLUSTER usually
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
  Future<void> startDiscovery() async {
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
        "User-Discoverer", // userNickName
        _strategy,
        serviceId: "com.kreoassist",
        onEndpointFound: (String id, String userName, String serviceId) {
          // Automatically request connection for simple mesh logic
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
          // Handle lost endpoint
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
  Future<void> stopAll() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    _connectedEndpoints.clear();
    _statusController.add(MeshConnectionStatus.disconnected);
  }

  @override
  Future<void> sendPayload(
      String endpointId, Map<String, dynamic> payload) async {
    final String jsonString = jsonEncode(payload);
    await Nearby().sendBytesPayload(
        endpointId, Uint8List.fromList(utf8.encode(jsonString)));
  }

  @override
  Future<void> broadcastPayload(Map<String, dynamic> payload) async {
    final String jsonString = jsonEncode(payload);
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    for (final endpointId in _connectedEndpoints.keys) {
      await Nearby().sendBytesPayload(endpointId, bytes);
    }
  }

  final StreamController<Map<String, dynamic>> _payloadController =
      StreamController.broadcast();

  @override
  Stream<Map<String, dynamic>> get payloadStream => _payloadController.stream;

  // ... (previous code)

  // Helper callbacks
  void _onConnectionInitiated(String id, ConnectionInfo info) {
    // Auto-accept connection from trusted sources or all for now
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endpointId, payload) {
        if (payload.type == PayloadType.BYTES) {
          final String str = utf8.decode(payload.bytes!);
          final Map<String, dynamic> data = jsonDecode(str);

          // Add sender ID to data so UI knows who sent it
          data['senderId'] = endpointId;

          print("Received payload from $endpointId: $data");
          _payloadController.add(data);
        }
      },
    );
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
}
