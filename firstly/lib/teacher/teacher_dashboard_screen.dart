import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_assignment_screen.dart';
import 'edit_assignment_screen.dart'; // Make sure this screen is created

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  String? selectedClassId;
  List<Map<String, dynamic>> teacherClasses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherClasses();
  }

  Future<void> _loadTeacherClasses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('classes')
        .where('teacherId', isEqualTo: user.uid)
        .get();

    setState(() {
      teacherClasses = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'className': doc['className'],
        };
      }).toList();

      if (teacherClasses.isNotEmpty) {
        selectedClassId = teacherClasses.first['id'];
      }

      isLoading = false;
    });
  }

  void _confirmDelete(String assignmentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this assignment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true && selectedClassId != null) {
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(selectedClassId!)
          .collection('assignments')
          .doc(assignmentId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Class:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: selectedClassId,
              hint: const Text('Choose your class'),
              isExpanded: true,
              items: teacherClasses.map<DropdownMenuItem<String>>((cls) {
                return DropdownMenuItem<String>(
                  value: cls['id'] as String,
                  child: Text(cls['className'] as String),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedClassId = value;
                });
              },
            ),
            const SizedBox(height: 12),
            if (selectedClassId != null)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddAssignmentScreen(classId: selectedClassId!),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Assignment'),
              ),
            const SizedBox(height: 20),
            if (selectedClassId == null)
              const Center(child: Text('Please select a class to view assignments.'))
            else
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('classes')
                      .doc(selectedClassId!)
                      .collection('assignments')
                      .orderBy('dueDate')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final assignments = snapshot.data?.docs ?? [];

                    if (assignments.isEmpty) {
                      return const Center(child: Text('No assignments yet.'));
                    }

                    return ListView.builder(
                      itemCount: assignments.length,
                      itemBuilder: (context, index) {
                        final assignment = assignments[index];
                        final title = assignment['title'];
                        final dueDate = (assignment['dueDate'] as Timestamp).toDate();
                        final formattedDate =
                            '${dueDate.year}-${dueDate.month}-${dueDate.day}';

                        return Card(
                          child: ListTile(
                            title: Text(title),
                            subtitle: Text('Due: $formattedDate'),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditAssignmentScreen(
                                        classId: selectedClassId!,
                                        assignmentId: assignment.id,
                                      ),
                                    ),
                                  );
                                } else if (value == 'delete') {
                                  _confirmDelete(assignment.id);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
