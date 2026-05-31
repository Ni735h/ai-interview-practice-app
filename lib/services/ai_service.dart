import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AIService {
  AIService();

  static const String baseUrl = "https://deception-preplan-storage.ngrok-free.dev";

  // Sample expected answers for common questions (for local fallback)
  final Map<String, Map<String, dynamic>> _expectedAnswers = {
    "Tell me about yourself": {
      "keyPoints": [
        "professional background",
        "relevant experience",
        "skills and achievements",
        "career goals",
        "why interested in role"
      ],
      "sampleAnswer": "I have [X] years of experience in [field], specializing in [key skills]. I've successfully [achievement]. I'm passionate about [industry] and excited about this opportunity because [reason]."
    },
    "Why do you want this role": {
      "keyPoints": [
        "company research",
        "role alignment with skills",
        "career growth",
        "passion for industry",
        "value contribution"
      ],
      "sampleAnswer": "I'm excited about this role because it aligns perfectly with my skills in [skill]. I admire [company]'s work in [area], and I want to contribute by [specific contribution]."
    },
    "What are your strengths": {
      "keyPoints": [
        "specific skills",
        "examples of strength in action",
        "results achieved",
        "soft skills",
        "technical abilities"
      ],
      "sampleAnswer": "My key strengths include [strength1], [strength2], and [strength3]. For example, I recently [specific example] which resulted in [positive outcome]."
    },
    "What is your biggest weakness": {
      "keyPoints": [
        "honest weakness",
        "improvement actions",
        "learning journey",
        "turning weakness into strength",
        "self-awareness"
      ],
      "sampleAnswer": "I sometimes struggle with [weakness], but I've been improving by [action taken]. I now [positive outcome]."
    },
  };

  Future<List<String>> getQuestions({
    required String role,
    required String level,
    required bool isDemo,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse("$baseUrl/generate-questions"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "role": role.trim(),
              "level": level.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      print("QUESTION STATUS: ${res.statusCode}");
      print("QUESTION BODY: ${res.body}");

      if (res.statusCode != 200) {
        throw Exception("API returned status ${res.statusCode}");
      }

      final data = jsonDecode(res.body);

      if (data["questions"] == null || data["questions"] is! List) {
        throw Exception("Invalid questions format from API");
      }

      List<String> questions = List<String>.from(
        (data["questions"] as List).map((q) => q.toString().trim()),
      ).where((q) => q.isNotEmpty).toList();

      if (questions.isEmpty) {
        throw Exception("Questions list is empty");
      }

      if (isDemo && questions.length > 5) {
        return questions.take(5).toList();
      }

      return questions;
    } catch (e) {
      print("QUESTION ERROR: $e");

      return isDemo
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
              "Describe a challenge you faced and how you overcame it.",
              "Where do you see yourself in 5 years?",
              "Why should we hire you?",
              "Tell me about a time you worked in a team.",
              "How do you handle pressure?",
              "What questions do you have for us?",
            ];
    }
  }

  /// Main evaluation method – tries backend first, falls back to local analysis
  Future<String> evaluateAnswer(
    List<String> questions,
    List<String> answers,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse("$baseUrl/evaluate"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "questions": questions,
              "answers": answers,
            }),
          )
          .timeout(const Duration(seconds: 45));

      print("EVAL STATUS: ${res.statusCode}");
      print("EVAL BODY: ${res.body}");

      if (res.statusCode != 200) {
        throw Exception("Evaluation API failed with status ${res.statusCode}");
      }

      final data = jsonDecode(res.body);

      // If backend returns structured JSON (new format)
      if (data.containsKey("per_question_feedback") && data.containsKey("score_out_of_10")) {
        return _formatBackendEvaluation(data);
      }
      // If backend returns old plain text "result"
      else if (data["result"] != null) {
        return data["result"].toString();
      }
      else {
        throw Exception("Unknown response format");
      }
    } catch (e) {
      print("EVALUATION ERROR, using fallback: $e");
      // Use enhanced local fallback
      return _generateEnhancedFallbackEvaluation(questions, answers);
    }
  }

  /// Converts backend JSON into a human-readable string with per-question ideal answer & feedback
  String _formatBackendEvaluation(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    final perQuestion = data["per_question_feedback"] as List;
    final score = (data["score_out_of_10"] ?? 0).toString();
    final overall = data["overall_feedback"] ?? "";
    final strengths = (data["strengths"] as List?) ?? [];
    final improvements = (data["improvements"] as List?) ?? [];
    final finalVerdict = data["final_verdict"] ?? "";

    buffer.writeln("╔══════════════════════════════════════════════════════════════╗");
    buffer.writeln("║                    INTERVIEW EVALUATION                      ║");
    buffer.writeln("╚══════════════════════════════════════════════════════════════╝\n");
    buffer.writeln("📊 SCORE: $score/10\n");
    buffer.writeln("📋 DETAILED FEEDBACK (per question):\n");

    for (var q in perQuestion) {
      final qNum = q["question_number"];
      final question = q["question"];
      final userAnswer = q["user_answer"];
      final verdict = q["verdict"];
      final note = q["note"] ?? "";
      final ideal = q["ideal_answer"] ?? "Not provided";
      final feedbackOnUser = q["feedback_on_user_answer"] ?? "";

      buffer.writeln("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      buffer.writeln("Q$qNum: $question");
      buffer.writeln("Your answer: $userAnswer");
      buffer.writeln("Verdict: $verdict");
      if (note.isNotEmpty) buffer.writeln("Note: $note");
      buffer.writeln("\n✅ IDEAL ANSWER (the correct way to answer):");
      buffer.writeln("   $ideal");
      if (feedbackOnUser.isNotEmpty) {
        buffer.writeln("\n📝 FEEDBACK ON YOUR ANSWER:");
        buffer.writeln("   $feedbackOnUser");
      }
      buffer.writeln();
    }

    buffer.writeln("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    buffer.writeln("💪 STRENGTHS:");
    for (var s in strengths) buffer.writeln("  • $s");
    buffer.writeln("\n📈 IMPROVEMENTS:");
    for (var imp in improvements) buffer.writeln("  • $imp");
    buffer.writeln("\n📝 OVERALL FEEDBACK:\n$overall");
    buffer.writeln("\n🏆 FINAL VERDICT:\n$finalVerdict");
    buffer.writeln("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    return buffer.toString();
  }

  // ========== LOCAL FALLBACK METHODS (identical to your original) ==========

  /// Add relevance analysis for each question (used only if backend fails)
  Future<String> _addRelevanceAnalysis(
    List<String> questions,
    List<String> answers,
    String aiResult,
  ) async {
    String relevanceSection = "\n\n" + "=" * 60 + "\n";
    relevanceSection += "📊 DETAILED ANSWER RELEVANCE ANALYSIS\n";
    relevanceSection += "=" * 60 + "\n\n";
    
    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      final answer = answers[i];
      
      relevanceSection += "Q${i + 1}: ${question.length > 50 ? question.substring(0, 50) + '...' : question}\n";
      relevanceSection += "-" * 40 + "\n";
      
      if (answer.trim().isEmpty) {
        relevanceSection += "❌ Status: NOT ATTEMPTED\n";
        relevanceSection += "💡 Expected Approach: Provide a structured answer covering key aspects of the question.\n\n";
        continue;
      }
      
      final relevance = await _analyzeAnswerRelevance(question, answer);
      
      relevanceSection += "✅ Status: ATTEMPTED\n";
      relevanceSection += "📝 Answer Length: ${answer.length} characters, ${answer.split(' ').length} words\n";
      relevanceSection += "🎯 Relevance Score: ${relevance['score']}/10\n";
      relevanceSection += "📌 Relevance Level: ${relevance['level']}\n";
      relevanceSection += "💬 Feedback: ${relevance['feedback']}\n";
      
      if (relevance['missingPoints'].isNotEmpty) {
        relevanceSection += "⚠️ Missing Key Points:\n";
        for (var point in relevance['missingPoints']) {
          relevanceSection += "   • $point\n";
        }
      }
      
      if (relevance['coveredPoints'].isNotEmpty) {
        relevanceSection += "✅ Covered Points:\n";
        for (var point in relevance['coveredPoints']) {
          relevanceSection += "   • $point\n";
        }
      }
      
      relevanceSection += "\n📖 What a Good Answer Should Include:\n";
      relevanceSection += "   ${relevance['expectedAnswer']}\n";
      
      relevanceSection += "\n" + "-" * 40 + "\n\n";
    }
    
    return aiResult + relevanceSection;
  }

  Future<Map<String, dynamic>> _analyzeAnswerRelevance(String question, String answer) async {
    final answerLower = answer.toLowerCase();
    final questionLower = question.toLowerCase();
    
    final keyConcepts = _extractKeyConcepts(questionLower);
    
    final coveredPoints = <String>[];
    final missingPoints = <String>[];
    
    for (var concept in keyConcepts) {
      if (answerLower.contains(concept.toLowerCase())) {
        coveredPoints.add(concept);
      } else {
        missingPoints.add(concept);
      }
    }
    
    double score = 0;
    String level = "";
    String feedback = "";
    
    if (coveredPoints.isEmpty) {
      score = (answer.length / 200 * 2).clamp(0.0, 3.0);
      level = "Off-topic";
      feedback = "Your answer doesn't address the main question. Please focus on the specific question asked.";
    } else if (coveredPoints.length < keyConcepts.length / 2) {
      score = 4.0 + (coveredPoints.length / keyConcepts.length * 2);
      level = "Partially Relevant";
      feedback = "You've touched on some points but missed key aspects of the question.";
    } else if (coveredPoints.length >= keyConcepts.length / 2) {
      score = 7.0 + (coveredPoints.length / keyConcepts.length * 3);
      level = "Relevant";
      feedback = "Good answer! You've covered the main points effectively.";
    }
    
    if (coveredPoints.length >= keyConcepts.length * 0.8) {
      score = score.clamp(9.0, 10.0);
      level = "Highly Relevant";
      feedback = "Excellent! Your answer is comprehensive and directly addresses the question.";
    }
    
    if (answer.length < 30) {
      score = (score - 2).clamp(0.0, 10.0);
      feedback += " Consider providing more detail in your answer.";
    }
    
    score = double.parse(score.toStringAsFixed(1));
    
    String expectedAnswer = _getExpectedAnswerForQuestion(question);
    
    return {
      'score': score,
      'level': level,
      'feedback': feedback,
      'coveredPoints': coveredPoints,
      'missingPoints': missingPoints,
      'expectedAnswer': expectedAnswer,
    };
  }

  List<String> _extractKeyConcepts(String question) {
    final concepts = <String>[];
    if (question.contains("tell me about yourself")) {
      concepts.addAll(["background", "experience", "skills", "goals"]);
    } else if (question.contains("why do you want")) {
      concepts.addAll(["interest", "company", "role", "contribution"]);
    } else if (question.contains("strengths")) {
      concepts.addAll(["skills", "examples", "results", "unique"]);
    } else if (question.contains("weakness")) {
      concepts.addAll(["honest weakness", "improvement", "action taken", "learning"]);
    } else if (question.contains("challenge") || question.contains("problem")) {
      concepts.addAll(["situation", "action", "result", "learning"]);
    } else if (question.contains("team")) {
      concepts.addAll(["collaboration", "role", "contribution", "outcome"]);
    } else if (question.contains("pressure") || question.contains("stress")) {
      concepts.addAll(["situation", "response", "technique", "result"]);
    } else if (question.contains("future") || question.contains("5 years")) {
      concepts.addAll(["career path", "goals", "skills", "contribution"]);
    } else if (question.contains("skills")) {
      concepts.addAll(["technical skills", "soft skills", "examples", "application"]);
    } else {
      final words = question.split(' ');
      for (var word in words) {
        if (word.length > 5 && !concepts.contains(word)) {
          concepts.add(word);
        }
      }
      if (concepts.length > 5) concepts.length = 5;
    }
    return concepts;
  }

  String _getExpectedAnswerForQuestion(String question) {
    final questionLower = question.toLowerCase();
    if (questionLower.contains("tell me about yourself")) {
      return "A good answer should include: Your professional background, key achievements, relevant skills, career goals, and why you're interested in this role. Keep it concise (1-2 minutes).";
    } else if (questionLower.contains("why do you want")) {
      return "A good answer should: Show you've researched the company, explain how your skills align with the role, express genuine interest, and describe what you can contribute.";
    } else if (questionLower.contains("strengths")) {
      return "A good answer should: List 2-3 specific strengths, provide concrete examples of each, and explain how they benefit the role/company.";
    } else if (questionLower.contains("weakness")) {
      return "A good answer should: Be honest about a real weakness, explain steps you're taking to improve, show self-awareness, and avoid 'perfectionism' clichés.";
    } else if (questionLower.contains("challenge") || questionLower.contains("problem")) {
      return "A good STAR answer should: Describe the Situation, explain your Task, detail the Actions you took, and share the Results achieved.";
    } else {
      return "A good answer should be: Relevant to the question, specific with examples, concise but detailed, and demonstrate your knowledge/skills.";
    }
  }

  String _adjustScoreFairly(String aiResult, List<String> questions, List<String> answers) {
    int totalQuestions = questions.length;
    int attemptedCount = answers.where((a) => a.trim().isNotEmpty).length;
    
    double originalScore = 0;
    final scoreMatch = RegExp(r'Score:\s*([0-9]+(?:\.[0-9]+)?)').firstMatch(aiResult);
    if (scoreMatch != null) {
      originalScore = double.tryParse(scoreMatch.group(1) ?? '0') ?? 0;
    }
    
    double fairScore = originalScore;
    if (attemptedCount == totalQuestions && originalScore < 5) {
      fairScore = 5.0;
    } else if (attemptedCount >= totalQuestions / 2 && originalScore < 3) {
      fairScore = 3.0;
    } else if (attemptedCount > 0 && originalScore < 1) {
      fairScore = 1.0;
    }
    
    double attemptBonus = (attemptedCount / totalQuestions) * 2;
    if (originalScore > 0) {
      fairScore = originalScore + attemptBonus;
    }
    fairScore = fairScore.clamp(0.0, 10.0);
    fairScore = double.parse(fairScore.toStringAsFixed(1));
    
    if ((fairScore - originalScore).abs() > 0.5) {
      String fairScoreLine = "\n\n✨ ADJUSTED FAIR SCORE: $fairScore/10 ✨\n";
      String explanation = "📌 Note: Score adjusted because you attempted $attemptedCount/$totalQuestions questions. ";
      explanation += (attemptedCount == totalQuestions) 
          ? "Great job answering all questions!" 
          : "Try to answer all questions next time for a higher score!";
      
      if (aiResult.contains('Score:')) {
        aiResult = aiResult.replaceAll(
          RegExp(r'Score:\s*[0-9]+(?:\.[0-9]+)?\s*/?\s*10?'),
          'Score: $fairScore/10'
        );
        if (!aiResult.contains('ADJUSTED FAIR SCORE')) {
          aiResult = aiResult.replaceFirst(
            'Score: $fairScore/10',
            'Score: $fairScore/10\n$explanation'
          );
        }
      } else {
        aiResult = "Score: $fairScore/10\n$explanation\n\n$aiResult";
      }
    }
    return aiResult;
  }

  String _generateEnhancedFallbackEvaluation(List<String> questions, List<String> answers) {
    int total = questions.length;
    int attempted = answers.where((a) => a.trim().isNotEmpty).length;
    int notAttempted = total - attempted;
    
    double avgAnswerLength = 0;
    List<String> attemptedAnswers = answers.where((a) => a.trim().isNotEmpty).toList();
    if (attemptedAnswers.isNotEmpty) {
      int totalLength = attemptedAnswers.fold(0, (sum, a) => sum + a.trim().length);
      avgAnswerLength = totalLength / attemptedAnswers.length;
    }
    
    double baseScore = (attempted / total) * 5;
    double qualityBonus = 0;
    if (avgAnswerLength > 100) {
      qualityBonus = 3;
    } else if (avgAnswerLength > 50) {
      qualityBonus = 2;
    } else if (avgAnswerLength > 20) {
      qualityBonus = 1;
    }
    
    double finalScore = (baseScore + qualityBonus).clamp(0.0, 10.0);
    finalScore = double.parse(finalScore.toStringAsFixed(1));
    
    String feedback = "";
    if (attempted == total) {
      feedback = "Excellent! You attempted all questions. ";
    } else if (attempted >= total / 2) {
      feedback = "Good effort! You attempted more than half the questions. ";
    } else if (attempted > 0) {
      feedback = "You attempted some questions. ";
    } else {
      feedback = "No answers were submitted. ";
    }
    
    if (avgAnswerLength > 50) {
      feedback += "Your answers were detailed and showed good understanding.";
    } else if (avgAnswerLength > 20) {
      feedback += "Your answers were concise. Consider adding more details.";
    } else if (attempted > 0 && avgAnswerLength > 0) {
      feedback += "Your answers were brief. Try to elaborate more.";
    }
    
    String result = """
╔══════════════════════════════════════════════════════════════╗
║                    INTERVIEW EVALUATION                      ║
╚══════════════════════════════════════════════════════════════╝

📊 OVERALL STATISTICS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Total Questions: $total
• Attempted: $attempted
• Not Attempted: $notAttempted
• Average Answer Length: ${avgAnswerLength.toStringAsFixed(0)} characters

⭐ FINAL SCORE: $finalScore/10 ⭐
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📝 OVERALL FEEDBACK:
$feedback

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 DETAILED QUESTION ANALYSIS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

""";
    
    for (int i = 0; i < questions.length; i++) {
      final answer = answers[i];
      final isAttempted = answer.trim().isNotEmpty;
      
      result += "Q${i + 1}: ${questions[i]}\n";
      result += "━" * 40 + "\n";
      
      if (!isAttempted) {
        result += "❌ Status: NOT ATTEMPTED\n";
        result += "💡 Suggestion: Please provide an answer for this question.\n";
        result += "📖 Expected: Give a relevant response based on your experience.\n\n";
      } else {
        final wordCount = answer.trim().split(RegExp(r'\s+')).length;
        result += "✅ Status: ATTEMPTED\n";
        result += "📝 Your Answer: \"${answer.length > 100 ? answer.substring(0, 100) + '...' : answer}\"\n";
        result += "📊 Metrics: ${answer.length} characters, $wordCount words\n";
        
        String relevanceLevel = "";
        if (answer.length < 30) {
          relevanceLevel = "⚠️ Too brief - needs more detail";
        } else if (answer.length < 100) {
          relevanceLevel = "📌 Adequate - could add more depth";
        } else {
          relevanceLevel = "✅ Good detail - well explained";
        }
        result += "🎯 Relevance: $relevanceLevel\n";
        
        result += "📖 What a good answer should include:\n";
        result += "   • Directly address the question asked\n";
        result += "   • Provide specific examples from your experience\n";
        result += "   • Be clear, concise, and professional\n";
        result += "   • Demonstrate your knowledge and skills\n\n";
      }
    }
    
    result += """
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 TIPS FOR IMPROVEMENT:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${attempted != total ? "• Answer ALL questions to maximize your score\n" : ""}
${avgAnswerLength < 50 ? "• Provide MORE DETAILED answers (aim for 50+ characters)\n" : ""}
• Use the STAR method for behavioral questions
• Practice speaking clearly and confidently
• Research common questions for your role
• Take 2-3 seconds to think before answering

🏆 FINAL VERDICT:
${finalScore >= 8 ? "Outstanding! You're well-prepared for real interviews!" : finalScore >= 6 ? "Good job! Keep practicing to refine your answers." : finalScore >= 4 ? "Decent effort! Focus on answering all questions with more detail." : "Keep practicing! Try to attempt every question in your next session."}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Note: This evaluation was generated locally. Your answers were analyzed
for relevance, completeness, and effort.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
""";
    
    return result;
  }
}