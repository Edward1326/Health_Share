import 'package:flutter/material.dart';
import 'package:health_share/screens/groups/group_details.dart';
import 'package:health_share/components/navbar_main.dart';
import 'package:health_share/services/group_services/group_functions.dart';
import 'package:health_share/services/group_services/group_fetch_service.dart';
import 'package:health_share/services/group_services/group_management_service.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  int _selectedIndex = 1;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = false;
  String? _currentUserId;

  static const primaryColor = Color(0xFF03989E);
  static const accentColor = Color(0xFF04B1B8);
  static const lightBg = Color(0xFFF8FAF8);
  static const borderColor = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    _currentUserId = GroupFunctions.getCurrentUserId();
    await _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    if (_currentUserId == null) return;

    setState(() => _isLoading = true);

    try {
      _groups = await FetchGroupService.fetchUserGroups(_currentUserId!);
    } catch (e) {
      _showError('Error fetching groups: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredGroups {
    return GroupFunctions.filterGroups(_groups, _searchQuery);
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    if (width > 600) return 2;
    return 2;
  }

  double _getChildAspectRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 0.9;
    if (width > 800) return 0.88;
    if (width > 600) return 0.85;
    return 0.82;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;
    final isTablet = screenWidth > 600 && screenWidth <= 900;
    final isLargeScreen = screenWidth > 900;

    final titleFontSize = isLargeScreen ? 24.0 : (isTablet ? 22.0 : 20.0);
    final toolbarHeight = isDesktop ? 84.0 : 140.0;

    return Scaffold(
      backgroundColor: lightBg,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(toolbarHeight),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20 : 12,
              vertical: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar (top)
                Material(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: const InputDecoration(
                              hintText: 'Search groups',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // My Groups title (bottom)
                Text(
                  'My Groups',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: titleFontSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(
                    color: primaryColor,
                    strokeWidth: 2.5,
                  ),
                )
                : LayoutBuilder(
                  builder: (context, constraints) {
                    return GridView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 60.0 : (isTablet ? 40.0 : 20.0),
                        vertical: 20,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _getCrossAxisCount(context),
                        crossAxisSpacing: constraints.maxWidth > 600 ? 20 : 14,
                        mainAxisSpacing: constraints.maxWidth > 600 ? 20 : 14,
                        childAspectRatio: _getChildAspectRatio(context),
                      ),
                      itemCount:
                          _filteredGroups.isEmpty
                              ? 1
                              : _filteredGroups.length + 1,
                      itemBuilder: (context, index) {
                        // Always show create group card first
                        if (index == 0) {
                          return _buildCreateGroupCard();
                        }

                        // If no groups, only create card is shown
                        if (_filteredGroups.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final group = _filteredGroups[index - 1];
                        return TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 300 + (index * 80)),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: 0.8 + (value * 0.2),
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: _buildGroupCard(group),
                        );
                      },
                    );
                  },
                ),
      ),
      bottomNavigationBar: MainNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildCreateGroupCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showCreateGroupDialog,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primaryColor,
              width: 2,
              style: BorderStyle.solid,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: primaryColor,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Create',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'New Group',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: primaryColor.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToGroupDetails(group),
        onLongPress: () => _showGroupMenu(context, group),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar Circle
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          (group['name'] ?? 'G')[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Group Name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        group['name'] ?? 'Unnamed Group',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Member Count
                    FutureBuilder<int>(
                      future: GroupFunctions.getMemberCount(group['id']),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_rounded,
                                size: 15,
                                color: primaryColor.withOpacity(0.8),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Active Dot
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGroupMenu(BuildContext context, Map<String, dynamic> group) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.people_rounded, color: primaryColor),
                ),
                title: const Text(
                  'View Members',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showMembersDialog(group['id']);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _navigateToGroupDetails(Map<String, dynamic> group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => GroupDetailsScreen(
              groupId: group['id'],
              groupName: group['name'],
              groupData: group,
            ),
      ),
    );
  }

  void _showCreateGroupDialog() {
    final TextEditingController nameController = TextEditingController();
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Create New Group',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              content: TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: primaryColor),
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  labelStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: primaryColor.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: primaryColor.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: primaryColor.withOpacity(0.05),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: primaryColor.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      isCreating
                          ? null
                          : () async {
                            if (nameController.text.isNotEmpty) {
                              setDialogState(() => isCreating = true);
                              await _createGroup(nameController.text);
                              Navigator.pop(context);
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child:
                      isCreating
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text(
                            'Create',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createGroup(String name) async {
    try {
      await GroupManagementService.createGroup(
        name: name,
        userId: _currentUserId!,
      );

      await _fetchGroups();
      _showSuccess('Group "$name" created successfully!');
    } catch (e) {
      _showError('Error creating group: $e');
    }
  }

  void _showMembersDialog(String groupId) async {
    try {
      final members = await FetchGroupService.getGroupMembersWithDetails(
        groupId,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.people_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Group Members',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child:
                    members.isEmpty
                        ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_outline_rounded,
                                size: 64,
                                color: primaryColor.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No members yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: primaryColor.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.separated(
                          shrinkWrap: true,
                          itemCount: members.length,
                          separatorBuilder:
                              (context, index) => Divider(
                                height: 1,
                                color: primaryColor.withOpacity(0.1),
                              ),
                          itemBuilder: (context, index) {
                            final member = members[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: primaryColor,
                                radius: 24,
                                child: Text(
                                  member['User']['email'][0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              title: Text(
                                member['User']['email'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                              subtitle: Text(
                                'Joined: ${DateTime.parse(member['added_at']).toString().split(' ')[0]}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: primaryColor.withOpacity(0.6),
                                ),
                              ),
                            );
                          },
                        ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      _showError('Error loading members: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 6,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 6,
        ),
      );
    }
  }
}
