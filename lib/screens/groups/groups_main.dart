import 'package:flutter/material.dart';
import 'package:health_share/screens/groups/group_details.dart';
import 'package:health_share/components/navbar_main.dart';
import 'package:health_share/services/group_services/group_functions.dart';
import 'package:health_share/services/group_services/group_fetch_service.dart';
import 'package:health_share/services/group_services/group_management_service.dart';
import 'package:health_share/services/group_services/group_member_service.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  int _selectedIndex = 2;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
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

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Groups',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildGroupsList(),
      ),
      bottomNavigationBar: MainNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) => setState(() => _selectedIndex = index),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGroupDialog,
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildGroupsList() {
    final filteredGroups = _filteredGroups;
    if (filteredGroups.isEmpty) {
      return _buildEmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: filteredGroups.length,
      itemBuilder: (context, index) {
        final group = filteredGroups[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildGroupCard(group),
        );
      },
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToGroupDetails(group),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2D5A3D), Color(0xFF1E3A4C)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Calendar icon in top left
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.group, color: Colors.white, size: 20),
                ),
              ),
              // Menu button in top right
              Positioned(
                top: 8,
                right: 8,
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'add_member') {
                      _showAddMemberDialog(group['id']);
                    } else if (value == 'members') {
                      _showMembersDialog(group['id']);
                    }
                  },
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'add_member',
                          child: Row(
                            children: [
                              Icon(Icons.person_add, size: 18),
                              SizedBox(width: 8),
                              Text('Add Member'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'members',
                          child: Row(
                            children: [
                              Icon(Icons.people, size: 18),
                              SizedBox(width: 8),
                              Text('View Members'),
                            ],
                          ),
                        ),
                      ],
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                ),
              ),
              // Illustration (placeholder circle)
              Positioned(
                right: -20,
                top: 20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              // Group name and description
              Positioned(
                left: 16,
                bottom: 16,
                right: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group['name'] ?? 'No Name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<int>(
                      future: GroupFunctions.getMemberCount(group['id']),
                      builder: (context, snapshot) {
                        return Text(
                          '${snapshot.data ?? 0} members',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.groups, color: Colors.grey[400], size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              'No groups found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first group to get started',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Create New Group'),
              content: TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600]),
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
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      isCreating
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text('Create'),
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

  void _showAddMemberDialog(String groupId) {
    final TextEditingController emailController = TextEditingController();
    bool isAddingMember = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Add Member'),
              content: TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'Enter user\'s email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              actions: [
                TextButton(
                  onPressed:
                      isAddingMember ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      isAddingMember
                          ? null
                          : () async {
                            if (emailController.text.isNotEmpty) {
                              setDialogState(() => isAddingMember = true);
                              try {
                                await GroupMemberService.addMemberToGroup(
                                  groupId: groupId,
                                  email: emailController.text,
                                );
                                Navigator.pop(context);
                                _showSuccess(
                                  '${emailController.text} has been added to the group',
                                );
                              } catch (e) {
                                setDialogState(() => isAddingMember = false);
                                _showError(
                                  e.toString().replaceAll('Exception: ', ''),
                                );
                              }
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      isAddingMember
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text('Add Member'),
                ),
              ],
            );
          },
        );
      },
    );
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Group Members'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF4CAF50),
                        child: Text(
                          member['User']['email'][0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(member['User']['email']),
                      subtitle: Text(
                        'Joined: ${DateTime.parse(member['added_at']).toString().split(' ')[0]}',
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
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
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    }
  }
}
