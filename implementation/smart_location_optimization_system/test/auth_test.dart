import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_location_optimization_system/services/supabase_auth_service.dart';
import 'package:smart_location_optimization_system/utils/supabase_config.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  });

  test('SupabaseAuthService.signOut() handles network failure by clearing local session', () async {
    final client = Supabase.instance.client;
    
    // 1. Mock session to represent authenticated state
    final dummyUser = User(
      id: 'dummy-test-user-id',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    );
    final dummySession = Session(
      accessToken: 'dummy-token',
      tokenType: 'bearer',
      expiresIn: 3600,
      refreshToken: 'dummy-refresh',
      user: dummyUser,
    );
    
    // Load it into the client
    final sessionJson = dummySession.toJson();
    final jsonString = '{"access_token":"${sessionJson['access_token']}","expires_in":3600,"refresh_token":"${sessionJson['refresh_token']}","token_type":"bearer","user":${client.auth.currentUser != null ? "null" : "{\"id\":\"dummy-test-user-id\",\"aud\":\"authenticated\",\"created_at\":\"\"}"}}';
    
    try {
      await client.auth.recoverSession(jsonString);
    } catch (_) {}

    // Verify session is active
    expect(client.auth.currentSession, isNotNull);

    // Call signOut, which will fail because 'dummy-token' is invalid and cannot be revoked on the server
    // (leading to network/auth exceptions), but our fallback should still force-clear it.
    await SupabaseAuthService.signOut();

    // Verify that the session is successfully cleared in memory
    expect(client.auth.currentSession, isNull);
  });
}
