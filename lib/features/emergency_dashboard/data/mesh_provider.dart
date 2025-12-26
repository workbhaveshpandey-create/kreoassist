import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../mesh_network/data/mesh_network_service_impl.dart';
import '../../mesh_network/domain/mesh_network_service.dart';
import '../../../../core/services/notification_service.dart';

// State class to hold immutable state
class MeshState {
  final bool isAdvertising;
  final bool isDiscovering;
  final MeshConnectionStatus status;
  final List<String> connectedEndpoints;
  final List<String> logs;

  const MeshState({
    this.isAdvertising = false,
    this.isDiscovering = false,
    this.status = MeshConnectionStatus.disconnected,
    this.connectedEndpoints = const [],
    this.logs = const [],
  });

  MeshState copyWith({
    bool? isAdvertising,
    bool? isDiscovering,
    MeshConnectionStatus? status,
    List<String>? connectedEndpoints,
    List<String>? logs,
  }) {
    return MeshState(
      isAdvertising: isAdvertising ?? this.isAdvertising,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      status: status ?? this.status,
      connectedEndpoints: connectedEndpoints ?? this.connectedEndpoints,
      logs: logs ?? this.logs,
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

  StreamSubscription? _statusSub;
  StreamSubscription? _payloadSub;

  MeshNotifier(this._meshService, this._notificationService)
      : super(const MeshState()) {
    _initListeners();
  }

  void _initListeners() {
    _statusSub = _meshService.statusStream.listen((status) {
      if (status == MeshConnectionStatus.connected &&
          state.status != MeshConnectionStatus.connected) {
        _notificationService.showNotification(
          id: 1,
          title: 'Mesh Network Connected',
          body: 'Connected to a new peer node.',
        );
      }
      state = state.copyWith(status: status);
      state =
          state.copyWith(connectedEndpoints: _meshService.connectedEndpoints);
    });

    _payloadSub = _meshService.payloadStream.listen((data) {
      if (data.containsKey('message')) {
        _notificationService.showNotification(
          id: 2,
          title: 'New Mesh Message',
          body: 'From ${data['senderId']}: ${data['message']}',
        );
      }
    });
  }

  void startAdvertising(String username) {
    if (state.isAdvertising) return;
    _meshService.startAdvertising(username);
    state = state.copyWith(isAdvertising: true, isDiscovering: false);
  }

  void startDiscovery() {
    if (state.isDiscovering) return;
    _meshService.startDiscovery();
    state = state.copyWith(isDiscovering: true, isAdvertising: false);
  }

  void stopAll() {
    _meshService.stopAll();
    state = state.copyWith(isAdvertising: false, isDiscovering: false);
  }

  void sendMessage(String peerId, String message) {
    _meshService.sendPayload(peerId, {'message': message});
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _payloadSub?.cancel();
    super.dispose();
  }
}
