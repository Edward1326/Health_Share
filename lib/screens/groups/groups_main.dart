import 'package:basic_utils/basic_utils.dart' as crypto;
import 'package:basic_utils/basic_utils.dart';
import 'package:flutter/material.dart';
import 'package:health_share/screens/groups/group_details.dart';
import 'package:health_share/components/navbar_main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rsa_encrypt/rsa_encrypt.dart';
import 'package:crypto/crypto.dart' as crypto;

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
  List<Map<String, dynamic>> _invitations = [];
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
    _getCurrentUser();
    _fetchGroups();
    _fetchInvitations();
  }

  Future<void> _getCurrentUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    setState(() {
      _currentUserId = user?.id;
    });
  }

  Future<void> _fetchGroups() async {
    if (_currentUserId == null) return;

    setState(() => _isLoading = true);

    // Fetch groups where the current user is a member
    final response = await Supabase.instance.client
        .from('Group_Members')
        .select('''
          group_id,
          Group!inner(*)
        ''')
        .eq('user_id', _currentUserId!)
        .order('added_at', ascending: false);

    setState(() {
      _groups = List<Map<String, dynamic>>.from(
        response.map((item) => item['Group']),
      );
      _isLoading = false;
    });
  }

  Future<void> _fetchInvitations() async {
    if (_currentUserId == null) {
      print('DEBUG: _currentUserId is null');
      return;
    }

    print('DEBUG: Fetching invitations for user: $_currentUserId');

    try {
      final response = await Supabase.instance.client
          .from('Group_Invitations')
          .select('''
          *,
          Group!inner(name),
          invited_by_user:User!invited_by(email)
        ''')
          .eq('invitee_id', _currentUserId!)
          .eq('status', 'pending')
          .order('invited_at', ascending: false);

      print('DEBUG: Raw response: $response');
      print('DEBUG: Response length: ${response.length}');

      setState(() {
        _invitations = List<Map<String, dynamic>>.from(response);
      });

      print('DEBUG: _invitations length: ${_invitations.length}');
    } catch (e) {
      print('DEBUG: Error fetching invitations: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredGroups {
    if (_searchQuery.isEmpty) return _groups;
    return _groups
        .where(
          (group) => (group['name'] ?? '').toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
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
          if (_invitations.isNotEmpty)
            Stack(
              children: [
                IconButton(
                  onPressed: _showInvitationsDialog,
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: Colors.grey[600],
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '${_invitations.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 8),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            )
          else
            IconButton(
              onPressed: () {},
              icon: Icon(Icons.notifications_outlined, color: Colors.grey[600]),
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
                  _buildCreateGroupButton(),
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
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 20),
            SizedBox(width: 8),
            Text(
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _navigateToGroupDetails(group);
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group['name'] ?? 'No Name',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<int>(
                        future: _getMemberCount(group['id']),
                        builder: (context, snapshot) {
                          return Text(
                            '${snapshot.data ?? 0} members',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'invite') {
                      _showInviteDialog(group['id']);
                    } else if (value == 'members') {
                      _showMembersDialog(group['id']);
                    }
                  },
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'invite',
                          child: Row(
                            children: [
                              Icon(Icons.person_add, size: 16),
                              SizedBox(width: 8),
                              Text('Invite Members'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'members',
                          child: Row(
                            children: [
                              Icon(Icons.people, size: 16),
                              SizedBox(width: 8),
                              Text('View Members'),
                            ],
                          ),
                        ),
                      ],
                  child: Icon(Icons.more_vert, color: Colors.grey[600]),
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
              'Create your first group or wait for invitations',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<int> _getMemberCount(String groupId) async {
    final response = await Supabase.instance.client
        .from('Group_Members')
        .select('id')
        .eq('group_id', groupId);
    return response.length;
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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
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
                    backgroundColor: const Color(0xFF667EEA),
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
      // Generate RSA key pair
      final helper = RsaKeyHelper();
      final pair = await helper.computeRSAKeyPair(helper.getSecureRandom());
      final crypto.RSAPublicKey publicKey =
          pair.publicKey as crypto.RSAPublicKey;
      final crypto.RSAPrivateKey privateKey =
          pair.privateKey as crypto.RSAPrivateKey;
      final publicPem = CryptoUtils.encodeRSAPublicKeyToPem(publicKey);
      final privatePem = CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);

      // Create group
      final groupResponse =
          await Supabase.instance.client
              .from('Group')
              .insert({
                'name': name,
                'user_id': _currentUserId,
                'rsa_public_key': publicPem,
                'rsa_private_key': privatePem,
              })
              .select()
              .single();

      // Add creator as first member
      await Supabase.instance.client.from('Group_Members').insert({
        'group_id': groupResponse['id'],
        'user_id': _currentUserId,
      });

      // Refresh groups list
      await _fetchGroups();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group "$name" created successfully!'),
            backgroundColor: const Color(0xFF667EEA),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showInviteDialog(String groupId) {
    final TextEditingController emailController = TextEditingController();
    bool isInviting = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Invite Member'),
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
                  onPressed: isInviting ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      isInviting
                          ? null
                          : () async {
                            if (emailController.text.isNotEmpty) {
                              setDialogState(() => isInviting = true);
                              await _inviteUser(groupId, emailController.text);
                              Navigator.pop(context);
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667EEA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      isInviting
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
                          : const Text('Invite'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _inviteUser(String groupId, String email) async {
    try {
      // Find user by email from custom User table
      final userResponse =
          await Supabase.instance.client
              .from('User')
              .select('id')
              .eq('email', email)
              .maybeSingle();

      if (userResponse == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found with this email'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check if user is already a member
      final memberCheck =
          await Supabase.instance.client
              .from('Group_Members')
              .select('id')
              .eq('group_id', groupId)
              .eq('user_id', userResponse['id'])
              .maybeSingle();

      if (memberCheck != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User is already a member of this group'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Check for existing pending invitation
      final inviteCheck =
          await Supabase.instance.client
              .from('Group_Invitations')
              .select('id')
              .eq('group_id', groupId)
              .eq('invitee_id', userResponse['id'])
              .eq('status', 'pending')
              .maybeSingle();

      if (inviteCheck != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invitation already sent to this user'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Send invitation
      await Supabase.instance.client.from('Group_Invitations').insert({
        'group_id': groupId,
        'invitee_id': userResponse['id'],
        'invited_by': _currentUserId,
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation sent to $email'),
            backgroundColor: const Color(0xFF667EEA),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending invitation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showInvitationsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Group Invitations'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _invitations.length,
              itemBuilder: (context, index) {
                final invitation = _invitations[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invitation['Group']['name'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Invited by: ${invitation['invited_by_user']['email']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed:
                                  () => _respondToInvitation(
                                    invitation['id'],
                                    'rejected',
                                  ),
                              child: const Text('Reject'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed:
                                  () => _respondToInvitation(
                                    invitation['id'],
                                    'accepted',
                                    groupId: invitation['group_id'],
                                  ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF667EEA),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Accept'),
                            ),
                          ],
                        ),
                      ],
                    ),
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

  Future<void> _respondToInvitation(
    String invitationId,
    String status, {
    String? groupId,
  }) async {
    try {
      // Update invitation status
      await Supabase.instance.client
          .from('Group_Invitations')
          .update({
            'status': status,
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invitationId);

      // If accepted, add user to group members
      if (status == 'accepted' && groupId != null) {
        await Supabase.instance.client.from('Group_Members').insert({
          'group_id': groupId,
          'user_id': _currentUserId,
        });
      }

      // Refresh data
      await _fetchInvitations();
      await _fetchGroups();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'accepted'
                  ? 'Invitation accepted! You\'ve joined the group.'
                  : 'Invitation rejected.',
            ),
            backgroundColor:
                status == 'accepted'
                    ? const Color(0xFF667EEA)
                    : Colors.grey[600],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error responding to invitation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMembersDialog(String groupId) async {
    try {
      final response = await Supabase.instance.client
          .from('Group_Members')
          .select('''
            *,
            User!user_id(email)
          ''')
          .eq('group_id', groupId);

      final members = List<Map<String, dynamic>>.from(response);

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
                        backgroundColor: const Color(0xFF667EEA),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading members: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
