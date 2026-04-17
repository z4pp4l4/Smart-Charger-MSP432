import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import 'edit_profile_page.dart';
import 'login_page.dart';
import 'notifications_page.dart';
import '../../widgets/navbar_widget.dart';

class ProfilePage extends StatelessWidget {
  final String username;
  final UserProfile profile;
  final Function(UserProfile) onUpdateProfile;
  final Function(UserProfile) onLogoutUpdateProfile;

  const ProfilePage({
    super.key,
    required this.username,
    required this.profile,
    required this.onUpdateProfile,
    required this.onLogoutUpdateProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: Colors.teal.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage('https://www.w3schools.com/w3images/avatar2.png'),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(profile.email, style: const TextStyle(fontSize: 14, color: Colors.white70)),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfilePage(
                          username: username,
                          onSaveProfile: (n, s, e, ph) {
                            final updated = UserProfile(
                              name: n,
                              surname: s,
                              email: e,
                              phone: ph,
                              savingMode: profile.savingMode,
                              minThreshold: profile.minThreshold,
                              maxThreshold: profile.maxThreshold,
                            );
                            onUpdateProfile(updated);
                          },
                          currentName: profile.name,
                          currentSurname: profile.surname,
                          currentEmail: profile.email,
                          currentPhone: profile.phone,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          BottomNavBar(
            icon: Icons.notifications,
            title: 'Notification',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationPage()),
              );
            },
          ),
          BottomNavBar(
            icon: Icons.exit_to_app,
            title: 'Log out',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => LoginPage(
                    onUpdateProfile: onLogoutUpdateProfile,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
