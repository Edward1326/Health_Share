import 'package:flutter/material.dart';

class MainNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const MainNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  void _handleNavigation(BuildContext context, int index) {
    if (index != selectedIndex) {
      onItemTapped(index);

      final routes = {
        0: '/home',
        1: '/files',
        2: '/groups',
        3: '/organizations', // Add this route
        4: '/profile',
      };

      if (routes.containsKey(index)) {
        Navigator.pushReplacementNamed(context, routes[index]!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context: context,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                index: 0,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.folder_outlined,
                activeIcon: Icons.folder,
                label: 'Files',
                index: 1,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.group_outlined,
                activeIcon: Icons.group,
                label: 'Groups',
                index: 2,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.apartment_outlined,
                activeIcon: Icons.apartment,
                label: 'Organizations',
                index: 3,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => _handleNavigation(context, index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF667EEA).withOpacity(0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey(isSelected),
                color: isSelected ? const Color(0xFF667EEA) : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? const Color(0xFF667EEA) : Colors.grey[600],
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
