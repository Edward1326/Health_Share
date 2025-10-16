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
  bool _isSearchExpanded = false;

  List<Map<String, dynamic>> _allOrganizations = [];

  bool _isLoading = false;

  static const primaryColor = Color(0xFF416240);
  static const accentColor = Color(0xFF6A8E6E);
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

  bool _isMobileLayout(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
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

    // Responsive dimensions
    final titleFontSize = isLargeScreen ? 24.0 : (isTablet ? 22.0 : 20.0);
    final toolbarHeight = isDesktop ? 72.0 : 64.0;
    final searchExpandedWidth =
        isLargeScreen ? 350.0 : (isTablet ? 280.0 : screenWidth * 0.6);
    final horizontalPadding = isLargeScreen ? 60.0 : (isTablet ? 40.0 : 20.0);

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: toolbarHeight,
        title: Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Health Share',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: titleFontSize,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Search icon/bar on the right
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: _isSearchExpanded ? searchExpandedWidth : 51,
                height: 48,
                decoration: BoxDecoration(
                  color: _isSearchExpanded ? lightBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isSearchExpanded ? borderColor : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isSearchExpanded
                            ? Icons.close_rounded
                            : Icons.search_rounded,
                        color: primaryColor,
                        size: 24,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSearchExpanded = !_isSearchExpanded;
                          if (!_isSearchExpanded) {
                            _searchController.clear();
                            _searchQuery = '';
                          }
                        });
                      },
                    ),
                    if (_isSearchExpanded)
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          onChanged:
                              (value) => setState(() => _searchQuery = value),
                          style: const TextStyle(
                            fontSize: 15,
                            color: primaryColor,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search organizations...',
                            hintStyle: TextStyle(
                              color: primaryColor.withOpacity(0.4),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.only(right: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: borderColor),
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
                  : _buildOrgList(),
        ),
      ),
      bottomNavigationBar: MainNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }

  Widget _buildOrgList() {
    final orgs = _filteredOrganizations;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding =
        screenWidth > 900 ? 60.0 : (screenWidth > 600 ? 40.0 : 20.0);

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 20,
      ),
      itemCount: orgs.length,
      itemBuilder: (context, i) {
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (i * 50)),
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
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildOrgCard(orgs[i]),
          ),
        );
      },
    );
  }

  Widget _buildOrgCard(Map<String, dynamic> org) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth <= 900;

    // Responsive card dimensions
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
    // Responsive font sizes
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
