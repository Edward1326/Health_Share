import 'package:flutter/material.dart';
import 'package:health_share/components/navbar_main.dart';
import 'package:health_share/screens/organizations/all_orgs/org_details.dart';
import 'package:health_share/services/org_services/org_service.dart';

class OrgsScreen extends StatefulWidget {
  const OrgsScreen({super.key});

  @override
  State<OrgsScreen> createState() => _OrgsScreenState();
}

class _OrgsScreenState extends State<OrgsScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  int _selectedIndex = 2;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> _allOrganizations = [];

  bool _isLoading = false;
  bool _isList = true;

  static const primaryColor = const Color(0xFF416240);
  static const accentColor = const Color(0xFFA3B18A);
  static const lightBg = Color(0xFFF8FAF8);
  static const borderColor = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    _slideController.forward();
    _fetchAllOrganizations();
  }

  Future<void> _fetchAllOrganizations() async {
    setState(() => _isLoading = true);
    try {
      final orgs = await OrgService.fetchAllOrgs();
      setState(() => _allOrganizations = orgs);
    } catch (e) {
      _showError('Error loading organizations: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredOrganizations {
    if (_searchQuery.isEmpty) return _allOrganizations;
    return _allOrganizations
        .where(
          (org) => (org['name'] ?? '').toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  void _toggleLayout() {
    setState(() {
      _isList = !_isList;
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
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
                              hintText: 'Search organizations',
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
                // My Organizations title + layout toggle (bottom)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Organizations',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: titleFontSize,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isList
                            ? Icons.grid_view_rounded
                            : Icons.view_list_rounded,
                        color: primaryColor,
                      ),
                      onPressed: _toggleLayout,
                      iconSize: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child:
              _isLoading
                  ? const Center(
                    child: CircularProgressIndicator(
                      color: primaryColor,
                      strokeWidth: 2.5,
                    ),
                  )
                  : _filteredOrganizations.isEmpty
                  ? _buildEmptyState()
                  : _isList
                  ? _buildOrgList()
                  : _buildOrgGrid(),
        ),
      ),
      bottomNavigationBar: MainNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }

  // --- FIXED & IMPROVED LAYOUTS ---

  Widget _buildOrgList() {
    final orgs = _filteredOrganizations;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding =
        screenWidth > 900 ? 60.0 : (screenWidth > 600 ? 40.0 : 16.0);

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 20,
      ),
      itemCount: orgs.length,
      itemBuilder: (context, i) {
        final org = orgs[i];
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 250 + (i * 40)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => OrgDetailsScreen(
                          orgId: org['id'],
                          orgName: org['name'],
                        ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Left image
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                      child: Image.network(
                        org['image'] ?? '',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Container(
                              width: 100,
                              height: 100,
                              color: primaryColor.withOpacity(0.08),
                              child: Icon(
                                Icons.business_rounded,
                                color: primaryColor.withOpacity(0.4),
                                size: 40,
                              ),
                            ),
                      ),
                    ),

                    // Right content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              org['name'] ?? 'Unnamed Organization',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              org['description'] ?? 'No description available',
                              style: TextStyle(
                                fontSize: 13,
                                color: primaryColor.withOpacity(0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrgGrid() {
    final orgs = _filteredOrganizations;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding =
        screenWidth > 900 ? 60.0 : (screenWidth > 600 ? 40.0 : 16.0);

    int crossAxisCount = 2;
    if (screenWidth > 1200)
      crossAxisCount = 4;
    else if (screenWidth > 900)
      crossAxisCount = 3;
    else if (screenWidth < 600)
      crossAxisCount = 2;

    return GridView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 20,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: orgs.length,
      itemBuilder: (context, i) {
        final org = orgs[i];
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 250 + (i * 40)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(scale: 0.9 + (value * 0.1), child: child),
            );
          },
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => OrgDetailsScreen(
                        orgId: org['id'],
                        orgName: org['name'],
                      ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top image
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        org['image'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Container(
                              color: primaryColor.withOpacity(0.08),
                              child: Icon(
                                Icons.business_rounded,
                                color: primaryColor.withOpacity(0.4),
                                size: 50,
                              ),
                            ),
                      ),
                    ),
                  ),

                  // Bottom details
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            org['name'] ?? 'Unnamed Organization',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: primaryColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            org['description'] ?? 'No description available',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryColor.withOpacity(0.7),
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
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
      },
    );
  }

  Widget _buildOrgCard(Map<String, dynamic> org) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth <= 900;

    final cardMaxWidth = screenWidth > 1200 ? 1100.0 : 900.0;
    final cardHeight = isMobile ? 160.0 : (isTablet ? 180.0 : 200.0);
    final imageWidth = isMobile ? 120.0 : (isTablet ? 220.0 : 280.0);
    final cardPadding = isMobile ? 16.0 : (isTablet ? 18.0 : 20.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (c) =>
                      OrgDetailsScreen(orgId: org['id'], orgName: org['name']),
            ),
          );
        },
        child: Container(
          constraints: BoxConstraints(maxWidth: cardMaxWidth),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child:
                isMobile
                    ? _buildMobileCardLayout(
                      org,
                      cardHeight,
                      imageWidth,
                      cardPadding,
                    )
                    : _buildDesktopCardLayout(
                      org,
                      imageWidth,
                      cardPadding,
                      isTablet,
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrgGridCard(Map<String, dynamic> org) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (c) =>
                      OrgDetailsScreen(orgId: org['id'], orgName: org['name']),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image at top
              Expanded(flex: 2, child: _buildOrgImage(org, isMobile: true)),
              // Details at bottom
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildOrgGridDetails(org),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCardLayout(
    Map<String, dynamic> org,
    double height,
    double imageWidth,
    double padding,
  ) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildOrgImage(org, width: imageWidth, isMobile: true),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: _buildOrgDetails(org, isMobile: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopCardLayout(
    Map<String, dynamic> org,
    double imageWidth,
    double padding,
    bool isTablet,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildOrgImage(org, width: imageWidth, isMobile: false),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: _buildOrgDetails(org, isMobile: false, isTablet: isTablet),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrgImage(
    Map<String, dynamic> org, {
    double? height,
    double? width,
    required bool isMobile,
  }) {
    final imageUrl = org['image'] as String?;

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          bottomLeft: Radius.circular(18),
        ),
      ),
      padding: const EdgeInsets.only(left: 5),
      child:
          imageUrl != null && imageUrl.isNotEmpty
              ? ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildImagePlaceholder();
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        color: primaryColor,
                        strokeWidth: 2,
                        value:
                            loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                      ),
                    );
                  },
                ),
              )
              : _buildImagePlaceholder(),
    );
  }

  Widget _buildImagePlaceholder() {
    return Center(
      child: Icon(
        Icons.business_rounded,
        color: primaryColor.withOpacity(0.3),
        size: 64,
      ),
    );
  }

  Widget _buildOrgDetails(
    Map<String, dynamic> org, {
    required bool isMobile,
    bool isTablet = false,
  }) {
    final titleFontSize = isMobile ? 16.0 : (isTablet ? 18.0 : 20.0);
    final descriptionFontSize = isMobile ? 13.0 : (isTablet ? 14.0 : 15.0);
    final maxLines = isMobile ? 2 : (isTablet ? 2 : 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                org['name'] ?? 'Unnamed Organization',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: titleFontSize,
                  color: primaryColor,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  org['description'] ?? 'No description available',
                  style: TextStyle(
                    fontSize: descriptionFontSize,
                    color: primaryColor.withOpacity(0.65),
                    height: 1.5,
                  ),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (!isMobile) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 14 : 16,
                  vertical: isTablet ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: isTablet ? 13 : 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: isTablet ? 16 : 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildOrgGridDetails(Map<String, dynamic> org) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                org['name'] ?? 'Unnamed Organization',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: primaryColor,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  org['description'] ?? 'No description available',
                  style: TextStyle(
                    fontSize: 13,
                    color: primaryColor.withOpacity(0.65),
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
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
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.business_rounded,
                color: primaryColor.withOpacity(0.3),
                size: 56,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'No organizations found',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Try adjusting your search criteria',
              style: TextStyle(
                fontSize: 15,
                color: primaryColor.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}
