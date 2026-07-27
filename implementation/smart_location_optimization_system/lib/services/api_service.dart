import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'user_data_sync_service.dart';

class CandidateLocation {
  final String id;
  final double latitude;
  final double longitude;
  final double suitabilityScore;

  CandidateLocation({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.suitabilityScore,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'suitability_score': suitabilityScore,
  };

  factory CandidateLocation.fromJson(Map<String, dynamic> json) {
    return CandidateLocation(
      id: json['id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      suitabilityScore: (json['suitability_score'] as num).toDouble(),
    );
  }
}

class SuitabilityResult {
  final double score;
  final int competitors;
  final String level1Category;
  final String level3Category;
  final int regionalSaturation;
  final Map<String, dynamic>? footTraffic;

  SuitabilityResult({
    required this.score,
    required this.competitors,
    required this.level1Category,
    required this.level3Category,
    required this.regionalSaturation,
    this.footTraffic,
  });

  factory SuitabilityResult.fromJson(Map<String, dynamic> json) {
    final details = json['details'] as Map<String, dynamic>;
    return SuitabilityResult(
      score: (json['suitability_score'] as num).toDouble(),
      competitors: (details['competitors_within_5km'] as num).toInt(),
      level1Category: details['detected_category_level1'] as String,
      level3Category: details['detected_category_level3'] as String,
      regionalSaturation: (details['regional_saturation'] as num).toInt(),
      footTraffic: json['foot_traffic'] as Map<String, dynamic>?,
    );
  }
}



class ApiService {
  // Switched to HIGH-PERFORMANCE local server
  static const String baseUrl = 'http://127.0.0.1:8000';
  static const String apiKey = 'my_secure_key_123';

  static final Map<String, List<Map<String, dynamic>>> _propertiesCache = {};
  static final Map<String, Map<String, dynamic>> _predictCache = {};

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-API-KEY': apiKey,
  };

  /// Maps UI categories to Backend Dataset Categories
  static String _mapCategory(String category) {
    final lower = category.toLowerCase().trim();
    switch (lower) {
      case 'restaurant': return 'Grocery store';
      case 'cafe': return 'Grocery store';
      case 'retail store': return 'Clothing store';
      case 'grocery': return 'Grocery store';
      case 'office space': return 'Travel agency';
      case 'overall': return 'Overall';
      case 'sports & fitness': return 'Sports & Fitness';
      case 'retail & shopping': return 'Retail & Shopping';
      case 'travel & lodging': return 'Travel & Lodging';
      case 'transportation & logistics': return 'Transportation & Logistics';
      default: return category;
    }
  }

  /// Fetches real heatmap data from the /heatmap-data endpoint
  static Future<List<Map<String, dynamic>>> getHeatmapData(String category, {String? city}) async {
    try {
      final backendCategory = _mapCategory(category);
      final queryParams = {
        'category': backendCategory,
        if (city != null && city.isNotEmpty) 'city': city,
      };
      final uri = Uri.parse('$baseUrl/heatmap-data').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      }
    } catch (e) {
      // API error handled silently
    }
    return []; 
  }

