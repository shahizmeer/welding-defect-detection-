import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'student_list_screen.dart';

class TeacherClassScreen extends StatefulWidget {
  const TeacherClassScreen({super.key});

  @override
  State<TeacherClassScreen> createState() => _TeacherClassScreenState();
}

class _TeacherClassScreenState extends State<TeacherClassScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890';
    return List.generate(6, (index) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return chars[(timestamp + index) % chars.length];
    }).join();
  }

  Future<void> _addClassDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add New Class'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Class Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final user = _auth.currentUser;
              if (controller.text.trim().isNotEmpty && user != null) {
                await _firestore.collection('classes').add({
                  'className': controller.text.trim(),
                  'joinCode': _generateJoinCode(),
                  'teacherId': user.uid,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editClassName(String docId, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Class Name'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _firestore.collection('classes').doc(docId).update({
                'className': controller.text.trim(),
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteClass(String docId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Delete this class?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _firestore.collection('classes').doc(docId).delete();
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text("Not logged in."));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Your Classes')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('classes')
            .where('teacherId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final classDocs = snapshot.data?.docs ?? [];

          if (classDocs.isEmpty) {
            return const Center(child: Text("No classes yet. Add one."));
          }

          return ListView.builder(
            itemCount: classDocs.length,
            itemBuilder: (context, index) {
              final classData = classDocs[index].data() as Map<String, dynamic>;
              final docId = classDocs[index].id;

              return ListTile(
                title: Text(classData['className'] ?? ''),
                subtitle: Text('Join Code: ${classData['joinCode'] ?? ''}'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentListScreen(classId: docId),
                    ),
                  );
                },
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editClassName(docId, classData['className'] ?? '');
                    } else if (value == 'delete') {
                      _deleteClass(docId);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit Name')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Class')),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addClassDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
