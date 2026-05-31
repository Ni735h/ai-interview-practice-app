import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ChatbotService {
  // ============================================================
  // 🔧 UPDATE THIS URL WITH YOUR BACKEND URL
  // ============================================================
  
  // For local development with ngrok (when testing on real device)
  // Example: "https://abc123.ngrok-free.dev"
  static const String baseUrl = "https://your-ngrok-url.ngrok-free.dev";
  
  // For local emulator testing (Android emulator)
  // static const String baseUrl = "http://10.0.2.2:5000";
  
  // For local iOS simulator testing
  // static const String baseUrl = "http://localhost:5000";
  
  // For production
  // static const String baseUrl = "https://api.yourdomain.com";

  // Fallback responses when backend is unavailable
  final Map<String, String> _fallbackResponses = {
    "hello": "Hello! 👋 How can I help you with your interview preparation today?",
    "hi": "Hi there! 👋 Ready to practice? I'm here to help!",
    "hey": "Hey! 👋 How can I assist you with your interview practice today?",
    "help": "I can help you with:\n• Starting interviews\n• Understanding your scores\n• Dashboard statistics\n• Leaderboard rankings\n• Interview tips\n\nWhat would you like to know?",
    "how to start": "To start an interview, click the 'Start Interview' button. Choose your role (e.g., Flutter Developer) and difficulty level, then answer questions using voice or text. 🚀",
    "start interview": "Click the 'Start Interview' button on the Dashboard or from the menu. Select your role and difficulty level to begin practicing! 🎯",
    "score": "Your interview scores range from 0 to 10. They're calculated based on answer relevance, completeness, and delivery. Keep practicing to improve! 📊",
    "dashboard": "The Dashboard shows your total interviews, average score, questions attempted, attempt rate, and recent interview history. It's your personal performance tracker! 📈",
    "leaderboard": "The Leaderboard shows top performers based on their average interview scores. You can see how you rank against other users! 🏆",
    "delete interview": "You can delete any interview from your history by clicking the delete icon (trash can) next to it. This will automatically update your stats. 🗑️",
    "practice": "Regular practice is key! Try to attempt all questions, speak clearly, and use specific examples from your experience. 💪",
    "tips": "Interview tips:\n1️⃣ Use STAR method (Situation, Task, Action, Result)\n2️⃣ Speak clearly and confidently\n3️⃣ Give specific examples\n4️⃣ Listen carefully to questions\n5️⃣ Take a moment to think before answering",
    "camera": "The camera feature helps analyze your facial expressions and eye contact during interviews. You can enable it in the interview setup. 📸",
    "thank": "You're welcome! 😊 Keep practicing to improve your scores!",
    "thanks": "You're welcome! 😊 Happy practicing!",
    "bye": "Goodbye! 👋 Come back anytime to practice. Best of luck with your interviews! 🌟",
    "goodbye": "Goodbye! 👋 Wishing you success in your interviews!",
    "feature": "Our app features AI-generated questions, voice recognition, face monitoring, instant feedback, leaderboard, and detailed scorecards! ✨",
    "free": "Yes, the basic version is completely free! You can practice unlimited interviews. 🎉",
  };

  Future<String> getAIResponse(String userMessage, {String context = "dashboard"}) async {
    try {
      // Try to connect to backend
      final response = await http.post(
        Uri.parse("$baseUrl/chatbot/ask"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "message": userMessage,
          "context": context, // dashboard, interview, landing, onboarding
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["response"] ?? _getFallbackResponse(userMessage);
      } else {
        if (kDebugMode) {
          print("Backend error: ${response.statusCode}");
          print("Response body: ${response.body}");
        }
        return _getFallbackResponse(userMessage);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Chatbot API Error: $e");
      }
      return _getFallbackResponse(userMessage);
    }
  }

  String _getFallbackResponse(String message) {
    final lowerMsg = message.toLowerCase().trim();
    
    // Check for exact matches first
    for (var entry in _fallbackResponses.entries) {
      if (lowerMsg.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Check for keywords
    if (lowerMsg.contains("interview") && (lowerMsg.contains("how") || lowerMsg.contains("start"))) {
      return _fallbackResponses["how to start"]!;
    }
    
    if (lowerMsg.contains("score") || lowerMsg.contains("rating") || lowerMsg.contains("mark")) {
      return _fallbackResponses["score"]!;
    }
    
    if (lowerMsg.contains("dashboard") || lowerMsg.contains("stat") || lowerMsg.contains("performance") || lowerMsg.contains("overview")) {
      return _fallbackResponses["dashboard"]!;
    }
    
    if (lowerMsg.contains("leaderboard") || lowerMsg.contains("rank") || lowerMsg.contains("top") || lowerMsg.contains("leader")) {
      return _fallbackResponses["leaderboard"]!;
    }
    
    if (lowerMsg.contains("tip") || lowerMsg.contains("advice") || lowerMsg.contains("suggestion") || lowerMsg.contains("improve")) {
      return _fallbackResponses["tips"]!;
    }
    
    if (lowerMsg.contains("camera") || lowerMsg.contains("face") || lowerMsg.contains("video")) {
      return _fallbackResponses["camera"]!;
    }
    
    if (lowerMsg.contains("delete") || lowerMsg.contains("remove") || lowerMsg.contains("clear")) {
      return _fallbackResponses["delete interview"]!;
    }
    
    if (lowerMsg.contains("feature") || lowerMsg.contains("what can")) {
      return _fallbackResponses["feature"]!;
    }
    
    if (lowerMsg.contains("free") || lowerMsg.contains("cost") || lowerMsg.contains("price")) {
      return _fallbackResponses["free"]!;
    }
    
    // Context-specific responses
    if (lowerMsg.contains("welcome") || lowerMsg.contains("start")) {
      return "Welcome to AI Mock Interview! 🎯 Ready to practice? Click 'Start Interview' to begin your journey to interview success! 🚀";
    }
    
    // Default response
    return "I'm here to help! You can ask me about:\n\n How to start an interview\n Understanding your scores\n Dashboard features\n Leaderboard rankings\n Interview tips & advice\n Camera usage\n App features\n\nWhat would you like to know? 🎯";
  }

  // Get random interview tip
  Future<String> getInterviewTip() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/chatbot/tip"),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["tip"] ?? "Practice STAR method: Situation, Task, Action, Result! 🌟";
      }
      return _getRandomTip();
    } catch (e) {
      if (kDebugMode) {
        print("Get tip error: $e");
      }
      return _getRandomTip();
    }
  }

  String _getRandomTip() {
    final tips = [
      "Use the STAR method: Situation, Task, Action, Result! 🌟",
      "Speak clearly and maintain eye contact with the camera! 👀",
      "Practice answering common questions in your field! 📝",
      "Record yourself to identify areas for improvement! 🎥",
      "Take deep breaths before answering to stay calm! 😌",
      "Research the company before your interview! 🔍",
      "Prepare 2-3 questions to ask the interviewer! ❓",
      "Dress professionally even for virtual interviews! 👔",
      "Test your camera and microphone before starting! 🎙️",
      "Use specific examples from your experience! 💼",
      "Listen carefully to each question before answering! 👂",
      "Don't be afraid to take a moment to think! 🤔",
      "Show enthusiasm and genuine interest! ✨",
      "Be honest about your experiences! 🎯",
    ];
    return tips[DateTime.now().millisecondsSinceEpoch % tips.length];
  }

  // Get motivational quote
  Future<String> getMotivationalQuote() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/chatbot/quote"),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["quote"] ?? "Believe in yourself! You've got this! 💪";
      }
      return _getRandomQuote();
    } catch (e) {
      if (kDebugMode) {
        print("Get quote error: $e");
      }
      return _getRandomQuote();
    }
  }

  String _getRandomQuote() {
    final quotes = [
      "Believe in yourself! You've got this! 💪",
      "Every expert was once a beginner! 🌱",
      "Practice makes progress, not perfection! 🎯",
      "Your next interview could be your best one yet! ✨",
      "Confidence comes from preparation! 📚",
      "Each interview is a learning opportunity! 🎓",
      "Stay positive and keep growing! 🌈",
      "You are capable of amazing things! ⭐",
      "Success is the sum of small efforts! 🔥",
      "Don't stop until you're proud! 🏆",
    ];
    return quotes[DateTime.now().millisecondsSinceEpoch % quotes.length];
  }

  // Check backend health
  Future<bool> isBackendAvailable() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/"),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}