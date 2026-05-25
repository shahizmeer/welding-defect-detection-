import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:firstly/config/api_config.dart';

import 'teacher_assignment_detail_screen.dart';

class StudentProgressScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String classId;

  const StudentProgressScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.classId,
  });

  @override
  State<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

class _StudentProgressScreenState extends State<StudentProgressScreen> {
  List<Map<String, dynamic>> submissions = [];
  double? predictedFinalScore;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() => isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('submissions')
          .where('studentId', isEqualTo: widget.studentId)
          .get();

      final items = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        final assignmentId = data['assignmentId'];
        final assignmentTitle = data['assignmentTitle'] ?? 'Assignment';

        Timestamp? dueDate;
        if (assignmentId != null) {
          final assignmentDoc = await FirebaseFirestore.instance
              .collection('classes')
              .doc(widget.classId)
              .collection('assignments')
              .doc(assignmentId)
              .get();

          dueDate = assignmentDoc.data()?['dueDate'];
        }

        return {
          'title': assignmentTitle,
          'assignmentId': assignmentId,
          'status': data['gradingResult'] != null ? 'Graded' : 'Submitted',
          'grade': _calculateAdjustedScore(data['gradingResult'], data['defectLabel']),
          'timestamp': timestamp?.toDate(),
          'dueDate': dueDate?.toDate(),
          'defect': data['defectLabel'],
        };
      }).toList());

      setState(() {
        submissions = items;
      });

      await _loadPrediction();
    } catch (e) {
      debugPrint('Error loading submissions: $e');
    }

    setState(() => isLoading = false);
  }

  double? _extractScore(dynamic result) {
    if (result is String) {
      final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(result);
      if (match != null) {
        return double.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  double? _calculateAdjustedScore(dynamic gradingResult, dynamic defectLabel) {
    final score = _extractScore(gradingResult);
    if (score == null) return null;

    if (defectLabel == 'bad') {
      return -score;
    }

    return score;
  }

  Future<void> _loadPrediction() async {
    try {
      final taskScores = <double>[];

      for (var submission in submissions) {
        final grade = submission['grade'];
        final status = submission['status'];

        if (grade != null && status == 'Graded') {
          taskScores.add(grade);
        }
      }

      debugPrint('✅ Passing scores to backend: $taskScores');

      if (taskScores.isEmpty) {
        setState(() => predictedFinalScore = null);
        return;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.finalPredictUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'task_scores': taskScores}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          predictedFinalScore = data['predicted_final_score']?.toDouble();
        });
      } else {
        debugPrint('Prediction failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error during prediction: $e');
    }
  }

  List<FlSpot> _buildChartSpots() {
    final graded = submissions
        .asMap()
        .entries
        .where((e) => e.value['grade'] != null)
        .map((e) => FlSpot(
      (e.key + 1).toDouble(),
      (e.value['grade'] as double),
    ))
        .toList();
    return graded;
  }

  @override
  Widget build(BuildContext context) {
    final chartSpots = _buildChartSpots();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.studentName} Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSubmissions,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Submission History',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: submissions.isEmpty
                  ? const Center(child: Text('No submissions yet.'))
                  : ListView.builder(
                itemCount: submissions.length,
                itemBuilder: (context, index) {
                  final item = submissions[index];
                  final submitTime = item['timestamp'] != null
                      ? '${item['timestamp'].year}-${item['timestamp'].month.toString().padLeft(2, '0')}-${item['timestamp'].day.toString().padLeft(2, '0')} ${item['timestamp'].hour}:${item['timestamp'].minute.toString().padLeft(2, '0')}'
                      : '-';

                  return Card(
                    child: ListTile(
                      title:
                      Text(item['title'] ?? 'Untitled Task'),
                      subtitle: Text(
                          'Status: ${item['status']} | Submitted: $submitTime'),
                      trailing: item['grade'] != null
                          ? Text(
                        'Grade: ${item['grade']}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: (item['grade'] as double) < 0
                              ? Colors.red
                              : Colors.black,
                        ),
                      )
                          : const Text('Pending'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TeacherAssignmentDetailScreen(
                                  assignmentId: item['assignmentId'],
                                  assignmentTitle: item['title'],
                                  studentId: widget.studentId,
                                ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            const Text('Performance Overview',
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: chartSpots.isEmpty
                  ? const Center(
                  child: Text('No graded assignments yet'))
                  : LineChart(
                LineChartData(
                  titlesData: FlTitlesData(show: false),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: chartSpots,
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.blue,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              predictedFinalScore != null
                  ? 'Predicted Final Mark: ${predictedFinalScore!.toStringAsFixed(1)}%'
                  : 'Predicted Final Mark: Not enough data',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
