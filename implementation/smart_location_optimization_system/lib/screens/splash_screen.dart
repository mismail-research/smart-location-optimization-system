import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/loca_logo.dart';
import 'landing_screen.dart';
import 'reset_password_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _oauthTimeoutTimer;
  bool _navigationTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    final String urlString = Uri.base.toString();
    final bool isRecovery = urlString.contains('recovery') || Uri.base.fragment.contains('recovery');
    final bool isAuthRedirect = urlString.contains('code=') || urlString.contains('access_token=');
    
    debugPrint('SPLASH: Current URL = $urlString');
    debugPrint('SPLASH: isRecovery = $isRecovery');
    debugPrint('SPLASH: isAuthRedirect = $isAuthRedirect');

    if (isRecovery) {
      debugPrint('SPLASH: Recovery flow detected from URL. Navigating to ResetPasswordScreen immediately.');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToResetPassword();
      });
      return;
    }

    // Set up a fallback timer so the app NEVER freezes if Google/Supabase has a network lag
    if (isAuthRedirect) {
      _oauthTimeoutTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && !_navigationTriggered) {
          debugPrint('SPLASH: OAuth exchange timed out. Falling back to Landing Screen.');
          _navigateToLanding();
        }
      });
    }

    // Direct and immediate OAuth check to skip animation entirely if session is already active
    if (isAuthRedirect && Supabase.instance.client.auth.currentSession != null) {
      debugPrint('SPLASH: OAuth redirect already has active session. Navigating to Dashboard immediately.');
      _oauthTimeoutTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToDashboardImmediate();
      });
      return;
    }

    // Stream listener for both recovery and fast OAuth session initialization
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      debugPrint('SPLASH: AuthState Stream fired: Event = ${data.event}');
      if (data.event == AuthChangeEvent.passwordRecovery && !_navigationTriggered) {
        debugPrint('SPLASH: AuthState Stream triggered navigation to ResetPasswordScreen');
        _navigateToResetPassword();
      } else if (data.session != null && isAuthRedirect && !_navigationTriggered) {
        debugPrint('SPLASH: AuthState Stream triggered immediate navigation to Dashboard');
        _oauthTimeoutTimer?.cancel();
        _navigateToDashboardImmediate();
      }
    });

    // Start splash screen animation ONLY if this is NOT an OAuth redirect sign-in flow
    if (!isAuthRedirect) {
      _controller.forward().then((_) async {
        if (!mounted || _navigationTriggered) return;
        
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          debugPrint('SPLASH: Found active session. Navigating to Dashboard...');
          _navigateToDashboardImmediate(isGuest: false);
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        final isGuest = prefs.getBool('is_guest') ?? false;
        
        if (isGuest) {
          debugPrint('SPLASH: Found guest session. Navigating to Dashboard...');
          _navigateToDashboardImmediate(isGuest: true);
          return;
        }

        debugPrint('SPLASH: Animation completed. Navigating to Landing Screen...');
        _navigateToLanding();
      });
    }
  }

  void _navigateToResetPassword() {
    if (_navigationTriggered) return;
    _navigationTriggered = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ResetPasswordScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }


  void _navigateToDashboardImmediate({bool isGuest = false}) {
    if (_navigationTriggered) return;
    _navigationTriggered = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => DashboardScreen(isGuest: isGuest),
      ),
    );
  }



  void _navigateToLanding() {
    if (_navigationTriggered) return;
    _navigationTriggered = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LandingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _oauthTimeoutTimer?.cancel();
    _authSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String urlString = Uri.base.toString();
    final bool isAuthRedirect = urlString.contains('code=') || urlString.contains('access_token=');

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: isAuthRedirect
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const LocaLogo(
                    animate: false,
                    scale: 1.2,
                  ),
                  const SizedBox(height: 32),
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade300),
                    strokeWidth: 3,
                  ),
                ],
              )
            : AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return LocaLogo(
                    animate: true,
                    animationValue: _controller.value,
                    scale: 1.5,
                  );
                },
              ),
      ),
    );
  }
}
