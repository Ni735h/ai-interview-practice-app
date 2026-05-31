import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'interview_setup_screen.dart';
import 'leaderboard_screen.dart';
import 'about_screen.dart';
import 'dashboard_screen.dart';
import 'onboarding_screen.dart';

class LandingScreen extends StatefulWidget {
  final bool openLogin;

  const LandingScreen({super.key, this.openLogin = false});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  bool showAuthCard = false;
  bool isLogin = true;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool isOnline = true;

  bool _hasShownOfflineDialog = false;
  bool _hasShownOnlineDialog = false;
  bool _isStatusDialogOpen = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Voice Chatbot (will be moved to Onboarding)
  bool _isChatbotOpen = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  final FlutterTts _flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();
  String _chatbotResponse = "";
  Timer? _listeningTimer;
  final ScrollController _chatScrollController = ScrollController();
  bool _showTimeoutMessage = false; // For timeout message

  // Chatbot questions and answers
  final List<Map<String, String>> _chatbotKnowledge = [
    {"question": "what is this app", "answer": "This is an AI Mock Interview app that helps you practice for job interviews with smart questions, live practice, and instant feedback."},
    {"question": "how to practice", "answer": "Click on 'Start Practice', choose your role and difficulty level, then answer questions using voice or text."},
    {"question": "features", "answer": "Our app features AI-generated questions, voice recognition, face monitoring, instant feedback, leaderboard, and detailed scorecards."},
    {"question": "free", "answer": "Yes, the basic version is completely free! You can practice unlimited interviews."},
    {"question": "leaderboard", "answer": "The leaderboard shows top performers based on their average interview scores."},
    {"question": "camera", "answer": "Camera feature helps analyze your facial expressions and eye contact during interviews. You can enable it in settings."},
    {"question": "score", "answer": "Scores are calculated based on answer relevance, completeness, and delivery. Score ranges from 0 to 10."},
    {"question": "hello", "answer": "Hello! 👋 I'm your AI assistant. How can I help you today?"},
    {"question": "hi", "answer": "Hi there! 👋 Ready to ace your interviews? Ask me anything about the app!"},
    {"question": "help", "answer": "I can help you with: How to practice, App features, Scoring system, Leaderboard, Camera usage. Just ask!"},
    {"question": "thank", "answer": "You're welcome! 😊 Happy practicing! Keep improving every day."},
    {"question": "bye", "answer": "Goodbye! 👋 Come back anytime to practice. Best of luck with your interviews!"},
  ];

  final Color darkBlue = const Color(0xFF021B34);
  final Color deepBlue = const Color(0xFF032D52);
  final Color cyan = const Color(0xFF18C8FF);
  final Color softBlue = const Color(0xFF60A5FA);
  final Color neon = const Color(0xFF8EF3FF);

