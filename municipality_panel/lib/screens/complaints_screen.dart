import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ComplaintsScreen extends StatefulWidget {
  final String municipalityId;
  const ComplaintsScreen({super.key, required this.municipalityId});

  @override
  _ComplaintsScreenState createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  late Stream<QuerySnapshot> _complaintsStream;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _complaintsStream = FirebaseFirestore.instance
        .collection('Municipalities')
        .doc(widget.municipalityId)
        .collection('Complaints')
        .orderBy('createdAt', descending: true)
        .snapshots();

    _isLoading = false;
  }

  // Updates the status of a complaint (mark it as resolved)
  Future<void> _updateComplaintStatus(String complaintId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Municipalities')
          .doc(widget.municipalityId)
          .collection('Complaints')
          .doc(complaintId)
          .update({
        'status': 'resolved',
      });

      _showSnackbar('Complaint marked as resolved!');
    } catch (e) {
      _showSnackbar('Failed to update complaint status: $e');
    }
  }

  // Shows a snackbar with a message
  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Displays individual complaint details
  Widget _buildComplaintCard(DocumentSnapshot complaint) {
    final complaintData = complaint.data() as Map<String, dynamic>;
    final complaintId = complaint.id;
    final description = complaintData['description'] ?? '';
    final status = complaintData['status'] ?? 'open';
    final createdAt = (complaintData['createdAt'] as Timestamp).toDate();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      child: ListTile(
        title: Text('Complaint #$complaintId'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Description: $description'),
            const SizedBox(height: 5),
            Text('Status: $status'),
            const SizedBox(height: 5),
            Text('Reported on: ${createdAt.toLocal()}'),
          ],
        ),
        trailing: status != 'resolved'
            ? IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () => _updateComplaintStatus(complaintId),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              Future.delayed(const Duration(seconds: 2), () {
                setState(() {
                  _isLoading = false;
                });
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _complaintsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No complaints found.'));
                }

                final complaints = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: complaints.length,
                  itemBuilder: (context, index) {
                    return _buildComplaintCard(complaints[index]);
                  },
                );
              },
            ),
    );
  }
}