import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/notification_service.dart';

class MedicalProfileScreen extends StatefulWidget {
  const MedicalProfileScreen({super.key});

  @override
  State<MedicalProfileScreen> createState() => _MedicalProfileScreenState();
}

class _MedicalProfileScreenState extends State<MedicalProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  String _selectedBloodGroup = 'Unknown';
  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
    'Unknown'
  ];

  bool _showOnLockScreen = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _nameController.text = prefs.getString('medical_name') ?? '';
      _selectedBloodGroup = prefs.getString('medical_blood') ?? 'Unknown';
      _allergiesController.text = prefs.getString('medical_allergies') ?? '';
      _conditionsController.text = prefs.getString('medical_conditions') ?? '';
      _emergencyContactController.text =
          prefs.getString('medical_contact') ?? '';
      _showOnLockScreen = prefs.getBool('medical_show_lock') ?? false;
    });
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('medical_name', _nameController.text);
    await prefs.setString('medical_blood', _selectedBloodGroup);
    await prefs.setString('medical_allergies', _allergiesController.text);
    await prefs.setString('medical_conditions', _conditionsController.text);
    await prefs.setString('medical_contact', _emergencyContactController.text);
    await prefs.setBool('medical_show_lock', _showOnLockScreen);

    // Update Notification
    if (_showOnLockScreen) {
      await NotificationService.showMedicalNotification(
        name: _nameController.text,
        bloodGroup: _selectedBloodGroup,
        allergies: _allergiesController.text,
        conditions: _conditionsController.text,
      );
    } else {
      await NotificationService.cancelMedicalNotification();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Medical ID Updated Successfully',
              style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF00C853),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Medical Profile",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Gradient Element
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF5252).withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5252).withOpacity(0.2),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    // Header Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE53935).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_outline_rounded,
                                color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 20),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Emergency ID",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text("This info will be visible to rescuers.",
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideY(begin: 0.2, end: 0),

                    const SizedBox(height: 30),

                    // Full Name
                    _buildSectionTitle("Personal Details"),
                    const SizedBox(height: 12),
                    _buildTextField(
                        controller: _nameController,
                        label: "Full Name",
                        icon: Icons.badge_outlined),

                    const SizedBox(height: 24),

                    // Blood Group Selector
                    _buildSectionTitle("Blood Group"),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _bloodGroups
                          .map((bg) => _buildBloodGroupChip(bg))
                          .toList(),
                    ),

                    const SizedBox(height: 30),

                    // Medical Info
                    _buildSectionTitle("Medical History"),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _allergiesController,
                      label: "Allergies",
                      icon: Icons.warning_amber_rounded,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _conditionsController,
                      label: "Chronic Conditions",
                      icon: Icons.monitor_heart_outlined,
                      maxLines: 2,
                    ),

                    const SizedBox(height: 30),

                    // Emergency Contact
                    _buildSectionTitle("Emergency Contact"),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _emergencyContactController,
                      label: "Phone Number",
                      icon: Icons.phone_in_talk_outlined,
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 30),

                    // Lock Screen Toggle
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF29B6F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                                Icons.screen_lock_portrait_rounded,
                                color: Color(0xFF29B6F6)),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Show on Screen",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                Text("Persistent Notification",
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _showOnLockScreen,
                            onChanged: (v) =>
                                setState(() => _showOnLockScreen = v),
                            activeColor: const Color(0xFF29B6F6),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saveData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5252),
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor: const Color(0xFFFF5252).withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Save Medical Profile",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 300.ms)
                        .slideY(begin: 0.2, end: 0),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white54),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          floatingLabelStyle: const TextStyle(color: Color(0xFFFF5252)),
        ),
      ),
    );
  }

  Widget _buildBloodGroupChip(String label) {
    final isSelected = _selectedBloodGroup == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedBloodGroup = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5252) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF5252)
                : Colors.white.withOpacity(0.1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: const Color(0xFFFF5252).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
