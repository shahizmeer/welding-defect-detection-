import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditAssignmentScreen extends StatefulWidget {
  final String classId;
  final String assignmentId;

  const EditAssignmentScreen({
    super.key,
    required this.classId,
    required this.assignmentId,
  });

  @override
  State<EditAssignmentScreen> createState() => _EditAssignmentScreenState();
}

class _EditAssignmentScreenState extends State<EditAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  DateTime? _selectedDueDate;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignmentDetails();
  }

  Future<void> _loadAssignmentDetails() async {
    final doc = await FirebaseFirestore.instance
        .collection('classes')
        .doc(widget.classId)
        .collection('assignments')
        .doc(widget.assignmentId)
        .get();

    final data = doc.data();
    if (data != null) {
      setState(() {
        _titleController.text = data['title'];
        _selectedDueDate = (data['dueDate'] as Timestamp).toDate();
        isLoading = false;
      });
    }
  }

  Future<void> _updateAssignment() async {
    if (!_formKey.currentState!.validate() || _selectedDueDate == null) return;

    await FirebaseFirestore.instance
        .collection('classes')
        .doc(widget.classId)
        .collection('assignments')
        .doc(widget.assignmentId)
        .update({
      'title': _titleController.text.trim(),
      'dueDate': _selectedDueDate,
    });

    Navigator.pop(context); // Return to dashboard
  }

  void _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Assignment')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Assignment Title'),
                validator: (value) =>
                value == null || value.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDueDate == null
                          ? 'No date selected'
                          : 'Due Date: ${_selectedDueDate!.year}-${_selectedDueDate!.month}-${_selectedDueDate!.day}',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickDueDate,
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Pick Date'),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _updateAssignment,
                child: const Text('Update Assignment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
