import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'assignment_detail_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  Map<String, dynamic>? joinedClass;

  @override
  void initState() {
    super.initState();
    _loadJoinedClass();
  }

  Future<void> _loadJoinedClass() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    final joinedClassId = userDoc.data()?['joinedClassId'];
    if (joinedClassId != null) {
      final classDoc = await FirebaseFirestore.instance.collection('classes').doc(joinedClassId).get();
      if (classDoc.exists) {
        setState(() {
          joinedClass = {
            'classId': joinedClassId,
            'className': classDoc['className'],
            'joinCode': classDoc['joinCode'],
          };
        });
      }
    }
  }

  Future<DocumentSnapshot?> _getSubmission(String assignmentId) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('submissions')
        .where('assignmentId', isEqualTo: assignmentId)
        .where('studentId', isEqualTo: userId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty ? snapshot.docs.first : null;
  }

  void _joinClassDialog() {
    final controller = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter Class Join Code'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. ABC123'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final code = controller.text.trim().toUpperCase();
              final classSnap = await FirebaseFirestore.instance
                  .collection('classes')
                  .where('joinCode', isEqualTo: code)
                  .limit(1)
                  .get();

              if (classSnap.docs.isNotEmpty && user != null) {
                final classDoc = classSnap.docs.first;
                final classId = classDoc.id;
                final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                final name = userDoc['username'] ?? 'Unnamed';
                final matric = userDoc['matricCard'] ?? 'No Matric';

                await FirebaseFirestore.instance
                    .collection('classes')
                    .doc(classId)
                    .collection('students')
                    .doc(user.uid)
                    .set({
                  'name': name,
                  'matricCard': matric,
                  'email': user.email,
                  'joinedAt': Timestamp.now(),
                });

                await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                  'joinedClassId': classId,
                });

                setState(() {
                  joinedClass = {
                    'classId': classId,
                    'className': classDoc['className'],
                    'joinCode': code,
                  };
                });

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Successfully joined class!')),
                );
              } else {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid class code')),
                );
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(int submitted, int total) {
    int notSubmitted = total - submitted;
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text("Your Submission Overview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(
                  color: Colors.green,
                  value: submitted.toDouble(),
                  title: 'Submitted',
                  titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                PieChartSectionData(
                  color: Colors.red,
                  value: notSubmitted.toDouble(),
                  title: 'Not Submitted',
                  titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
              sectionsSpace: 4,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        Text('$submitted of $total submitted', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Home')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Assignment Planner', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            joinedClass != null
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Class:', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 6),
                Text('Class Name: ${joinedClass!['className']}'),
                Text('Join Code: ${joinedClass!['joinCode']}'),
                const SizedBox(height: 20),
              ],
            )
                : const Text('You haven’t joined any class yet.'),
            const SizedBox(height: 20),
            Expanded(
              child: joinedClass == null
                  ? const Center(child: Text('Join a class to see assignments.'))
                  : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('classes')
                    .doc(joinedClass!['classId'])
                    .collection('assignments')
                    .orderBy('dueDate')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text('Error loading assignments'));
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final assignments = snapshot.data?.docs ?? [];
                  if (assignments.isEmpty) return const Center(child: Text('No assignments yet.'));

                  return FutureBuilder<List<bool>>(
                    future: Future.wait(assignments.map((a) async {
                      final submission = await _getSubmission(a.id);
                      return submission != null;
                    })),
                    builder: (context, snapshot2) {
                      if (!snapshot2.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final submissionStatuses = snapshot2.data!;
                      final submittedCount = submissionStatuses.where((s) => s).length;

                      return Column(
                        children: [
                          _buildPieChart(submittedCount, assignments.length),
                          Expanded(
                            child: ListView.builder(
                              itemCount: assignments.length,
                              itemBuilder: (context, index) {
                                final assignment = assignments[index];
                                final title = assignment['title'];
                                final dueDate = (assignment['dueDate'] as Timestamp).toDate();
                                final formattedDate = '${dueDate.year}-${dueDate.month}-${dueDate.day}';
                                final submitted = submissionStatuses[index];

                                return ListTile(
                                  title: Text(title),
                                  subtitle: Text('Due: $formattedDate'),
                                  trailing: Text(
                                    submitted ? 'Submitted' : 'Not Submitted',
                                    style: TextStyle(color: submitted ? Colors.green : Colors.red),
                                  ),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AssignmentDetailScreen(
                                          assignmentId: assignment.id,
                                          assignmentTitle: title,
                                          dueDate: dueDate,
                                        ),
                                      ),
                                    );
                                    setState(() {}); // ✅ Refresh on return
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _joinClassDialog,
        icon: const Icon(Icons.input),
        label: const Text('Join Class'),
      ),
    );
  }
}
