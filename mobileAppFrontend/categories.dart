import 'package:flutter/material.dart';
import 'login.dart';
import 'collections.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF252526),
      body: SafeArea(
        child: Column(
          children: [
            // Top buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Themes Button
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007ACC),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 36,
                        vertical: 18,
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Themes",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Impact',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  // Demo Button
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CollectionsPage()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 36,
                        vertical: 18,
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Demo',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Impact',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  // Log Out Button
                  ElevatedButton(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                      (route) => false,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007ACC),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 36,
                        vertical: 18,
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Log Out",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Impact',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Divider line
            Container(
              height: 4,
              width: double.infinity,
              color: const Color(0xFF007ACC),
            ),

            const SizedBox(height: 10),

            // Home Text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const CategoriesPage()),
                      ),
                      child: const Text(
                        'Home',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Impact',
                          letterSpacing: 0.5,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '>',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Impact',
                    ),
                  ),
                ],
              ),
            ),

            // Add Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 80,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF252526),
                    side: const BorderSide(
                      color: Color(0xFF007ACC),
                      width: 3,
                    ),
                    shape: const StadiumBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    '+',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF007ACC),
                    ),
                  ),
                ),
              ),
            ),

            // Placeholder content
            const Expanded(
              child: Center(
                child: Text(
                  "Categories Content",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Impact',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}