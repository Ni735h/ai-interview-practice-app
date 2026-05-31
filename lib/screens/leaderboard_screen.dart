import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final Color bg = const Color(0xFF0F172A);
  final Color card = const Color(0xFF1E293B);
  final Color accent = const Color(0xFF6366F1);
  final Color green = const Color(0xFF22C55E);

  String searchText = "";

  String _displayName(Map<String, dynamic> data) {
    final rawName = (data['name'] ?? "").toString().trim();
    final email = (data['email'] ?? "").toString().trim();

    if (rawName.isNotEmpty &&
        rawName.toLowerCase() != "user" &&
        !rawName.contains(' ')) {
      return rawName;
    }

    if (email.isNotEmpty && email.contains('@')) {
      return email.split('@').first;
    }

    if (rawName.isNotEmpty) {
      return rawName;
    }

    return "User";
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          "Leaderboard",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('averageScore', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No users yet 🚀",
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
            );
          }

          final allUsers = snapshot.data!.docs;

          final filteredUsers = allUsers.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = _displayName(data).toLowerCase();
            return name.contains(searchText.toLowerCase());
          }).toList();

          int currentUserRank = -1;
          Map<String, dynamic>? currentUserData;

          for (int i = 0; i < allUsers.length; i++) {
            if (allUsers[i].id == currentUser?.uid) {
              currentUserRank = i + 1;
              currentUserData = allUsers[i].data() as Map<String, dynamic>;
              break;
            }
          }

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (currentUserData != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accent.withOpacity(0.35),
                                  accent.withOpacity(0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: accent.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: accent,
                                  child: Text(
                                    "$currentUserRank",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Your Rank",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _displayName(currentUserData),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  "${((currentUserData['averageScore'] ?? 0) as num).toDouble().toStringAsFixed(1)}/10",
                                  style: GoogleFonts.poppins(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          onChanged: (value) {
                            setState(() {
                              searchText = value;
                            });
                          },
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Search user...",
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.white54,
                            ),
                            filled: true,
                            fillColor: card,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),

                      if (filteredUsers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 30,
                          ),
                          child: Center(
                            child: Text(
                              "No users found",
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),

                      if (filteredUsers.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (filteredUsers.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: _topUserCard(
                                      filteredUsers[1],
                                      2,
                                      Colors.grey,
                                      95,
                                      90,
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: _topUserCard(
                                    filteredUsers[0],
                                    1,
                                    Colors.amber,
                                    115,
                                    120,
                                  ),
                                ),
                                if (filteredUsers.length > 2)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: _topUserCard(
                                      filteredUsers[2],
                                      3,
                                      Colors.brown,
                                      95,
                                      90,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

                      if (filteredUsers.length > 3)
                        ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredUsers.length - 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final actualIndex = index + 3;
                            final data = filteredUsers[actualIndex].data()
                                as Map<String, dynamic>;
                            final name = _displayName(data);
                            final score =
                                ((data['averageScore'] ?? 0) as num).toDouble();
                            final interviews = data['totalInterviews'] ?? 0;
                            final isCurrent =
                                filteredUsers[actualIndex].id == currentUser?.uid;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isCurrent ? accent.withOpacity(0.18) : card,
                                borderRadius: BorderRadius.circular(18),
                                border: isCurrent
                                    ? Border.all(color: accent.withOpacity(0.45))
                                    : null,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getRankColor(actualIndex),
                                  child: Text(
                                    "${actualIndex + 1}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  "$interviews interviews",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "${score.toStringAsFixed(1)}/10",
                                      style: GoogleFonts.poppins(
                                        color: green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (isCurrent)
                                      Text(
                                        "You",
                                        style: GoogleFonts.poppins(
                                          color: accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _topUserCard(
    QueryDocumentSnapshot user,
    int rank,
    Color color,
    double avatarSize,
    double height,
  ) {
    final data = user.data() as Map<String, dynamic>;
    final name = _displayName(data);
    final score = ((data['averageScore'] ?? 0) as num).toDouble();
    final interviews = data['totalInterviews'] ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.95),
                color.withOpacity(0.55),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 18,
              ),
            ],
          ),
          child: Center(
            child: Text(
              "$rank",
              style: const TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 100,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "${score.toStringAsFixed(1)}/10",
          style: GoogleFonts.poppins(
            color: Colors.greenAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "$interviews interviews",
          style: GoogleFonts.poppins(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: avatarSize * 0.8,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.22),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }

  Color _getRankColor(int index) {
    if (index == 0) return Colors.amber;
    if (index == 1) return Colors.grey;
    if (index == 2) return Colors.brown;
    return accent;
  }
}