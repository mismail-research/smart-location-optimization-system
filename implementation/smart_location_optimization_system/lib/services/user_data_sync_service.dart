import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart';
import 'history_service.dart';
import 'comparison_history_service.dart';
import 'report_service.dart';

class UserDataSyncService {
  static bool _isLoading = false;

  /// Load user data from local cache first, then sync and merge with Supabase raw_user_meta_data
  static Future<void> loadUserData({bool merge = false}) async {
    final client = Supabase.instance.client;
    
    // Check if there is any local data in memory (e.g. from guest session) before loading
    final bool hasLocalData = ApiService.getSavedLocationsRaw().isNotEmpty ||
        ApiService.getFavoritesRaw().isNotEmpty ||
        HistoryService.getHistoryRaw().isNotEmpty ||
        ComparisonHistoryService.getHistoryRaw().isNotEmpty ||
        ReportService.reportsNotifier.value.isNotEmpty;

    _isLoading = true;
    try {
      User? user = client.auth.currentUser;
      
      if (user == null) {
        debugPrint('Sync: No user logged in. Skipping load.');
        _isLoading = false;
        return;
      }

      // Step 1: Load from local SharedPreferences backup immediately for instant UI response
      try {
        final prefs = await SharedPreferences.getInstance();
        final localDataString = prefs.getString('user_data_${user.id}');
        if (localDataString != null) {
          debugPrint('Sync: Found local SharedPreferences cache. Loading...');
          final localData = jsonDecode(localDataString);
          if (localData is Map) {
            if (localData.containsKey('saved_locations')) {
              ApiService.loadSavedLocationsRaw(localData['saved_locations'], merge: false);
            }
            if (localData.containsKey('favorites')) {
              ApiService.loadFavoritesRaw(localData['favorites'], merge: false);
            }
            if (localData.containsKey('history')) {
              HistoryService.loadHistoryRaw(localData['history'], merge: false);
            }
            if (localData.containsKey('comparison_history')) {
              ComparisonHistoryService.loadHistoryRaw(localData['comparison_history'], merge: false);
            }
            if (localData.containsKey('reports')) {
              ReportService.loadReportsRaw(localData['reports'], merge: false);
            }
            debugPrint('Sync: Loaded data from local SharedPreferences cache successfully.');
          }
        }
      } catch (e) {
        debugPrint('Sync: Error loading from local SharedPreferences cache: $e');
      }

      // Step 2: Fetch fresh user object from server to get latest online metadata
      try {
        final userResponse = await client.auth.getUser();
        if (userResponse.user != null) {
          user = userResponse.user;
        }
      } catch (e) {
        debugPrint('Sync: Error fetching fresh user object from server, falling back to local cache: $e');
      }

      // Step 3: Load online metadata and merge it with local memory
      final metadata = user?.userMetadata;
      if (metadata != null) {
        debugPrint('Sync: Loading/merging online user metadata (merge: $merge)...');

        if (metadata.containsKey('saved_locations')) {
          ApiService.loadSavedLocationsRaw(metadata['saved_locations'], merge: true);
        }
        if (metadata.containsKey('favorites')) {
          ApiService.loadFavoritesRaw(metadata['favorites'], merge: true);
        }
        if (metadata.containsKey('history')) {
          HistoryService.loadHistoryRaw(metadata['history'], merge: true);
        }
        if (metadata.containsKey('comparison_history')) {
          ComparisonHistoryService.loadHistoryRaw(metadata['comparison_history'], merge: true);
        }
        if (metadata.containsKey('reports')) {
          ReportService.loadReportsRaw(metadata['reports'], merge: true);
        }
      } else {
        debugPrint('Sync: No online user metadata found.');
      }

      debugPrint('Sync: User data sync completed.');

      // Step 4: Save the unified merged state back to local cache and server
      _isLoading = false; // Temporarily allow saving to store the unified state
      await saveUserData();
    } catch (e) {
      debugPrint('Sync: Error during data sync: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// Save user data to both local SharedPreferences cache and Supabase raw_user_meta_data
  static Future<void> saveUserData() async {
    if (_isLoading) return; // Prevent saving while loading data
    
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      debugPrint('Sync: No user logged in. Skipping save.');
      return;
    }

    try {
      debugPrint('Sync: Saving user data to profile...');
      final data = {
        'saved_locations': ApiService.getSavedLocationsRaw(),
        'favorites': ApiService.getFavoritesRaw(),
        'history': HistoryService.getHistoryRaw(),
        'comparison_history': ComparisonHistoryService.getHistoryRaw(),
        'reports': ReportService.getReportsRaw(),
      };

      // 1. Save to SharedPreferences first (instant and reliable local cache)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data_${user.id}', jsonEncode(data));
      debugPrint('Sync: User data saved to local SharedPreferences.');

      // 2. Save to Supabase
      await client.auth.updateUser(
        UserAttributes(
          data: data,
        ),
      );
      debugPrint('Sync: User data saved to Supabase successfully.');
    } catch (e) {
      debugPrint('Sync: Error saving user data: $e');
    }
  }

  /// Clear all local user data from in-memory services and SharedPreferences cache on logout
  static void clearUserData() async {
    debugPrint('Sync: Clearing local user data from memory...');
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_data_${user.id}');
        debugPrint('Sync: Local SharedPreferences cache cleared.');
      } catch (e) {
        debugPrint('Sync: Error clearing local SharedPreferences cache: $e');
      }
    }
    ApiService.clearData();
    HistoryService.clearData();
    ComparisonHistoryService.clearData();
    ReportService.clearData();
    debugPrint('Sync: Local user data cleared.');
  }
}
