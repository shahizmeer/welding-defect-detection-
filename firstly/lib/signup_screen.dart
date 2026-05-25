import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../teacher/teacher_main_navigation.dart';
import '../student/student_main_navigation.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _matricCardController = TextEditingController();
  final _staffIdController = TextEditingController();

  String _selectedRole = 'Student';
  bool hidePassword = true;

  void handleRegister() async {
    final emailInput = _emailController.text.trim();
    final email = emailInput.contains('@') ? emailInput : '$emailInput@example.com';
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();
    final username = _usernameController.text.trim();
    final matricCard = _matricCardController.text.trim();
    final staffId = _staffIdController.text.trim();

    // Basic validation
    if (password != confirm) {
      showSnack("Passwords do not match");
      return;
    }

    if (username.isEmpty) {
      showSnack("Username is required");
      return;
    }

    if (_selectedRole == 'Student' && (matricCard.isEmpty || matricCard.length < 5)) {
      showSnack("Matric Card must atleast be 5 characters");
      return;
    }

    if (_selectedRole == 'Teacher' && (staffId.isEmpty || staffId.length < 5)) {
      showSnack("Staff ID must atleast be 5 characters");
      return;
    }

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final uid = userCredential.user!.uid;

      final Map<String, dynamic> userData = {
        'email': email,
        'username': username,
        'role': _selectedRole,
        'createdAt': Timestamp.now(),
      };

      if (_selectedRole == 'Student') {
        userData['matricCard'] = matricCard;
      } else if (_selectedRole == 'Teacher') {
        userData['staffId'] = staffId;
      }

      // Save to Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set(userData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registration successful! Please login."),
          backgroundColor: Colors.green,
        ),
      );


      // Wait 2 seconds, then go to login
      await Future.delayed(const Duration(seconds: 2));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String errorMsg = 'Registration failed';
      if (e.code == 'email-already-in-use') {
        errorMsg = 'Email already in use.';
      } else if (e.code == 'invalid-email') {
        errorMsg = 'Invalid email format.';
      } else if (e.code == 'weak-password') {
        errorMsg = 'Password must be at least 6 characters.';
      } else {
        errorMsg = 'Error: ${e.message}';
      }

      showSnack(errorMsg);
    } catch (e) {
      showSnack("Unexpected error: $e");
    }
  }



  void showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Image.asset('assets/logo.png', height: 150),
                const SizedBox(height: 32),
                const Text("Register",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  items: const [
                    DropdownMenuItem(value: 'Student', child: Text('Student')),
                    DropdownMenuItem(value: 'Teacher', child: Text('Teacher')),
                  ],
                  onChanged: (value) => setState(() => _selectedRole = value!),
                  decoration: const InputDecoration(
                    labelText: "Register as",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.school),
                  ),
                ),
                const SizedBox(height: 20),

                if (_selectedRole == 'Student')
                  TextField(
                    controller: _matricCardController,
                    decoration: const InputDecoration(
                      labelText: "Matric Card Number",
                      prefixIcon: Icon(Icons.credit_card),
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (_selectedRole == 'Teacher')
                  TextField(
                    controller: _staffIdController,
                    decoration: const InputDecoration(
                      labelText: "Staff ID",
                      prefixIcon: Icon(Icons.work),
                      border: OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 20),

                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: "Full Name / Username",
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: hidePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(hidePassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => hidePassword = !hidePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Confirm Password",
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 10, 122, 250),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text("Register"),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Already have an account? Login"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
