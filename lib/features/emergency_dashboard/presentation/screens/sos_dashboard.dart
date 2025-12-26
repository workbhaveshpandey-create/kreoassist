import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'first_aid_screen.dart';
import 'sos_screen.dart';

class SOSDashboard extends StatelessWidget {
  const SOSDashboard({super.key});

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
          const SizedBox(height: 32),

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

          const SizedBox(height: 32),

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
                    "Tip: Mesh Network works without internet. Use it when signal is lost.",
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
}
