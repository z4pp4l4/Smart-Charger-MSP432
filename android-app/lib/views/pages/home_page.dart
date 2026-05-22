import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import 'package:battery_plus/battery_plus.dart';
import 'profile_page.dart';
import 'phone_page.dart';
import 'esp_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.username,
    required this.profile,
    required this.onUpdateProfile,
  });

  final String title;
  final String username;
  final UserProfile profile;
  final Function(UserProfile) onUpdateProfile;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  late UserProfile _currentProfile;
  BatteryState _batteryState = BatteryState.unknown;

  @override
  void initState() {
    super.initState();
    _currentProfile = widget.profile;
  }

  void _handleBatteryStateChanged(BatteryState state) {
    setState(() => _batteryState = state);
  }
  void _handleProfileUpdate(UserProfile updatedProfile) async {
    await ProfileService.saveProfile(widget.username, updatedProfile);

    if (!mounted) return;

    setState(() {
      _currentProfile = updatedProfile;
    });
    
    widget.onUpdateProfile(updatedProfile);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Battery App'), centerTitle: true),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.battery_0_bar_rounded), label: 'ESP32'),
          NavigationDestination(icon: Icon(Icons.phone_android), label: 'Phone'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          EspPage(profile: _currentProfile, batteryState: _batteryState),
          PhonePage(
            username: widget.username,
            profile: _currentProfile,
            onUpdateProfile: _handleProfileUpdate,
            onBatteryStateChanged: _handleBatteryStateChanged,
          ),
          ProfilePage(
            username: widget.username,
            profile: _currentProfile,
            onUpdateProfile: _handleProfileUpdate,
            onLogoutUpdateProfile: widget.onUpdateProfile,
          ),
        ],
      ),
    );
  }
}
