import 'package:flutter/material.dart';

class EditMedicineScreen extends StatelessWidget {
  const EditMedicineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Medicine'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit, size: 64, color: Colors.deepPurple),
            SizedBox(height: 16),
            Text(
              'Edit Medicine Screen',
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

