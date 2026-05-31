import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper method to get current user
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  Future<void> saveInterview(
    int score,
    int totalQuestions,
    int attempted, {
    String role = "Unknown Role",
    String level = "-",
  }) async {
    final user = _currentUser;
    if (user == null) {
      print('No user logged in, cannot save interview');
      return;
    }

    try {
      final userRef = _firestore.collection("users").doc(user.uid);

      final doc = await userRef.get();
      final data = doc.data() ?? {};

      final double prevAvg = ((data["averageScore"] ?? 0) as num).toDouble();
      final int prevCount = ((data["totalInterviews"] ?? 0) as num).toInt();
      final int prevAttempted = ((data["questionsAttempted"] ?? 0) as num).toInt();
      final int prevTotalQuestions = ((data["totalQuestions"] ?? 0) as num).toInt();

      final int newCount = prevCount + 1;
      final int newAttempted = prevAttempted + attempted;
      final int newTotalQuestions = prevTotalQuestions + totalQuestions;

      final double newAvg = ((prevAvg * prevCount) + score) / newCount;

      final double attemptRate = newTotalQuestions == 0
          ? 0
          : (newAttempted / newTotalQuestions) * 100;

      // 1️⃣ Save inside user's interview history
      await userRef.collection("interview_history").add({
        "role": role,
        "level": level,
        "score": score.toDouble(),
        "total": totalQuestions,
        "attempted": attempted,
        "createdAt": FieldValue.serverTimestamp(),
      });

      // 2️⃣ Update user stats
      await userRef.set({
        "averageScore": newAvg,
        "totalInterviews": newCount,
        "questionsAttempted": newAttempted,
        "totalQuestions": newTotalQuestions,
        "attemptRate": attemptRate,
        "lastScore": score.toDouble(),
        "lastRole": role,
        "lastLevel": level,
        "email": user.email ?? "",
        "name": data["name"] ?? user.email?.split('@').first ?? "User",
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('Interview saved successfully for user: ${user.email}');
    } catch (e) {
      print('Error saving interview: $e');
      // Re-throw if you want to handle it in the UI
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserInterviews() {
    final user = _currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    return _firestore
        .collection("users")
        .doc(user.uid)
        .collection("interview_history")
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getLeaderboard() {
    return _firestore
        .collection("users")
        .orderBy("averageScore", descending: true)
        .limit(20)
        .snapshots();
  }

  // Additional helper methods you might need
  
  Future<Map<String, dynamic>?> getUserStats() async {
    final user = _currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection("users").doc(user.uid).get();
      return doc.data();
    } catch (e) {
      print('Error fetching user stats: $e');
      return null;
    }
  }

  Future<void> updateUserName(String name) async {
    final user = _currentUser;
    if (user == null) return;

    try {
      await _firestore.collection("users").doc(user.uid).set({
        "name": name,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating user name: $e');
      rethrow;
    }
  }

  Future<void> deleteInterview(String interviewId) async {
    final user = _currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection("users")
          .doc(user.uid)
          .collection("interview_history")
          .doc(interviewId)
          .delete();
          
      // Recalculate stats after deletion
      await _recalculateUserStats();
    } catch (e) {
      print('Error deleting interview: $e');
      rethrow;
    }
  }

  Future<void> _recalculateUserStats() async {
    final user = _currentUser;
    if (user == null) return;

    try {
      final interviews = await _firestore
          .collection("users")
          .doc(user.uid)
          .collection("interview_history")
          .get();

      if (interviews.docs.isEmpty) {
        // Reset stats if no interviews
        await _firestore.collection("users").doc(user.uid).set({
          "averageScore": 0,
          "totalInterviews": 0,
          "questionsAttempted": 0,
          "totalQuestions": 0,
          "attemptRate": 0,
        }, SetOptions(merge: true));
        return;
      }

      double totalScore = 0;
      int totalAttempted = 0;
      int totalQuestionsSum = 0;
      int lastScore = 0;
      String lastRole = "";
      String lastLevel = "";

      for (var doc in interviews.docs) {
        final data = doc.data();
        totalScore += (data["score"] ?? 0) as num;
        totalAttempted += (data["attempted"] ?? 0) as int;
        totalQuestionsSum += (data["total"] ?? 0) as int;
      }

      final double avgScore = totalScore / interviews.docs.length;
      final double attemptRate = totalQuestionsSum == 0 ? 0 : (totalAttempted / totalQuestionsSum) * 100;

      // Get last interview
      if (interviews.docs.isNotEmpty) {
        final lastInterview = interviews.docs.first.data();
        lastScore = (lastInterview["score"] ?? 0).round();
        lastRole = lastInterview["role"] ?? "";
        lastLevel = lastInterview["level"] ?? "";
      }

      await _firestore.collection("users").doc(user.uid).set({
        "averageScore": avgScore,
        "totalInterviews": interviews.docs.length,
        "questionsAttempted": totalAttempted,
        "totalQuestions": totalQuestionsSum,
        "attemptRate": attemptRate,
        "lastScore": lastScore.toDouble(),
        "lastRole": lastRole,
        "lastLevel": lastLevel,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error recalculating stats: $e');
    }
  }
}