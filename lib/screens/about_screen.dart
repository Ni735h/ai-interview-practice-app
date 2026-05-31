import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          "About Us",
          style: GoogleFonts.poppins(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          "AI Interview Pro helps students and professionals "
          "prepare for real interviews using AI-based feedback, "
          "speech analysis, and facial recognition scoring.",
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}