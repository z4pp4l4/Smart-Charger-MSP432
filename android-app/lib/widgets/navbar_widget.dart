import 'package:flutter/material.dart';


class BottomNavBar extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const BottomNavBar({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      leading: Icon(icon, color: Colors.teal.shade200),
      title: Text(title, style: const TextStyle(fontSize: 18)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}