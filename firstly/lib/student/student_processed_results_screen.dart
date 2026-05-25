import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

class StudentProcessedResultsScreen extends StatefulWidget {
  const StudentProcessedResultsScreen({super.key});

  @override
  State<StudentProcessedResultsScreen> createState() => _StudentProcessedResultsScreenState();
}

class _StudentProcessedResultsScreenState extends State<StudentProcessedResultsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Processed Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear History',
            onPressed: _confirmDeleteAllHistory,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showImageSourceDialog,
        child: const Icon(Icons.upload),
        tooltip: 'Upload New Image',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search by result (e.g. Good, Bad)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('processed_results')
                  .where('studentId', isEqualTo: userId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No processed results found.'));
                }

                final results = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final gradingResult = data['gradingResult'] ?? 'Pending';
                  final processedImageUrl = data['processedImageUrl'] ?? '';
                  final originalImageUrl = data['originalImageUrl'] ?? '';
                  final timestamp = data['timestamp'] is Timestamp
                      ? (data['timestamp'] as Timestamp).toDate()
                      : DateTime.now();

                  return {
                    'gradingResult': gradingResult,
                    'processedImageUrl': processedImageUrl,
                    'originalImageUrl': originalImageUrl,
                    'timestamp': timestamp,
                  };
                }).where((result) {
                  return result['gradingResult']
                      .toString()
                      .toLowerCase()
                      .contains(_searchQuery);
                }).toList();

                if (results.isEmpty) {
                  return const Center(child: Text('No matching results found.'));
                }

                return ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(result['timestamp']);
                    final isGood = result['gradingResult'].contains('Good');

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        leading: GestureDetector(
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              backgroundColor: Colors.transparent,
                              child: InteractiveViewer(
                                child: Image.network(
                                  result['processedImageUrl'],
                                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 100),
                                ),
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              result['processedImageUrl'],
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(result['gradingResult'])),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isGood ? Colors.green[100] : Colors.red[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isGood ? 'Good Weld' : 'Bad Weld',
                                style: TextStyle(
                                  color: isGood ? Colors.green[800] : Colors.red[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Processed on: $formattedDate'),
                            if (result['originalImageUrl'] != '')
                              GestureDetector(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    backgroundColor: Colors.transparent,
                                    child: InteractiveViewer(
                                      child: Image.network(result['originalImageUrl']),
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'View Original Image',
                                  style: TextStyle(color: Colors.blue.shade700, decoration: TextDecoration.underline),
                                ),
                              ),
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
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take a Photo'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text('Choose from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800);
    if (pickedFile == null) return;

    File imageFile = File(pickedFile.path);

    final fileName = path.basename(imageFile.path);
    final storageRef = FirebaseStorage.instance.ref().child('uploads/$fileName');
    final uploadTask = await storageRef.putFile(imageFile);
    final imageUrl = await uploadTask.ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('processed_results').add({
      'studentId': FirebaseAuth.instance.currentUser!.uid,
      'originalImageUrl': imageUrl,
      'processedImageUrl': imageUrl,
      'gradingResult': 'Pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image uploaded successfully')),
    );
  }

  void _confirmDeleteAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text('This will permanently delete all processed results including images from Cloudinary.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAllProcessedResults();
    }
  }

  Future<void> _deleteAllProcessedResults() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final querySnapshot = await FirebaseFirestore.instance
        .collection('processed_results')
        .where('studentId', isEqualTo: user.uid)
        .get();

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final originalUrl = data['originalImageUrl'] ?? '';
      final processedUrl = data['processedImageUrl'] ?? '';

      await _deleteFromCloudinary(originalUrl);
      await _deleteFromCloudinary(processedUrl);

      await doc.reference.delete();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All processed history cleared.')),
    );
  }

  Future<void> _deleteFromCloudinary(String imageUrl) async {
    if (imageUrl.isEmpty) return;

    try {
      final publicId = Uri.parse(imageUrl).pathSegments.last.split('.').first;
      const cloudName = 'duccfjeev';
      const apiKey = '428733196321522';
      const apiSecret = '6tDUGrBoUnIdQL5dBeTO9B10sg8';

      final String basicAuth = 'Basic ' + base64Encode(utf8.encode('$apiKey:$apiSecret'));
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');

      final response = await http.post(
        url,
        headers: {'Authorization': basicAuth},
        body: {'public_id': publicId},
      );

      if (response.statusCode != 200) {
        debugPrint('Cloudinary delete failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error deleting Cloudinary image: $e');
    }
  }
}
