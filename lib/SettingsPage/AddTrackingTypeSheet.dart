import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:retracker/Utils/CustomSnackBar.dart';
import '../Utils/GuestAuthService.dart';
import '../Utils/LocalDatabaseService.dart';

// lib/SettingsPage/AddTrackingTypeSheet.dart
void showAddtrackingTypeSheet(
    BuildContext context,
    GlobalKey<FormState> formKey,
    TextEditingController titleController,
    StateSetter setState,
    VoidCallback onTypeAdded, // Add this callback
    ) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.53,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add Custom Type',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'Type',
                          hintText: 'Enter new tracking type',
                          prefixIcon: const Icon(Icons.title),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a tracking type';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            // Submit button
            Container(
              padding: const EdgeInsets.all(24),
              child: FilledButton.icon(                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      String trackingTitle = titleController.text.trim();

                      if (await GuestAuthService.isGuestMode()) {
                        // Save to local database for guest users
                        final localDb = LocalDatabaseService();
                        final currentList = await localDb.getProfileData('custom_trackingType', defaultValue: <String>[]);
                        List<String> updatedList = List<String>.from(currentList);
                        updatedList.add(trackingTitle);
                        
                        await localDb.saveProfileData('custom_trackingType', updatedList);
                      } else {
                        // Save to Firebase for authenticated users
                        String uid = FirebaseAuth.instance.currentUser!.uid;
                        DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data/custom_trackingType');

                        DataSnapshot snapshot = await databaseRef.get();
                        List<String> currentList = [];
                        if (snapshot.exists) {
                          currentList = List<String>.from(snapshot.value as List);
                        }

                        currentList.add(trackingTitle);
                        await databaseRef.set(currentList);
                      }

                      titleController.clear();
                      Navigator.pop(context);

                      customSnackBar(
                        context: context,
                        message: 'New tracking type added successfully',
                      );

                      onTypeAdded(); // Call the callback to refresh the dropdown
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.error, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Failed to add Type'),
                            ],
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Save Type'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}