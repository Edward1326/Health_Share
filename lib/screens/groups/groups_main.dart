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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Groups',
          style: TextStyle(
            color: Color(0xFF416240),
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFF416240).withOpacity(0.1),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(
                MediaQuery.of(context).size.width > 600 ? 24.0 : 16.0,
              ),
              child: _buildSearchBar(),
            ),
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF416240),
                          strokeWidth: 3,
                        ),
                      )
                      : _filteredGroups.isEmpty
                      ? _buildEmptyState()
                      : LayoutBuilder(
                        builder: (context, constraints) {
                          return GridView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: constraints.maxWidth > 600 ? 24 : 16,
                              vertical: 8,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _getCrossAxisCount(context),
                                  crossAxisSpacing:
                                      constraints.maxWidth > 600 ? 20 : 14,
                                  mainAxisSpacing:
                                      constraints.maxWidth > 600 ? 20 : 14,
                                  childAspectRatio: _getChildAspectRatio(
                                    context,
                                  ),
                                ),
                            itemCount: _filteredGroups.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _buildCreateGroupCard();
                              }
                              final group = _filteredGroups[index - 1];
                              return TweenAnimationBuilder<double>(
                                duration: Duration(
                                  milliseconds: 300 + (index * 80),
                                ),
                                tween: Tween(begin: 0.0, end: 1.0),
                                curve: Curves.easeOut,
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: 0.8 + (value * 0.2),
                                    child: Opacity(
                                      opacity: value,
                                      child: child,
                                    ),
                                  );
                                },
                                child: _buildGroupCard(group),
                              );
                            },
                          );
                        },
                      ),
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
      constraints: const BoxConstraints(maxWidth: 800),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF416240).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF416240).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(fontSize: 15, color: Color(0xFF416240)),
        decoration: InputDecoration(
          hintText: 'Search groups...',
          hintStyle: TextStyle(
            color: const Color(0xFF416240).withOpacity(0.4),
            fontSize: 15,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: const Color(0xFF416240).withOpacity(0.6),
            size: 22,
          ),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: const Color(0xFF416240).withOpacity(0.6),
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
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
              color: const Color(0xFF416240),
              width: 2,
              style: BorderStyle.solid,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF416240).withOpacity(0.12),
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
                  color: const Color(0xFF416240).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF416240).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Color(0xFF416240),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Create',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF416240),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'New Group',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF416240).withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    const primaryColor = Color(0xFF416240);
    const accentColor = Color(0xFF6A8E6E); // softer complementary tone
    const lightBg = Color(0xFFF8FAF8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToGroupDetails(group),
        onLongPress: () => _showGroupMenu(context, group),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: lightBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: primaryColor.withOpacity(0.12),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.08),
                blurRadius: 10,
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
                  color: const Color(0xFF416240).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF416240).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
                    color: Color(0xFF416240),
                  ),
                ),
                title: const Text(
                  'Add Member',
                  style: TextStyle(
                    color: Color(0xFF416240),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAddMemberDialog(group['id']);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF416240).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.people_rounded,
                    color: Color(0xFF416240),
                  ),
                ),
                title: const Text(
                  'View Members',
                  style: TextStyle(
                    color: Color(0xFF416240),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF416240).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_rounded,
                color: const Color(0xFF416240).withOpacity(0.4),
                size: 60,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No groups yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF416240),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first group to get started',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF416240).withOpacity(0.6),
              ),
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
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF416240).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Color(0xFF416240),
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
                        color: Color(0xFF416240),
                      ),
                    ),
                  ),
                ],
              ),
              content: TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Color(0xFF416240)),
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  labelStyle: TextStyle(
                    color: const Color(0xFF416240).withOpacity(0.7),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: const Color(0xFF416240).withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: const Color(0xFF416240).withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF416240),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF416240).withOpacity(0.05),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: const Color(0xFF416240).withOpacity(0.6),
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
                    backgroundColor: const Color(0xFF416240),
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

  void _showAddMemberDialog(String groupId) {
    final TextEditingController emailController = TextEditingController();
    bool isAddingMember = false;

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
                      color: const Color(0xFF416240).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      color: Color(0xFF416240),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Add Member',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF416240),
                      ),
                    ),
                  ),
                ],
              ),
              content: TextField(
                controller: emailController,
                autofocus: true,
                style: const TextStyle(color: Color(0xFF416240)),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: TextStyle(
                    color: const Color(0xFF416240).withOpacity(0.7),
                  ),
                  hintText: 'Enter user\'s email',
                  hintStyle: TextStyle(
                    color: const Color(0xFF416240).withOpacity(0.4),
                  ),
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF416240),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: const Color(0xFF416240).withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: const Color(0xFF416240).withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF416240),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF416240).withOpacity(0.05),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              actions: [
                TextButton(
                  onPressed:
                      isAddingMember ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: const Color(0xFF416240).withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
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
                    backgroundColor: const Color(0xFF416240),
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
                      isAddingMember
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
                            'Add Member',
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
                      color: const Color(0xFF416240).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.people_rounded,
                      color: Color(0xFF416240),
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
                        color: Color(0xFF416240),
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
                                color: const Color(0xFF416240).withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No members yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: const Color(
                                    0xFF416240,
                                  ).withOpacity(0.6),
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
                                color: const Color(0xFF416240).withOpacity(0.1),
                              ),
                          itemBuilder: (context, index) {
                            final member = members[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF416240),
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
                                  color: Color(0xFF416240),
                                ),
                              ),
                              subtitle: Text(
                                'Joined: ${DateTime.parse(member['added_at']).toString().split(' ')[0]}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: const Color(
                                    0xFF416240,
                                  ).withOpacity(0.6),
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
                      color: Color(0xFF416240),
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
          backgroundColor: const Color(0xFF416240),
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
