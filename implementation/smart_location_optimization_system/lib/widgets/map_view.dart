import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import '../services/history_service.dart';
import './score_popup.dart';
import './rental_estimate_popup.dart';
import '../screens/comparison_view.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

enum MapAnalysisMode { predict, rentEstimate }

class CandidateData {
  final int number;
  final LatLng position;
  final SuitabilityResult result;
  bool isOptimized = false;

  CandidateData({
    required this.number,
    required this.position,
    required this.result,
  });
}

class DashboardMapView extends StatefulWidget {
  final Stream<String>? searchStream;
  final void Function({int myZoneTabIndex})? onNavigateToMyZone;
  final bool isSelectingLocation;
  final void Function(Map<String, dynamic> location)? onLocationSelected;
  final void Function(int index, {Map<String, dynamic>? analysisData})? onNavigateToTab;

  const DashboardMapView({
    super.key,
    this.searchStream,
    this.onNavigateToMyZone,
    this.isSelectingLocation = false,
    this.onLocationSelected,
    this.onNavigateToTab,
  });

  @override
  State<DashboardMapView> createState() => DashboardMapViewState();
}

class DashboardMapViewState extends State<DashboardMapView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Persisted static variables to survive state destruction across tabs/activities
  static String? _persistedCityName;
  static LatLng? _persistedCityCoords;
  static String _persistedSelectedHeatmap = 'Overall';
  static String? _persistedSelectedMarkerCategory;
  static Map<String, dynamic>? _persistedSelectedLocation;
  static List<Marker> _persistedCategoryMarkers = [];
  static List<CircleMarker> _persistedHeatmapCircles = [];
  static bool _persistedShowAvailableListings = false;
  static double _persistedZoom = 5.5;

  double _currentZoom = 5.5;

  void _saveStateToPersisted() {
    _persistedCityName = _activeCityName;
    _persistedCityCoords = _activeCityCoords;
    _persistedSelectedHeatmap = _selectedHeatmap;
    _persistedSelectedMarkerCategory = _selectedMarkerCategory;
    _persistedSelectedLocation = _selectedLocation;
    _persistedCategoryMarkers = _categoryMarkers;
    _persistedHeatmapCircles = _activeHeatmapCircles;
    _persistedShowAvailableListings = _showAvailableListings;
    _persistedZoom = _currentZoom;
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
      _saveStateToPersisted();
    }
  }

  String? _resolveCityName(String? name, LatLng? coords) {
    if (name != null && name.isNotEmpty) {
      final clean = name.toLowerCase().trim();
      if (clean.contains('lahore')) return 'Lahore';
      if (clean.contains('karachi')) return 'Karachi';
      if (clean.contains('islamabad')) return 'Islamabad';
      if (clean.contains('rawalpindi')) return 'Rawalpindi';
    }
    
    if (coords != null) {
      final Map<String, LatLng> knownCities = {
        'Lahore': const LatLng(31.5204, 74.3587),
        'Karachi': const LatLng(24.8607, 67.0011),
        'Islamabad': const LatLng(33.6844, 73.0479),
        'Rawalpindi': const LatLng(33.5984, 73.0441),
      };
      
      String closestCity = 'Lahore';
      double minDistance = double.infinity;
      for (final entry in knownCities.entries) {
        final distance = Geolocator.distanceBetween(
          coords.latitude,
          coords.longitude,
          entry.value.latitude,
          entry.value.longitude,
        );
        if (distance < minDistance) {
          minDistance = distance;
          closestCity = entry.key;
        }
      }
      return closestCity;
    }
    return null;
  }

  // Center on Pakistan/Regional view as per screenshot
  final LatLng _initialCenter = LatLng(30.3753, 69.3451);
  final MapController _mapController = MapController();
  
  String _selectedHeatmap = 'Overall';
  String? _selectedMarkerCategory;
  bool _isLayersPanelExpanded = true;
  bool _isSearching = false;
  bool _isLoadingHeatmap = false;
  List<CircleMarker> _activeHeatmapCircles = [];
  List<Marker> _categoryMarkers = [];
  String _selectedMinPrice = 'Min';
  String _selectedMaxPrice = 'Max';
  bool _usePriceRange = false;
  
  Timer? _propertiesDebounceTimer;
  
  // New Analysis State
  final List<CandidateData> _candidates = [];
  MapAnalysisMode _analysisMode = MapAnalysisMode.predict;
  bool _isLoadingAnalysis = false;
  bool _isLoadingOptimize = false;
  bool _optimizationDone = false;
  List<CandidateLocation> _optimizedResults = [];
  
  // Optimization settings
  int _numToSelect = 2;
  double _minDistKm = 5.0;
  
  // Separate Lists for Heatmap Layers
  // (Removed unused fallback circle lists)
  
  // New State for Explore Cards
  Map<String, dynamic>? _selectedLocation;
  final List<Map<String, dynamic>> _comparisonLocations = [];
  bool _isComparing = false;
  bool _isSelectionMode = false;
  
  // State for Map Layers
  bool _showAvailableListings = false;
  bool _showForSale = true;
  bool _showForRent = true;
  bool _showHeatmap = false;
  String? _activeCityName;
  LatLng? _activeCityCoords;
  bool _justClickedMarker = false;
  bool _isProgrammaticMove = false;

  double _parseTimeSpent(dynamic value) {
    if (value == null) return 45.0;
    if (value is num) return value.toDouble();
    final String str = value.toString().toLowerCase();
    if (str.contains('hour')) {
      final match = RegExp(r'([\d.]+)').firstMatch(str);
      if (match != null) {
        final hours = double.tryParse(match.group(1) ?? '1') ?? 1.0;
        return hours * 60.0;
      }
    } else if (str.contains('min')) {
      final match = RegExp(r'([\d.]+)').firstMatch(str);
      if (match != null) {
        return double.tryParse(match.group(1) ?? '30') ?? 30.0;
      }
    }
    return 45.0;
  }

  double _parseRentToNumericValue(dynamic rentValue) {
    if (rentValue == null) return 50.0;
    String clean = rentValue.toString().trim().toLowerCase();
    
    // Remove currency prefixes
    clean = clean.replaceAll('pkr', '').replaceAll('pr', '').replaceAll('rs', '').trim();
    
    // Remove suffix markers like /mo or /marla
    clean = clean.replaceAll('/mo', '').replaceAll('/marla', '').replaceAll(' ', '').replaceAll(',', '');
    
    double multiplier = 1.0;
    if (clean.endsWith('m')) {
      multiplier = 1000.0; // In thousands, so 22.5M = 22500K
      clean = clean.substring(0, clean.length - 1);
    } else if (clean.endsWith('k')) {
      multiplier = 1.0; // In thousands, so 150K = 150
      clean = clean.substring(0, clean.length - 1);
    } else {
      final rawVal = double.tryParse(clean);
      if (rawVal != null) {
        if (rawVal >= 1000) {
          return rawVal / 1000.0;
        }
        return rawVal;
      }
    }
    
    final val = double.tryParse(clean);
    if (val != null) {
      return val * multiplier;
    }
    return 50.0; // Fallback
  }

  double _parsePriceRangeValue(String value, {required bool isMin}) {
    final clean = value.toLowerCase().trim();
    if (clean == 'min') return 0.0;
    if (clean == 'max') return double.infinity;
    final numeric = clean.replaceAll('k', '');
    return double.tryParse(numeric) ?? (isMin ? 0.0 : double.infinity);
  }

  String _formatPriceValue(dynamic priceValue) {
    if (priceValue == null) return '0k';
    final str = priceValue.toString().toLowerCase();
    if (str.endsWith('k') || str.endsWith('m')) {
      return priceValue.toString();
    }
    final cleanStr = priceValue.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    final numValue = double.tryParse(cleanStr);
    if (numValue == null) return priceValue.toString();
    String formatted = '';
    if (numValue >= 1000000) {
      final double millions = numValue / 1000000.0;
      formatted = millions == millions.toInt() 
          ? '${millions.toInt()}M' 
          : '${millions.toStringAsFixed(1)}M';
    } else if (numValue >= 1000) {
      final double thousands = numValue / 1000.0;
      formatted = thousands == thousands.toInt() 
          ? '${thousands.toInt()}k' 
          : '${thousands.toStringAsFixed(1)}k';
    } else {
      formatted = numValue == numValue.toInt() ? '${numValue.toInt()}' : numValue.toString();
    }
    if (str.contains('/mo')) {
      formatted += '/mo';
    } else if (str.contains('/marla')) {
      formatted += '/marla';
    }
    return formatted;
  }

  List<Map<String, dynamic>> _properties = [];

  Future<void> _loadProperties(double lat, double lon) async {
    try {
      final data = await ApiService.getProperties(lat: lat, lon: lon, radiusKm: 30.0, city: _activeCityName);
      if (mounted) {
        setState(() {
          var filteredData = data;
          if (_activeCityName != null && _activeCityName!.isNotEmpty) {
            final activeCityLower = _activeCityName!.toLowerCase().trim();
            filteredData = data.where((p) {
              final propCity = (p['city'] ?? p['location'] ?? '').toString().toLowerCase();
              return propCity.contains(activeCityLower) || activeCityLower.contains(propCity);
            }).toList();
          }
          _properties = filteredData.map((p) {
            final formattedPriceStr = _formatPriceValue(p['price']);
            return {
              'title': '${p['property_type'] ?? 'Property'} in ${p['location'] ?? 'Unknown'}',
              'price': 'PKR $formattedPriceStr',
              'status': p['purpose'] ?? 'Available',
              'score': p['Area_in_Marla'] ?? 0,
              'scoreLabel': 'Property Size',
              'traffic': p['bedrooms'] ?? 0,
              'competition': 50,
              'rent': 'PKR $formattedPriceStr',
              'lat': (p['latitude'] as num).toDouble(),
              'lon': (p['longitude'] as num).toDouble(),
              'isProperty': true,
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading properties: $e');
    }
  }

  void _promptCityForProperties() {
    final TextEditingController searchController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 24,
          child: Container(
            padding: const EdgeInsets.all(24),
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.home_work_rounded, color: Colors.blue.shade700, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Search Property Listings',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Please select or search a city in Pakistan to load available properties from the database.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'POPULAR CITIES',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildQuickCityChip('Lahore', LatLng(31.5204, 74.3587)),
                    _buildQuickCityChip('Karachi', LatLng(24.8607, 67.0011)),
                    _buildQuickCityChip('Islamabad', LatLng(33.6844, 73.0479)),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'SEARCH CUSTOM CITY',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: searchController,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. Rawalpindi, Peshawar...',
                    hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      Navigator.pop(context);
                      searchLocation(val.trim());
                    }
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() => _showAvailableListings = false);
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        final val = searchController.text.trim();
                        if (val.isNotEmpty) {
                          Navigator.pop(context);
                          searchLocation(val);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 0,
                      ),
                      child: Text(
                        'Search',
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickCityChip(String city, LatLng coords) {
    return ActionChip(
      label: Text(city),
      labelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.blue.shade700,
      ),
      backgroundColor: Colors.blue.shade50,
      side: BorderSide(color: Colors.blue.shade100),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () {
        Navigator.pop(context);
        setState(() {
          _activeCityCoords = coords;
          _activeCityName = city;
        });
        _mapController.move(coords, 12.0);
        _loadProperties(coords.latitude, coords.longitude);
        _loadHeatmapForCategory(_selectedHeatmap, isHeatmap: true, isMarkers: false);
        if (_selectedMarkerCategory != null) {
          _loadHeatmapForCategory(_selectedMarkerCategory!, isHeatmap: false, isMarkers: true);
        }
      },
    );
  }

  final List<String> _categories = [
    'Sports & Fitness',
    'Retail & Shopping',
    'Travel & Lodging',
    'Transportation & Logistics'
  ];

  @override
  void initState() {
    super.initState();
    
    // Restore persisted state
    _activeCityName = _persistedCityName;
    _activeCityCoords = _persistedCityCoords;
    _selectedHeatmap = _persistedSelectedHeatmap;
    _selectedMarkerCategory = _persistedSelectedMarkerCategory;
    _selectedLocation = _persistedSelectedLocation;
    _categoryMarkers = List.from(_persistedCategoryMarkers);
    _activeHeatmapCircles = List.from(_persistedHeatmapCircles);
    _showAvailableListings = _persistedShowAvailableListings;
    _currentZoom = _persistedZoom;

    if (_activeCityCoords != null && _showAvailableListings) {
      _loadProperties(_activeCityCoords!.latitude, _activeCityCoords!.longitude);
    }
    
    if (_categoryMarkers.isEmpty && _selectedMarkerCategory != null) {
      _loadHeatmapForCategory(_selectedMarkerCategory!, isHeatmap: false, isMarkers: true);
    }
    if (_activeHeatmapCircles.isEmpty) {
      _loadHeatmapForCategory(_selectedHeatmap, isHeatmap: true, isMarkers: false);
    }

    if (widget.searchStream != null) {
      widget.searchStream!.listen((query) {
        searchLocation(query);
      });
    }
  }

  @override
  void dispose() {
    _propertiesDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHeatmapForCategory(String category, {bool isHeatmap = true, bool isMarkers = true}) async {
    setState(() => _isLoadingHeatmap = true);
    try {
      final data = await ApiService.getHeatmapData(category, city: null);
      
      // Filter by selected city if active, but only for markers
      var filteredDataForMarkers = data;
      if (_activeCityName != null && _activeCityName!.isNotEmpty) {
        final activeCityLower = _activeCityName!.toLowerCase().trim();
        filteredDataForMarkers = data.where((p) {
          final locality = (p['locality'] ?? '').toString().toLowerCase().trim();
          return locality.contains(activeCityLower) || activeCityLower.contains(locality);
        }).toList();
      }

      if (data.isNotEmpty) {
        final maxWeight = data.map((p) => (p['weight'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
        
        List<CircleMarker> circles = [];
        if (isHeatmap) {
          circles = data.map((p) {
            final lat = (p['lat'] as num).toDouble();
            final lon = (p['lng'] as num).toDouble();
            final weight = (p['weight'] as num).toDouble();
            final intensity = weight / maxWeight;
            
            return CircleMarker(
              point: LatLng(lat, lon),
              radius: 22 * intensity + 8,
              useRadiusInMeter: false,
              color: _getHeatmapColor(intensity).withValues(alpha: 0.25 * intensity),
              borderStrokeWidth: 0,
            );
          }).toList();
        }

        List<Marker> topMarkers = [];
        if (isMarkers && filteredDataForMarkers.isNotEmpty) {
          final sortedData = List<Map<String, dynamic>>.from(filteredDataForMarkers);
          sortedData.sort((a, b) => (b['weight'] as num).compareTo(a['weight'] as num));
          
          final filteredSortedData = sortedData.where((p) {
            if (!_usePriceRange) return true;
            final rentalAvg = p['rental_avg_per_marla'] != null ? (p['rental_avg_per_marla'] as num).toDouble() : 0.0;
            final weight = (p['weight'] as num).toDouble();
            final rentVal = rentalAvg > 0 ? rentalAvg / 1000.0 : weight * 90.0;
            
            final minLimit = _parsePriceRangeValue(_selectedMinPrice, isMin: true);
            final maxLimit = _parsePriceRangeValue(_selectedMaxPrice, isMin: false);
            return rentVal >= minLimit && rentVal <= maxLimit;
          }).toList();
          
          topMarkers = filteredSortedData.asMap().entries.map((entry) {
            final p = entry.value;
            final index = entry.key;
            final lat = (p['lat'] as num).toDouble();
            final lon = (p['lng'] as num).toDouble();
            final weight = (p['weight'] as num).toDouble();
            
            final name = p['name']?.toString() ?? '$category Site #${index + 1}';
            final locality = p['locality']?.toString() ?? 'Pakistan';
            final suitabilityScore = p['suitability_score'] != null ? (p['suitability_score'] as num).toDouble() : (weight * 150).toDouble();
            final categoryL3 = p['category_level3']?.toString() ?? '';
            final rentalAvg = p['rental_avg_per_marla'] != null ? (p['rental_avg_per_marla'] as num).toDouble() : 0.0;
            
            final priceStr = rentalAvg > 0 
                ? 'PKR ${rentalAvg.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}/marla'
                : 'PKR ${((weight * 2000) + 30000).toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}/mo';
            
            final scoreLabelStr = categoryL3.isNotEmpty 
                ? categoryL3 
                : (weight > 0.8 ? 'Premium Match' : (weight > 0.5 ? 'Excellent Match' : 'Good Match'));

            final Map<String, dynamic> locationData = {
              'title': name,
              'price': '$priceStr ($locality)',
              'status': 'Active POI',
              'score': suitabilityScore.toInt(),
              'scoreLabel': scoreLabelStr,
              'traffic': weight.toInt(),
              'competition': p['competitors_within_5km'] != null ? (p['competitors_within_5km'] as num).toInt() : (weight * 0.8).toInt(),
              'competitor_count': p['competitor_count'] != null ? (p['competitor_count'] as num).toInt() : (weight * 1.5).toInt(),
              'rent': rentalAvg > 0 ? '${(rentalAvg / 1000).toInt()}K' : '${(weight * 90).toInt()}K',
              'lat': lat,
              'lon': lon,
              'isProperty': false,
              'time_spent': _parseTimeSpent(p['time_spent']),
              'weekday_avg_popularity': p['weekday_avg_popularity'] != null ? (p['weekday_avg_popularity'] as num).toDouble() : 60.0,
              'weekend_avg_popularity': p['weekend_avg_popularity'] != null ? (p['weekend_avg_popularity'] as num).toDouble() : 75.0,
              'afternoon_avg': p['afternoon_avg'] != null ? (p['afternoon_avg'] as num).toDouble() : 65.0,
              'evening_avg': p['evening_avg'] != null ? (p['evening_avg'] as num).toDouble() : 80.0,
              'morning_avg': p['morning_avg'] != null ? (p['morning_avg'] as num).toDouble() : 40.0,
              'night_avg': p['night_avg'] != null ? (p['night_avg'] as num).toDouble() : 30.0,
              'max_popularity': p['max_popularity'] != null ? (p['max_popularity'] as num).toDouble() : 90.0,
              'peak_hour': p['peak_hour'] != null ? (p['peak_hour'] as num).toInt() : 18,
              'peak_day': p['peak_day']?.toString() ?? 'Saturday',
            };

            return Marker(
              point: LatLng(lat, lon),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) {
                  _justClickedMarker = true;
                },
                onTap: () {
                  _justClickedMarker = true;
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _justClickedMarker = false;
                  });
                  _handleLocationSelection(locationData);
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: _getHeatmapColor(weight / maxWeight),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList();
        }

        setState(() {
          if (isHeatmap) _activeHeatmapCircles = circles;
          if (isMarkers) _categoryMarkers = topMarkers;
          _isLoadingHeatmap = false;
        });
      } else {
        setState(() {
          if (isHeatmap) _activeHeatmapCircles = [];
          if (isMarkers) _categoryMarkers = [];
          _isLoadingHeatmap = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingHeatmap = false);
    }
  }

  Color _getHeatmapColor(double intensity) {
    if (intensity > 0.8) return Colors.red;
    if (intensity > 0.5) return Colors.orange;
    if (intensity > 0.3) return Colors.yellow;
    return Colors.blue;
  }

  // (Removed unused _fetchLayerData method)

  Future<void> searchLocation(String query) async {
    if (query.isEmpty) return;
    
    String searchText = query;
    String? category;

    // Check if it's JSON from SearchDialog
    if (query.startsWith('{')) {
      try {
        final data = json.decode(query);
        final city = data['city'] ?? '';
        final loc = data['location'] ?? '';
        category = data['businessType'];
        searchText = '$loc $city'.trim();
        
        setState(() {
          _selectedMinPrice = data['minPrice'] ?? 'Min';
          _selectedMaxPrice = data['maxPrice'] ?? 'Max';
          _usePriceRange = data['usePriceRange'] ?? false;
        });
        
        if (data.containsKey('lat') && data.containsKey('lon') && data['lat'] != 0.0) {
          final lat = (data['lat'] as num).toDouble();
          final lon = (data['lon'] as num).toDouble();
          final newCoords = LatLng(lat, lon);
          _activeCityCoords = newCoords;
          _activeCityName = _resolveCityName(city.isNotEmpty ? city : searchText, newCoords);
        }

        final String? cat = category;
        if (cat != null && _categories.contains(cat)) {
          setState(() {
            _selectedHeatmap = cat;
            if (_usePriceRange) {
              _showAvailableListings = true;
              _selectedMarkerCategory = cat;
            }
          });
          _loadHeatmapForCategory(cat, isHeatmap: true, isMarkers: true);
        } else {
          _loadHeatmapForCategory(_selectedHeatmap, isHeatmap: true, isMarkers: false);
          if (_selectedMarkerCategory != null) {
            _loadHeatmapForCategory(_selectedMarkerCategory!, isHeatmap: false, isMarkers: true);
          }
        }

        if (data.containsKey('lat') && data.containsKey('lon') && data['lat'] != 0.0) {
          final lat = (data['lat'] as num).toDouble();
          final lon = (data['lon'] as num).toDouble();
          if (data.containsKey('score') || data.containsKey('analysisData')) {
            final score = data['score'] ?? 0;
            final analysis = data['analysisData'] ?? {};
            
            final locMap = {
              'title': (data['location'] ?? data['title'] ?? 'Selected Site').toString(),
              'price': data['price'] != null ? data['price'].toString() : (analysis['rental_avg_per_marla'] != null ? 'PKR ${analysis['rental_avg_per_marla']}/marla' : 'Active POI'),
              'status': 'Active POI',
              'score': score,
              'scoreLabel': analysis['details']?['detected_category_level3']?.toString() ?? 'Selected Match',
              'traffic': analysis['foot_traffic']?['traffic_score'] ?? 80,
              'competition': analysis['details']?['competitors_within_5km'] ?? 3,
              'rent': analysis['rental_avg_per_marla'] != null 
                  ? '${(analysis['rental_avg_per_marla'] as num).toInt()}K' 
                  : '0K',
              'lat': lat,
              'lon': lon,
              'isProperty': false,
              'time_spent': _parseTimeSpent(analysis['time_spent']),
              'weekday_avg_popularity': ((analysis['weekday_avg_popularity'] ?? 60.0) as num).toDouble(),
              'weekend_avg_popularity': ((analysis['weekend_avg_popularity'] ?? 75.0) as num).toDouble(),
              'afternoon_avg': ((analysis['afternoon_avg'] ?? 65.0) as num).toDouble(),
              'evening_avg': ((analysis['evening_avg'] ?? 80.0) as num).toDouble(),
              'morning_avg': ((analysis['morning_avg'] ?? 40.0) as num).toDouble(),
              'night_avg': ((analysis['night_avg'] ?? 30.0) as num).toDouble(),
              'max_popularity': ((analysis['max_popularity'] ?? 90.0) as num).toDouble(),
              'peak_hour': ((analysis['peak_hour'] ?? 18) as num).toInt(),
              'peak_day': analysis['peak_day'] ?? 'Saturday',
            };
            
            setState(() {
              _selectedLocation = locMap;
            });
          }
          
          _mapController.move(LatLng(lat, lon), 15.0);
          _loadProperties(lat, lon);
          return;
        }
      } catch (e) {
        debugPrint('JSON decode error: $e');
      }
    }

    if (searchText.isEmpty) return;

    // Direct coords fallback for major cities in Pakistan to ensure precise and fast navigation
    final Map<String, LatLng> knownCities = {
      'lahore': const LatLng(31.5204, 74.3587),
      'karachi': const LatLng(24.8607, 67.0011),
      'islamabad': const LatLng(33.6844, 73.0479),
      'rawalpindi': const LatLng(33.5984, 73.0441),
    };

    final cleanQuery = searchText.toLowerCase().trim();
    LatLng? matchedCoords;
    String matchedCityName = searchText;
    for (final entry in knownCities.entries) {
      if (cleanQuery == entry.key || cleanQuery.contains(entry.key)) {
        matchedCoords = entry.value;
        matchedCityName = entry.key[0].toUpperCase() + entry.key.substring(1);
        break;
      }
    }

    if (matchedCoords != null) {
      setState(() {
        _activeCityCoords = matchedCoords;
        _activeCityName = matchedCityName;
      });
      _mapController.move(matchedCoords, 12.0);
      _loadProperties(matchedCoords.latitude, matchedCoords.longitude);
      _loadHeatmapForCategory(_selectedHeatmap, isHeatmap: true, isMarkers: false);
      if (_selectedMarkerCategory != null) {
        _loadHeatmapForCategory(_selectedMarkerCategory!, isHeatmap: false, isMarkers: true);
      }
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?q=$searchText&format=json&limit=1'),
        headers: {'User-Agent': 'LocaAI-App-FYP'},
      );

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        if (results.isNotEmpty) {
          final lat = double.parse(results[0]['lat']);
          final lon = double.parse(results[0]['lon']);
          final newCenter = LatLng(lat, lon);
          
          _activeCityCoords = newCenter;
          _activeCityName = _resolveCityName(searchText, newCenter);
          
          _mapController.move(newCenter, 12.0);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Found: ${results[0]['display_name']}', style: GoogleFonts.inter()),
                backgroundColor: Colors.blue.shade700,
              ),
            );
          }
          _loadProperties(lat, lon);
          _loadHeatmapForCategory(_selectedHeatmap, isHeatmap: true, isMarkers: false);
          if (_selectedMarkerCategory != null) {
            _loadHeatmapForCategory(_selectedMarkerCategory!, isHeatmap: false, isMarkers: true);
          }
        }
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location services are disabled. Please enable them.', style: GoogleFonts.inter()),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location permissions are denied.', style: GoogleFonts.inter()),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location permissions are permanently denied.', style: GoogleFonts.inter()),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    } 

    if (mounted) {
      setState(() {
        _isLoadingAnalysis = true; 
      });
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _mapController.move(LatLng(position.latitude, position.longitude), 14.0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Centered to your current location', style: GoogleFonts.inter()),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location. Using default center.', style: GoogleFonts.inter()),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _mapController.move(_initialCenter, 13.0);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAnalysis = false;
        });
      }
    }
  }

  // --- New Methods for Analysis & Optimization ---

  Future<void> _onMapTapped(TapPosition tapPosition, LatLng point) async {
    if (_justClickedMarker) return;

    if (widget.isSelectingLocation && widget.onLocationSelected != null) {
      final activeCategory = _selectedMarkerCategory ?? (_selectedHeatmap != 'Overall' ? _selectedHeatmap : null);
      if (activeCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a category first', style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      widget.onLocationSelected!({
        'title': 'Custom Location (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})',
        'lat': point.latitude,
        'lon': point.longitude,
        'city': _activeCityName ?? 'Lahore',
        'category': activeCategory,
      });
      return;
    }

    if (_analysisMode == MapAnalysisMode.predict) {
      final activeCategory = _selectedMarkerCategory ?? (_selectedHeatmap != 'Overall' ? _selectedHeatmap : null);
      if (activeCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a category first', style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    // Diagnostic snackbar to confirm click is detected
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Analyzing: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (_isLoadingAnalysis || _isLoadingOptimize) return;

    setState(() {
      _isLoadingAnalysis = true;
      if (_analysisMode == MapAnalysisMode.predict) {
        _optimizationDone = false;
        _optimizedResults.clear();
        for (var c in _candidates) {
          c.isOptimized = false;
        }
      }
    });

    try {
      if (_analysisMode == MapAnalysisMode.predict) {
        final resultData = await ApiService.getSmartPredict(
          lat: point.latitude,
          lon: point.longitude,
          category: (_selectedMarkerCategory ?? _selectedHeatmap).toLowerCase(),
          city: _activeCityName ?? 'lahore',
        );

        setState(() => _isLoadingAnalysis = false);

        if (resultData != null) {
          final result = SuitabilityResult.fromJson(resultData);
          final siteNum = _candidates.length + 1;
          
          setState(() {
            _candidates.add(CandidateData(
              number: siteNum,
              position: point,
              result: result,
            ));
            _numToSelect = _candidates.length;
          });

          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (_) => ScorePopup(
                result: result,
                latitude: point.latitude,
                longitude: point.longitude,
                siteNumber: siteNum,
                onAiPressed: () {
                  Navigator.pop(context);
                  if (widget.onNavigateToTab != null) {
                    widget.onNavigateToTab!(3, analysisData: {
                      'suitability_score': result.score,
                      'lat': point.latitude,
                      'lon': point.longitude,
                      'city': _activeCityName ?? 'lahore',
                      'foot_traffic': result.footTraffic,
                      'details': {
                        'competitors_within_5km': result.competitors,
                        'regional_saturation': result.regionalSaturation,
                        'detected_category_level1': result.level1Category,
                        'detected_category_level3': result.level3Category,
                      }
                    });
                  }
                },
              ),
            );
          }
        }
      } else {
        // MapAnalysisMode.rentEstimate
        final estimateData = await ApiService.getRentalEstimate(
          lat: point.latitude,
          lon: point.longitude,
          radiusKm: 3.0,
          city: _activeCityName ?? 'lahore',
        );

        setState(() => _isLoadingAnalysis = false);

        if (estimateData != null && mounted) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (_) => RentalEstimatePopup(
              data: estimateData,
              latitude: point.latitude,
              longitude: point.longitude,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoadingAnalysis = false);
    }
  }



  Future<void> _runOptimization() async {
    if (_candidates.length < 2) return;

    setState(() => _isLoadingOptimize = true);

    final candidateModels = _candidates.map((c) {
      return CandidateLocation(
        id: 'site_${c.number}',
        latitude: c.position.latitude,
        longitude: c.position.longitude,
        suitabilityScore: c.result.score,
      );
    }).toList();

    try {
      final selected = await ApiService.optimizeLocations(
        candidates: candidateModels,
        numToSelect: _numToSelect.clamp(1, _candidates.length),
        minDistKm: _minDistKm,
      );

      setState(() {
        _isLoadingOptimize = false;
        if (selected != null && selected.isNotEmpty) {
          _optimizationDone = true;
          _optimizedResults = selected;
          final selectedIds = selected.map((s) => s.id).toSet();
          for (var c in _candidates) {
            c.isOptimized = selectedIds.contains('site_${c.number}');
          }
        }
      });
    } catch (e) {
      setState(() => _isLoadingOptimize = false);
    }
  }

  void _clearAll() {
    setState(() {
      _candidates.clear();
      _optimizationDone = false;
      _optimizedResults.clear();
      _numToSelect = 2;
    });
  }

  List<Marker> _buildAnalysisMarkers() {
    return _candidates.map((c) {
      final isOpt = c.isOptimized;
      // All candidate markers are solid red (Color(0xFFEF4444)), matching the user request screenshots
      const color = Color(0xFFEF4444);

      return Marker(
        point: c.position,
        width: isOpt ? 52 : 44,
        height: isOpt ? 52 : 44,
        alignment: Alignment.center,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            _justClickedMarker = true;
          },
          onTap: () {
            _justClickedMarker = true;
            Future.delayed(const Duration(milliseconds: 100), () {
              _justClickedMarker = false;
            });
            HistoryService.addToHistory({
              'title': 'Site Analysis #${c.number}',
              'score': c.result.score.toInt(),
              'lat': c.position.latitude,
              'lon': c.position.longitude,
            });
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (_) => ScorePopup(
                result: c.result,
                latitude: c.position.latitude,
                longitude: c.position.longitude,
                siteNumber: c.number,
                onAiPressed: () {
                  Navigator.pop(context);
                  if (widget.onNavigateToTab != null) {
                    widget.onNavigateToTab!(3, analysisData: {
                      'suitability_score': c.result.score,
                      'lat': c.position.latitude,
                      'lon': c.position.longitude,
                      'city': _activeCityName ?? 'lahore',
                      'foot_traffic': c.result.footTraffic,
                      'details': {
                        'competitors_within_5km': c.result.competitors,
                        'regional_saturation': c.result.regionalSaturation,
                        'detected_category_level1': c.result.level1Category,
                        'detected_category_level3': c.result.level3Category,
                      }
                    });
                  }
                },
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: isOpt ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isOpt ? 0.3 : 0.2),
                  blurRadius: isOpt ? 12 : 6,
                ),
              ],
            ),
            child: Center(
              child: isOpt
                  ? const Icon(Icons.star_rounded, color: Colors.white, size: 20)
                  : Text(
                      '${c.number}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Color _getScoreColor(double score) {
    if (score >= 70) return const Color(0xFF10B981);
    if (score >= 50) return const Color(0xFFF59E0B);
    if (score >= 30) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  void _showOptimizationSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Optimization Settings',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Locations to Select',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '$_numToSelect',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _numToSelect.toDouble(),
                    min: 1,
                    max: _candidates.isNotEmpty ? _candidates.length.toDouble() : 5,
                    divisions: _candidates.isNotEmpty ? (_candidates.length - 1).clamp(1, 100) : 4,
                    onChanged: (val) {
                      setModalState(() {
                        _numToSelect = val.toInt();
                      });
                      setState(() {
                        _numToSelect = val.toInt();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Min Distance (km)',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${_minDistKm.toStringAsFixed(1)} km',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _minDistKm,
                    min: 1.0,
                    max: 20.0,
                    divisions: 19,
                    onChanged: (val) {
                      setModalState(() {
                        _minDistKm = val;
                      });
                      setState(() {
                        _minDistKm = val;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOptimizationControlBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_candidates.length} candidates',
                  style: GoogleFonts.inter(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, color: Colors.black87),
                    onPressed: _showOptimizationSettings,
                    tooltip: 'Optimization Settings',
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.black87),
                    onPressed: _clearAll,
                    tooltip: 'Clear Candidates',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isLoadingOptimize ? null : _runOptimization,
              icon: _isLoadingOptimize
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.flash_on, color: Colors.white, size: 18),
              label: Text(
                'Optimize ${_candidates.length} Locations',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimizationResultsPanel() {
    final totalCandidates = _candidates.length;
    final totalSelected = _optimizedResults.length;
    
    final avgSuitability = totalSelected > 0 
        ? _optimizedResults.map((s) => s.suitabilityScore).reduce((a, b) => a + b) / totalSelected
        : 0.0;
        
    final bestSuitability = totalSelected > 0 
        ? _optimizedResults.map((s) => s.suitabilityScore).reduce((a, b) => a > b ? a : b)
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.emoji_events_rounded, color: Colors.green.shade600, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Optimization Results',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                onPressed: () {
                  setState(() {
                    _optimizationDone = false;
                    _optimizedResults.clear();
                    for (var c in _candidates) {
                      c.isOptimized = false;
                    }
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$totalSelected best locations selected from $totalCandidates candidates',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 14),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.blue.shade700, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Selected $totalSelected optimal locations from $totalCandidates candidates. Average suitability: ${avgSuitability.toStringAsFixed(1)}% | Best individual: ${bestSuitability.toStringAsFixed(1)}% | Min separation: 1.0 km.',
                    style: GoogleFonts.inter(
                      color: Colors.blue.shade900,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.35,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _optimizedResults.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final opt = _optimizedResults[index];
                  final siteNumStr = opt.id.replaceAll('site_', '');
                  final siteNum = int.tryParse(siteNumStr) ?? (index + 1);
                  
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SITE $siteNum',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    '${opt.latitude.toStringAsFixed(4)}, ${opt.longitude.toStringAsFixed(4)}',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey.shade500,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFD1FAE5)),
                              ),
                              child: Text(
                                '${opt.suitabilityScore.toStringAsFixed(1)}%',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF047857),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          opt.suitabilityScore >= bestSuitability 
                              ? 'This is the best location overall. It has the highest score (${opt.suitabilityScore.toStringAsFixed(1)}%) out of all $totalCandidates options.'
                              : 'This is a premium alternative site, selected for optimal distance separation.',
                          style: GoogleFonts.inter(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleLocationSelection(Map<String, dynamic> location) {
    _justClickedMarker = true;
    Future.delayed(const Duration(milliseconds: 100), () {
      _justClickedMarker = false;
    });

    if (widget.isSelectingLocation && widget.onLocationSelected != null) {
      final activeCategory = _selectedMarkerCategory ?? (_selectedHeatmap != 'Overall' ? _selectedHeatmap : null);
      if (activeCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a category first', style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      widget.onLocationSelected!(location);
      return;
    }

    HistoryService.addToHistory(location);
    if (_isSelectionMode && location['isProperty'] != true) {
      // Check uniqueness by coordinates to allow multiple same-category sites
      bool alreadyIn = _comparisonLocations.any((l) => 
        l['lat'] == location['lat'] && l['lon'] == location['lon']
      );

      if (!alreadyIn) {
        if (_comparisonLocations.length >= 4) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Maximum of 4 locations can be compared at a time.', style: GoogleFonts.inter()),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red.shade600,
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        setState(() {
          _comparisonLocations.add(location);
          _isComparing = true; // Show panel
          _selectedLocation = null; // Hide detail card if open to focus on comparison box
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${location['title']} to comparison', style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${location['title']} is already in comparison', style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      setState(() {
        _selectedLocation = location;
        // If we are already comparing, keep the comparison box visible
        // Otherwise, the detail card will show
      });
      _isProgrammaticMove = true;
      _mapController.move(LatLng(location['lat'], location['lon']), 14.0);
      Future.delayed(const Duration(milliseconds: 500), () {
        _isProgrammaticMove = false;
      });
      if (location['isProperty'] == true) {
        _fetchPropertySmartPredict(location);
      }
    }
  }

  Future<void> _fetchPropertySmartPredict(Map<String, dynamic> location) async {
    try {
      final category = (_selectedMarkerCategory ?? _selectedHeatmap).toLowerCase();
      final resultData = await ApiService.getSmartPredict(
        lat: location['lat'],
        lon: location['lon'],
        category: category,
        city: _activeCityName ?? 'lahore',
      );
      if (resultData != null && mounted && _selectedLocation == location) {
        final result = SuitabilityResult.fromJson(resultData);
        setState(() {
          _selectedLocation!['suitability_score'] = result.score.toInt();
          _selectedLocation!['foot_traffic_score'] = result.footTraffic?['traffic_score']?.toInt() ?? 80;
        });
      } else if (mounted && _selectedLocation == location) {
        // Fallback calculation for smooth UX if API returns null
        setState(() {
          final double seed = (location['lat'] * 1000 + location['lon'] * 1000).abs() % 30;
          _selectedLocation!['suitability_score'] = ((68 + seed) * 1.5).toInt().clamp(0, 150);
          _selectedLocation!['foot_traffic_score'] = (62 + seed * 0.8).toInt().clamp(0, 100);
        });
      }
    } catch (e) {
      debugPrint('Error fetching property smart predict: $e');
      if (mounted && _selectedLocation == location) {
        setState(() {
          final double seed = (location['lat'] * 1000 + location['lon'] * 1000).abs() % 30;
          _selectedLocation!['suitability_score'] = ((68 + seed) * 1.5).toInt().clamp(0, 150);
          _selectedLocation!['foot_traffic_score'] = (62 + seed * 0.8).toInt().clamp(0, 100);
        });
      }
    }
  }

  // --- End New Methods ---

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _activeCityCoords ?? _initialCenter,
            initialZoom: _currentZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: _onMapTapped,
            onPositionChanged: (position, hasGesture) {
              _currentZoom = position.zoom;
              if (hasGesture && !_isProgrammaticMove && _showAvailableListings) {
                _propertiesDebounceTimer?.cancel();
                _propertiesDebounceTimer = Timer(const Duration(milliseconds: 300), () {
                  _loadProperties(
                    position.center.latitude,
                    position.center.longitude,
                  );
                });
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.slos.smart_location_optimization_system',
            ),
            // Dynamic Heatmap Layer
            if (_showHeatmap)
              CircleLayer(circles: _activeHeatmapCircles),
            
            // Category Business Markers
            if (_selectedMarkerCategory != null)
              MarkerLayer(markers: _categoryMarkers),
            
            // New Analysis Markers
            MarkerLayer(markers: _buildAnalysisMarkers()),
            
            // Property Markers
            if (_showAvailableListings)
              MarkerLayer(
                markers: _properties.where((prop) {
                  final status = prop['status']?.toString().toLowerCase() ?? '';
                  final isSale = status.contains('sale');
                  final isRent = status.contains('rent');
                  
                  bool matchesStatus = false;
                  if (_showForSale && isSale) matchesStatus = true;
                  if (_showForRent && isRent) matchesStatus = true;
                  if (!matchesStatus) return false;
                  
                  if (_usePriceRange) {
                    final priceVal = _parseRentToNumericValue(prop['rent'] ?? prop['price']);
                    final minLimit = _parsePriceRangeValue(_selectedMinPrice, isMin: true);
                    final maxLimit = _parsePriceRangeValue(_selectedMaxPrice, isMin: false);
                    return priceVal >= minLimit && priceVal <= maxLimit;
                  }
                  return true;
                }).map((prop) {
                  final isSelected = _selectedLocation != null &&
                      _selectedLocation!['lat'] == prop['lat'] &&
                      _selectedLocation!['lon'] == prop['lon'];
                  return Marker(
                    point: LatLng(prop['lat'], prop['lon']),
                    width: isSelected ? 44.0 : 36.0,
                    height: isSelected ? 44.0 : 36.0,
                    alignment: Alignment.center,
                    child: RepaintBoundary(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) {
                          _justClickedMarker = true;
                        },
                        onTap: () {
                          _justClickedMarker = true;
                          Future.delayed(const Duration(milliseconds: 100), () {
                            _justClickedMarker = false;
                          });
                          _handleLocationSelection(prop);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue.shade700 : Colors.blue.shade500,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: isSelected ? 3.0 : 2.0),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: isSelected ? 22 : 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            
            // Selected Location Highlight Marker (from history/view/search)
            if (_selectedLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                      double.tryParse(_selectedLocation!['lat'].toString()) ?? 0.0,
                      double.tryParse(_selectedLocation!['lon'].toString()) ?? 0.0,
                    ),
                    width: 48.0,
                    height: 48.0,
                    alignment: Alignment.center,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedLocation!['isProperty'] == true 
                              ? Colors.blue.shade600 
                              : _getScoreColor(double.tryParse(_selectedLocation!['score'].toString()) ?? 0.0),
                          width: 3.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.location_on_rounded,
                          color: _selectedLocation!['isProperty'] == true 
                              ? Colors.blue.shade600 
                              : _getScoreColor(double.tryParse(_selectedLocation!['score'].toString()) ?? 0.0),
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (_isSearching || _isLoadingHeatmap)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                ),
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            ),
          ),
        
        // Analysis Mode Toggle (Floating at bottom center)
        if (_candidates.isEmpty)
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeButton(MapAnalysisMode.predict, 'Site Analysis', Icons.analytics_outlined),
                    const SizedBox(width: 4),
                    _buildModeButton(MapAnalysisMode.rentEstimate, 'Rental Estimate', Icons.monetization_on_outlined),
                  ],
                ),
              ),
            ),
          ),

        // Analyzing Indicator
        if (_isLoadingAnalysis)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue)),
                    SizedBox(width: 10),
                    Text('Analyzing location...',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
                  ],
                ),
              ),
            ),
          ),

        // Clear All Button (Only show when not showing results panel)
        if (_candidates.isNotEmpty && !_optimizationDone)
          Positioned(
            top: 140,
            left: 24,
            child: FloatingActionButton.small(
              onPressed: _clearAll,
              backgroundColor: Colors.white,
              child: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
            ),
          ),

        // Left Map Layers Panel
        Positioned(
          top: MediaQuery.of(context).size.width > 800 ? 24 : 80,
          left: 24,
          child: _buildLeftLayersPanel(),
        ),

        // Floating Categories (Top Bar)
        Positioned(
          top: 24,
          left: MediaQuery.of(context).size.width > 800 ? 320 : 24,
          right: 24,
          child: _buildFloatingCategories(),
        ),

        // Zoom Controls (Adjust dynamically based on overlay panels to prevent overlap)
        Positioned(
          right: 24,
          bottom: _isComparing 
              ? 280 
              : (_selectedLocation != null 
                  ? 240 
                  : (_candidates.isNotEmpty 
                      ? (_optimizationDone ? 360 : 200) 
                      : 100)),
          child: Column(
            children: [
              _buildMapActionButton(Icons.add, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
              const SizedBox(height: 8),
              _buildMapActionButton(Icons.remove, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
              const SizedBox(height: 16),
              _buildMapActionButton(Icons.my_location, _getCurrentLocation),
            ],
          ),
        ),

        // Bottom Right Detail Card (Explore 6)
        if (_selectedLocation != null && !_isComparing)
          Positioned(
            bottom: 24,
            right: 24,
            child: _buildLocationDetailCard(_selectedLocation!),
          ),

        // Bottom Comparison Panel (Explore 7)
        if (_isComparing)
          Positioned(
            bottom: 24,
            left: MediaQuery.of(context).size.width > 900 ? 300 : 24, // Avoid overlapping left panel on desktop
            right: 24,
            child: _buildComparisonPanel(),
          ),

        // Bottom Optimization / Results Panel (Explore Candidate Optimization Flow)
        if (_candidates.isNotEmpty && !_isComparing && _selectedLocation == null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _optimizationDone 
                ? _buildOptimizationResultsPanel() 
                : _buildOptimizationControlBar(),
          ),
      ],
    );
  }

  Widget _buildMapActionButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black87, size: 20),
        onPressed: onTap,
      ),
    );
  }

  // (Removed unused fallback logic)

  // --- New Explore Section Widgets ---

  Widget _buildLeftLayersPanel() {
    final categories = [
      {'title': 'Overall', 'icon': Icons.public},
      {'title': 'Sports & Fitness', 'icon': Icons.fitness_center},
      {'title': 'Retail & Shopping', 'icon': Icons.shopping_bag_outlined},
      {'title': 'Travel & Lodging', 'icon': Icons.hotel_outlined},
      {'title': 'Transportation & Logistics', 'icon': Icons.local_shipping_outlined},
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.layers_rounded, color: Colors.blue.shade600, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Map Layers',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, 
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(_isLayersPanelExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                onPressed: () {
                  setState(() {
                    _isLayersPanelExpanded = !_isLayersPanelExpanded;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (_isLayersPanelExpanded) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DENSITY HEATMAPS', 
                  style: GoogleFonts.inter(
                    fontSize: 10, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.grey.shade500, 
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(
                  height: 20,
                  width: 32,
                  child: Switch(
                    value: _showHeatmap,
                    onChanged: (v) {
                      setState(() {
                        _showHeatmap = v;
                      });
                    },
                    activeThumbColor: Colors.white,
                    activeTrackColor: Colors.blue.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...categories.map((cat) {
              final isSelected = _selectedHeatmap == cat['title'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildCategoryTile(
                  cat['title'] as String, 
                  cat['icon'] as IconData, 
                  isSelected,
                ),
              );
            }),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            Text(
              'PROPERTY DATA', 
              style: GoogleFonts.inter(
                fontSize: 10, 
                fontWeight: FontWeight.bold, 
                color: Colors.grey.shade500, 
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            _buildSwitchRow(
              'Available Listings', 
              _showAvailableListings, 
              Icons.home_work_outlined, 
              (v) {
                setState(() {
                  _showAvailableListings = v;
                  if (v) {
                    _showForSale = true;
                    _showForRent = true;
                  }
                });
                if (v) {
                  if (_activeCityCoords != null) {
                    _loadProperties(
                      _activeCityCoords!.latitude,
                      _activeCityCoords!.longitude,
                    );
                  } else {
                    _promptCityForProperties();
                  }
                }
              },
            ),
            if (_showAvailableListings) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: _buildSwitchRow(
                  'For Sale', 
                  _showForSale, 
                  Icons.sell_outlined, 
                  (val) {
                    setState(() => _showForSale = val);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: _buildSwitchRow(
                  'For Rent', 
                  _showForRent, 
                  Icons.key_outlined, 
                  (val) {
                    setState(() => _showForRent = val);
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildLegendDot(Colors.blue, 'Available'),
                  const SizedBox(width: 12),
                  _buildLegendDot(Colors.orange, 'Pending'),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSwitchRow(String label, bool value, IconData icon, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 24,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.blue.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildLocationDetailCard(Map<String, dynamic> location) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(location['title'], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(location['price'], style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _selectedLocation = null),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.shade500, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    location['isProperty'] == true
                        ? (location['suitability_score'] != null ? '${location['suitability_score']}' : '--')
                        : '${location['score']}',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location['isProperty'] == true
                          ? (location['suitability_score'] != null ? '${location['suitability_score']}/150 Suitability' : 'Loading Suitability...')
                          : location['scoreLabel'],
                      style: GoogleFonts.inter(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      location['isProperty'] == true ? '${location['score']} Marla Property' : 'Suitability Score',
                      style: GoogleFonts.inter(color: Colors.green.shade600, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric(
                location['isProperty'] == true ? Icons.bed : Icons.people, 
                '${location['traffic']}', 
                location['isProperty'] == true ? 'Bedrooms' : 'Traffic',
              ),
              if (location['isProperty'] == true)
                _buildMetric(
                  Icons.people_outline, 
                  location['foot_traffic_score'] != null ? '${location['foot_traffic_score']}%' : 'Loading...', 
                  'Foot Traffic',
                ),
              if (location['isProperty'] != true) ...[
                _buildMetric(Icons.storefront, '${location['competition']}', 'Competitors (5km)'),
                if (!(location['title']?.toString().toLowerCase().contains('analysis') ?? false))
                  _buildMetric(Icons.store, '${location['competitor_count'] ?? 0}', 'Competitors (Actual)'),
              ],
              _buildMetric(
                Icons.attach_money, 
                ((location['title']?.toString().toLowerCase().contains('analysis') ?? false) && location['rent'] == '0K')
                    ? '${(((location['score'] as num?) ?? 0) * 0.6 + 15).toInt()}K'
                    : '${location['rent']}', 
                (location['isProperty'] == true && (location['status']?.toString().toLowerCase().contains('sale') ?? false)) 
                    ? 'Price' 
                    : 'Avg Rent',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    ApiService.toggleFavorite(location);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ApiService.isFavorite(location) 
                        ? 'Added to Favorites' 
                        : 'Removed from Favorites'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      width: 200,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(12),
                  side: BorderSide(color: ApiService.isFavorite(location) ? Colors.red.shade200 : Colors.grey.shade300),
                  backgroundColor: ApiService.isFavorite(location) ? Colors.red.shade50 : Colors.white,
                ),
                child: Icon(
                  ApiService.isFavorite(location) ? Icons.favorite : Icons.favorite_border, 
                  color: ApiService.isFavorite(location) ? Colors.red : Colors.grey, 
                  size: 20
                ),
              ),
              if (location['isProperty'] != true && !(location['title']?.toString().toLowerCase().contains('analysis') ?? false)) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      bool alreadyIn = _comparisonLocations.any((l) => 
                        l['lat'] == location['lat'] && l['lon'] == location['lon']
                      );
                      if (!alreadyIn) {
                        if (_comparisonLocations.length >= 4) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Maximum of 4 locations can be compared at a time.', style: GoogleFonts.inter()),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.red.shade600,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        setState(() {
                          _comparisonLocations.add(location);
                          _isComparing = true;
                        });
                      } else {
                        setState(() {
                          _isComparing = true;
                        });
                      }
                    },
                    icon: const Icon(Icons.add, size: 16, color: Colors.black87),
                    label: Text('Compare', style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ApiService.saveLocation(location);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Location saved to My Zone')),
                    );
                    if (widget.onNavigateToMyZone != null) {
                      widget.onNavigateToMyZone!(myZoneTabIndex: 0);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  String _formatMetricValue(String value) {
    final doubleVal = double.tryParse(value);
    if (doubleVal != null) {
      if (doubleVal == doubleVal.roundToDouble()) {
        return doubleVal.toInt().toString();
      }
      return doubleVal.toStringAsFixed(1);
    }
    return value;
  }

  Widget _buildMetric(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.blue.shade400),
          const SizedBox(height: 4),
          Text(
            _formatMetricValue(value),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 9),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, -5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.compare_arrows, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Text('Comparing ${_comparisonLocations.length} location${_comparisonLocations.length > 1 ? 's' : ''}', 
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = !_isSelectionMode; // Toggle mode
                      });
                      if (_isSelectionMode) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Selection mode active: Tap markers to add them', style: GoogleFonts.inter()),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.blue.shade600,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.add_circle_outline, size: 16, color: _isSelectionMode ? Colors.blue.shade700 : Colors.blue.shade400),
                    label: Text('Add', style: TextStyle(color: _isSelectionMode ? Colors.blue.shade700 : Colors.blue.shade400, fontWeight: _isSelectionMode ? FontWeight.bold : FontWeight.normal)),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _isComparing = false;
                      _comparisonLocations.clear();
                      _selectedLocation = null;
                    }),
                    icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                    label: const Text('Clear', style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (_comparisonLocations.isEmpty) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(
                              backgroundColor: Colors.white,
                              elevation: 0.5,
                              shadowColor: Colors.black.withValues(alpha: 0.2),
                              leading: IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
                                onPressed: () => Navigator.pop(context),
                              ),
                              title: Text(
                                'Location Comparison',
                                style: GoogleFonts.outfit(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              centerTitle: true,
                            ),
                            body: SafeArea(
                              child: ComparisonView(
                                selectedLocations: _comparisonLocations,
                                onNavigateToMyZoneReports: () {
                                  Navigator.pop(context);
                                  if (widget.onNavigateToMyZone != null) {
                                    widget.onNavigateToMyZone!(myZoneTabIndex: 1);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade100,
                      foregroundColor: Colors.blue.shade700,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Open full comparison', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Comparison Bar Chart
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _comparisonLocations.length,
              separatorBuilder: (context, index) => const VerticalDivider(width: 32, indent: 10, endIndent: 10),
              itemBuilder: (context, index) {
                final loc = _comparisonLocations[index];
                return SizedBox(
                  width: 250,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(loc['title'], style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
                            Text(index == 0 ? 'Primary' : 'Secondary', style: GoogleFonts.inter(color: index == 0 ? Colors.blue.shade600 : Colors.purple.shade600, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Builder(
                              builder: (context) {
                                double trafficVal = double.tryParse(loc['traffic']?.toString() ?? '0') ?? 0.0;
                                double compVal = double.tryParse(loc['competition']?.toString() ?? '0') ?? 0.0;
                                double rentVal = _parseRentToNumericValue(loc['rent']);
                                
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildComparisonBar('Traffic', trafficVal / 100.0, Colors.blue),
                                    const SizedBox(height: 4),
                                    _buildComparisonBar('Competition', compVal / 50.0, Colors.purple),
                                    const SizedBox(height: 4),
                                    _buildComparisonBar('Rent', rentVal > 0 ? rentVal / 100.0 : 0.05, Colors.orange),
                                  ],
                                );
                              }
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBar(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTile(String label, IconData icon, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedHeatmap = label;
        });
        _loadHeatmapForCategory(label, isHeatmap: true, isMarkers: false);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade200 : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon, 
              size: 18, 
              color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.blue.shade700 : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 14, color: Colors.blue.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(MapAnalysisMode mode, String label, IconData icon) {
    final isSelected = _analysisMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _analysisMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingCategories() {
    final categories = [
      {'title': 'Sports & Fitness', 'icon': Icons.fitness_center},
      {'title': 'Retail & Shopping', 'icon': Icons.shopping_bag_outlined},
      {'title': 'Travel & Lodging', 'icon': Icons.hotel_outlined},
      {'title': 'Transportation & Logistics', 'icon': Icons.local_shipping_outlined},
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedMarkerCategory == cat['title'];
          return _buildFloatingChip(
            cat['title'] as String, 
            cat['icon'] as IconData, 
            isSelected,
          );
        },
      ),
    );
  }

  Widget _buildFloatingChip(String label, IconData icon, bool isSelected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (_selectedMarkerCategory == label) {
              _selectedMarkerCategory = null;
              _categoryMarkers = [];
            } else {
              _selectedMarkerCategory = label;
              _loadHeatmapForCategory(label, isHeatmap: false, isMarkers: true);
            }
          });
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: isSelected ? Colors.blue.shade500 : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.blue.shade700 : Colors.black87,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.blue.shade700 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

