import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/services/local_storage_service.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';
import 'onboarding/onboarding_screen.dart';

import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Wait for at least 1 second AND for fonts to load to prevent layout shifts
    await Future.wait([
      Future.delayed(const Duration(seconds: 1)),
      GoogleFonts.pendingFonts([
        GoogleFonts.inter(),
      ]),
    ]);
    
    if (!mounted) return;
    
    final authProvider = context.read<AuthProvider>();
    await authProvider.loadUser();

    if (!mounted) return;

    // Determine navigation based on auth and onboarding status
    Widget nextScreen;
    
    if (authProvider.isAuthenticated) {
      // Check if onboarding is completed
      final storage = LocalStorageService();
      final onboardingCompleted = await storage.isOnboardingCompleted();
      
      // Also check if user has name and school (fallback check)
      final user = authProvider.user;
      final hasProfile = user?.schoolName != null && 
                        user?.schoolName?.isNotEmpty == true;
      
      if (onboardingCompleted || hasProfile) {
        nextScreen = const HomeScreen();
      } else {
        nextScreen = const OnboardingScreen();
      }
    } else {
      nextScreen = const LoginScreen();
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'AI Teaching Coach',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'TEACH Framework Analysis',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
