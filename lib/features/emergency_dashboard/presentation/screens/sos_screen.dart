import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  List<EmergencyContact> _emergencyContacts = [];
  bool _isSending = false;
  Position? _currentPosition;

  // Native SMS channel
  static const platform = MethodChannel('com.kreoassist/sms');

  // India Emergency Numbers
  static const List<Map<String, dynamic>> emergencyServices = [
    {
      'name': 'National Emergency',
      'number': '112',
      'icon': Icons.emergency,
      'color': Color(0xFFE53935)
    },
    {
      'name': 'Police',
      'number': '100',
      'icon': Icons.local_police,
      'color': Color(0xFF1976D2)
    },
    {
      'name': 'Ambulance',
      'number': '102',
      'icon': Icons.local_hospital,
      'color': Color(0xFF43A047)
    },
    {
      'name': 'Fire',
      'number': '101',
      'icon': Icons.local_fire_department,
      'color': Color(0xFFFF6B35)
    },
    {
      'name': 'Women Helpline',
      'number': '1091',
      'icon': Icons.woman,
      'color': Color(0xFFAD1457)
    },
    {
      'name': 'Disaster Management',
      'number': '1078',
      'icon': Icons.flood,
      'color': Color(0xFF5C6BC0)
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _getCurrentLocation();
    _checkAndRequestSmsPermission();
  }

  Future<void> _checkAndRequestSmsPermission() async {
    try {
      final hasPermission = await platform.invokeMethod('checkPermission');
      if (!hasPermission) {
        await platform.invokeMethod('requestPermission');
      }
    } catch (e) {
      print("Permission check error: $e");
    }
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getStringList('emergency_contacts') ?? [];
    setState(() {
      _emergencyContacts = contactsJson.map((c) {
        final parts = c.split('|');
        return EmergencyContact(name: parts[0], phone: parts[1]);
      }).toList();
    });
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson =
        _emergencyContacts.map((c) => '${c.name}|${c.phone}').toList();
    await prefs.setStringList('emergency_contacts', contactsJson);
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print("Location error: $e");
    }
  }

  /// Direct dial - immediately starts call via native channel
  Future<void> _directCall(String number) async {
    try {
      await platform.invokeMethod('directCall', {'phone': number});
    } catch (e) {
      print("Native call error: $e");
      // Fallback to url_launcher
      final uri = Uri.parse('tel:$number');
      await launchUrl(uri);
    }
  }

  /// Send SMS directly via native channel (auto-send, no app opens)
  Future<bool> _sendDirectSMS(String phone, String message) async {
    try {
      final result = await platform.invokeMethod('sendSMS', {
        'phone': phone,
        'message': message,
      });
      return result == true;
    } catch (e) {
      print("Native SMS error: $e");
      return false;
    }
  }

  Future<void> _sendSOSToAll() async {
    if (_emergencyContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add emergency contacts first!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    await _getCurrentLocation();

    String message = "🆘 EMERGENCY SOS!\n\nI need help urgently.";
    if (_currentPosition != null) {
      message +=
          "\n\n📍 Location:\nhttps://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}";
    }

    int successCount = 0;

    // Send SMS to each contact via native channel
    for (final contact in _emergencyContacts) {
      final success = await _sendDirectSMS(contact.phone, message);
      if (success) {
        successCount++;
        print("SMS sent to ${contact.name}");
      }
    }

    setState(() => _isSending = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successCount > 0
              ? '✅ SOS sent to $successCount contacts!'
              : '❌ Failed to send. Grant SMS permission.'),
          backgroundColor: successCount > 0 ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _addContact() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Add Emergency Contact',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                labelStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
                setState(() {
                  _emergencyContacts.add(EmergencyContact(
                    name: nameController.text,
                    phone: phoneController.text,
                  ));
                });
                _saveContacts();
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Emergency SOS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Big SOS Button
            GestureDetector(
              onTap: _isSending ? null : _sendSOSToAll,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE53935).withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _isSending
                        ? const SizedBox(
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 4),
                          )
                        : const Icon(Icons.sos, size: 64, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      _isSending ? 'SENDING...' : 'SEND SOS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Auto-sends SMS with location (no tap needed)',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Emergency Services
            const Text('Quick Dial',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 4),
            const Text('Tap to call immediately',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
              children: emergencyServices
                  .map((service) => _buildServiceCard(service))
                  .toList(),
            ),
            const SizedBox(height: 24),

            // My Emergency Contacts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('My Emergency Contacts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    )),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Color(0xFFFF6B35)),
                  onPressed: _addContact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_emergencyContacts.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Center(
                  child: Text(
                    'No contacts added.\nTap + to add emergency contacts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...(_emergencyContacts
                  .asMap()
                  .entries
                  .map((e) => _buildContactCard(e.key, e.value))),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    return GestureDetector(
      onTap: () => _directCall(service['number']),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: (service['color'] as Color).withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(service['icon'], color: service['color'], size: 28),
            const SizedBox(height: 8),
            Text(
              service['number'],
              style: TextStyle(
                color: service['color'],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              service['name'],
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(int index, EmergencyContact contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFFF6B35),
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                Text(contact.phone,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.green),
            onPressed: () => _directCall(contact.phone),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              setState(() => _emergencyContacts.removeAt(index));
              _saveContacts();
            },
          ),
        ],
      ),
    );
  }
}

class EmergencyContact {
  final String name;
  final String phone;

  EmergencyContact({required this.name, required this.phone});
}
