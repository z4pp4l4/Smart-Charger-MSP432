import 'package:first_tuto/models/user_profile.dart';
import 'package:first_tuto/views/pages/login_page.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // We keep a local state of the profile to pass around if needed, 
  // but LoginPage will load the correct one from disk.
  UserProfile _profile = UserProfile();

  void _updateProfile(UserProfile profile) {
    setState(() {
      _profile = profile;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal.shade200,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: LoginPage(
        onUpdateProfile: _updateProfile,
      ),
    );
  }
}
