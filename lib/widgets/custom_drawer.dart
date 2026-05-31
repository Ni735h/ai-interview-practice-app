import 'package:flutter/material.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF8F5F0), // Cream color
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF6366F1),
            ),
            child: Row(
              children: const [
                Icon(Icons.psychology, color: Colors.white, size: 40),
                SizedBox(width: 10),
                Text(
                  "AI Interview",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                )
              ],
            ),
          ),

          // Home
          ListTile(
            leading: const Icon(
              Icons.home,
              color: Colors.black,
            ),
            title: const Text(
              "Home",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
            },
          ),

          // Leaderboard
          ListTile(
            leading: const Icon(
              Icons.leaderboard,
              color: Colors.black,
            ),
            title: const Text(
              "Leaderboard",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {},
          ),

          // Login / Signup
          ListTile(
            leading: const Icon(
              Icons.login,
              color: Colors.black,
            ),
            title: const Text(
              "Login / Signup",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}