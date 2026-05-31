import 'dart:ui';
import 'package:flutter/material.dart';
import 'interview_screen.dart';

class InterviewSetupScreen extends StatefulWidget {
  final bool isDemo;

  const InterviewSetupScreen({super.key, required this.isDemo});

  @override
  State<InterviewSetupScreen> createState() =>
      _InterviewSetupScreenState();
}

class _InterviewSetupScreenState
    extends State<InterviewSetupScreen> {
  final roleController = TextEditingController();

  String selectedLevel = "Easy";
  bool useCamera = false;

  final Color darkBlue = const Color(0xFF021B34);
  final Color deepBlue = const Color(0xFF032D52);
  final Color cyan = const Color(0xFF18C8FF);

  @override
  void dispose() {
    roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildPremiumBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Center(
                      child: Container(
                        width: 500,
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.03),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.10),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cyan.withOpacity(0.15),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _robotCard(),
                            const SizedBox(height: 24),
                            const Text(
                              "Interview Setup",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Choose your role, difficulty level, and interview mode",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 28),
                            _input(
                              "Enter Role (Flutter Developer)",
                              roleController,
                            ),
                            const SizedBox(height: 18),
                            DropdownButtonFormField<String>(
                              dropdownColor: const Color(0xFF0D2238),
                              value: selectedLevel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              iconEnabledColor: Colors.white,
                              items: ["Easy", "Medium", "Hard"]
                                  .map(
                                    (e) => DropdownMenuItem<String>(
                                      value: e,
                                      child: Text(
                                        e,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val == null) return;
                                setState(() {
                                  selectedLevel = val;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: "Select Level",
                                labelStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.06),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: cyan),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            _cameraToggleCard(),

                            const SizedBox(height: 30),
                            _premiumButton(
                              text: "Start Interview",
                              onTap: () {
                                if (roleController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Enter role"),
                                    ),
                                  );
                                  return;
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InterviewScreen(
                                      role: roleController.text.trim(),
                                      level: selectedLevel,
                                      isDemo: widget.isDemo,
                                      useCamera: useCamera,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBackground() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                darkBlue,
                deepBlue,
                const Color(0xFF00162B),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cyan.withOpacity(0.12),
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          left: -40,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blueAccent.withOpacity(0.08),
            ),
          ),
        ),
      ],
    );
  }

  Widget _robotCard() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.03),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: cyan.withOpacity(0.15),
            blurRadius: 20,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 74,
          height: 74,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Color(0xFF12C2FF),
                Color(0xFF00AEEF),
              ],
            ),
          ),
          child: const Icon(
            Icons.smart_toy,
            color: Colors.white,
            size: 38,
          ),
        ),
      ),
    );
  }

  Widget _cameraToggleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.03),
          ],
        ),
        border: Border.all(
          color: useCamera
              ? cyan.withOpacity(0.65)
              : Colors.white.withOpacity(0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: useCamera
                ? cyan.withOpacity(0.18)
                : Colors.transparent,
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cyan.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              useCamera ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Enable Camera Analysis",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Use camera during interview for live presence and confidence tracking.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: useCamera,
            activeColor: cyan,
            onChanged: (value) {
              setState(() {
                useCamera = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _premiumButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF12C2FF),
            Color(0xFF00AEEF),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x5512C2FF),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _input(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      cursorColor: cyan,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.75),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cyan),
        ),
      ),
    );
  }
}