import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherAssignmentDetailScreen extends StatelessWidget {
  final String assignmentId;
  final String assignmentTitle;
  final String studentId;

  const TeacherAssignmentDetailScreen({
    super.key,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.studentId,
  });

  Future<DocumentSnapshot?> _getStudentSubmission() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('submissions')
        .where('assignmentId', isEqualTo: assignmentId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty ? snapshot.docs.first : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Submission: $assignmentTitle')),
      body: FutureBuilder<DocumentSnapshot?>(
        future: _getStudentSubmission(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final submission = snapshot.data;

          if (submission != null && submission.exists) {
            final data = submission.data() as Map<String, dynamic>;

            final submittedDate = data['timestamp'] != null
                ? (data['timestamp'] as Timestamp).toDate().toString()
                : 'No timestamp';
            final gradingResult =
                data['gradingResult']?.toString() ?? 'Pending';
            final score = data['score'];
            final defect = data['defectLabel']?.toString();
            final imageUrl = data['processedImageUrl']?.toString() ?? '';

            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  Text(
                    'Submitted on: $submittedDate',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Grading Result: $gradingResult',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (defect != null && defect.trim().isNotEmpty)
                    Text(
                      'Defect Detected: $defect',
                      style: TextStyle(
                        fontSize: 16,
                        color: defect == 'bad' ? Colors.red : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                  if (score != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Score: ${score.toString()}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: (score is num && score < 0)
                              ? Colors.red
                              : Colors.black,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                  const Text('Processed Image:',
                      style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                  imageUrl.isNotEmpty
                      ? GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullscreenImageScreen(
                            imageUrl: imageUrl,
                          ),
                        ),
                      );
                    },
                    child: Image.network(
                      imageUrl,
                      height: 250,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        size: 100,
                      ),
                    ),
                  )
                      : const Text('No processed image found.'),
                ],
              ),
            );
          } else {
            return const Center(
                child: Text('No submission found for this assignment.'));
          }
        },
      ),
    );
  }
}

class FullscreenImageScreen extends StatelessWidget {
  final String imageUrl;

  const FullscreenImageScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Image Viewer")),
      backgroundColor: Colors.black,
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.white, size: 100),
          ),
        ),
      ),
    );
  }
}
