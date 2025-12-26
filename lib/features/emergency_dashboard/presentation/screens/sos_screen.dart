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

class _SOSScreenState extends State<SOSScreen> with TickerProviderStateMixin {
  List<EmergencyContact> _emergencyContacts = [];
  bool _isSending = false;
  Position? _currentPosition;

  // Animation for Hold-to-SOS
  late AnimationController _holdController;
  late AnimationController _pulseController;

  // Native SMS channel
  static const platform = MethodChannel('com.kreoassist/sms');

  // India Emergency Numbers
  static const List<Map<String, dynamic>> emergencyServices = [
    {
      'name': 'National',
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
      'name': 'Women',
      'number': '1091',
      'icon': Icons.woman,
      'color': Color(0xFFAD1457)
    },
    {
      'name': 'Disaster',
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

    // Hold controller (3 seconds to trigger)
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _sendSOSToAll();
        _holdController.reset();
        HapticFeedback.heavyImpact();
      }
    });

    // Pulse controller for visual heartbeat
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _holdController.dispose();
    _pulseController.dispose();
    super.dispose();
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
          behavior: SnackBarBehavior.floating,
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
          behavior: SnackBarBehavior.floating,
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
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
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
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: Colors.white38),
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
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Save Contact',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Emergency SOS',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            // HERO SOS BUTTON (Hold to Trigger)
            Center(
              child: GestureDetector(
                onTapDown: (_) => _holdController.forward(),
                onTapUp: (_) => _holdController.reverse(),
                onTapCancel: () => _holdController.reverse(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Pulse Ring
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 200 + (_pulseController.value * 20),
                          height: 200 + (_pulseController.value * 20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFF3D00).withOpacity(
                                0.1 - (_pulseController.value * 0.05)),
                          ),
                        );
                      },
                    ),
                    // Progress Ring
                    SizedBox(
                      width: 190,
                      height: 190,
                      child: AnimatedBuilder(
                        animation: _holdController,
                        builder: (context, child) => CircularProgressIndicator(
                          value: _holdController.value,
                          strokeWidth: 8,
                          backgroundColor: const Color(0xFF2C2C2C),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF3D00)),
                        ),
                      ),
                    ),
                    // Button Core
                    Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD50000), Color(0xFFB71C1C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF3D00).withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.touch_app,
                              color: Colors.white, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            _isSending ? "SENDING" : "HOLD SOS",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Hold for 3 seconds to alert contacts",
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),

            const SizedBox(height: 32),

            // Emergency Safety Circle (Horizontal List)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Safety Circle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    )),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: Color(0xFFFF6B35)),
                  onPressed: _addContact,
                  tooltip: "Add Contact",
                ),
              ],
            ),

            SizedBox(
              height: 100,
              child: _emergencyContacts.isEmpty
                  ? Center(
                      child: TextButton.icon(
                        onPressed: _addContact,
                        icon:
                            const Icon(Icons.person_add, color: Colors.white54),
                        label: const Text("Add Trusted Contacts",
                            style: TextStyle(color: Colors.white54)),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _emergencyContacts.length,
                      itemBuilder: (context, index) {
                        final contact = _emergencyContacts[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    _showContactOptions(index, contact),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFFFF6B35),
                                        width: 2),
                                  ),
                                  child: CircleAvatar(
                                    radius: 28,
                                    backgroundColor: const Color(0xFF1E1E1E),
                                    child: Text(
                                      contact.name[0].toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                contact.name.split(' ')[0],
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 24),

            // Quick Access Grid
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Emergency Services',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  )),
            ),
            const SizedBox(height: 16),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: emergencyServices.length,
              itemBuilder: (context, index) =>
                  _buildServiceTile(emergencyServices[index]),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showContactOptions(int index, EmergencyContact contact) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(contact.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text(contact.phone, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOptionBtn(Icons.call, "Call", Colors.green, () {
                  Navigator.pop(ctx);
                  _directCall(contact.phone);
                }),
                _buildOptionBtn(Icons.message, "SMS", Colors.blue, () {
                  Navigator.pop(ctx);
                  final uri = Uri.parse('sms:${contact.phone}');
                  launchUrl(uri);
                }),
                _buildOptionBtn(Icons.delete, "Remove", Colors.red, () {
                  Navigator.pop(ctx);
                  setState(() => _emergencyContacts.removeAt(index));
                  _saveContacts();
                }),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildOptionBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white),
          style: IconButton.styleFrom(
              backgroundColor: color.withOpacity(0.2),
              padding: const EdgeInsets.all(16)),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildServiceTile(Map<String, dynamic> service) {
    return GestureDetector(
      onTap: () => _directCall(service['number']),
      child: Container(
        decoration: BoxDecoration(
          color: (service['color'] as Color).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: (service['color'] as Color).withOpacity(0.3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (service['color'] as Color).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(service['icon'], color: service['color'], size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service['name'],
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    service['number'],
                    style: TextStyle(
                        color: (service['color'] as Color),
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmergencyContact {
  final String name;
  final String phone;

  EmergencyContact({required this.name, required this.phone});
}
