import 'package:flutter/material.dart';
import 'package:health_share/screens/navbar/navbar_main.dart';
import 'package:health_share/screens/organizations/org_details.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrgScreen extends StatefulWidget {
  const OrgScreen({super.key});

  @override
  State<OrgScreen> createState() => _OrgScreenState();
}

class _OrgScreenState extends State<OrgScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  int _selectedIndex = 3;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> _organizations = [];
  bool _isLoading = false;

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
    _fetchOrganizations();
  }

  Future<void> _fetchOrganizations() async {
    setState(() => _isLoading = true);
    final response = await Supabase.instance.client
        .from('Organization')
        .select()
        .order('name', ascending: true);
    setState(() {
      _organizations = List<Map<String, dynamic>>.from(response);
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredOrganizations {
    if (_searchQuery.isEmpty) return _organizations;
    return _organizations
        .where(
          (org) => (org['name'] ?? '').toString().toLowerCase().contains(
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
          'Organizations', // Changed from 'Groups'
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
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
              child: _buildSearchBar(), // Only the search bar remains
            ),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildOrganizationsList(),
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
          hintText: 'Search for organizations...',
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

  Widget _buildOrganizationsList() {
    final filteredOrgs = _filteredOrganizations;
    if (filteredOrgs.isEmpty) {
      return _buildEmptySearchState();
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      itemCount: filteredOrgs.length,
      itemBuilder: (context, index) {
        final org = filteredOrgs[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildOrganizationCard(org),
        );
      },
    );
  }

  Widget _buildOrganizationCard(Map<String, dynamic> org) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => OrgDetailsScreen(
                    orgId: org['id'],
                    orgName: org['name'] ?? 'No Name',
                  ),
            ),
          );
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  org['name'] ?? 'No Name',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  org['description'] ?? '',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearchState() {
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
              child: Icon(Icons.search_off, color: Colors.grey[400], size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              'No organizations found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching with different keywords or create a new organization',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
