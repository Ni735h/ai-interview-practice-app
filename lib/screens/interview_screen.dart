import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../services/face_monitor_service.dart';
import 'interview_setup_screen.dart';
import 'landing_screen.dart';

class InterviewScreen extends StatefulWidget {
  final String role;
  final String level;
  final bool isDemo;
  final bool useCamera;

  const InterviewScreen({
    super.key,
    required this.role,
    required this.level,
    required this.isDemo,
    required this.useCamera,
  });

  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final AIService aiService = AIService();
  final FirestoreService firestoreService = FirestoreService();
  final FaceMonitorService faceMonitorService = FaceMonitorService();
  final FlutterTts flutterTts = FlutterTts();
  final SpeechToText speech = SpeechToText();

  late AnimationController _controller;

  CameraController? _cameraController;
  bool cameraReady = false;
  bool cameraPermissionDenied = false;
  bool faceMonitoringStarted = false;

  FaceFrameStatus faceStatus = FaceFrameStatus.initial();

  List<String> questions = [];
  List<String> userAnswers = [];

  int currentIndex = 0;
  bool loading = true;
  bool savingResult = false;
  bool isSpeaking = false;
  bool isListening = false;
  bool _isWarningShowing = false;
  int _appSwitchCount = 0;
  bool _tipShown = false;
  
  // Theme toggle
  bool _isLightBlueTheme = false;

  String userAnswer = "";
  final TextEditingController answerController = TextEditingController();

  Timer? _answerTimer;
  int currentAnswerSeconds = 0;
  DateTime? lastSpeechUpdateTime;

  List<int> answerDurations = [];
  List<String> evaluationFeedback = [];

  final String _quickTip = "💡 Tip: Speak clearly and take your time. Use specific examples from your experience!";

  bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;

  // Theme colors
  Color get backgroundColor => _isLightBlueTheme ? const Color(0xFFF0F4F8) : const Color(0xFF0F172A);
  Color get cardColor => _isLightBlueTheme ? Colors.white : const Color(0xFF1F2937);
  Color get textColor => _isLightBlueTheme ? const Color(0xFF1A2B4C) : Colors.white;
  Color get textSecondaryColor => _isLightBlueTheme ? const Color(0xFF5A6E8A) : Colors.white70;
  Color get borderColor => _isLightBlueTheme ? const Color(0xFFB8D3F0) : Colors.white12;
  Color get appBarColor => _isLightBlueTheme ? const Color(0xFFE8F0FE) : const Color(0xFF0F172A);
  
