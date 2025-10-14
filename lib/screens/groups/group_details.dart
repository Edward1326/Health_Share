import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:health_share/screens/groups/user_files_screen.dart';
import 'package:health_share/services/group_services/group_files_service.dart';
import 'package:health_share/services/group_services/group_functions.dart';
import 'package:health_share/services/group_services/group_fetch_service.dart';
import 'package:health_share/services/group_services/group_member_service.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final Map<String, dynamic> groupData;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.groupData,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _members = [];
  Map<String, List<Map<String, dynamic>>> _filesByUser = {};
  bool _isLoading = true;
  String? _currentUserId;
  bool _isGroupOwner = false;
  final Color _primaryColor = const Color(0xFF416240);
  final Color _accentColor = const Color(0xFF6A8E6E);
  late AnimationController _fabAnimController;
  late AnimationController _headerAnimController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fabAnimController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _headerAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    setState(() => _isLoading = true);
    _currentUserId = GroupFunctions.getCurrentUserId();
    _isGroupOwner = GroupFunctions.isUserGroupOwner(
      _currentUserId,
      widget.groupData,
    );
    await Future.wait([_fetchMembers(), _fetchSharedFiles()]);
    setState(() => _isLoading = false);
    _fabAnimController.forward();
    _headerAnimController.forward();
  }

  Future<void> _fetchMembers() async {
    try {
      final members = await FetchGroupService.fetchGroupMembers(widget.groupId);
      if (mounted) setState(() => _members = members);
    } catch (e) {
      _showError('Error loading members: $e');
    }
  }

  Future<void> _fetchSharedFiles() async {
    try {
      final sharedFiles = await GroupFileService.fetchGroupSharedFiles(
        widget.groupId,
      );
      final filesByUser = GroupFileService.organizeFilesByUser(sharedFiles);
      if (mounted) setState(() => _filesByUser = filesByUser);
    } catch (e) {
      if (mounted) setState(() => _filesByUser = {});
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchMembers(), _fetchSharedFiles()]);
    setState(() => _isLoading = false);
    _showSuccess('Refreshed successfully');
  }

  List<Map<String, dynamic>> get _filteredMembers {
    if (_searchQuery.isEmpty) return _members;
    return _members.where((member) {
      final email = member['User']?['email'] ?? '';
      return email.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _filteredFilesByUser {
    if (_searchQuery.isEmpty) return _filesByUser;
    final filtered = <String, List<Map<String, dynamic>>>{};
    _filesByUser.forEach((key, files) {
      final userName = key.split('|').length > 1 ? key.split('|')[1] : '';
      if (userName.toLowerCase().contains(_searchQuery.toLowerCase())) {
        filtered[key] = files;
      }
    });
    return filtered;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fabAnimController.dispose();
    _headerAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: _primaryColor,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [_buildSliverAppBar()];
          },
          body:
              _isLoading
                  ? Center(
                    child: CircularProgressIndicator(color: _primaryColor),
                  )
                  : TabBarView(
                    controller: _tabController,
                    children: [_buildFilesTab(), _buildMembersTab()],
                  ),
        ),
      ),
      floatingActionButton:
          _isGroupOwner
              ? ScaleTransition(
                scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _fabAnimController,
                    curve: Curves.elasticOut,
                  ),
                ),
                child: FloatingActionButton.extended(
                  onPressed: _showAddMemberDialog,
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text(
                    'Add Member',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              )
              : null,
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      floating: false,
      pinned: true,
      backgroundColor: _primaryColor,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: InkWell(
          onTap: () => Navigator.pop(context),
          customBorder: const CircleBorder(),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isSearchVisible ? Icons.search_off_rounded : Icons.search,
          ),
          onPressed: () {
            setState(() {
              _isSearchVisible = !_isSearchVisible;
              if (!_isSearchVisible) {
                _searchController.clear();
                _searchQuery = '';
              }
            });
          },
          color: Colors.white,
          tooltip: 'Search',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            if (value == 'refresh') _refreshData();
            if (value == 'leave') _showLeaveGroupDialog();
          },
          itemBuilder:
              (context) => [
                const PopupMenuItem(value: 'refresh', child: Text('Refresh')),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'leave',
                  child: Text(
                    'Leave Group',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: FadeTransition(
          opacity: _headerAnimController,
          child: _buildGroupHeader(),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(_isSearchVisible ? 110 : 50),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: _primaryColor,
          child: Column(
            children: [if (_isSearchVisible) _buildSearchBar(), _buildTabBar()],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Hero(
                tag: 'group_avatar_${widget.groupId}',
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Text(
                    (widget.groupName.isNotEmpty ? widget.groupName[0] : 'G')
                        .toUpperCase(),
                    style: TextStyle(
                      color: _primaryColor,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.groupName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_members.length} Members',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  Text(
                    '${_filesByUser.length} Folders',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white.withOpacity(0.7),
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(width: 3.0, color: Colors.white),
        insets: EdgeInsets.symmetric(horizontal: 16.0),
      ),
      tabs: [
        Tab(text: 'FILES (${_filesByUser.length})'),
        Tab(text: 'MEMBERS (${_members.length})'),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText:
              _tabController.index == 0
                  ? 'Search folders...'
                  : 'Search members...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                  : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildMembersTab() {
    final displayMembers = _filteredMembers;
    if (displayMembers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'No Members Found',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: displayMembers.length,
      itemBuilder: (context, index) => _buildMemberCard(displayMembers[index]),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final user = member['User'];
    if (user == null) return const SizedBox.shrink();

    final email = user['email'] ?? 'Unknown User';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';
    final isOwner = member['user_id'] == widget.groupData['user_id'];
    final isCurrentUser = member['user_id'] == _currentUserId;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _primaryColor,
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(email, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Wrap(
          spacing: 8,
          children: [
            if (isOwner) _buildBadge('Owner', Icons.star, _primaryColor),
            if (isCurrentUser) _buildBadge('You', Icons.check, Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, IconData icon, Color color) {
    return Chip(
      avatar: Icon(icon, color: color, size: 14),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color.withOpacity(0.1),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.only(left: 2, right: 6),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildFilesTab() {
    final displayFiles = _filteredFilesByUser;
    if (displayFiles.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_off_outlined,
        title: 'No Files Found',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: displayFiles.keys.length,
      itemBuilder: (context, index) {
        final userKey = displayFiles.keys.elementAt(index);
        final parts = userKey.split('|');
        final userId = parts[0];
        final firstName = parts.length > 1 ? parts[1] : 'Unknown';
        final userFiles = displayFiles[userKey]!;
        return _buildUserFileFolder(userId, firstName, userFiles);
      },
    );
  }

  Widget _buildUserFileFolder(
    String userId,
    String firstName,
    List<Map<String, dynamic>> userFiles,
  ) {
    final totalSize = userFiles.fold<int>(
      0,
      (sum, file) => sum + ((file['file']?['file_size'] ?? 0) as int),
    );

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => UserFilesScreen(
                    groupId: widget.groupId,
                    memberId: userId,
                    memberName: firstName,
                    memberFiles: userFiles,
                  ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Hero(
            tag: 'user_avatar_$userId',
            child: CircleAvatar(
              backgroundColor: _accentColor,
              child: Text(
                firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          title: Text(
            '$firstName\'s Files',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${userFiles.length} files • ${GroupFunctions.formatFileSize(totalSize)}',
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // --- Dialogs and Snackbars (Functionality Unchanged, UI Polished) ---

  void _showAddMemberDialog() {
    final TextEditingController emailController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Member'),
            content: TextField(
              controller: emailController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Email Address'),
              keyboardType: TextInputType.emailAddress,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (emailController.text.isNotEmpty) {
                    Navigator.pop(context);
                    try {
                      await GroupMemberService.addMemberToGroup(
                        groupId: widget.groupId,
                        email: emailController.text,
                      );
                      await _fetchMembers();
                      _showSuccess(
                        '${emailController.text} added successfully',
                      );
                    } catch (e) {
                      _showError(e.toString().replaceAll('Exception: ', ''));
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  void _showLeaveGroupDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Leave Group'),
            content: Text(
              'Are you sure you want to leave "${widget.groupName}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _leaveGroup();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Leave'),
              ),
            ],
          ),
    );
  }

  Future<void> _leaveGroup() async {
    try {
      await GroupMemberService.leaveGroup(
        groupId: widget.groupId,
        userId: _currentUserId!,
      );
      if (mounted) {
        Navigator.pop(context, true);
        _showSuccess('Left "${widget.groupName}" successfully');
      }
    } catch (e) {
      _showError('Error leaving group: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _primaryColor),
    );
  }
}
