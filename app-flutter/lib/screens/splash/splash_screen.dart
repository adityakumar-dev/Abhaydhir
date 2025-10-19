import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spring_admin/providers/event_provider.dart';
import 'package:spring_admin/screens/home/home.dart';
import 'package:spring_admin/screens/login/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  static const String routeName = '/splash';
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  
  final _supabase = Supabase.instance.client;
  late final StreamSubscription<AuthState> _authStateSubscription;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    
    // Set up animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    _controller.forward();
    
    // Listen to auth state changes (official Supabase way)
    _authStateSubscription = _supabase.auth.onAuthStateChange.listen(
      (data) {
        if (_redirecting) return;
        
        final session = data.session;
        
        if (session != null) {
          _redirectToHome();
        } else {
          _redirectToLogin();
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auth error: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
        _redirectToLogin();
      },
    );
  }

  Future<void> _redirectToHome() async {
    if (_redirecting || !mounted) return;
    
    setState(() {
      _redirecting = true;
    });
    
    // Wait for animation to complete
    await Future.delayed(const Duration(milliseconds: 2000));
    
    if (!mounted) return;
    
    try {
      // Initialize event provider
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      await eventProvider.initialize();
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, HomeScreen.routeName);
      }
    } catch (e) {
      debugPrint('Error initializing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      _redirectToLogin();
    }
  }

  Future<void> _redirectToLogin() async {
    if (_redirecting || !mounted) return;
    
    setState(() {
      _redirecting = true;
    });
    
    // Wait for animation to complete
    await Future.delayed(const Duration(milliseconds: 2000));
    
    if (mounted) {
      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
    }
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: SizedBox.expand(
          child: Stack(
            children: [
              // Positioned.fill(child: Image.asset('assets/images/tahni.jpg', fit: BoxFit.cover,)), 
            //  Text("temp"),
              Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.background,
                      Theme.of(context).colorScheme.surface,
                    ],
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/splash.jpeg',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Column(

                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),
                        // App name with scale and fade animation
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Card(
                                  color: Theme.of(context).colorScheme.surface,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Image.asset(
                                      'assets/images/emblem.png',
                                      width: 64,
                                      height: 64,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'अभयधीर',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  textAlign: TextAlign.center,
                                  '"Advanced biometric high-security authentication yields dual-layered, highly intelligent recognition"',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        // letterSpacing: 0.5,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(flex: 2),
                        // Powered by section with slide up and fade animation
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Powered by',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        letterSpacing: 0.5,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .shadowColor
                                            .withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/images/utu-logo.png',
                                    width: 48,
                                    height: 48,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