  Color get repeatButtonColor => _isLightBlueTheme ? const Color(0xFFE2E8F0) : const Color(0xFF374151);
  Color get speakButtonColor => _isLightBlueTheme ? const Color(0xFF4A90E2) : const Color(0xFF6366F1);
  Color get clearButtonColor => _isLightBlueTheme ? const Color(0xFFF5A623) : const Color(0xFFF59E0B);
  Color get nextButtonColor => _isLightBlueTheme ? const Color(0xFF2E7D64) : const Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      lowerBound: 0.95,
      upperBound: 1.05,
    )..repeat(reverse: true);

    flutterTts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() => isSpeaking = false);
    });

    flutterTts.setErrorHandler((message) {
      if (!mounted) return;
      setState(() => isSpeaking = false);
    });

    _startSetup();
  }

  void _toggleTheme() {
    setState(() {
      _isLightBlueTheme = !_isLightBlueTheme;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      _handleAppSwitch();
    } else if (state == AppLifecycleState.resumed) {
      if (_isWarningShowing) {
        _isWarningShowing = false;
      }
    }
  }

  Future<void> _handleAppSwitch() async {
    if (_isWarningShowing) return;
    
    _appSwitchCount++;
    
    if (isSpeaking) {
      await flutterTts.stop();
      setState(() => isSpeaking = false);
    }
    
    if (isListening) {
      stopListening();
    }
    
    _isWarningShowing = true;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orangeAccent,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "⚠️ Warning!",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Do not switch apps during the interview!\nThis is considered as cheating attempt.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textSecondaryColor,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Attempt $_appSwitchCount / 3",
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _appSwitchCount >= 3 
                              ? "Interview will be terminated after 3 attempts!"
                              : "${3 - _appSwitchCount} attempts remaining before interview is cancelled.",
                          style: TextStyle(
                            color: textSecondaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _isWarningShowing = false;
                            
                            if (_appSwitchCount >= 3) {
                              _terminateInterviewForCheating();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: repeatButtonColor,
                            foregroundColor: textColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Continue",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _terminateInterviewForCheating() async {
    if (isListening) stopListening();
    await flutterTts.stop();
    speech.stop();
    _answerTimer?.cancel();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.gavel,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Interview Terminated!",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "You have switched apps multiple times.\nThis violates the interview rules.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LandingScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Go to Home",
                    style: TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startSetup() async {
    await _initCamera();
    await loadQuestions();
  }

  Future<void> _initCamera() async {
    if (!widget.useCamera) return;

    try {
      final status = await Permission.camera.request();

      if (!status.isGranted) {
        if (!mounted) return;
        setState(() {
          cameraReady = false;
          cameraPermissionDenied = true;
        });
        return;
      }

      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          cameraReady = false;
          cameraPermissionDenied = false;
        });
        return;
      }

      CameraDescription selectedCamera = cameras.first;

      for (final cam in cameras) {
        if (cam.lensDirection == CameraLensDirection.front) {
          selectedCamera = cam;
          break;
        }
      }

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      if (!mounted) return;
      setState(() {
        cameraReady = true;
        cameraPermissionDenied = false;
      });

      await _startFaceMonitoring();
    } catch (e) {
      debugPrint("Camera init error: $e");
      if (!mounted) return;
      setState(() {
        cameraReady = false;
        cameraPermissionDenied = false;
      });
    }
  }

  Future<void> _startFaceMonitoring() async {
    if (!widget.useCamera) return;
    if (_cameraController == null) return;
    if (!_cameraController!.value.isInitialized) return;
    if (faceMonitoringStarted) return;

    try {
      await _cameraController!.startImageStream((CameraImage image) async {
        final status = await faceMonitorService.processCameraImage(
          image,
          _cameraController!.description,
        );

        if (status != null && mounted) {
          setState(() {
            faceStatus = status;
          });
        }
      });

      faceMonitoringStarted = true;
    } catch (e) {
      debugPrint("Face monitoring start error: $e");
    }
  }

  Future<void> loadQuestions() async {
    try {
      final data = await aiService.getQuestions(
        role: widget.role,
        level: widget.level,
        isDemo: widget.isDemo,
      );

      final finalQuestions = data.take(10).toList();

      if (!mounted) return;

      setState(() {
        questions = finalQuestions;
        userAnswers = List.filled(finalQuestions.length, "");
        answerDurations = List.filled(finalQuestions.length, 0);
        evaluationFeedback = List.filled(finalQuestions.length, "");
        loading = false;
      });

      if (questions.isNotEmpty) {
        await speak(questions[0]);
      }
    } catch (e) {
      debugPrint("Question load error: $e");

      if (!mounted) return;

      final fallbackQuestions = widget.isDemo
          ? [
              "Tell me about yourself.",
              "Why do you want this role?",
              "What are your strengths?",
              "What is your biggest weakness?",
              "What are the main responsibilities of this role?",
            ]
          : [
              "Tell me about yourself.",
              "Why do you want this role?",
              "What are your strengths?",
              "What is your biggest weakness?",
              "What are the main responsibilities of this role?",
              "What skills are important for this position?",
              "What tools or technologies are commonly used in this field?",
              "What challenges can arise in this role?",
              "How would you solve a real-world problem in this role?",
              "What makes someone successful in this position?",
            ];

      setState(() {
        questions = fallbackQuestions;
        userAnswers = List.filled(fallbackQuestions.length, "");
        answerDurations = List.filled(fallbackQuestions.length, 0);
        evaluationFeedback = List.filled(fallbackQuestions.length, "");
        loading = false;
      });

      if (questions.isNotEmpty) {
        await speak(questions[0]);
      }
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    if (mounted) {
      setState(() => isSpeaking = true);
    }

    await flutterTts.stop();
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.45);
    await flutterTts.setPitch(1.0);
    await flutterTts.speak(text);
  }

  Future<void> startListening() async {
    final available = await speech.initialize();
    if (!available) return;

    currentAnswerSeconds = 0;
    lastSpeechUpdateTime = DateTime.now();

    _answerTimer?.cancel();
    _answerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        currentAnswerSeconds++;
      });
    });

    if (!mounted) return;
    setState(() {
      isListening = true;
    });

    speech.listen(
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.confirmation,
      ),
      onResult: (result) {
        if (!mounted || questions.isEmpty) return;

        final recognized = result.recognizedWords;

        setState(() {
          userAnswer = recognized;
          answerController.text = recognized;
          answerController.selection = TextSelection.fromPosition(
            TextPosition(offset: answerController.text.length),
          );
        });
      },
    );
  }

  void stopListening() {
    speech.stop();
    _answerTimer?.cancel();

    if (!mounted) return;
    setState(() {
      isListening = false;
      userAnswer = answerController.text;
    });
  }

  String cleanAnswer(String text) {
    String cleaned = text.trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.replaceAll(' ,', ',');
    cleaned = cleaned.replaceAll(' .', '.');
    cleaned = cleaned.replaceAll(' ?', '?');
    cleaned = cleaned.replaceAll(' !', '!');

    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    return cleaned;
  }

  void saveCurrentAnswer() {
    if (questions.isEmpty || currentIndex >= questions.length) return;

    final editedAnswer = cleanAnswer(answerController.text);
    userAnswer = editedAnswer;
    userAnswers[currentIndex] = editedAnswer;
    answerDurations[currentIndex] = currentAnswerSeconds;
  }

  Future<bool> _showSkipQuestionDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.question_mark,
                    color: Colors.orangeAccent,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Skip This Question?",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: repeatButtonColor,
                          foregroundColor: textColor,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("No", style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("Yes", style: TextStyle(fontSize: 14, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ) ?? false;
  }

  Future<void> goNext() async {
    if (questions.isEmpty) return;

    if (isListening) {
      stopListening();
    }

    if (answerController.text.trim().isEmpty) {
      final shouldSkip = await _showSkipQuestionDialog();
      if (!shouldSkip) {
        return;
      }
      saveCurrentAnswer();
    } else {
      saveCurrentAnswer();
    }

    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
        userAnswer = "";
        answerController.clear();
        currentAnswerSeconds = 0;
      });

      await speak(questions[currentIndex]);
    } else {
      await finishInterview();
    }
  }

  void goLanding() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LandingScreen(),
      ),
      (route) => false,
    );
  }

  void goLandingLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LandingScreen(openLogin: true),
      ),
      (route) => false,
    );
  }

  void retryInterview() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => InterviewSetupScreen(isDemo: widget.isDemo),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (currentIndex > 0 || userAnswers.any((a) => a.trim().isNotEmpty)) {
      final shouldExit = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Exit Interview?",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getProgressMessage(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textSecondaryColor,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Progress will be lost if you exit now!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFFFB74D),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: repeatButtonColor,
                            foregroundColor: textColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Continue",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Exit",
                            style: TextStyle(fontSize: 14, color: Colors.white),
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
      return shouldExit ?? false;
    }
    return true;
  }

  String _getProgressMessage() {
    final attempted = userAnswers.where((a) => a.trim().isNotEmpty).length;
    final total = questions.length;
    
    if (attempted == 0) {
      return "You haven't answered any questions yet.";
    } else if (attempted < total) {
      return "You have completed $attempted out of $total questions.\nCurrent question: ${currentIndex + 1}/$total";
    } else {
      return "You have completed all $total questions!";
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.exit_to_app,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Leave Interview?",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _getProgressMessage(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "All your answers will be lost!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFFB74D),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: repeatButtonColor,
                          foregroundColor: textColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Stay",
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _navigateToHome();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Leave",
                          style: TextStyle(fontSize: 14, color: Colors.white),
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

  void _navigateToHome() {
    if (isListening) {
      stopListening();
    }
    flutterTts.stop();
    speech.stop();
    _answerTimer?.cancel();
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LandingScreen(),
      ),
      (route) => false,
    );
  }

  void _shareResults(String aiScore, int attempted, int total, String role) {
    final shareText = """
🎯 AI INTERVIEW RESULTS 🎯

Role: $role
Score: $aiScore/10
Questions Attempted: $attempted/$total

💪 Keep practicing to improve your score!
📱 Practice with AI Interview App

#InterviewPractice #AIInterview #CareerGrowth
""";
    
    Share.share(shareText);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Share options opened!")),
    );
  }

  String extractAiScore(String text) {
    final match = RegExp(
      r'Score:\s*([0-9]+(?:\.[0-9]+)?)\s*/\s*10',
      caseSensitive: false,
    ).firstMatch(text);

    if (match != null) {
      return double.tryParse(match.group(1) ?? '0')?.toStringAsFixed(1) ?? '0';
    }

    final altMatch = RegExp(
      r'Score:\s*([0-9]+(?:\.[0-9]+)?)',
      caseSensitive: false,
    ).firstMatch(text);

    if (altMatch != null) {
      final parsed = double.tryParse(altMatch.group(1) ?? '0') ?? 0;
      if (parsed > 10) return '10.0';
      if (parsed < 0) return '0.0';
      return parsed.toStringAsFixed(1);
    }

    return '0';
  }

  String extractQuestionFeedback(String aiResult, int questionIndex) {
    final lines = aiResult.split('\n');
    String feedback = "No specific feedback available.";
    
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('Q${questionIndex + 1}:') || 
          lines[i].contains('Question ${questionIndex + 1}:') ||
          (lines[i].contains('$questionIndex.') && lines[i].contains('Feedback:'))) {
        if (i + 1 < lines.length) {
          feedback = lines[i + 1].trim();
          break;
        }
      }
    }
    
    return feedback;
  }

  String buildFallbackEvaluationForQuestion(int index, String answer, int duration) {
    if (answer.trim().isEmpty) {
      return "Not attempted. No answer provided for this question.";
    }
    
    int wordCount = answer.trim().split(RegExp(r'\s+')).length;
    return """Answered in ${duration}s with $wordCount words.
Content: ${answer.length > 100 ? answer.substring(0, 100) + '...' : answer}""";
  }

  Future<void> finishInterview() async {
    if (savingResult || questions.isEmpty) return;

    if (isListening) {
      stopListening();
    }

    saveCurrentAnswer();

    setState(() => savingResult = true);

    final total = questions.length;
    final attempted = userAnswers.where((a) => a.trim().isNotEmpty).length;
    final notAttempted = total - attempted;

    final faceSummary = faceMonitorService.buildSessionSummary();

    String aiResult;
    try {
      aiResult = await aiService.evaluateAnswer(
        questions,
        userAnswers,
      );
      
      for (int i = 0; i < questions.length; i++) {
        if (userAnswers[i].trim().isNotEmpty) {
          evaluationFeedback[i] = extractQuestionFeedback(aiResult, i);
          if (evaluationFeedback[i].isEmpty || evaluationFeedback[i] == "No specific feedback available.") {
            evaluationFeedback[i] = buildFallbackEvaluationForQuestion(i, userAnswers[i], answerDurations[i]);
          }
        } else {
          evaluationFeedback[i] = "Not attempted.";
        }
      }
    } catch (_) {
      for (int i = 0; i < questions.length; i++) {
        evaluationFeedback[i] = buildFallbackEvaluationForQuestion(i, userAnswers[i], answerDurations[i]);
      }
      aiResult = "";
    }

    final aiScore = extractAiScore(aiResult);

    if (isLoggedIn) {
      try {
        await firestoreService.saveInterview(
          double.parse(aiScore).round(),
          total,
          attempted,
          role: widget.role,
          level: widget.level,
        );
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() => savingResult = false);

    _showScorecardDialog(
      role: widget.role,
      level: widget.level,
      attempted: attempted,
      total: total,
      notAttempted: notAttempted,
      aiScore: aiScore,
      faceVisibility: faceSummary.visibilityPercent.toStringAsFixed(0),
      cameraEngage: faceSummary.engagementPercent.toStringAsFixed(0),
    );
  }

  void _showScorecardDialog({
    required String role,
    required String level,
    required int attempted,
    required int total,
    required int notAttempted,
    required String aiScore,
    required String faceVisibility,
    required String cameraEngage,
  }) {
    int currentPage = 0;
    String finalAiScore = aiScore;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 700,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: speakButtonColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "Page ${currentPage + 1}/3",
                              style: TextStyle(
                                color: speakButtonColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            "Interview Scorecard",
                            style: TextStyle(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.share, color: textSecondaryColor),
                            onPressed: () => _shareResults(finalAiScore, attempted, total, role),
                            tooltip: "Share Results",
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: currentPage == 0
                            ? _buildPage1Results(
                                role: role,
                                level: level,
                                attempted: attempted,
                                total: total,
                                notAttempted: notAttempted,
                                aiScore: aiScore,
                                faceVisibility: faceVisibility,
                                cameraEngage: cameraEngage,
                              )
                            : currentPage == 1
                                ? _buildPage2QuestionSummary()
                                : _buildPage3DetailedFeedback(),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (currentPage > 0)
                            ElevatedButton(
                              onPressed: () {
                                setDialogState(() {
                                  currentPage--;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: repeatButtonColor,
                                foregroundColor: textColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text("Back"),
                            )
                          else
                            const SizedBox(width: 80),
                          
                          if (currentPage < 2)
                            ElevatedButton(
                              onPressed: () {
                                setDialogState(() {
                                  currentPage++;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: speakButtonColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text("Next", style: TextStyle(color: Colors.white)),
                            )
                          else
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    retryInterview();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: nextButtonColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: const Text("Retry", style: TextStyle(color: Colors.white)),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    isLoggedIn ? goLanding() : goLandingLogin();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: speakButtonColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: Text(isLoggedIn ? "Home" : "Login", style: const TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPage1Results({
    required String role,
    required String level,
    required int attempted,
    required int total,
    required int notAttempted,
    required String aiScore,
    required String faceVisibility,
    required String cameraEngage,
  }) {
    return Column(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _scoreBox("Role", role),
            _scoreBox("Level", level),
            _scoreBox("Attempted", "$attempted / $total"),
            _scoreBox("Not Attempted", "$notAttempted"),
            _scoreBox("AI Final Score", "$aiScore / 10"),
            _scoreBox("Face Visibility", "$faceVisibility%"),
            _scoreBox("Camera Engage", "$cameraEngage%"),
          ],
        ),
      ],
    );
  }

  Widget _buildPage2QuestionSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Question Summary",
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(questions.length, (index) {
          final answered = userAnswers[index].trim().isNotEmpty;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: answered
                  ? const Color(0xFF10B981).withOpacity(0.12)
                  : const Color(0xFFEF4444).withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: answered
                    ? const Color(0xFF10B981).withOpacity(0.35)
                    : const Color(0xFFEF4444).withOpacity(0.30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      answered ? Icons.check_circle : Icons.cancel,
                      color: answered ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Q${index + 1}: ${answered ? "Attempted" : "Not Attempted"}",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (answered)
                      Text(
                        "${answerDurations[index]}s",
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  questions[index],
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPage3DetailedFeedback() {
    final hasUnattempted = userAnswers.any((answer) => answer.trim().isEmpty);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Detailed Feedback",
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(questions.length, (index) {
          final answered = userAnswers[index].trim().isNotEmpty;
          if (!answered) return const SizedBox.shrink();
          
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: speakButtonColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          "${index + 1}",
                          style: TextStyle(
                            color: speakButtonColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        questions[index],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isLightBlueTheme ? Colors.grey.shade50 : Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Your Answer:",
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        userAnswers[index],
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Divider(color: borderColor),
                      const SizedBox(height: 8),
                      Text(
                        "Score & Feedback:",
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        evaluationFeedback[index],
                        style: TextStyle(
                          color: speakButtonColor,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        if (hasUnattempted)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.30)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFEF4444), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Some questions were not attempted. Retry the interview to answer all questions for a complete evaluation.",
                    style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _scoreBox(String title, String value) {
    return Container(
      width: 145,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondaryColor, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPanel() {
    final String cameraText = !widget.useCamera
        ? "Camera Off"
        : cameraPermissionDenied
            ? "Camera Permission Denied"
            : cameraReady
                ? "Camera Ready"
                : "Initializing Camera...";

    String eyesStatus = "None";
    if (faceStatus.eyesOpen == true) {
      eyesStatus = "Open";
    } else if (faceStatus.eyesOpen == false) {
      eyesStatus = "Closed";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Live Camera Coaching",
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
              color: Colors.black26,
            ),
            child: widget.useCamera && cameraReady && _cameraController != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _cameraController!.value.previewSize?.height ?? 300,
                        height: _cameraController!.value.previewSize?.width ?? 400,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      cameraText,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondaryColor),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(faceStatus.faceDetected ? Icons.face : Icons.face_retouching_natural, color: faceStatus.faceDetected ? Colors.green : Colors.grey, size: 16),
                const SizedBox(width: 6),
                Text("Face: ${faceStatus.faceDetected ? "Detected" : "Not Detected"}", style: TextStyle(color: faceStatus.faceDetected ? Colors.green : textSecondaryColor, fontSize: 12)),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(faceStatus.eyesOpen == true ? Icons.visibility : Icons.visibility_off, color: faceStatus.eyesOpen == true ? Colors.green : Colors.grey, size: 16),
                const SizedBox(width: 6),
                Text("Eyes: $eyesStatus", style: TextStyle(color: faceStatus.eyesOpen == true ? Colors.green : textSecondaryColor, fontSize: 12)),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(faceStatus.singleFacePresent ? Icons.person : Icons.people, color: faceStatus.singleFacePresent ? Colors.green : Colors.orange, size: 16),
                const SizedBox(width: 6),
                Text("Single Face: ${faceStatus.singleFacePresent ? "Yes" : "No"}", style: TextStyle(color: faceStatus.singleFacePresent ? Colors.green : Colors.orange, fontSize: 12)),
              ]),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            faceStatus.coachingText,
            style: TextStyle(
              color: textSecondaryColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: speakButtonColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${widget.role} • ${widget.level}",
                  style: TextStyle(
                    color: speakButtonColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                questions.isEmpty
                    ? "Question 0/0"
                    : "Question ${currentIndex + 1}/${questions.length}",
                style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            questions.isNotEmpty
                ? questions[currentIndex]
                : "Loading question...",
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTipCard() {
    if (_tipShown) return const SizedBox.shrink();
    
    _tipShown = true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lightbulb, color: Color(0xFFF59E0B), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "💡 Quick Tip",
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _quickTip,
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 16),
            onPressed: () {
              setState(() {
                _tipShown = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: currentAnswerSeconds > 45 
            ? Colors.red.withOpacity(0.3)
            : currentAnswerSeconds > 30 
                ? Colors.orange.withOpacity(0.3)
                : speakButtonColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: currentAnswerSeconds > 45 
              ? Colors.red 
              : currentAnswerSeconds > 30 
                  ? Colors.orange 
                  : speakButtonColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            currentAnswerSeconds > 45 
                ? Icons.timer_off 
                : Icons.timer,
            color: currentAnswerSeconds > 45 
                ? Colors.red 
                : currentAnswerSeconds > 30 
                    ? Colors.orange 
                    : speakButtonColor,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            _formatTime(currentAnswerSeconds),
            style: TextStyle(
              color: currentAnswerSeconds > 45 
                  ? Colors.red 
                  : currentAnswerSeconds > 30 
                      ? Colors.orange 
                      : textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    return '${seconds}s';
  }

  Widget _buildAnswerPanel() {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timer and Word Counter Row
            Row(
              children: [
                _buildLiveTimer(),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "📝 ${answerController.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} words",
                    style: TextStyle(color: textSecondaryColor, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Buttons Row (ABOVE the text field)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: questions.isEmpty
                        ? null
                        : () => speak(questions[currentIndex]),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: repeatButtonColor,
                      foregroundColor: textColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      minimumSize: const Size(0, 40),
                    ),
                    child: const Text(
                      "Repeat",
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isListening ? stopListening : startListening,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isListening
                          ? Colors.redAccent
                          : speakButtonColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      minimumSize: const Size(0, 40),
                    ),
                    child: Text(
                      isListening ? "Stop" : "Speak",
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        answerController.clear();
                        userAnswer = "";
                        currentAnswerSeconds = 0;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: clearButtonColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      minimumSize: const Size(0, 40),
                    ),
                    child: const Text(
                      "Clear",
                      style: TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: savingResult ? null : goNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: nextButtonColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      minimumSize: const Size(0, 40),
                    ),
                    child: Text(
                      questions.isNotEmpty &&
                              currentIndex == questions.length - 1
                          ? "Finish"
                          : "Next",
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Answer Text Field (BELOW the buttons)
            Container(
              constraints: const BoxConstraints(
                minHeight: 200,
                maxHeight: 350,
              ),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isLightBlueTheme ? Colors.grey.shade50 : const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: TextField(
                  controller: answerController,
                  onChanged: (value) {
                    setState(() {
                      userAnswer = value;
                    });
                  },
                  minLines: 8,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: "Speak or type your answer here...",
                    hintStyle: TextStyle(color: textSecondaryColor),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    flutterTts.stop();
    speech.stop();
    _answerTimer?.cancel();
    answerController.dispose();
    _controller.dispose();
    _cameraController?.dispose();
    faceMonitorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 1000;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: appBarColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: _showExitConfirmation,
            tooltip: 'Exit Interview',
          ),
          title: Text(
            "AI Interview",
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          centerTitle: true,
          actions: [
            // Theme Toggle Button
            IconButton(
              icon: Icon(
                _isLightBlueTheme ? Icons.dark_mode : Icons.light_mode,
                color: textColor,
              ),
              onPressed: _toggleTheme,
              tooltip: _isLightBlueTheme ? "Switch to Dark Theme" : "Switch to Light Blue Theme",
            ),
            IconButton(
              icon: Icon(Icons.share, color: textSecondaryColor),
              onPressed: () {
                final attempted = userAnswers.where((a) => a.trim().isNotEmpty).length;
                _shareResults("In Progress", attempted, questions.length, widget.role);
              },
              tooltip: 'Share Progress',
            ),
            IconButton(
              icon: Icon(Icons.home, color: textColor),
              onPressed: _showExitConfirmation,
              tooltip: 'Go to Home',
            ),
          ],
        ),
        body: loading
            ? Center(child: CircularProgressIndicator())
            : questions.isEmpty
                ? Center(
                    child: Text(
                      "No Questions Loaded ❌",
                      style: TextStyle(color: textColor),
                    ),
                  )
                : SafeArea(
                    child: wide
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    children: [
                                      _buildCameraPanel(),
                                      const SizedBox(height: 20),
                                      _buildQuestionCard(),
                                      const SizedBox(height: 12),
                                      _buildQuickTipCard(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 5,
                                  child: _buildAnswerPanel(),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildCameraPanel(),
                                const SizedBox(height: 16),
                                _buildQuestionCard(),
                                const SizedBox(height: 12),
                                _buildQuickTipCard(),
                                const SizedBox(height: 20),
                                _buildAnswerPanel(),
                              ],
                            ),
                          ),
                  ),
      ),
    );
  }
}