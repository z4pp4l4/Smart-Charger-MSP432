import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';

class EditProfilePage extends StatefulWidget {
  final String username;
  final Function(String, String, String, String) onSaveProfile;
  final String currentName;
  final String currentSurname;
  final String currentEmail;
  final String currentPhone;

  const EditProfilePage({
    super.key,
    required this.username,
    required this.onSaveProfile,
    required this.currentName,
    required this.currentSurname,
    required this.currentEmail,
    required this.currentPhone,
  });

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _surnameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _surnameController = TextEditingController(text: widget.currentSurname);
    _emailController = TextEditingController(text: widget.currentEmail);
    _phoneController = TextEditingController(text: widget.currentPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    final updated = UserProfile(
      name:    _nameController.text,
      surname: _surnameController.text,
      email:   _emailController.text,
      phone:   _phoneController.text,
    );

    // 1. Save to disk (Async operation)
    await ProfileService.saveProfile(widget.username, updated); 
    
    // 2. Check if we are still on the screen before updating UI or popping
    if (!mounted) return;
    
    widget.onSaveProfile(updated.name, updated.surname, updated.email, updated.phone);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              TextField(controller: _surnameController, decoration: const InputDecoration(labelText: 'Surname')),
              const SizedBox(height: 10),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 10),
              TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _saveProfile, child: const Text('Save Profile')),
            ],
          ),
        ),
      ),
    );
  }
}
