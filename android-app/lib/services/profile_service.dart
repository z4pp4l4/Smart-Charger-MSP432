import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class ProfileService {
  static const String _prefix = 'user_profile_';

  static Future<void> saveProfile(String username, UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${username.trim().toLowerCase()}';
    
    final jsonData = jsonEncode(profile.toMap());
    await prefs.setString(key, jsonData);
    
    print('DEBUG: Saved profile for [$username] to key [$key]: $jsonData');
  }

  static Future<UserProfile> loadProfile(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${username.trim().toLowerCase()}';
    
    final jsonData = prefs.getString(key);
    print('DEBUG: Loading profile for [$username] from key [$key]. Found: $jsonData');

    if (jsonData == null) {
      return UserProfile(); // Returns default '--' values
    }

    try {
      final Map<String, dynamic> map = jsonDecode(jsonData);
      return UserProfile.fromMap(map);
    } catch (e) {
      print('DEBUG: Error decoding profile: $e');
      return UserProfile();
    }
  }
}
