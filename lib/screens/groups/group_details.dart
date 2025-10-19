import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:health_share/screens/groups/user_files_screen.dart';
import 'package:health_share/screens/profile/view_profile.dart';
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

  // Colors
  late Color _primaryColor;
  late Color _accentColor;
  late Color _bg;
  late Color _card;
  late Color _textPrimary;
  late Color _textSecondary;

  late AnimationController _staggerController;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _initializeColors();
    _initializeScreen();
  }

  void _initializeColors() {
    _primaryColor = const Color(0xFF03989E);
    _accentColor = const Color(0xFF04B1B8);
    _bg = const Color(0xFFF6F8FA);
    _card = Colors.white;
    _textPrimary = const Color(0xFF1A1A1A);
    _textSecondary = Colors.grey[600]!;
  }

  Future<void> _initializeScreen() async {
    setState(() => _isLoading = true);
    _currentUserId = GroupFunctions.getCurrentUserId();
    _isGroupOwner = GroupFunctions.isUserGroupOwner(
      _currentUserId,
      widget.groupData,
    );
    await Future.wait([_fetchMembers(), _fetchSharedFiles()]);
    if (mounted) setState(() => _isLoading = false);
    _staggerController.forward();
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
    if (mounted) setState(() => _isLoading = false);
    _showSuccess('Refreshed successfully');
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

  List<Map<String, dynamic>> get _filteredMembers {
    if (_searchQuery.isEmpty) return _members;
    return _members
        .where(
          (m) => (m['User']?['email'] ?? '').toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _staggerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: _isGroupOwner ? _buildFAB() : null,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildTabBar(),
            if (_isSearchVisible) _buildSearchField(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: _primaryColor,
                child: _isLoading ? _buildLoadingState() : _buildTabView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final avatarTag = 'group_avatar_${widget.groupId}';
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16),
      child: Column(
        children: [
          // Back button row
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _primaryColor,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  setState(() => _isSearchVisible = !_isSearchVisible);
                  if (!_isSearchVisible) {
                    _searchController.clear();
                    _searchQuery = '';
                  }
                },
                icon: Icon(_isSearchVisible ? Icons.search_off : Icons.search),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                color: Colors.white,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.more_vert, color: _primaryColor),
                ),
                onSelected: (v) {
                  if (v == 'refresh') _refreshData();
                  if (v == 'leave') _showLeaveGroupDialog();
                },
                itemBuilder:
                    (_) => [
                      const PopupMenuItem(
                        value: 'refresh',
                        child: Row(
                          children: [
                            Icon(Icons.refresh, size: 20),
                            SizedBox(width: 12),
                            Text('Refresh'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'leave',
                        child: Row(
                          children: [
                            Icon(
                              Icons.exit_to_app,
                              size: 20,
                              color: Colors.red,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Leave Group',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Gradient glass card
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _primaryColor.withOpacity(0.95),
                      _accentColor.withOpacity(0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Hero(
                          tag: avatarTag,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                (widget.groupName.isNotEmpty
                                        ? widget.groupName[0]
                                        : 'G')
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: _primaryColor,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.groupName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildInfoChip(
                                    Icons.group,
                                    '${_members.length} members',
                                  ),
                                  _buildInfoChip(
                                    Icons.folder,
                                    '${_filesByUser.length} shared',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _refreshData,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Refresh'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showLeaveGroupDialog,
                            icon: const Icon(Icons.exit_to_app, size: 18),
                            label: const Text('Leave'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(14),
        shadowColor: Colors.black.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white,
            border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: _primaryColor,
            unselectedLabelColor: _textSecondary,
            indicatorColor: _primaryColor,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              Tab(text: 'FILES (${_filteredFilesByUser.length})'),
              Tab(text: 'MEMBERS (${_filteredMembers.length})'),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSearch() {
    setState(() => _isSearchVisible = !_isSearchVisible);
    if (!_isSearchVisible) {
      _searchController.clear();
      _searchQuery = '';
    }
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText:
              _tabController.index == 0
                  ? 'Search folders or users...'
                  : 'Search members by email...',
          prefixIcon: Icon(Icons.search, color: _primaryColor),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                    icon: Icon(Icons.clear, color: _primaryColor),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                  : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _primaryColor),
          const SizedBox(height: 12),
          Text(
            'Loading group data...',
            style: TextStyle(color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTabView() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 12),
      child: TabBarView(
        controller: _tabController,
        children: [_buildFilesGrid(), _buildMembersList()],
      ),
    );
  }

  Widget _buildFilesGrid() {
    final display = _filteredFilesByUser;
    if (display.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_off,
        title: 'No Files',
        subtitle: 'Members haven\'t shared files yet',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: display.keys.length,
      itemBuilder: (context, index) {
        final userKey = display.keys.elementAt(index);
        final parts = userKey.split('|');
        final userId = parts[0];
        final firstName = parts.length > 1 ? parts[1] : 'Unknown';
        final files = display[userKey]!;

        return AnimatedBuilder(
          animation: _staggerController,
          builder: (context, child) {
            final t = (_staggerController.value - (index * 0.05)).clamp(
              0.0,
              1.0,
            );
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 12),
                child: child,
              ),
            );
          },
          child: _buildUserFileFolder(userId, firstName, files),
        );
      },
    );
  }

  Widget _buildMembersList() {
    final display = _filteredMembers;
    if (display.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'No Members',
        subtitle: 'Invite members to get started',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: display.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final member = display[index];
        return _buildMemberCard(member);
      },
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final user = member['User'];
    if (user == null) return const SizedBox.shrink();
    final email = user['email'] ?? 'Unknown';
    final person = user['Person'];
    final firstName = person?['first_name'] ?? '';
    final lastName = person?['last_name'] ?? '';
    final displayName = [
      firstName,
      lastName,
    ].where((e) => e.isNotEmpty).join(' ');
    final initial =
        displayName.isNotEmpty
            ? displayName[0].toUpperCase()
            : (email.isNotEmpty ? email[0].toUpperCase() : 'U');
    final isOwner = member['user_id'] == widget.groupData['user_id'];
    final isCurrentUser = member['user_id'] == _currentUserId;
    final canRemove = _isGroupOwner && !isOwner && !isCurrentUser;

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => ViewProfileScreen(
                    userId: member['user_id'],
                    userName: member['first_name'] ?? '',
                    userEmail: email,
                  ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _accentColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName.isNotEmpty ? displayName : email,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(color: _textSecondary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isOwner) _badge('Owner', Icons.star, _primaryColor),
              if (isCurrentUser && !isOwner)
                _badge('You', Icons.check, _accentColor),
              if (canRemove)
                IconButton(
                  onPressed: () => _showRemoveMemberDialog(member),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserFileFolder(
    String userId,
    String firstName,
    List<Map<String, dynamic>> userFiles,
  ) {
    final totalSize = userFiles.fold<int>(
      0,
      (s, f) => s + ((f['file']?['file_size'] ?? 0) as int),
    );

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => UserFilesScreen(
                    groupId: widget.groupId,
                    memberId: userId,
                    memberName: firstName,
                    memberFiles: userFiles,
                  ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Hero(
                tag: 'user_avatar_$userId',
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_accentColor, _primaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$firstName's Files",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.description,
                              size: 14,
                              color: _textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${userFiles.length} ${userFiles.length == 1 ? 'file' : 'files'}',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.storage,
                              size: 14,
                              color: _textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              GroupFunctions.formatFileSize(totalSize),
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: _textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryColor.withOpacity(0.1),
                  _accentColor.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: _primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: _textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _showAddMemberDialog,
      backgroundColor: _primaryColor,
      label: const Text(
        'Add Member',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      icon: const Icon(Icons.person_add),
      elevation: 4,
    );
  }

  void _showAddMemberDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Add Member'),
            content: TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Email address',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
                    await _addMember(emailController.text);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  Future<void> _addMember(String email) async {
    try {
      await GroupFunctions.addMemberToGroup(
        groupId: widget.groupId,
        email: email,
        ownerId: _currentUserId!,
      );
      await _fetchMembers();
      _showSuccess('$email added successfully');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showRemoveMemberDialog(Map<String, dynamic> member) {
    final user = member['User'];
    final email = user?['email'] ?? 'Unknown';
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Remove Member'),
            content: Text(
              'Are you sure you want to remove $email from this group?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _removeMember(member);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    try {
      final user = member['User'];
      final email = user?['email'] ?? 'Unknown';
      final userId = member['user_id'];
      await GroupFunctions.removeMemberFromGroup(
        groupId: widget.groupId,
        userId: userId,
        ownerId: _currentUserId!,
      );
      await _fetchMembers();
      _showSuccess('$email removed successfully');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showLeaveGroupDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
