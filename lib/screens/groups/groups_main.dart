// groups_main.dart
import 'package:flutter/material.dart';
import 'package:health_share/screens/navbar/navbar_main.dart';
import 'package:health_share/screens/groups/group_details.dart';
import 'package:health_share/screens/groups/group_invitations.dart';
import 'package:health_share/services/group_service.dart';
import 'package:health_share/services/group_invitation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  final GroupService _groupService = GroupService();
  final GroupInvitationService _invitationService = GroupInvitationService();
  List<Map<String, dynamic>> _userGroups = [];
  List<Map<String, dynamic>> _allGroups = [];
  int _pendingInvitationsCount = 0;
  bool _isLoading = false;
  bool _showMyGroups = true; // Toggle between "My Groups" and "All Groups"

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
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    // Don't show loading if we're just refreshing
    if (_userGroups.isEmpty && _allGroups.isEmpty) {
      setState(() => _isLoading = true);
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load groups and invitations in parallel for better performance
      final results = await Future.wait([
        _groupService.getUserGroups(currentUser.id),
        _groupService.getAllGroups(),
        _invitationService.getPendingInvitations(currentUser.id),
      ]);

      setState(() {
        _userGroups = results[0];
        _allGroups = results[1];
        _pendingInvitationsCount = (results[2] as List).length;
        _isLoading = false;
      });

      print(
        'Groups loaded: ${_userGroups.length} user groups, ${_allGroups.length} total groups, $_pendingInvitationsCount pending invitations',
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        print('Error loading groups: $e');
        // Only show error message if it's the initial load
        if (_userGroups.isEmpty && _allGroups.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading groups: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  List<Map<String, dynamic>> get _filteredGroups {
    final groups = _showMyGroups ? _userGroups : _allGroups;
    if (_searchQuery.isEmpty) return groups;

    return groups.where((group) {
      final groupData = _showMyGroups ? group['Group'] : group;
      final name = (groupData?['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Groups',
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          // Invitations button with badge
          Stack(
            children: [
              IconButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GroupInvitationsScreen(),
                    ),
                  );
                  _loadGroups(); // Refresh after returning from invitations
                },
                icon: Icon(Icons.mail_outline, color: Colors.grey[600]),
              ),
              if (_pendingInvitationsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_pendingInvitationsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: _loadGroups,
            icon: Icon(Icons.refresh, color: Colors.grey[600]),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildToggleButtons(),
                  const SizedBox(height: 16),
                  if (_showMyGroups) _buildCreateGroupButton(),
                ],
              ),
            ),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildGroupsList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MainNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search for groups...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 22),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[400], size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButtons() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showMyGroups = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color:
                      _showMyGroups
                          ? const Color(0xFF667EEA)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'My Groups',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _showMyGroups ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showMyGroups = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color:
                      !_showMyGroups
                          ? const Color(0xFF667EEA)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'All Groups',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_showMyGroups ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateGroupButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          _showCreateGroupDialog();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF667EEA),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          shadowColor: const Color(0xFF667EEA).withOpacity(0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Create a Group',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsList() {
    final filteredGroups = _filteredGroups;
    if (filteredGroups.isEmpty) {
      return _buildEmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
    final groupData = _showMyGroups ? group['Group'] : group;
    final currentUser = Supabase.instance.client.auth.currentUser;
    final isOwner = currentUser?.id == groupData['user_id'];
    final isMember =
        _showMyGroups; // If it's in "My Groups", user is already a member

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isMember) {
            // Navigate to group details if user is a member
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => GroupDetailsScreen(
                      groupId: groupData['id'],
                      groupName: groupData['name'] ?? 'No Name',
                      isOwner: isOwner,
                    ),
              ),
            );
          } else {
            // Show join group dialog if not a member
            _showJoinGroupDialog(groupData);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF667EEA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.group,
                    color: Color(0xFF667EEA),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groupData['name'] ?? 'No Name',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(groupData['created_at']),
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      if (isOwner && _showMyGroups)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF11998E).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Owner',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF11998E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isMember)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667EEA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Join',
                      style: TextStyle(
                        color: Color(0xFF667EEA),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
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
              child: Icon(
                _showMyGroups ? Icons.group_outlined : Icons.search_off,
                color: Colors.grey[400],
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _showMyGroups ? 'No groups joined yet' : 'No groups found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _showMyGroups
                  ? 'Create your first group or join existing ones'
                  : 'Try searching with different keywords',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupDialog() {
    final TextEditingController nameController = TextEditingController();
    bool _isCreating = false;

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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    enabled: !_isCreating,
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    autofocus: true,
                  ),
                  if (_isCreating) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Creating group...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isCreating ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: _isCreating ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      _isCreating
                          ? null
                          : () async {
                            if (nameController.text.trim().isNotEmpty) {
                              final currentUser =
                                  Supabase.instance.client.auth.currentUser;
                              if (currentUser == null) return;

                              try {
                                // Set creating state
                                setDialogState(() {
                                  _isCreating = true;
                                });

                                // Create the group
                                await _groupService.createGroup(
                                  name: nameController.text.trim(),
                                  userId: currentUser.id,
                                );

                                // Close dialog immediately after creation
                                Navigator.pop(context);

                                // Show success message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Group "${nameController.text}" created!',
                                    ),
                                    backgroundColor: const Color(0xFF667EEA),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );

                                // Refresh the groups list in the background
                                _loadGroups();
                              } catch (e) {
                                // Reset creating state on error
                                setDialogState(() {
                                  _isCreating = false;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error creating group: $e'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isCreating
                            ? Colors.grey[300]
                            : const Color(0xFF667EEA),
                    foregroundColor:
                        _isCreating ? Colors.grey[500] : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      _isCreating
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.grey,
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

  void _showJoinGroupDialog(Map<String, dynamic> groupData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool _isJoining = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Join Group'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Do you want to join "${groupData['name']}"?'),
                  if (_isJoining) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Joining group...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isJoining ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: _isJoining ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      _isJoining
                          ? null
                          : () async {
                            final currentUser =
                                Supabase.instance.client.auth.currentUser;
                            if (currentUser == null) return;

                            try {
                              setDialogState(() {
                                _isJoining = true;
                              });

                              await _groupService.joinGroup(
                                groupId: groupData['id'],
                                userId: currentUser.id,
                              );

                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Joined "${groupData['name']}" successfully!',
                                  ),
                                  backgroundColor: const Color(0xFF11998E),
                                  duration: const Duration(seconds: 2),
                                ),
                              );

                              // Refresh groups in background
                              _loadGroups();
                            } catch (e) {
                              setDialogState(() {
                                _isJoining = false;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isJoining ? Colors.grey[300] : const Color(0xFF667EEA),
                    foregroundColor:
                        _isJoining ? Colors.grey[500] : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      _isJoining
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.grey,
                              ),
                            ),
                          )
                          : const Text('Join'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }
}
