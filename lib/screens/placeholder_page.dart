import 'package:flutter/material.dart' hide Text;

import '../widgets/localized_text.dart';

/// Reusable placeholder for screens not yet built
class PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderPage({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: const Color(0xFF0D4F7C)),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Coming Soon', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
