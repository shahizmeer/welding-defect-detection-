import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'student_progress_screen.dart';

class StudentListScreen extends StatelessWidget {
  final String classId;
  const StudentListScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Students in Class')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .collection('students')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No students in this class yet.'));
          }

          final students = snapshot.data!.docs;

          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              final name = student.data().toString().contains('name') ? student['name'] : 'No Name';
              final matric = student.data().toString().contains('matricCard') ? student['matricCard'] : 'No Matric';
              final uid = student.id;

              return ListTile(
                title: Text(name),
                subtitle: Text('Matric: $matric'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentProgressScreen(
                        studentId: uid, // keep using Firestore doc ID
                        studentName: name,
                        classId: classId,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
