import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/chatbot_service.dart';
import 'interview_setup_screen.dart';
import 'leaderboard_screen.dart';
import 'landing_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  final ChatbotService _chatbotService = ChatbotService();

  final Color bg1 = const Color(0xFF020617);
  final Color bg2 = const Color(0xFF0F172A);
  final Color cyan = const Color(0xFF18C8FF);
  final Color violet = const Color(0xFF6366F1);
  final Color green = const Color(0xFF22C55E);
  final Color orange = const Color(0xFFF59E0B);

  // Voice Chatbot
  bool _isChatbotOpen = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  final FlutterTts _flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();
  String _chatbotResponse = "";
  Timer? _listeningTimer;
  final ScrollController _chatScrollController = ScrollController();
  bool _showTimeoutMessage = false;

  late AnimationController _micPulseController;
  late Animation<double> _micPulseAnim;
  late AnimationController _floatController;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _micPulseAnim = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _micPulseController, curve: Curves.easeInOut),
    );

    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _initTts();
    _initSpeech();
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

    setState(() {
      _showTimeoutMessage = false;
      _isListening = true;
      _chatbotResponse = "🎤 Listening...";
    });

    _listeningTimer?.cancel();
    _listeningTimer = Timer(const Duration(seconds: 10), () {
      if (_isListening) {
        _stopListening(timeout: true);
      }
    });

    _speechToText.listen(
      onResult: (result) {
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
        _chatbotResponse = "⏹️ Stopped listening.";
      } else if (_chatbotResponse == "🎤 Listening...") {
        _chatbotResponse = "";
      }
    });
  }

  Future<void> _processUserQuery(String query) async {
    setState(() {
      _chatbotResponse = "🤖 Thinking...";
    });

    try {
      // Use ChatbotService to get AI response
      final answer = await _chatbotService.getAIResponse(query, context: "dashboard");
      
      setState(() {
        _chatbotResponse = answer;
      });

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      // Speak the answer
      await _speakAnswer(answer);
    } catch (e) {
      setState(() {
        _chatbotResponse = "Sorry, I'm having trouble connecting. Please try again later. 😐";
      });
    }
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
        _showTimeoutMessage = false;
        _chatbotResponse = "";
      }
    });
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
              onTap: () {},
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: 450,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [bg1, bg2],
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
                            style: const TextStyle(
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
                                          const Color(0xFF60A5FA),
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
                                    child: Icon(
                                      _isSpeaking ? Icons.record_voice_over : Icons.assistant,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Hi! I'm your AI assistant",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Ask me about your dashboard or interviews",
                              style: TextStyle(
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
                                        style: TextStyle(
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
                                      style: TextStyle(
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
                      child: Center(
                        child: GestureDetector(
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

  Future<void> _deleteInterview(String docId, Map<String, dynamic> item) async {
    if (user == null) return;

    final userRef =
        FirebaseFirestore.instance.collection("users").doc(user!.uid);

    final interviewRef = userRef.collection("interview_history").doc(docId);

    final attempted = _getInt(item['attempted']);
    final total = _getInt(item['total']);
    final score = _getDouble(item['score']);

    final userDoc = await userRef.get();
    final userData = userDoc.data() ?? {};

    final oldTotalInterviews = _getInt(userData['totalInterviews']);
    final oldQuestionsAttempted = _getInt(userData['questionsAttempted']);
    final oldTotalQuestions = _getInt(userData['totalQuestions']);
    final oldAverageScore = _getDouble(userData['averageScore']);

    final newTotalInterviews =
        oldTotalInterviews > 0 ? oldTotalInterviews - 1 : 0;
    final newQuestionsAttempted =
        (oldQuestionsAttempted - attempted).clamp(0, 999999999);
    final newTotalQuestions =
        (oldTotalQuestions - total).clamp(0, 999999999);

    double newAverageScore = 0;
    if (newTotalInterviews > 0) {
      newAverageScore =
          ((oldAverageScore * oldTotalInterviews) - score) / newTotalInterviews;
      if (newAverageScore < 0) newAverageScore = 0;
    }

    final newAttemptRate = newTotalQuestions == 0
        ? 0.0
        : (newQuestionsAttempted / newTotalQuestions) * 100;

    await interviewRef.delete();

    // Get the latest interview to update lastRole and lastLevel
    String newLastRole = "No interview yet";
    String newLastLevel = "-";
    double newLastScore = 0;

    if (newTotalInterviews > 0) {
      final latestInterviewQuery = await userRef
          .collection("interview_history")
          .orderBy("createdAt", descending: true)
          .limit(1)
          .get();
      
      if (latestInterviewQuery.docs.isNotEmpty) {
        final latestData = latestInterviewQuery.docs.first.data();
        newLastRole = latestData['role'] ?? "No interview yet";
        newLastLevel = latestData['level'] ?? "-";
        newLastScore = _getDouble(latestData['score']);
      }
    }

    await userRef.set({
      "totalInterviews": newTotalInterviews,
      "questionsAttempted": newQuestionsAttempted,
      "totalQuestions": newTotalQuestions,
      "averageScore": newAverageScore,
      "attemptRate": newAttemptRate,
      "lastRole": newLastRole,
      "lastLevel": newLastLevel,
      "lastScore": newLastScore,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _micPulseController.dispose();
    _floatController.dispose();
    _listeningTimer?.cancel();
    _flutterTts.stop();
    _speechToText.stop();
    _chatScrollController.dispose();
    super.dispose();
  }

  void logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (route) => false,
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserData() {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getRecentHistory() {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .collection("interview_history")
        .orderBy("createdAt", descending: true)
        .limit(5)
        .snapshots();
  }

  int _getInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  double _getDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _drawer(),
      body: Stack(
        children: [
          _background(),
          SafeArea(
            child: user == null
                ? const Center(
                    child: Text(
                      "User not logged in",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: getUserData(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final data = snapshot.data!.data() ?? {};
                      final name = data['name'] ?? "User";
                      final interviews = _getInt(data['totalInterviews']);
                      final avgScore = _getDouble(data['averageScore']);
                      final totalQuestions = _getInt(data['totalQuestions']);
                      final attemptedQuestions =
                          _getInt(data['questionsAttempted']);
                      final lastRole = data['lastRole'] ?? "No interview yet";
                      final lastLevel = data['lastLevel'] ?? "-";

                      final attemptRate = totalQuestions == 0
                          ? 0.0
                          : (attemptedQuestions / totalQuestions) * 100;

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth > 1000;

                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _topBar(),
                                const SizedBox(height: 20),

                                const SizedBox(height: 28),

                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: _glass(),
                                  child: wide
                                      ? Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: _heroLeft(
                                                name: name,
                                                interviews: interviews,
                                                avgScore: avgScore,
                                                lastRole: lastRole,
                                                lastLevel: lastLevel,
                                              ),
                                            ),
                                            const SizedBox(width: 24),
                                            Expanded(
                                              flex: 2,
                                              child: _heroRight(
                                                avgScore: avgScore,
                                                attemptRate: attemptRate,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          children: [
                                            _heroLeft(
                                              name: name,
                                              interviews: interviews,
                                              avgScore: avgScore,
                                              lastRole: lastRole,
                                              lastLevel: lastLevel,
                                            ),
                                            const SizedBox(height: 20),
                                            _heroRight(
                                              avgScore: avgScore,
                                              attemptRate: attemptRate,
                                            ),
                                          ],
                                        ),
                                ),

                                const SizedBox(height: 28),

                                const Text(
                                  "Performance Overview",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 18),

                                GridView.count(
                                  crossAxisCount: wide ? 4 : 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: wide ? 1.2 : 1.1,
                                  children: [
                                    _statCard(
                                      title: "Total Interviews",
                                      value: "$interviews",
                                      icon: Icons.groups_rounded,
                                      color: violet,
                                    ),
                                    _statCard(
                                      title: "Average Score",
                                      value: avgScore.toStringAsFixed(1),
                                      icon: Icons.star_rounded,
                                      color: green,
                                    ),
                                    _statCard(
                                      title: "Questions Attempted",
                                      value: "$attemptedQuestions",
                                      icon: Icons.edit_note_rounded,
                                      color: cyan,
                                    ),
                                    _statCard(
                                      title: "Attempt Rate",
                                      value:
                                          "${attemptRate.toStringAsFixed(0)}%",
                                      icon: Icons.show_chart_rounded,
                                      color: orange,
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 28),

                                const Text(
                                  "Quick Actions",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 18),

                                wide
                                    ? Row(
                                        children: [
                                          Expanded(
                                            child: _quickCard(
                                              title: "Start New Interview",
                                              subtitle:
                                                  "Practice another mock interview with AI.",
                                              icon: Icons.play_circle_fill_rounded,
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const InterviewSetupScreen(
                                                      isDemo: false,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _quickCard(
                                              title: "Open Leaderboard",
                                              subtitle:
                                                  "See rank, top users, and compare your score.",
                                              icon: Icons.emoji_events_rounded,
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const LeaderboardScreen(),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          _quickCard(
                                            title: "Start New Interview",
                                            subtitle:
                                                "Practice another mock interview with AI.",
                                            icon: Icons.play_circle_fill_rounded,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const InterviewSetupScreen(
                                                    isDemo: false,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          _quickCard(
                                            title: "Open Leaderboard",
                                            subtitle:
                                                "See rank, top users, and compare your score.",
                                            icon: Icons.emoji_events_rounded,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const LeaderboardScreen(),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),

                                const SizedBox(height: 28),

                                const Text(
                                  "Recent Interviews",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 18),

                                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                  stream: getRecentHistory(),
                                  builder: (context, historySnapshot) {
                                    if (!historySnapshot.hasData) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }

                                    final docs = historySnapshot.data!.docs;

                                    if (docs.isEmpty) {
                                      return Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(20),
                                        decoration: _glass(),
                                        child: const Text(
                                          "No interview history yet.",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 15,
                                          ),
                                        ),
                                      );
                                    }

                                    return Column(
                                      children: docs.map((doc) {
                                        final item = doc.data();
                                        final role = item['role'] ?? 'Unknown';
                                        final level = item['level'] ?? '-';
                                        final attempted =
                                            _getInt(item['attempted']);
                                        final total = _getInt(item['total']);
                                        final score =
                                            _getDouble(item['score']);

                                        return Container(
                                          width: double.infinity,
                                          margin:
                                              const EdgeInsets.only(bottom: 14),
                                          padding: const EdgeInsets.all(18),
                                          decoration: _glass(),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 52,
                                                height: 52,
                                                decoration: BoxDecoration(
                                                  color: cyan.withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                child: const Icon(
                                                  Icons.history_rounded,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      role,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      "Level: $level  •  Attempted: $attempted / $total",
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    "${score.toStringAsFixed(1)} / 10",
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  IconButton(
                                                    onPressed: () async {
                                                      final confirm =
                                                          await showDialog<bool>(
                                                        context: context,
                                                        builder: (_) =>
                                                            AlertDialog(
                                                          title: const Text(
                                                            "Delete Interview",
                                                          ),
                                                          content: const Text(
                                                            "Are you sure you want to delete this interview record?",
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                context,
                                                                false,
                                                              ),
                                                              child: const Text(
                                                                "Cancel",
                                                              ),
                                                            ),
                                                            ElevatedButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                context,
                                                                true,
                                                              ),
                                                              child: const Text(
                                                                "Delete",
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );

                                                      if (confirm == true) {
                                                        await _deleteInterview(
                                                          doc.id,
                                                          item,
                                                        );
                                                      }
                                                    },
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.redAccent,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          if (_isChatbotOpen) _buildChatbotOverlay(),
        ],
      ),
    );
  }

  Widget _heroLeft({
    required String name,
    required int interviews,
    required double avgScore,
    required String lastRole,
    required String lastLevel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Welcome back, $name 👋",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Practice smarter, track performance, and level up your interview .",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _pill("Interviews: $interviews"),
            _pill("Avg Score: ${avgScore.toStringAsFixed(1)}"),
            _pill("Last: $lastRole"),
            _pill("Level: $lastLevel"),
          ],
        ),
        const SizedBox(height: 22),
        _premiumButton(
          text: "Start Interview",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const InterviewSetupScreen(isDemo: false),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _heroRight({
    required double avgScore,
    required double attemptRate,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.insights_rounded,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 14),
          Text(
            avgScore.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Average Score",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: attemptRate / 100,
              minHeight: 10,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(cyan),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Attempt Rate: ${attemptRate.toStringAsFixed(0)}%",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _background() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bg1, bg2, bg1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -70,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cyan.withOpacity(0.10),
            ),
          ),
        ),
        Positioned(
          bottom: -60,
          left: -40,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: violet.withOpacity(0.10),
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _glass() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.08),
          Colors.white.withOpacity(0.03),
        ],
      ),
      border: Border.all(
        color: Colors.white.withOpacity(0.10),
      ),
      boxShadow: [
        BoxShadow(
          color: cyan.withOpacity(0.10),
          blurRadius: 20,
        ),
      ],
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        const Spacer(),
        // Voice Chatbot Button
        GestureDetector(
          onTap: _toggleChatbot,
          child: Container(
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
                const Icon(Icons.smart_toy, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  "AI Voice",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }

  Widget _premiumButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 240,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cyan, const Color(0xFF00AEEF)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x5518C8FF),
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

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _glass(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _glass(),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: cyan.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: onTap,
            icon: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Drawer _drawer() {
    return Drawer(
      backgroundColor: const Color(0xFF071A2C),
      child: Column(
        children: [
          const SizedBox(height: 80),
          const ListTile(
            leading: Icon(Icons.dashboard, color: Colors.white),
            title: Text(
              "Dashboard",
              style: TextStyle(color: Colors.white),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.play_circle_fill, color: Colors.white),
            title: const Text(
              "Start Interview",
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InterviewSetupScreen(isDemo: false),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.emoji_events, color: Colors.white),
            title: const Text(
              "Leaderboard",
              style: TextStyle(color: Colors.white),
            ),
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
            leading: const Icon(Icons.smart_toy, color: Colors.white),
            title: const Text(
              "AI Voice Assistant",
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              _toggleChatbot();
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text(
              "Logout",
              style: TextStyle(color: Colors.white),
            ),
            onTap: logout,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}