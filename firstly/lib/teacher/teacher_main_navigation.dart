import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'teacher_dashboard_screen.dart';
import 'teacher_classes_screen.dart';
import 'teacher_profile_screen.dart';

class TeacherMainNavigation extends StatefulWidget {
  const TeacherMainNavigation({super.key});

  @override
  State<TeacherMainNavigation> createState() => _TeacherMainNavigationState();
}

class _TeacherMainNavigationState extends State<TeacherMainNavigation> {
  int _currentIndex = 0;
  Widget? _homeScreen;

  @override
  void initState() {
    super.initState();
    _loadTeacherClass();
  }

  void _loadTeacherClass() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('classes')
        .where('teacherId', isEqualTo: user.uid) // Ensure this field is consistent in Firestore
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        _homeScreen = const TeacherDashboardScreen();
      });
    } else {
      setState(() {
        _homeScreen = const Center(child: Text('No class found. Please create one.'));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget?> screens = [
      _homeScreen ?? const Center(child: CircularProgressIndicator()),
      const TeacherClassScreen(),
      const TeacherProfileScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex]!,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.class_), label: 'Classes'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
