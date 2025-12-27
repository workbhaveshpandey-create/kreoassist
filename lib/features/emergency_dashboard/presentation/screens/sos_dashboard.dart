import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import '../../../../core/services/flashlight_service.dart';
import 'first_aid_screen.dart';
import 'offline_maps_screen.dart';
import 'sos_screen.dart';

class SOSDashboard extends StatefulWidget {
  const SOSDashboard({super.key});

  @override
  State<SOSDashboard> createState() => _SOSDashboardState();
}

class _SOSDashboardState extends State<SOSDashboard> {
  bool _flashlightOn = false;
  bool _sosActive = false;
  bool _hasFlashlight = true;

  @override
  void initState() {
    super.initState();
    _checkFlashlight();
  }

  Future<void> _checkFlashlight() async {
    final has = await FlashlightService.hasFlashlight();
    if (mounted) {
      setState(() => _hasFlashlight = has);
    }
  }

  Future<void> _toggleFlashlight() async {
    await FlashlightService.toggle();
    if (mounted) {
      setState(() {
        _flashlightOn = FlashlightService.isOn;
        _sosActive = false;
      });
    }
  }

  Future<void> _toggleSOS() async {
    if (_sosActive) {
      await FlashlightService.stopSOS();
      if (mounted) {
        setState(() {
          _sosActive = false;
          _flashlightOn = false;
        });
      }
    } else {
      setState(() {
        _sosActive = true;
        _flashlightOn = false;
      });
      await FlashlightService.startSOS(
        onCycleComplete: () {
          // Optional: vibrate or update UI on each SOS cycle
        },
      );
    }
  }

  @override
  void dispose() {
    FlashlightService.stopSOS();
    FlashlightService.turnOff();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main Action Cards
          Row(
            children: [
              Expanded(
                child: _buildQuickCard(
                  context,
                  'First Aid',
                  'Medical Guide',
                  Icons.medical_services_outlined,
                  const Color(0xFF00C853),
                  [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FirstAidScreen())),
                ).animate().fadeIn(delay: 100.ms, duration: 300.ms).slideY(
                    begin: 0.15,
                    end: 0,
                    duration: 300.ms,
                    curve: Curves.easeOut),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickCard(
                  context,
                  'SOS Alert',
                  'Trigger Help',
                  Icons.sos,
                  const Color(0xFFFF5252),
                  [const Color(0xFFB71C1C), const Color(0xFFD32F2F)],
                  () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SOSScreen())),
                ).animate().fadeIn(delay: 150.ms, duration: 300.ms).slideY(
                    begin: 0.15,
                    end: 0,
                    duration: 300.ms,
                    curve: Curves.easeOut),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Offline Maps Card - Simple Clean Design
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const OfflineMapsScreen())),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF2A2A2A),
                ),
              ),
              child: Row(
                children: [
                  // Simple icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.map_rounded,
                      color: Color(0xFF60A5FA),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Text
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Offline Maps',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Save areas for offline use',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white38,
                    size: 26,
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

          const SizedBox(height: 24),

          // Flashlight Panel
          if (_hasFlashlight)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _sosActive
                      ? const Color(0xFFFF5252).withOpacity(0.5)
                      : _flashlightOn
                          ? const Color(0xFFFFD54F).withOpacity(0.5)
                          : Colors.white10,
                  width: _sosActive || _flashlightOn ? 2 : 1,
                ),
                boxShadow: [
                  if (_sosActive)
                    BoxShadow(
                      color: const Color(0xFFFF5252).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  if (_flashlightOn && !_sosActive)
                    BoxShadow(
                      color: const Color(0xFFFFD54F).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _sosActive
                            ? Icons.sos
                            : _flashlightOn
                                ? Icons.flashlight_on
                                : Icons.flashlight_off,
                        size: 20,
                        color: _sosActive
                            ? const Color(0xFFFF5252)
                            : _flashlightOn
                                ? const Color(0xFFFFD54F)
                                : Colors.white54,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _sosActive
                            ? "SOS Signal Active"
                            : _flashlightOn
                                ? "Flashlight On"
                                : "Flashlight & SOS",
                        style: TextStyle(
                          color: _sosActive
                              ? const Color(0xFFFF5252)
                              : _flashlightOn
                                  ? const Color(0xFFFFD54F)
                                  : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (_sosActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5252).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "... --- ...",
                            style: TextStyle(
                              color: Color(0xFFFF5252),
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFlashlightBtn(
                          icon: _flashlightOn
                              ? Icons.flashlight_off
                              : Icons.flashlight_on,
                          label: _flashlightOn ? "Turn Off" : "Flashlight",
                          color: const Color(0xFFFFD54F),
                          active: _flashlightOn && !_sosActive,
                          onTap: _toggleFlashlight,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildFlashlightBtn(
                          icon: Icons.sos,
                          label: _sosActive ? "Stop SOS" : "SOS Blink",
                          color: const Color(0xFFFF5252),
                          active: _sosActive,
                          onTap: _toggleSOS,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _sosActive
                        ? "Blinking SOS Morse Code pattern"
                        : "Use SOS to blink ... --- ... pattern",
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms)
                .slideY(begin: 0.1, duration: 400.ms),

          const SizedBox(height: 24),

          // Emergency Numbers Panel
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.phone_in_talk,
                        size: 20, color: Color(0xFFFF9933)),
                    SizedBox(width: 10),
                    Text(
                      "Quick Dial Numbers",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDialBtn("112", "Emergency", Icons.shield),
                    _buildDialBtn("100", "Police", Icons.local_police),
                    _buildDialBtn("102", "Ambulance", Icons.medical_services),
                    _buildDialBtn("101", "Fire", Icons.local_fire_department),
                  ],
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(delay: 300.ms, duration: 400.ms)
              .slideY(begin: 0.1, duration: 400.ms),

          const SizedBox(height: 24),

          // Tip Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF263238),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blueGrey.withOpacity(0.3)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Colors.blueGrey),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Tip: Use SOS flashlight in dark to signal for help with Morse code.",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(delay: 400.ms, duration: 400.ms)
              .slideY(begin: 0.1, duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildFlashlightBtn({
    required IconData icon,
    required String label,
    required Color color,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.2) : const Color(0xFF333333),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color : Colors.white12,
            width: active ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? color : Colors.white70, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: active ? color : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCard(
      BuildContext context,
      String title,
      String subtitle,
      IconData icon,
      Color iconColor,
      List<Color> gradient,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const Spacer(),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text(subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildDialBtn(String number, String label, IconData icon) {
    return InkWell(
      onTap: () async {
        await FlutterPhoneDirectCaller.callNumber(number);
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
            child: Icon(icon, size: 22, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(number,
              style: const TextStyle(
                  color: Color(0xFFFF9933), fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildMapTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white60),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Map grid pattern painter
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B82F6).withOpacity(0.1)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 30.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Add some dots at intersections
    final dotPaint = Paint()
      ..color = const Color(0xFF3B82F6).withOpacity(0.2)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
