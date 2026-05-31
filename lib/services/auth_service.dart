import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> signUp(String email, String password) async {
    try {
      final cleanedEmail = email.trim().toLowerCase();

      final res = await _auth.createUserWithEmailAndPassword(
        email: cleanedEmail,
        password: password,
      );

      final user = res.user;

      if (user != null) {
        await _firestore.collection("users").doc(user.uid).set({
          "name": cleanedEmail.split('@').first,
          "email": cleanedEmail,
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
        });
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw "Something went wrong";
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      final cleanedEmail = email.trim().toLowerCase();

      final res = await _auth.signInWithEmailAndPassword(
        email: cleanedEmail,
        password: password,
      );

      final user = res.user;

      if (user != null) {
        final userRef = _firestore.collection("users").doc(user.uid);
        final doc = await userRef.get();

        if (!doc.exists) {
          await userRef.set({
            "name": cleanedEmail.split('@').first,
            "email": cleanedEmail,
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
          });
        } else {
          final data = doc.data() ?? {};
          final currentName = (data["name"] ?? "").toString().trim();

          if (currentName.isEmpty || currentName.toLowerCase() == "user") {
            await userRef.set({
              "name": cleanedEmail.split('@').first,
              "email": cleanedEmail,
              "updatedAt": FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw "Something went wrong";
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return "Invalid email format";

      case 'user-not-found':
        return "User not found";

      case 'wrong-password':
      case 'invalid-credential':
        return "Wrong email or password";

      case 'email-already-in-use':
        return "Email already registered";

      case 'weak-password':
        return "Password should be at least 6 characters";

      case 'network-request-failed':
        return "No internet connection";

      case 'too-many-requests':
        return "Too many attempts. Try again later";

      default:
        return e.message ?? "Authentication error";
    }
  }
}