import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              slivers: [
                // Custom App Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dashboard',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Welcome back!',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.1),
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.notifications_outlined,
                              color: Colors.grey[700],
                            ),
                            onPressed: () {
                              // Show notifications
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Quick Actions Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          'Quick Actions',
                          Icons.flash_on_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildQuickActionsGrid(),
                      ],
                    ),
                  ),
                ),

                // Recent Folder Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildSectionHeader(
                          'Recent Folders',
                          Icons.folder_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildRecentFoldersGrid(),
                      ],
                    ),
                  ),
                ),

                // Groups Overview Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildSectionHeader(
                          'Groups Overview',
                          Icons.group_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildGroupsOverview(),
                      ],
                    ),
                  ),
                ),

                // Add some bottom padding for navbar
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionCard(
            title: 'Browse Files',
            subtitle: 'View all files',
            icon: Icons.folder_open_outlined,
            color: const Color(0xFF667EEA),
            onTap: () {
              // Navigate to FileScreen
              Navigator.pushNamed(context, '/files');
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildQuickActionCard(
            title: 'Open Folder',
            subtitle: 'Access folders',
            icon: Icons.folder_outlined,
            color: const Color(0xFF11998E),
            onTap: () {
              // Navigate to FolderScreen
              Navigator.pushNamed(context, '/folder');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.05),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.08)),
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                index: 0,
                onTap: () => _onNavTap(0),
              ),
              _buildNavItem(
                icon: Icons.folder_outlined,
                activeIcon: Icons.folder,
                label: 'Files',
                index: 1,
                onTap: () => _onNavTap(1),
              ),
              _buildNavItem(
                icon: Icons.group_outlined,
                activeIcon: Icons.group,
                label: 'Groups',
                index: 2,
                onTap: () => _onNavTap(2),
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                index: 3,
                onTap: () => _onNavTap(3),
              ),
              _buildNavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'Settings',
                index: 4,
                onTap: () => _onNavTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required VoidCallback onTap,
  }) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isActive
                  ? const Color(0xFF667EEA).withOpacity(0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? const Color(0xFF667EEA) : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? const Color(0xFF667EEA) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0:
        // Already on home, do nothing
        break;
      case 1:
        Navigator.pushNamed(context, '/files');
        break;
      case 2:
        // Navigate to groups (you can implement this later)
        break;
      case 3:
        Navigator.pushNamed(context, '/profile');
        break;
      case 4:
        Navigator.pushNamed(context, '/settings');
        break;
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF667EEA).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF667EEA), size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentFoldersGrid() {
    final recentFolders = [
      {
        'name': 'Projects',
        'icon': Icons.work_outline,
        'color': const Color(0xFF667EEA),
      },
      {
        'name': 'Documents',
        'icon': Icons.description_outlined,
        'color': const Color(0xFF11998E),
      },
      {
        'name': 'Photos',
        'icon': Icons.photo_outlined,
        'color': const Color(0xFFE056FD),
      },
      {
        'name': 'Downloads',
        'icon': Icons.download_outlined,
        'color': const Color(0xFFF093FB),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: recentFolders.length,
      itemBuilder: (context, index) {
        final folder = recentFolders[index];
        return _buildFolderCard(
          name: folder['name'] as String,
          icon: folder['icon'] as IconData,
          color: folder['color'] as Color,
          fileCount: (index + 1) * 12,
        );
      },
    );
  }

  Widget _buildFolderCard({
    required String name,
    required IconData icon,
    required Color color,
    required int fileCount,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.05),
      child: InkWell(
        onTap: () {
          // Navigate to specific folder
          Navigator.pushNamed(context, '/folder');
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const Spacer(),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$fileCount files',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupsOverview() {
    final groups = [
      {'name': 'Design Team', 'members': 8, 'avatar': '🎨'},
      {'name': 'Development', 'members': 12, 'avatar': '💻'},
      {'name': 'Marketing', 'members': 6, 'avatar': '📈'},
    ];

    return Column(
      children:
          groups
              .map(
                (group) => _buildGroupCard(
                  name: group['name'] as String,
                  members: group['members'] as int,
                  avatar: group['avatar'] as String,
                ),
              )
              .toList(),
    );
  }

  Widget _buildGroupCard({
    required String name,
    required int members,
    required String avatar,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        child: InkWell(
          onTap: () {
            // Navigate to groups (implement later)
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF667EEA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(avatar, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$members members',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey[400],
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
