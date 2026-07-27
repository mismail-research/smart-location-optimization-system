import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_location_optimization_system/utils/supabase_config.dart';
import 'package:smart_location_optimization_system/services/api_service.dart';
import 'package:smart_location_optimization_system/services/supabase_auth_service.dart';
import 'package:smart_location_optimization_system/services/user_data_sync_service.dart';

void main() {
  test('Integration Test: Save Location -> Logout -> Login -> Load Data', () async {
    SharedPreferences.setMockInitialValues({});
    
    print('Initializing Supabase client...');
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    final client = Supabase.instance.client;

    final email = 'test_flow_${DateTime.now().millisecondsSinceEpoch}@example.com';
    const password = 'password123';

    try {
      // 1. Sign up and sign in the user
      print('Signing up test user: $email...');
      final authResponse = await client.auth.signUp(email: email, password: password);
      expect(authResponse.user, isNotNull);
      print('Signed up successfully. Current User: ${client.auth.currentUser?.email}');

      // 2. Save a location (this should save it to the local memory and push it to Supabase userMetadata)
      print('Saving a location...');
      ApiService.saveLocation({
        'title': 'Test Integration Location',
        'scoreLabel': 'Great',
        'lat': 12.34,
        'lon': 56.78,
        'score': 85,
      });

      // Verify it's in local memory
      expect(ApiService.getSavedLocationsRaw().length, equals(1));
      expect(ApiService.getSavedLocationsRaw()[0]['title'], equals('Test Integration Location'));

      // Wait a moment for any async operations to complete
      await Future.delayed(const Duration(seconds: 1));

      // 3. Log out and clear local memory
      print('Logging out...');
      await SupabaseAuthService.signOut();
      expect(SupabaseAuthService.isLoggedIn, isFalse);

      print('Clearing local user data...');
      UserDataSyncService.clearUserData();
      expect(ApiService.getSavedLocationsRaw().isEmpty, isTrue);

      // 4. Log back in
      print('Logging back in...');
      final loginResponse = await client.auth.signInWithPassword(email: email, password: password);
      expect(loginResponse.user, isNotNull);
      expect(SupabaseAuthService.isLoggedIn, isTrue);

      // 5. Load user data from Supabase
      print('Loading user data from profile...');
      await UserDataSyncService.loadUserData(merge: true);

      // 6. Verify that the saved location is successfully restored!
      final savedLocations = ApiService.getSavedLocationsRaw();
      print('Restored Saved Locations: $savedLocations');
      expect(savedLocations.length, equals(1));
      expect(savedLocations[0]['title'], equals('Test Integration Location'));
      print('SUCCESS: Saved location successfully restored after login!');

    } catch (e) {
      print('Error during integration test: $e');
      fail('Test failed with error: $e');
    }
  });

  test('Unit Test: String JSON fallback decoding', () {
    ApiService.clearData();
    expect(ApiService.getSavedLocationsRaw().isEmpty, isTrue);

    // Call loadSavedLocationsRaw with a JSON string representation
    const jsonString = '[{"title": "String Location", "scoreLabel": "Excellent", "lat": 1.2, "lon": 3.4, "score": 90}]';
    ApiService.loadSavedLocationsRaw(jsonString);

    expect(ApiService.getSavedLocationsRaw().length, equals(1));
    expect(ApiService.getSavedLocationsRaw()[0]['title'], equals('String Location'));
    print('SUCCESS: JSON String fallback successfully decoded!');
  });
}
