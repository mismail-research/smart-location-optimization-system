import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SupabaseAuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Get the current logged-in user
  static User? get currentUser => _client.auth.currentUser;

  /// Get the current session
  static Session? get currentSession => _client.auth.currentSession;

  /// Check if a user is currently logged in
  static bool get isLoggedIn => currentSession != null;

  /// Get the user's email address
  static String? get currentUserEmail => currentUser?.email;

  /// Get the user's display name from metadata
  static String get currentUserName {
    if (currentUser == null) return 'Guest';
    final metadata = currentUser!.userMetadata;
    if (metadata == null) return 'User';
    return metadata['name'] ?? metadata['full_name'] ?? 'User';
  }

  /// Get the user's profile image URL if authenticated via Google or custom upload
  static String? get currentUserAvatar {
    if (currentUser == null) return null;
    final metadata = currentUser!.userMetadata;
    return metadata?['avatar_url'] ?? metadata?['picture'];
  }

  /// Get the user's formatted joined date dynamically from Supabase metadata
  static String get currentUserJoinedDate {
    if (currentUser == null) return 'Joined Jan 2024';
    try {
      final createdAtStr = currentUser!.createdAt;
      final dateTime = DateTime.parse(createdAtStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return 'Joined ${months[dateTime.month - 1]} ${dateTime.year}';
    } catch (e) {
      return 'Joined Jan 2024';
    }
  }

  /// Update the user's avatar image url in user metadata
  static Future<void> updateUserAvatar(String avatarUrl) async {
    if (currentUser == null) return;
    await _client.auth.updateUser(
      UserAttributes(
        data: {
          'avatar_url': avatarUrl,
        },
      ),
    );
  }

  /// Stream of Auth State Changes to listen dynamically
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign Up with Email and Password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name,
      },
    );
  }

  /// Sign In with Email and Password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign In with Google (Supports Web, Android, iOS, etc.)
  static Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // OAuth redirect flow for web: Dynamically redirect to whichever port the Flutter local server is currently running on
        final String redirectUrl = Uri.base.origin;
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectUrl,
        );
      } else {
        // Native Google Sign-In for Android/iOS
        // WebClientId is needed for Android to match project configuration
        final GoogleSignIn googleSignIn = GoogleSignIn(
          scopes: [
            'email',
            'https://www.googleapis.com/auth/userinfo.profile',
          ],
        );
        
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          throw 'Google Sign-In was cancelled by the user.';
        }

        final googleAuth = await googleUser.authentication;
        final accessToken = googleAuth.accessToken;
        final idToken = googleAuth.idToken;

        if (idToken == null) {
          throw 'Could not retrieve ID token from Google authentication.';
        }

        await _client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Update User Password
  static Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(
      UserAttributes(
        password: newPassword,
      ),
    );
  }

  /// Sign Out / Log Out
  static Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        // Sign out from Google first if signed in natively
        final GoogleSignIn googleSignIn = GoogleSignIn();
        if (await googleSignIn.isSignedIn()) {
          await googleSignIn.signOut();
        }
      } catch (_) {
        // Ignore native signout issues
      }
    }
    
    // Always sign out locally. This clears the in-memory session and local storage
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // Fallback: if even local signOut fails, clear via recoverSession
      try {
        await _client.auth.recoverSession('{}');
      } catch (_) {
        // Expected AuthException from empty JSON structure, ignored to let flow proceed
      }
    }
  }
}
