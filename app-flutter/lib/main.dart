import 'package:flutter/material.dart';
import 'package:spring_admin/providers/event_provider.dart';
import 'package:spring_admin/screens/splash/splash_screen.dart';
import 'package:spring_admin/utils/routes/routes.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:spring_admin/providers/camera_settings_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Get Supabase client instance
final supabase = Supabase.instance.client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
 
  // Initialize Supabase with proper configuration
  await Supabase.initialize(
    url: 'https://zxffvykqyoahuwrsqvhj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4ZmZ2eWtxeW9haHV3cnNxdmhqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAwNDk3NjcsImV4cCI6MjA4NTYyNTc2N30.ul3lPEhWP170LcMblg4D9feEYH8xvewq9To9sClEZas',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      // Enable automatic token refresh
      autoRefreshToken: true,
    ),
  );
  
  final prefs = await SharedPreferences.getInstance();

  // Initialize EventProvider
  final eventProvider = EventProvider();

  // Force portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CameraSettingsProvider(prefs)),
        ChangeNotifierProvider.value(value: eventProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRoutes.generateRoute,
      initialRoute: SplashScreen.routeName,
    );
  }
}
