import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dashboard_screen.dart';
import 'interview_setup_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController nameController = TextEditingController();

  String? selectedPracticeTime;
  String? selectedLanguage;

  int currentPage = 0;
  bool loading = false;
  bool isOnline = true;
  bool showOfflineCard = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  final Color darkBlue = const Color(0xFF021B34);
  final Color deepBlue = const Color(0xFF032D52);
  final Color neonBlue = const Color(0xFF18C8FF);

  late AnimationController _bgController;
  late AnimationController _floatController;
  late Animation<double> _floatAnim;

  final List<String> practiceOptions = [
    '30 mins',
    '1 hour',
    '2 hours',
    '3+ hours',
  ];

  final List<String> languageOptions = [
    'English',
    'Hindi',
    'Marathi',
    'Hinglish',
    'Tamil',
    'Telugu',
    'Bengali',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _initConnectivityStatus();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final nowOnline = !results.contains(ConnectivityResult.none);

      if (!mounted) return;

      setState(() {
        isOnline = nowOnline;
        showOfflineCard = !nowOnline;
      });
    });
  }

  Future<void> _initConnectivityStatus() async {
    final results = await Connectivity().checkConnectivity();
    if (!mounted) return;
    final nowOnline = !results.contains(ConnectivityResult.none);
    setState(() {
      isOnline = nowOnline;
      showOfflineCard = !nowOnline;
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _bgController.dispose();
    _floatController.dispose();
    _pageController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void nextPage() {
    if (currentPage == 0 && nameController.text.trim().isEmpty) {
      showMsg("Please enter your name");
      return;
    }

    if (currentPage == 1 && selectedPracticeTime == null) {
      showMsg("Please select practice time");
      return;
    }

    if (currentPage == 2 && selectedLanguage == null) {
      showMsg("Please select language");
      return;
    }

    if (currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      saveUserData();
    }
  }

  void showMsg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> saveUserData() async {
    try {
      setState(() => loading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showMsg("User not logged in");
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': nameController.text.trim(),
        'practiceTime': selectedPracticeTime,
        'spokenLanguage': selectedLanguage,
        'email': user.email,
        'isProfileComplete': true,
        'totalInterviews': 0,
        'averageScore': 0,
        'totalAttemptedQuestions': 0,
        'totalQuestions': 0,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      showMsg("Error: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void startInterview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InterviewSetupScreen(isDemo: false),
      ),
    );
  }

  Widget buildOptionCard({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [
                    Color(0xFF18C8FF),
                    Color(0xFF00AEEF),
                  ],
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.03),
                  ],
                ),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Colors.white.withOpacity(0.10),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: neonBlue.withOpacity(0.35),
                    blurRadius: 18,
                  )
                ]
              : [],
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: Listenable.merge([_bgController, _floatController]),
      builder: (_, __) {
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(
                      darkBlue,
                      const Color(0xFF041F3B),
                      _bgController.value,
                    )!,
                    Color.lerp(
                      deepBlue,
                      const Color(0xFF073B63),
                      _bgController.value,
                    )!,
                    Color.lerp(
                      const Color(0xFF00162B),
                      const Color(0xFF03111F),
                      _bgController.value,
                    )!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -80 + (_floatAnim.value * 0.5),
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: neonBlue.withOpacity(0.12),
                  boxShadow: [
                    BoxShadow(
                      color: neonBlue.withOpacity(0.18),
                      blurRadius: 70,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -50 - (_floatAnim.value * 0.4),
              left: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withOpacity(0.08),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.12),
                      blurRadius: 55,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(top: 110 + (_floatAnim.value * 0.5), left: 40, child: _dot()),
            Positioned(top: 210 - (_floatAnim.value * 0.5), right: 85, child: _dot()),
            Positioned(top: 300 + (_floatAnim.value * 0.6), left: 120, child: _dot()),
            Positioned(bottom: 150 - (_floatAnim.value * 0.4), right: 50, child: _dot()),
            Positioned.fill(
              child: CustomPaint(
                painter: OnboardingParticlePainter(progress: _bgController.value),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dot() {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.white, blurRadius: 10),
        ],
      ),
    );
  }

  Widget _robotCard() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (_, __) {
        return Transform.translate(
          offset: Offset(0, _floatAnim.value),
          child: Container(
            width: 130,
            height: 130,
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
                  color: neonBlue.withOpacity(0.18),
                  blurRadius: 24,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 52,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: currentPage == index ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: currentPage == index
                ? neonBlue
                : Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      width: 540,
      padding: const EdgeInsets.all(28),
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
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: neonBlue.withOpacity(0.10),
            blurRadius: 24,
          )
        ],
      ),
      child: child,
    );
  }

  Widget _premiumButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF18C8FF),
            Color(0xFF00AEEF),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: neonBlue.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : nextPage,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: loading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                currentPage == 2 ? "Finish" : "Continue",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: neonBlue),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Offline Card
                        if (showOfflineCard)
                          Container(
                            width: 540,
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFEF4444).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.wifi_off_rounded,
                                    color: Color(0xFFEF4444),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "You're Offline",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "No internet connection. Please check your network.",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final results = await Connectivity().checkConnectivity();
                                    final nowOnline = !results.contains(ConnectivityResult.none);
                                    setState(() {
                                      isOnline = nowOnline;
                                      showOfflineCard = !nowOnline;
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444).withOpacity(0.2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    "OK",
                                    style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          "Set Up Your Profile",
                          style: GoogleFonts.poppins(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Just 3 quick steps",
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _stepIndicator(),
                        const SizedBox(height: 28),
                        _robotCard(),
                        const SizedBox(height: 28),
                        _glassCard(
                          child: SizedBox(
                            height: 320,
                            child: PageView(
                              controller: _pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              onPageChanged: (value) {
                                setState(() => currentPage = value);
                              },
                              children: [
                                _buildNamePage(),
                                _buildPracticePage(),
                                _buildLanguagePage(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: 540,
                          child: Column(
                            children: [
                              _premiumButton(),
                              const SizedBox(height: 12),
                              // Start Interview Button
                              Container(
                                width: double.infinity,
                                height: 54,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF10B981),
                                      const Color(0xFF059669),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withOpacity(0.35),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: startInterview,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Start Interview",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildNamePage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            "What is your name?",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: nameController,
            cursorColor: neonBlue,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("Enter your name"),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticePage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            "How much time do you practice every day?",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 22),
          ...practiceOptions.map(
            (option) => buildOptionCard(
              text: option,
              isSelected: selectedPracticeTime == option,
              onTap: () {
                setState(() => selectedPracticeTime = option);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagePage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            "Which language do you prefer?",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 22),
          ...languageOptions.map(
            (option) => buildOptionCard(
              text: option,
              isSelected: selectedLanguage == option,
              onTap: () {
                setState(() => selectedLanguage = option);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingParticlePainter extends CustomPainter {
  final double progress;

  OnboardingParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(12);
    for (int i = 0; i < 16; i++) {
      final dx = random.nextDouble() * size.width;
      final baseDy = random.nextDouble() * size.height;
      final dy = baseDy + sin((progress * 2 * pi) + i) * 6;

      final paint = Paint()
        ..color = Colors.white.withOpacity(0.03 + (i % 4) * 0.012);

      canvas.drawCircle(Offset(dx, dy), 1.4 + (i % 3) * 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant OnboardingParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}