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
        0: '/files',
        1: '/groups',
        2: '/organizations',
        3: '/your-organizations',
        4: '/profile',
      };

      if (routes.containsKey(index)) {
        Navigator.pushReplacementNamed(context, routes[index]!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 8 : 16,
            vertical: isCompact ? 6 : 6,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context: context,
                icon: Icons.folder_rounded,
                label: 'Files',
                index: 0,
                isCompact: isCompact,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.group_rounded,
                label: 'Groups',
                index: 1,
                isCompact: isCompact,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.apartment_rounded,
                label: 'Orgs',
                index: 2,
                isCompact: isCompact,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.verified_rounded,
                label: 'My Orgs',
                index: 3,
                isCompact: isCompact,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.person_rounded,
                label: 'Profile',
                index: 4,
                isCompact: isCompact,
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
    required String label,
    required int index,
    required bool isCompact,
  }) {
    final isSelected = selectedIndex == index;
    final primaryColor = const Color(0xFF416240);
    return Expanded(
      child: GestureDetector(
        onTap: () => _handleNavigation(context, index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 4 : 8,
            vertical: 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon container with animated background
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: EdgeInsets.all(isCompact ? 8 : 10),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? primaryColor.withOpacity(0.15)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: isSelected ? 1.1 : 1.0,
                  child: Icon(
                    icon,
                    color: isSelected ? primaryColor : Colors.grey[600],
                    size: isCompact ? 22 : 26,
                  ),
                ),
              ),
              SizedBox(height: isCompact ? 2 : 4),
              // Label with animated color and weight
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                style: TextStyle(
                  fontSize: isCompact ? 10 : 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? primaryColor : Colors.grey[600],
                  letterSpacing: 0.2,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Active indicator
              SizedBox(height: isCompact ? 3 : 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: 3,
                width: isSelected ? (isCompact ? 20 : 24) : 0,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
