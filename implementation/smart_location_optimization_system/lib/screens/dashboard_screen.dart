import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/map_view.dart';
import '../widgets/search_dialog.dart';
import 'my_zone_view.dart';
import 'history_view.dart';
import 'ai_analyzer_view.dart';
import 'comparison_view.dart';
import 'profile_view.dart';
import 'settings_view.dart';
import '../services/supabase_auth_service.dart';
import '../services/user_data_sync_service.dart';
import 'properties_view.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  final bool isGuest;
  const DashboardScreen({super.key, this.isGuest = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 1; // 1 = Explore
  int _myZoneTabIndex = 0; // 0 = Saved Locations, 1 = Reports, 2 = Favorites
  late PageController _pageController;
  final StreamController<String> _searchStreamController = StreamController<String>.broadcast();
  Map<String, dynamic>? _selectedAnalysisData;
  Map<String, dynamic>? _selectedPropertyForView;
  bool _isSelectingLocationForAnalyzer = false;
  Map<String, dynamic>? _analyzerPreSelectedLocation;

  @override
  void initState() {
    super.initState();
    _loadSavedTab();
    _pageController = PageController(initialPage: _selectedIndex);
    
    if (!widget.isGuest) {
      UserDataSyncService.loadUserData(merge: true).then((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
    
    // Show the glowing search dialog after a brief delay ONLY if on Explore tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedIndex == 1) {
        Future.delayed(const Duration(milliseconds: 500), () async {
          if (!mounted) return;
          final result = await showDialog<Map<String, dynamic>>(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.6),
            builder: (context) => SearchDialog(isGuest: widget.isGuest),
          );
          if (result != null && result['city'] != null) {
            _searchStreamController.add(jsonEncode(result));
          }
        });
      }
    });
  }

  Future<void> _loadSavedTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIndex = prefs.getInt('last_dashboard_tab');
      if (savedIndex != null && savedIndex >= 0 && savedIndex <= 6 && mounted) {
        setState(() {
          _selectedIndex = savedIndex;
        });
        if (_pageController.hasClients) {
          _pageController.jumpToPage(savedIndex);
        }
      }
    } catch (e) {
      debugPrint('Error loading saved tab: $e');
    }
  }

  Future<void> _saveTab(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_dashboard_tab', index);
    } catch (e) {
      debugPrint('Error saving tab: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchStreamController.close();
    super.dispose();
  }

  void _showGuestRestrictionDialog() {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const Icon(Icons.lock_outline, size: 48, color: Colors.purple),
                const SizedBox(height: 16),
                Text(
                  'Login Required',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'You should login first or create an account to use the AI Analyzer.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
  }

  void _onItemTapped(int index, {Map<String, dynamic>? analysisData, int myZoneTabIndex = 0}) {
    if (widget.isGuest && index == 3) {
      _showGuestRestrictionDialog();
      return;
    }
    setState(() {
      _selectedIndex = index;
      _selectedAnalysisData = analysisData;
      if (index == 0) {
        _myZoneTabIndex = myZoneTabIndex;
      }
    });
    _saveTab(index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Top App Bar
          Container(
            height: isMobile ? 80 : 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
              ],
            ),
            child: isMobile 
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildBranding(isMobile),
                        _buildUserActions(isMobile),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildSearchBar(),
                  ],
                )
              : Row(
                  children: [
                    _buildBranding(isMobile),
                    const SizedBox(width: 32),
                    Expanded(child: _buildSearchBar()),
                    const SizedBox(width: 24),
                    _buildUserActions(isMobile),
                  ],
                ),
          ),
          // Swipeable Main Content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                  _saveTab(index);
                });
              },
              children: [
                MyZoneView(
                  initialTabIndex: _myZoneTabIndex,
                  onViewOnMap: (lat, lon, title, subtitle, item) {
                    final bool isProperty = item['isProperty'] == true;
                    if (isProperty) {
                      setState(() {
                        _selectedPropertyForView = item;
                      });
                      _onItemTapped(2); // Switch to property tab
                    } else {
                      _onItemTapped(1); // Switch to map tab
                      String businessType = 'Sports & Fitness';
                      if (subtitle.contains(' • ')) {
                        businessType = subtitle.split(' • ')[0];
                      }
                      _searchStreamController.add(jsonEncode({
                        'city': subtitle,
                        'location': title,
                        'businessType': businessType,
                        'lat': lat,
                        'lon': lon,
                        'score': item['score'] ?? 0,
                        if (item['analysisData'] != null) 'analysisData': item['analysisData'],
                      }));
                    }
                  },
                ),
                DashboardMapView(
                  searchStream: _searchStreamController.stream,
                  onNavigateToMyZone: ({int myZoneTabIndex = 0}) => _onItemTapped(0, myZoneTabIndex: myZoneTabIndex),
                  isSelectingLocation: _isSelectingLocationForAnalyzer,
                  onLocationSelected: (location) {
                    setState(() {
                      _isSelectingLocationForAnalyzer = false;
                      _analyzerPreSelectedLocation = location;
                    });
                    _onItemTapped(3); // Switch to AI Analyzer tab
                  },
                  onNavigateToTab: (index, {analysisData}) => _onItemTapped(index, analysisData: analysisData),
                ),
                PropertiesView(initialProperty: _selectedPropertyForView),
                AiAnalyzerView(
                  key: ValueKey(_selectedAnalysisData ?? _analyzerPreSelectedLocation), // Force rebuild when data/selection changes
                  initialAnalysisData: _selectedAnalysisData,
                  preSelectedLocation: _analyzerPreSelectedLocation,
                  onViewOnMap: (lat, lon, city) {
                    _onItemTapped(1); // Switch to Explore tab
                    // Emit search event to move map and set heatmap
                    _searchStreamController.add(jsonEncode({
                      'city': city,
                      'location': city,
                      'businessType': 'Sports & Fitness',
                      'lat': lat,
                      'lon': lon,
                    }));
                  },
                  onSelectFromMap: (city, category) {
                    setState(() {
                      _isSelectingLocationForAnalyzer = true;
                      _analyzerPreSelectedLocation = null;
                    });
                    _onItemTapped(1); // Switch to Explore Map tab
                    _searchStreamController.add(jsonEncode({
                      'city': city,
                      'location': city,
                      'businessType': category
                    }));
                  },
                  onResetSelection: () {
                    setState(() {
                      _analyzerPreSelectedLocation = null;
                      _selectedAnalysisData = null;
                    });
                  },
                ),
                 HistoryView(
                   onView: (item) {
                     _onItemTapped(1); // Switch to Explore Map tab
                     // Emit search event with full coordinate and metric data
                     _searchStreamController.add(jsonEncode({
                       'city': item.analysisData?['city'] ?? '',
                       'location': item.title,
                       'businessType': item.analysisData?['details']?['detected_category_level1'] ?? 'Sports & Fitness',
                       'lat': item.lat,
                       'lon': item.lon,
                       'score': item.score,
                       'analysisData': item.analysisData,
                     }));
                   },
                 ),
                 ComparisonView(
                   onNavigateToMyZoneReports: () => _onItemTapped(0, myZoneTabIndex: 1),
                 ),
                ProfileView(
                  isGuest: widget.isGuest,
                  onViewSavedLocations: () => _onItemTapped(0, myZoneTabIndex: 0),
                ),
                const SettingsView(),
              ],
            ),
          ),
          // Bottom Navigation Menu (Custom Scrollable)
          _buildBottomMenu(),
        ],
      ),
    );
  }

  Widget _buildBranding(bool isMobile) {
    return Row(
      children: [
        Image.asset('assets/logo.png', height: isMobile ? 24 : 32),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Loca.ai',
              style: GoogleFonts.inter(
                color: Colors.black, 
                fontWeight: FontWeight.bold, 
                fontSize: isMobile ? 16 : 18,
              ),
            ),
            if (!isMobile)
              Text(
                'Smart Location AI',
                style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 10),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        onTap: () async {
          final result = await showDialog<Map<String, dynamic>>(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.6),
            builder: (context) => SearchDialog(isGuest: widget.isGuest),
          );
          if (result != null && result['city'] != null) {
            _searchStreamController.add(jsonEncode(result));
          }
        },
        readOnly: true,
        decoration: InputDecoration(
          hintText: 'Search locations, properties...',
          hintStyle: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildUserActions(bool isMobile) {
    final avatarUrl = SupabaseAuthService.currentUserAvatar;
    return Row(
      children: [
        InkWell(
          onTap: () => _onItemTapped(6),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.grey.shade200,
                  child: ClipOval(
                    child: (widget.isGuest || avatarUrl == null)
                        ? const Icon(Icons.person, size: 18, color: Colors.grey)
                        : _buildHeaderAvatar(avatarUrl, 28),
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 8),
                  Text(widget.isGuest ? 'Guest' : SupabaseAuthService.currentUserName, style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderAvatar(String url, double size) {
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      } catch (e) {
        return Icon(Icons.person, size: size / 2, color: Colors.grey);
      }
    }
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.person, size: size / 2, color: Colors.grey),
    );
  }

  Widget _buildBottomMenu() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildBottomItem(0, Icons.location_on_outlined, 'My Zone'),
            _buildBottomItem(1, Icons.search, 'Explore'),
            _buildBottomItem(2, Icons.business, 'Property'),
            _buildBottomItem(3, Icons.analytics_outlined, 'AI-Analyzer'),
            _buildBottomItem(4, Icons.history, 'History'),
            _buildBottomItem(5, Icons.compare_arrows, 'Comparison'),
            _buildBottomItem(6, Icons.person_outline, 'Profile'),
            _buildBottomItem(7, Icons.settings_outlined, 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue.shade600 : Colors.grey.shade500,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.blue.shade600 : Colors.grey.shade500,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
