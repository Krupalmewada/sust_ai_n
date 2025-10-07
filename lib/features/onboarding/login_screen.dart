import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 80),
            // Centered logo and title
            Center(
              child: Column(
                children: const [
                  Icon(Icons.eco, size: 48, color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'sustAiN',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Colors.green,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'A World Without Waste',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: (){
                      Navigator.pushNamed(context, '/name');
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Login'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: (){
                      Navigator.pushNamed(context, '/name');
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Create New Account'),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.g_mobiledata, color: Colors.white)),
                      SizedBox(width: 16),
                      CircleAvatar(backgroundColor: Colors.black, child: Icon(Icons.apple, color: Colors.white)),
                      SizedBox(width: 16),
                      CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.facebook, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}