  late AnimationController _bgController;
  late AnimationController _floatController;
  late AnimationController _glowController;
  late AnimationController _micPulseController;
  late Animation<double> _floatAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _micPulseAnim;

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

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _glowAnim = Tween<double>(begin: 0.18, end: 0.32).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _micPulseAnim = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _micPulseController, curve: Curves.easeInOut),
    );

    _initConnectivityStatus();
    _initTts();
    _initSpeech();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final nowOnline = !results.contains(ConnectivityResult.none);

      if (!mounted) return;

      if (!nowOnline && isOnline) {
        if (!_hasShownOfflineDialog && !_isStatusDialogOpen) {
          _showStatusDialog(
            title: "You're Offline",
            message:
                "No internet connection detected.\nSome AI features may not work right now.",
            isOnlineStatus: false,
          );
          _hasShownOfflineDialog = true;
          _hasShownOnlineDialog = false;
        }
      }

      if (nowOnline && !isOnline) {
        if (!_hasShownOnlineDialog && !_isStatusDialogOpen) {
          _showStatusDialog(
            title: "You're Back Online",
            message: "Connection restored.\nAll AI features are ready again.",
            isOnlineStatus: true,
          );
          _hasShownOnlineDialog = true;
          _hasShownOfflineDialog = false;
        }
      }

      setState(() {
        isOnline = nowOnline;
      });
    });

    if (widget.openLogin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            showAuthCard = true;
            isLogin = true;
          });
        }
      });
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.0);
    
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    });
  }

  Future<void> _initSpeech() async {
    await _speechToText.initialize();
  }

  void _startListening() async {
    bool available = await _speechToText.initialize();
    if (!available) return;

    // Reset timeout message
    setState(() {
      _showTimeoutMessage = false;
      _isListening = true;
      _chatbotResponse = "🎤 Listening...";
    });

    // Auto-stop after 10 seconds if no speech detected
    _listeningTimer?.cancel();
    _listeningTimer = Timer(const Duration(seconds: 10), () {
      if (_isListening) {
        _stopListening(timeout: true);
      }
    });

    _speechToText.listen(
      onResult: (result) {
        // Reset timer when speech is detected
        if (result.finalResult || result.recognizedWords.isNotEmpty) {
          _listeningTimer?.cancel();
          _listeningTimer = Timer(const Duration(seconds: 10), () {
            if (_isListening) {
              _stopListening(timeout: true);
            }
          });
        }
        
        if (result.finalResult) {
          _processUserQuery(result.recognizedWords);
          _stopListening();
        }
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  void _stopListening({bool timeout = false}) {
    _listeningTimer?.cancel();
    _speechToText.stop();
    setState(() {
      _isListening = false;
      if (timeout && _chatbotResponse == "🎤 Listening...") {
        _showTimeoutMessage = true;
        _chatbotResponse = "⏹️ Stopped listening. Tap anywhere to resume.";
        // Auto-clear timeout message after tap
      } else if (_chatbotResponse == "🎤 Listening...") {
        _chatbotResponse = "";
      }
    });
  }

  void _processUserQuery(String query) {
    setState(() {
      _chatbotResponse = "🤖 Thinking...";
    });

    String answer = _findBestAnswer(query);
    
    setState(() {
      _chatbotResponse = answer;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    _speakAnswer(answer);
  }

  String _findBestAnswer(String query) {
    final lowerQuery = query.toLowerCase().trim();
    
    MapEntry<String, String>? bestMatch;
    int bestScore = 0;
    
    for (var entry in _chatbotKnowledge) {
      int score = 0;
      final questionWords = entry["question"]!.toLowerCase().split(' ');
      
      for (var word in questionWords) {
        if (lowerQuery.contains(word) && word.length > 2) {
          score++;
        }
      }
      
      if (score > bestScore) {
        bestScore = score;
        bestMatch = MapEntry(entry["question"]!, entry["answer"]!);
      }
    }
    
    if (bestScore >= 1 && bestMatch != null) {
      return bestMatch.value;
    }
    
    return "I'm not sure about that. Try asking about: practice, features, score, leaderboard, camera, or help. 🎯";
  }

  Future<void> _speakAnswer(String answer) async {
    setState(() => _isSpeaking = true);
    await _flutterTts.speak(answer);
  }

  void _clearResponseOnTap() {
    if (_showTimeoutMessage) {
      setState(() {
        _showTimeoutMessage = false;
        _chatbotResponse = "";
      });
    }
  }

  void _toggleChatbot() {
    setState(() {
      _isChatbotOpen = !_isChatbotOpen;
      if (!_isChatbotOpen) {
        _stopListening();
        _flutterTts.stop();
        setState(() {
          _isSpeaking = false;
          _showTimeoutMessage = false;
          _chatbotResponse = "";
        });
      } else {
        // Reset when opening
        _showTimeoutMessage = false;
        _chatbotResponse = "";
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    emailController.dispose();
    passwordController.dispose();
    _bgController.dispose();
    _floatController.dispose();
    _glowController.dispose();
    _micPulseController.dispose();
    _listeningTimer?.cancel();
    _flutterTts.stop();
    _speechToText.stop();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _initConnectivityStatus() async {
    final results = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() {
      isOnline = !results.contains(ConnectivityResult.none);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      drawer: _buildDrawer(user),
      body: Stack(
        children: [
          _buildPremiumBackground(),
          _buildMainContent(user),
          if (showAuthCard) _buildAuthOverlay(),
          if (_isChatbotOpen) _buildChatbotOverlay(),
        ],
      ),
    );
  }

  Widget _buildChatbotOverlay() {
    return GestureDetector(
      onTap: () {
        _clearResponseOnTap();
        _toggleChatbot();
      },
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping inside
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: 450,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [darkBlue, deepBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: cyan.withOpacity(0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: cyan.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: cyan.withOpacity(0.2)),
                        ),
                      ),
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _floatController,
                            builder: (_, __) {
                              return Transform.translate(
                                offset: Offset(0, _floatAnim.value * 0.3),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF18C8FF), Color(0xFF60A5FA)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.smart_toy,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "AI Voice Assistant",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: _toggleChatbot,
                          ),
                        ],
                      ),
                    ),
                    // Chatbot Response Area
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _chatScrollController,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            AnimatedBuilder(
                              animation: _micPulseController,
                              builder: (_, __) {
                                return Transform.scale(
                                  scale: _isListening ? _micPulseAnim.value : 1.0,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          cyan,
                                          softBlue,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: cyan.withOpacity(_isListening ? 0.6 : 0.3),
                                          blurRadius: _isListening ? 20 : 10,
                                          spreadRadius: _isListening ? 4 : 2,
                                        ),
                                      ],
                                    ),
                                    child: AnimatedBuilder(
                                      animation: _floatController,
                                      builder: (_, __) {
                                        return Transform.rotate(
                                          angle: _isListening ? sin(DateTime.now().millisecondsSinceEpoch / 200) * 0.2 : 0,
                                          child: Icon(
                                            _isSpeaking ? Icons.record_voice_over : Icons.assistant,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Hi! I'm your AI assistant",
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Ask me anything about interviews",
                              style: GoogleFonts.poppins(
                                color: cyan,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_chatbotResponse.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: cyan.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      _chatbotResponse.contains("🎤") ? Icons.mic : 
                                      (_chatbotResponse.contains("🤖") ? Icons.smart_toy : 
                                      (_chatbotResponse.contains("⏹️") ? Icons.stop : Icons.message)),
                                      color: _chatbotResponse.contains("⏹️") ? Colors.orangeAccent : cyan,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _chatbotResponse,
                                        style: GoogleFonts.poppins(
                                          color: _chatbotResponse.contains("⏹️") ? Colors.orangeAccent : Colors.white,
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_isListening)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ...[0, 1, 2].map((index) {
                                      return AnimatedBuilder(
                                        animation: _micPulseController,
                                        builder: (_, __) {
                                          return Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 3),
                                            width: 6 + (index * 2),
                                            height: 10 + (sin(DateTime.now().millisecondsSinceEpoch / 200 + index) * 5 + 10),
                                            decoration: BoxDecoration(
                                              color: cyan,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                          );
                                        },
                                      );
                                    }),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Listening...",
                                      style: GoogleFonts.poppins(
                                        color: cyan,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Microphone Button
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: cyan.withOpacity(0.2)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Tap anywhere to close • ",
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                          GestureDetector(
                            onTap: _isListening ? () => _stopListening() : _startListening,
                            child: AnimatedBuilder(
                              animation: _micPulseController,
                              builder: (_, __) {
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isListening ? Colors.redAccent : cyan,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isListening ? Colors.redAccent : cyan).withOpacity(0.5),
                                        blurRadius: _isListening ? 20 : 12,
                                        spreadRadius: _isListening ? 4 : 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _isListening ? Icons.mic : Icons.mic_none,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumBackground() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _bgController,
        _floatController,
        _glowController,
      ]),
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
              top: -90 + (_floatAnim.value * 0.5),
              right: -70,
              child: _animatedBlurOrb(
                size: 240,
                color: cyan.withOpacity(_glowAnim.value),
              ),
            ),
            Positioned(
              bottom: -70 - (_floatAnim.value * 0.4),
              left: -45,
              child: _animatedBlurOrb(
                size: 190,
                color: softBlue.withOpacity(0.12),
              ),
            ),
            Positioned(
              top: 120 + _floatAnim.value,
              left: 24,
              child: _animatedBlurOrb(
                size: 90,
                color: neon.withOpacity(0.08),
              ),
            ),
            Positioned(
              top: 220 - _floatAnim.value,
              right: 50,
              child: _animatedBlurOrb(
                size: 110,
                color: cyan.withOpacity(0.08),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: UltraLinePainter(progress: _bgController.value),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: ParticlePainter(progress: _floatController.value),
                ),
              ),
            ),
            Positioned(
              top: 120 + (_floatAnim.value * 0.5),
              left: 40,
              child: _glowDot(),
            ),
            Positioned(
              top: 210 - (_floatAnim.value * 0.4),
              right: 90,
              child: _glowDot(),
            ),
            Positioned(
              top: 310 + (_floatAnim.value * 0.7),
              left: 120,
              child: _glowDot(),
            ),
            Positioned(
              bottom: 180 - (_floatAnim.value * 0.5),
              right: 50,
              child: _glowDot(),
            ),
          ],
        );
      },
    );
  }

  Widget _animatedBlurOrb({
    required double size,
    required Color color,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.55),
            blurRadius: 80,
            spreadRadius: 8,
          ),
        ],
      ),
    );
  }

  Widget _glowDot() {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white70,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Colors.white54,
            blurRadius: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(User? user) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 36,
              ),
              child: user != null
                  ? _buildLoggedInContent(user)
                  : _buildGuestContent(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoggedInContent(User user) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        final totalInterviews = data['totalInterviews'] ?? 0;
        final averageScore = ((data['averageScore'] ?? 0) as num).toDouble();

        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildTopBar(),
            Column(
              children: [
                const SizedBox(height: 22),
                _buildHeroText(),
                const SizedBox(height: 22),
                _buildAiBotCard(),
                const SizedBox(height: 24),
                _buildMiniInsightRow(
                  totalInterviews: totalInterviews,
                  averageScore: averageScore,
                ),
                const SizedBox(height: 28),
                _premiumButton(
                  text: "Start Practice",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const InterviewSetupScreen(isDemo: false),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _premiumOutlineButton(
                  text: "Go to Dashboard",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DashboardScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildGuestContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildTopBar(),
        Column(
          children: [
            const SizedBox(height: 22),
            _buildHeroText(),
            const SizedBox(height: 22),
            _buildAiBotCard(),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Boost your confidence with AI mock interviews.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 30),
            _premiumButton(
              text: "Start Practice",
              onTap: () {
                setState(() {
                  showAuthCard = true;
                  isLogin = true;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        const Spacer(),
        // Voice Chatbot Button REMOVED from here
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: cyan.withOpacity(0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cyan.withOpacity(0.30)),
            boxShadow: [
              BoxShadow(
                color: cyan.withOpacity(0.10),
                blurRadius: 20,
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isOnline
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isOnline
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444))
                          .withOpacity(0.45),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isOnline ? "AI Ready" : "Offline",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroText() {
    return Column(
      children: [
        DefaultTextStyle(
          style: GoogleFonts.poppins(
            fontSize: 38,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.2,
            height: 1.15,
          ),
          textAlign: TextAlign.center,
          child: AnimatedTextKit(
            repeatForever: true,
            pause: const Duration(milliseconds: 1200),
            animatedTexts: [
              TyperAnimatedText(
                "AI MOCK INTERVIEW",
                speed: const Duration(milliseconds: 80),
              ),
              TyperAnimatedText(
                "PRACTICE LIKE A PRO",
                speed: const Duration(milliseconds: 80),
              ),
              TyperAnimatedText(
                "CRACK YOUR DREAM JOB",
                speed: const Duration(milliseconds: 80),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 24,
          child: DefaultTextStyle(
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
            child: AnimatedTextKit(
              repeatForever: true,
              pause: const Duration(milliseconds: 1000),
              animatedTexts: [
                FadeAnimatedText(
                  "Smart questions • live practice • instant feedback",
                ),
                FadeAnimatedText(
                  "Designed to improve confidence and performance",
                ),
                FadeAnimatedText(
                  "A premium AI interview experience on your device",
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniInsightRow({
    required int totalInterviews,
    required double averageScore,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _infoChip(
          title: "Interviews",
          value: "$totalInterviews",
          icon: Icons.play_circle_outline_rounded,
        ),
        _infoChip(
          title: "Avg Score",
          value: "${averageScore.toStringAsFixed(1)} / 10",
          icon: Icons.auto_graph_rounded,
        ),
      ],
    );
  }

  Widget _infoChip({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: cyan, size: 19),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 11.5,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiBotCard() {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatController, _glowController]),
      builder: (_, __) {
        return Transform.translate(
          offset: Offset(0, _floatAnim.value),
          child: Container(
            width: 225,
            height: 225,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.09),
                  Colors.white.withOpacity(0.03),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
              boxShadow: [
                BoxShadow(
                  color: cyan.withOpacity(0.16 + (_glowAnim.value * 0.25)),
                  blurRadius: 34,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 18,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: cyan.withOpacity(0.20),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  top: 34,
                  child: Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 98,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 14),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 70,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF17202A),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _eye(),
                              _eye(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: 78,
                      height: 82,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFA7D8FF),
                            Color(0xFF68B8FF),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _eye() {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: neon,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF8EF3FF),
            blurRadius: 12,
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
      width: 250,
      height: 58,
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
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _premiumOutlineButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 250,
      height: 58,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: cyan.withOpacity(0.7)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: Colors.white.withOpacity(0.02),
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildAuthOverlay() {
    return GestureDetector(
      onTap: () => setState(() => showAuthCard = false),
      child: Container(
        color: Colors.black.withOpacity(0.45),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 360,
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2238).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: cyan.withOpacity(0.12),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLogin ? "Login" : "Create Account",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: cyan,
                      decoration: _fieldDecoration("Email"),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: cyan,
                      decoration: _fieldDecoration("Password"),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cyan,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: loading ? null : _handleAuth,
                        child: loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                isLogin ? "Login" : "Sign Up",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          isLogin = !isLogin;
                        });
                      },
                      child: Text(
                        isLogin
                            ? "Don't have an account? Create Account"
                            : "Already have an account? Login",
                        style: GoogleFonts.poppins(
                          color: cyan,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cyan),
      ),
    );
  }

  Drawer _buildDrawer(User? user) {
    return Drawer(
      backgroundColor: const Color(0xFF071A2C),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF18C8FF), Color(0xFF60A5FA)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.smart_toy,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "AI Voice Assistant",
                  style: GoogleFonts.poppins(
                    color: cyan,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "Tap mic to ask questions",
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12),
          ListTile(
            leading: const Icon(Icons.home, color: Colors.white),
            title: const Text("Home", style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.leaderboard, color: Colors.white),
            title: const Text("Leaderboard", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LeaderboardScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.white),
            title: const Text("About Us", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AboutScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent, color: Colors.white),
            title: const Text("AI Voice Assistant", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _toggleChatbot();
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: Text(
              user == null ? "Login" : "Logout",
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () async {
              Navigator.pop(context);

              if (user == null) {
                setState(() {
                  showAuthCard = true;
                  isLogin = true;
                });
              } else {
                await FirebaseAuth.instance.signOut();
                setState(() {});
              }
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Future<void> _showStatusDialog({
    required String title,
    required String message,
    required bool isOnlineStatus,
  }) async {
    if (_isStatusDialogOpen || !mounted) return;

    _isStatusDialogOpen = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                color: (isOnlineStatus
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444))
                    .withOpacity(0.25),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isOnlineStatus
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444))
                      .withOpacity(0.16),
                ),
                child: Icon(
                  isOnlineStatus
                      ? Icons.wifi_rounded
                      : Icons.wifi_off_rounded,
                  color: isOnlineStatus
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  size: 40,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOnlineStatus
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    "OK",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    _isStatusDialogOpen = false;
  }

  Future<void> _showErrorDialog({
    required String title,
    required String message,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEF4444).withOpacity(0.16),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 42,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    "OK",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAuthSuccessDialog({
    required String title,
    required String message,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withOpacity(0.16),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 42,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    "CONTINUE",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAuth() async {
    if (emailController.text.trim().isEmpty) {
      await _showErrorDialog(
        title: "Email Required",
        message: "Please enter your email address to continue.",
      );
      return;
    }

    if (passwordController.text.trim().isEmpty) {
      await _showErrorDialog(
        title: "Password Required",
        message: "Please enter your password to continue.",
      );
      return;
    }

    try {
      setState(() => loading = true);

      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      } else {
        final credentials =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        final user = credentials.user;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            "name": emailController.text.trim().split('@').first,
            "email": emailController.text.trim().toLowerCase(),
            "averageScore": 0,
            "totalInterviews": 0,
            "questionsAttempted": 0,
            "totalQuestions": 0,
            "attemptRate": 0,
            "lastScore": 0,
            "lastRole": "No role yet",
            "lastLevel": "-",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      setState(() {
        showAuthCard = false;
      });

      await _showAuthSuccessDialog(
        title: isLogin ? "Login Successful" : "Account Created",
        message: isLogin
            ? "Welcome back. Your interview workspace is ready."
            : "Your account has been created successfully.",
      );

      if (!mounted) return;

      if (doc.exists && doc.data()?['isProfileComplete'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const DashboardScreen(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const OnboardingScreen(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorTitle = "Authentication Error";
      String errorMessage = "Something went wrong. Please try again.";

      switch (e.code) {
        case 'invalid-email':
          errorTitle = "Invalid Email Address";
          errorMessage = "The email address you entered is not valid.\nPlease check and try again.";
          break;
        case 'user-not-found':
          errorTitle = "Account Not Found";
          errorMessage = "No account exists with this email address.\nPlease sign up first.";
          break;
        case 'wrong-password':
          errorTitle = "Incorrect Password";
          errorMessage = "The password you entered is incorrect.\nPlease try again or reset your password.";
          break;
        case 'email-already-in-use':
          errorTitle = "Email Already Registered";
          errorMessage = "An account already exists with this email address.\nPlease login instead.";
          break;
        case 'weak-password':
          errorTitle = "Weak Password";
          errorMessage = "Your password is too weak.\nPlease use at least 6 characters.";
          break;
        case 'too-many-requests':
          errorTitle = "Too Many Attempts";
          errorMessage = "Too many failed login attempts.\nPlease try again later.";
          break;
        case 'network-request-failed':
          errorTitle = "Network Error";
          errorMessage = "Please check your internet connection and try again.";
          break;
        case 'user-disabled':
          errorTitle = "Account Disabled";
          errorMessage = "This account has been disabled.\nPlease contact support.";
          break;
        default:
          errorTitle = "Login Failed";
          errorMessage = e.message ?? "An unknown error occurred.\nPlease try again.";
      }

      if (!mounted) return;
      await _showErrorDialog(
        title: errorTitle,
        message: errorMessage,
      );
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(
        title: "Login Failed",
        message: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }
}

class UltraLinePainter extends CustomPainter {
  final double progress;

  UltraLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05 + (0.03 * progress))
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(size.width * 0.72, 0),
      Offset(size.width, size.height * 0.16),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.10, size.height * 0.86),
      Offset(size.width * 0.22, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.78, size.height * 0.18),
      Offset(size.width * 0.88, size.height * 0.28),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.88, size.height * 0.28),
      Offset(size.width * 0.80, size.height * 0.38),
      paint,
    );

    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF18C8FF).withOpacity(0.0),
          const Color(0xFF18C8FF).withOpacity(0.22),
          const Color(0xFF18C8FF).withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..strokeWidth = 1.5;

    final y = size.height * (0.20 + (0.55 * progress));
    canvas.drawLine(
      Offset(size.width * 0.10, y),
      Offset(size.width * 0.90, y + 16),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant UltraLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class ParticlePainter extends CustomPainter {
  final double progress;

  ParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(7);
    for (int i = 0; i < 18; i++) {
      final dx = random.nextDouble() * size.width;
      final baseDy = random.nextDouble() * size.height;
      final dy = baseDy + sin((progress * 2 * pi) + i) * 8;

      final paint = Paint()
        ..color = Colors.white.withOpacity(0.03 + (i % 4) * 0.015);

      canvas.drawCircle(Offset(dx, dy), 1.5 + (i % 3) * 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}