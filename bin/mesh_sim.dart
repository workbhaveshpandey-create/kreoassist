import 'dart:io';
import 'dart:convert';
import 'package:uuid/uuid.dart';

// Laptop Mesh Simulator
// Connects to KreoAssist app running on Phone via Debug Bridge (Port 4545)
// Simulates a Mesh Peer ("Laptop Rescue Node")

const int PORT = 4545;
final Uuid _uuid = Uuid();

// My Identity
const String MY_USER_ID = "laptop-simulator-007";
const String MY_USERNAME = "Laptop Cmd Center";

Future<void> main() async {
  print("====================================");
  print("🖥️  KreoAssist Mesh Simulator 1.0");
  print("====================================");
  print("This tool connects to your Android Phone running KreoAssist.");
  print("Ensure both devices are on the SAME Wi-Fi.");
  print("");

  stdout.write("Enter Phone IP Address: ");
  final ip = stdin.readLineSync()?.trim();

  if (ip == null || ip.isEmpty) {
    print("Invalid IP. Exiting.");
    return;
  }

  try {
    print("Connecting to $ip:$PORT...");
    final socket = await Socket.connect(ip, PORT);
    print("✅ Connected! You are now a visible Mesh Peer.");

    // 1. Send Handshake immediately
    _sendHandshake(socket);

    // 2. Listen for incoming
    socket.listen(
      (data) {
        final msg = String.fromCharCodes(data).trim();
        _handleIncoming(msg);
      },
      onDone: () => print("❌ Disconnected from phone."),
      onError: (e) => print("⚠️ Error: $e"),
    );

    // 3. Handle User Input
    print("Type message to broadcast (or 'q' to quit):");
    _handleInput(socket);
  } catch (e) {
    print("❌ Connection Failed: $e");
    print("Did you enable the Debug Bridge in the app code?");
  }
}

void _sendPacket(Socket socket, Map<String, dynamic> payload, {int ttl = 3}) {
  final packet = {
    'packetId': _uuid.v4(),
    'originId': MY_USER_ID,
    'ttl': ttl,
    'data': payload
  };

  socket.write(jsonEncode(packet));
  // No newline needed usually, but some readers like it.
  // Our server reader doesn't split by newline logic explicitly, but `String.fromCharCodes` might merge chunks.
  // Ideally we should frame it. But simple JSON usually works if small.
}

void _sendHandshake(Socket socket) {
  print("🤝 Sending Handshake...");
  final payload = {
    'type': 'handshake',
    'userId': MY_USER_ID,
    'username': MY_USERNAME,
  };
  _sendPacket(socket, payload);
}

void _handleIncoming(String msg) {
  try {
    // Might be multiple JSONs stuck together if fast
    // Simple heuristic: just try to parse
    final json = jsonDecode(msg);

    if (json.containsKey('packetId')) {
      final origin = json['originId'];
      if (origin == MY_USER_ID) return; // Ignore own echoes

      final data = json['data'];

      if (data['type'] == 'handshake') {
        print("👋 Handshake from ${data['username']} ($origin)");
      } else if (data['type'] == 'emergency_status') {
        final status = data['status'];
        final username = data['username'] ?? origin;
        final emoji = _getStatusEmoji(status);
        print("🚨 EMERGENCY STATUS [$username]: $emoji $status");
      } else if (data.containsKey('message')) {
        print("📩 CHAT [${data['senderId'] ?? origin}]: ${data['message']}");
      }
    }
  } catch (e) {
    // print("Raw: $msg");
  }
}

String _getStatusEmoji(String status) {
  switch (status.toLowerCase()) {
    case 'safe':
      return '✅';
    case 'needhelp':
    case 'need_help':
      return '🆘';
    case 'needwater':
    case 'need_water':
      return '💧';
    case 'trapped':
      return '🚨';
    default:
      return '❓';
  }
}

void _handleInput(Socket socket) {
  stdin.listen((data) {
    final input = String.fromCharCodes(data).trim();
    if (input == 'q') exit(0);

    if (input.isNotEmpty) {
      final payload = {'message': input};
      _sendPacket(socket, payload);
      print("You: $input");
    }
  });
}
