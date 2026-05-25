import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AssignmentDetailScreen extends StatelessWidget {
  final String assignmentId;
  final String assignmentTitle;
  final DateTime dueDate;

  const AssignmentDetailScreen({
    super.key,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.dueDate,
  });

  Future<QueryDocumentSnapshot?> _getSubmission() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final submissions = await FirebaseFirestore.instance
        .collection('submissions')
        .where('assignmentId', isEqualTo: assignmentId)
        .where('studentId', isEqualTo: userId)
        .limit(1)
        .get();

    return submissions.docs.isNotEmpty ? submissions.docs.first : null;
  }

  Future<void> _deleteSubmission(BuildContext context, String submissionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this submission? You can resubmit after deleting.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('submissions').doc(submissionId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submission deleted')),
        );
        Navigator.pop(context, true); // return true so Home refreshes
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(assignmentTitle)),
      body: FutureBuilder<QueryDocumentSnapshot?>(
        future: _getSubmission(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final submission = snapshot.data;

          if (submission != null) {
            final data = submission.data() as Map<String, dynamic>;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.containsKey('timestamp'))
                    Text(
                      'Submitted on: ${data['timestamp'].toDate()}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Grading Result: ${data['gradingResult'] ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (data.containsKey('score'))
                    Text(
                      'Score: ${data['score']}%',
                      style: const TextStyle(fontSize: 16),
                    ),
                  if (data.containsKey('defectLabel'))
                    Text(
                      'Defect: ${data['defectLabel']}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  const SizedBox(height: 16),
                  const Text('Processed Image:', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                  Image.network(
                    data['processedImageUrl'] ?? '',
                    height: 250,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 100),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _deleteSubmission(context, submission.id),
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete Submission'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('You have not submitted this assignment yet.'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/submit');
                    },
                    child: const Text('Submit Now'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