  /// Gets suitability score and details for a location
  static Future<Map<String, dynamic>?> getSmartPredict({
    required double lat,
    required double lon,
    required String category,
    required String city,
  }) async {
    final cacheKey = '${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}_${category.toLowerCase()}_${city.toLowerCase()}';
    if (_predictCache.containsKey(cacheKey)) {
      return _predictCache[cacheKey];
    }

    try {
      String backendCategory = _mapCategory(category);
      if (backendCategory == 'Overall') {
        backendCategory = 'Retail & Shopping'; // Default to a valid category for prediction if Overall is selected
      }

      final response = await http.post(
        Uri.parse('$baseUrl/smart-predict'),
        headers: _headers,
        body: json.encode({
          'latitude': lat,
          'longitude': lon,
          'category': backendCategory,
          'city': city,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _predictCache[cacheKey] = data;
        return data;
      }
    } catch (e) {
      // API error handled silently
    }
    return null;
  }

  /// Fetches rental estimate from the /rental-estimate endpoint
  static Future<Map<String, dynamic>?> getRentalEstimate({
    required double lat,
    required double lon,
    double radiusKm = 3.0,
    String? city,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rental-estimate'),
        headers: _headers,
        body: json.encode({
          'latitude': lat,
          'longitude': lon,
          'radius_km': radiusKm,
          if (city != null) 'city': city,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      // API error handled silently
    }
    return null;
  }

  /// Runs the optimization solver to find the best subset of candidates
  static Future<List<CandidateLocation>?> optimizeLocations({
    required List<CandidateLocation> candidates,
    int numToSelect = 2,
    double minDistKm = 5.0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/optimize'),
        headers: _headers,
        body: json.encode({
          'candidates': candidates.map((c) => c.toJson()).toList(),
          'num_to_select': numToSelect,
          'min_dist_km': minDistKm,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final selectedList = data['selected_locations'] as List;
        return selectedList
            .map((item) => CandidateLocation.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // API error handled silently
    }
    return null;
  }

  /// Fetches real property listings from the /properties endpoint
  static Future<List<Map<String, dynamic>>> getProperties({
    required double lat,
    required double lon,
    double radiusKm = 5.0,
    String? city,
  }) async {
    final cacheKey = '${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}_${radiusKm.toStringAsFixed(1)}_${city ?? ""}';
    if (_propertiesCache.containsKey(cacheKey)) {
      return _propertiesCache[cacheKey]!;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/properties'),
        headers: _headers,
        body: json.encode({
          'latitude': lat,
          'longitude': lon,
          'radius_km': radiusKm,
          if (city != null && city.isNotEmpty) 'city': city,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = List<Map<String, dynamic>>.from(data['properties']);
        _propertiesCache[cacheKey] = list;
        return list;
      }
    } catch (e) {
      // API error handled silently
    }
    return [];
  }

  static final List<Map<String, dynamic>> _favorites = [];
  static final ValueNotifier<List<Map<String, dynamic>>> favoritesNotifier = ValueNotifier<List<Map<String, dynamic>>>([]);

  static final List<Map<String, dynamic>> _savedLocations = [];
  static final ValueNotifier<List<Map<String, dynamic>>> savedLocationsNotifier = ValueNotifier<List<Map<String, dynamic>>>([]);

  static void saveLocation(Map<String, dynamic> location) {
    if (!_savedLocations.any((l) => l['title'] == location['title'])) {
      _savedLocations.add({
        'title': location['title'],
        'subtitle': location['scoreLabel'] ?? 'Saved Location',
        'lat': location['lat'] ?? 0.0,
        'lon': location['lon'] ?? 0.0,
        'city': location['title'],
        'category': 'Unknown',
        'score': location['score'] ?? 0,
        'isPositive': true,
      });
      savedLocationsNotifier.value = List.from(_savedLocations);
      UserDataSyncService.saveUserData();
    }
  }

  static void toggleSavedLocation(Map<String, dynamic> location) {
    final index = _savedLocations.indexWhere((l) => l['title'] == location['title']);
    if (index >= 0) {
      _savedLocations.removeAt(index);
      savedLocationsNotifier.value = List.from(_savedLocations);
      UserDataSyncService.saveUserData();
    } else {
      saveLocation(location);
    }
  }

  static bool isSavedLocation(Map<String, dynamic> location) {
    return _savedLocations.any((l) => l['title'] == location['title']);
  }

  /// Fetches real sample locations from the database for the "My Zone" and "Properties" views
  static List<Map<String, dynamic>> getSampleLocations() {
    return _savedLocations;
  }

  static void toggleFavorite(Map<String, dynamic> location) {
    final index = _favorites.indexWhere((f) => 
        f['title'] == location['title'] && 
        f['lat'] == location['lat'] && 
        f['lon'] == location['lon']);
    if (index >= 0) {
      _favorites.removeAt(index);
    } else {
      _favorites.add(location);
    }
    favoritesNotifier.value = List.from(_favorites);
    UserDataSyncService.saveUserData();
  }

  static bool isFavorite(Map<String, dynamic> location) {
    return _favorites.any((f) => 
        f['title'] == location['title'] && 
        f['lat'] == location['lat'] && 
        f['lon'] == location['lon']);
  }

  static List<Map<String, dynamic>> getFavorites() {
    return List.from(_favorites);
  }

  static void deleteSavedLocations(Set<dynamic> locations) {
    _savedLocations.removeWhere((l) => locations.any((sl) => sl['lat'] == l['lat'] && sl['lon'] == l['lon']));
    savedLocationsNotifier.value = List.from(_savedLocations);
    UserDataSyncService.saveUserData();
  }

  static void clearSavedLocations() {
    _savedLocations.clear();
    savedLocationsNotifier.value = List.from(_savedLocations);
    UserDataSyncService.saveUserData();
  }

  static void deleteFavorites(Set<dynamic> locations) {
    _favorites.removeWhere((f) => locations.any((sl) => sl['lat'] == f['lat'] && sl['lon'] == f['lon']));
    favoritesNotifier.value = List.from(_favorites);
    UserDataSyncService.saveUserData();
  }

  static void clearFavorites() {
    _favorites.clear();
    favoritesNotifier.value = List.from(_favorites);
    UserDataSyncService.saveUserData();
  }

  static List<Map<String, dynamic>> getSavedLocationsRaw() {
    return _savedLocations;
  }

  static void loadSavedLocationsRaw(dynamic data, {bool merge = false}) {
    dynamic parsedData = data;
    if (data is String) {
      try {
        parsedData = jsonDecode(data);
      } catch (e) {
        debugPrint('ApiService: Error decoding saved_locations JSON string: $e');
      }
    }

    if (parsedData is List) {
      final List<Map<String, dynamic>> incoming = [];
      for (final item in parsedData) {
        if (item is Map<String, dynamic>) {
          incoming.add(item);
        } else if (item is Map) {
          incoming.add(Map<String, dynamic>.from(item));
        }
      }

      if (merge) {
        for (final item in incoming) {
          if (!_savedLocations.any((l) => l['title'] == item['title'])) {
            _savedLocations.add(item);
          }
        }
      } else {
        _savedLocations.clear();
        _savedLocations.addAll(incoming);
      }
      savedLocationsNotifier.value = List.from(_savedLocations);
    }
  }

  static List<Map<String, dynamic>> getFavoritesRaw() {
    return _favorites;
  }

  static void loadFavoritesRaw(dynamic data, {bool merge = false}) {
    dynamic parsedData = data;
    if (data is String) {
      try {
        parsedData = jsonDecode(data);
      } catch (e) {
        debugPrint('ApiService: Error decoding favorites JSON string: $e');
      }
    }

    if (parsedData is List) {
      final List<Map<String, dynamic>> incoming = [];
      for (final item in parsedData) {
        if (item is Map<String, dynamic>) {
          incoming.add(item);
        } else if (item is Map) {
          incoming.add(Map<String, dynamic>.from(item));
        }
      }

      if (merge) {
        for (final item in incoming) {
          if (!_favorites.any((f) => f['title'] == item['title'] && f['lat'] == item['lat'] && f['lon'] == item['lon'])) {
            _favorites.add(item);
          }
        }
      } else {
        _favorites.clear();
        _favorites.addAll(incoming);
      }
      favoritesNotifier.value = List.from(_favorites);
    }
  }

  static void clearData() {
    _savedLocations.clear();
    _favorites.clear();
    savedLocationsNotifier.value = [];
    favoritesNotifier.value = [];
  }
}
