enum MeshConnectionStatus {
  disconnected,
  discovering,
  advertising,
  connected,
}

abstract class MeshNetworkService {
  /// stream of connection status
  Stream<MeshConnectionStatus> get statusStream;

  /// Starts advertising this device to nearby devices.
  /// [username] is the display name visible to others.
  Future<void> startAdvertising(String username);

  /// Starts discovering nearby devices.
  Future<void> startDiscovery();

  /// Stops both advertising and discovery.
  Future<void> stopAll();

  /// Sends a payload to a specific [endpointId].
  /// [payload] is the JSON map data to send.
  Future<void> sendPayload(String endpointId, Map<String, dynamic> payload);

  /// Broadcasts a payload to all connected devices.
  Future<void> broadcastPayload(Map<String, dynamic> payload);

  /// Stream of incoming payloads from connected devices
  Stream<Map<String, dynamic>> get payloadStream;

  /// Get list of connected endpoint IDs
  List<String> get connectedEndpoints;
}
