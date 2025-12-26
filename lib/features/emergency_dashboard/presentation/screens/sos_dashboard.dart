import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'first_aid_screen.dart';
import 'sos_screen.dart';

class SOSDashboard extends StatelessWidget {
  const SOSDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick Access Cards
          Row(
            children: [
              Expanded(
                child: _buildQuickCard(
                  context,
                  'First Aid',
                  Icons.medical_services,
                  const Color(0xFF43A047),
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FirstAidScreen(),
                      )),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickCard(
                  context,
                  'Emergency SOS',
                  Icons.sos,
                  const Color(0xFFE53935),
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SOSScreen(),
                      )),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Emergency Broadcast Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: const Color(0xFFE53935).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.broadcast_on_personal,
                    size: 48, color: Color(0xFFFF6B35)),
                const SizedBox(height: 16),
                const Text(
                  "MESH BROADCAST",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Broadcast your status to all nearby devices on the mesh network.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildBroadcastChip(context, "I'M SAFE", Colors.green),
                    _buildBroadcastChip(context, "NEED HELP", Colors.red),
                    _buildBroadcastChip(context, "NEED WATER", Colors.blue),
                    _buildBroadcastChip(context, "TRAPPED", Colors.orange),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Emergency Numbers Quick Reference
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Emergency Numbers",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNumberPill("112", "Emergency"),
                    _buildNumberPill("100", "Police"),
                    _buildNumberPill("102", "Ambulance"),
                    _buildNumberPill("101", "Fire"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCard(BuildContext context, String title, IconData icon,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildBroadcastChip(BuildContext context, String label, Color color) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Broadcasting: $label to mesh network"),
            backgroundColor: color,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildNumberPill(String number, String label) {
    return InkWell(
      onTap: () async {
        await FlutterPhoneDirectCaller.callNumber(number);
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
            ),
            child: Text(
              number,
              style: const TextStyle(
                  color: Color(0xFFFF6B35), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }
}
