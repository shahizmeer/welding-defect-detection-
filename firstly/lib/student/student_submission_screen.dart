import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firstly/config/api_config.dart';

class StudentSubmissionScreen extends StatefulWidget {
  const StudentSubmissionScreen({super.key});

  @override
  State<StudentSubmissionScreen> createState() => _StudentSubmissionScreenState();
}

class _StudentSubmissionScreenState extends State<StudentSubmissionScreen> {
  File? _selectedImage;
  String? _gradingResult;
  String? _processedImageUrl;
  String? _originalImageUrl;
  bool _isSubmitting = false;
  bool _autoSaveToHistory = true;

  String? selectedAssignmentId;
  List<Map<String, dynamic>> assignments = [];
  List<Map<String, dynamic>> _localProcessedResults = [];
  String? classId;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    classId = userDoc['joinedClassId'];

    final assignmentSnap = await FirebaseFirestore.instance
        .collection('classes')
        .doc(classId)
        .collection('assignments')
        .orderBy('dueDate')
        .get();

    final submissionSnap = await FirebaseFirestore.instance
        .collection('submissions')
        .where('studentId', isEqualTo: userId)
        .get();

    final submittedAssignmentIds = submissionSnap.docs.map((doc) => doc['assignmentId']).toSet();

    final filteredAssignments = assignmentSnap.docs.where((doc) {
      return !submittedAssignmentIds.contains(doc.id);
    }).map((doc) => {
      'id': doc.id,
      'title': doc['title'],
    }).toList();

    setState(() {
      assignments = filteredAssignments;
      if (!assignments.any((a) => a['id'] == selectedAssignmentId)) {
        selectedAssignmentId = null;
      }
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _gradingResult = null;
        _processedImageUrl = null;
        _originalImageUrl = null;
      });
    }
  }

  Future<void> _submitImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.predictUrl),
      );
      request.files.add(await http.MultipartFile.fromPath('file', _selectedImage!.path));
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final userId = FirebaseAuth.instance.currentUser!.uid;
        final resultText = "Score: ${data['score']}%\nDefect: ${data['defect']}";
        final serverTime = Timestamp.now();

        setState(() {
          _gradingResult = resultText;
          _processedImageUrl = data['image_url'];
          _originalImageUrl = data['original_image_url'] ?? '';
        });

        if (_autoSaveToHistory) {
          final entry = {
            'studentId': userId,
            'gradingResult': resultText,
            'processedImageUrl': _processedImageUrl!,
            'timestamp': serverTime.toDate(),
          };

          await FirebaseFirestore.instance.collection('processed_results').add({
            'studentId': userId,
            'gradingResult': resultText,
            'processedImageUrl': _processedImageUrl,
            'originalImageUrl': _originalImageUrl ?? '',
            'timestamp': serverTime,
          });

          setState(() {
            _localProcessedResults.insert(0, entry);
          });
        }
      } else {
        throw Exception('Failed to process image');
      }
    } catch (e) {
      setState(() {
        _gradingResult = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitToAssignment() async {
    if (selectedAssignmentId == null || _processedImageUrl == null || _gradingResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select assignment and process the image first.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Submission"),
        content: const Text("Are you sure you want to submit this task? You cannot resubmit unless you delete your current submission."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Submit")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final selectedAssignment = assignments.firstWhere((a) => a['id'] == selectedAssignmentId);

      final scoreMatch = RegExp(r'Score:\s*(\d+(\.\d+)?)%').firstMatch(_gradingResult!);
      double? score = scoreMatch != null ? double.tryParse(scoreMatch.group(1)!) : null;
      final isBad = _gradingResult!.toLowerCase().contains("bad weld");
      if (score != null && isBad) {
        score = -score;
      }

      await FirebaseFirestore.instance.collection('submissions').add({
        'assignmentId': selectedAssignmentId,
        'assignmentTitle': selectedAssignment['title'],
        'studentId': userId,
        'classId': classId,
        'originalImageUrl': _originalImageUrl ?? '',
        'processedImageUrl': _processedImageUrl!,
        'gradingResult': _gradingResult!,
        'score': score,
        'defectLabel': isBad ? 'bad' : 'good',
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submission successful')),
      );

      await _loadAssignments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: $e')),
      );
    }
  }

  Future<bool> _checkImageAvailability(String url, {int retries = 10}) async {
    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) return true;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(
          child: Image.network(imageUrl),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Welding Assignment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text("Auto-save to history"),
                Switch(
                  value: _autoSaveToHistory,
                  onChanged: (val) {
                    setState(() => _autoSaveToHistory = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _selectedImage != null
                ? Center(child: Image.file(_selectedImage!, height: 250))
                : Container(
              height: 250,
              color: Colors.grey[200],
              child: const Center(child: Text('No image selected')),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: const Text('Pick Image'),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Process Image'),
            ),
            const SizedBox(height: 24),
            if (_gradingResult != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedAssignmentId,
                    items: assignments.map((assignment) {
                      return DropdownMenuItem<String>(
                        value: assignment['id'],
                        child: Text(assignment['title']),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => selectedAssignmentId = value),
                    decoration: const InputDecoration(labelText: 'Select Assignment to Submit'),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _gradingResult!.contains("Bad Weld")
                            ? Colors.red.shade50
                            : _gradingResult!.contains("Good Weld")
                            ? Colors.green.shade50
                            : Colors.blue.shade50,
                        border: Border.all(
                          color: _gradingResult!.contains("Bad Weld")
                              ? Colors.red
                              : _gradingResult!.contains("Good Weld")
                              ? Colors.green
                              : Colors.blue,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _gradingResult!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: _gradingResult!.contains("Bad Weld")
                              ? Colors.red[800]
                              : _gradingResult!.contains("Good Weld")
                              ? Colors.green[800]
                              : Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_processedImageUrl != null)
                    FutureBuilder<bool>(
                      future: _checkImageAvailability(_processedImageUrl!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.data == true) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(child: Text("Processed Image:")),
                              const SizedBox(height: 10),
                              Center(
                                child: GestureDetector(
                                  onTap: () => _showImageDialog(_processedImageUrl!),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      _processedImageUrl!,
                                      height: 250,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        } else {
                          return const Text("Processed image is not ready yet.");
                        }
                      },
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _submitToAssignment,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Submit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
