import 'package:flutter/material.dart';

class MedicineDetailScreen extends StatelessWidget {
  const MedicineDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine Details'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication_liquid, size: 64, color: Colors.deepPurple),
            SizedBox(height: 16),
            Text(
              'Medicine Detail Screen',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Functionality not yet implemented'),
          ],
        ),
      ),
    );
  }
}

