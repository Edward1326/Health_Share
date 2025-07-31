import 'package:flutter/material.dart';
import 'package:health_share/screens/files/files.dart';
import 'package:health_share/screens/files/folder.dart';
import 'package:health_share/screens/home/home.dart';
import 'package:health_share/screens/login/login.dart';
import 'package:health_share/screens/profile/profile.dart';
import 'package:health_share/screens/settings/settings.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/home': (context) => const HomeScreen(),
  '/login': (context) => const LoginScreen(),
  '/profile': (context) => const ProfileScreen(),
  '/settings': (context) => const SettingsScreen(),
  '/files': (context) => const FileScreen(),
  '/folder': (context) => const FolderScreen(),
};
