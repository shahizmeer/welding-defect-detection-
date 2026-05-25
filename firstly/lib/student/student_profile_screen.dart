import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  String name = '';
  String matricCard = '';
  String email = '';
  String? className;
  String? classCode;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data();

    if (userData != null) {
      name = userData['username'] ?? 'No Name';
      matricCard = userData['matricCard'] ?? 'No Matric';
      email = user.email ?? 'No Email';

      final joinedClassId = userData['joinedClassId'];
      if (joinedClassId != null) {
        final classDoc = await FirebaseFirestore.instance
            .collection('classes')
            .doc(joinedClassId)
            .get();
        if (classDoc.exists) {
          className = classDoc['className'];
          classCode = classDoc['joinCode'];
        }
      }
    }

    setState(() => loading = false);
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(name),
            const SizedBox(height: 16),

            const Text('Matric Card', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(matricCard),
            const SizedBox(height: 16),

            const Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(email),
            const SizedBox(height: 16),

            const Text('Joined Class', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (className != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Class: $className'),
                  Text('Join Code: $classCode'),
                ],
              )
            else
              const Text('You have not joined any class yet.'),

            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password change not implemented yet')),
                );
              },
              icon: const Icon(Icons.lock_reset),
              label: const Text('Reset Password'),
            ),
            const Spacer(),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
