import 'package:flutter/material.dart';
import 'package:health_share/screens/files/files_main.dart';
import 'package:health_share/screens/groups/groups_main.dart';
import 'package:health_share/screens/home/home.dart';
import 'package:health_share/screens/login/login.dart';
import 'package:health_share/screens/organizations/all_orgs/orgs_screen.dart';
import 'package:health_share/screens/organizations/joined_org/my_orgs.dart';
import 'package:health_share/screens/profile/profile_main.dart';
import 'package:health_share/screens/settings/settings_main.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/home': (context) => const HomeScreen(),
  '/login': (context) => const LoginScreen(),
  '/profile': (context) => const ProfileScreen(),
  '/settings': (context) => const SettingsScreen(),
  '/files': (context) => const FilesScreen(),
  '/groups': (context) => const GroupsScreen(),
  '/organizations': (context) => const OrgsScreen(),
  '/your-organizations': (context) => const YourOrgsScreen(),
};
