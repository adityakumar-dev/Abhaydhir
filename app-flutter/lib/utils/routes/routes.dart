import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:spring_admin/screens/login/login.dart';
import 'package:spring_admin/screens/new%20entry/departure_screen.dart';
import 'package:spring_admin/screens/new%20entry/qr_code_verify.dart';
import 'package:spring_admin/screens/register/register_screen.dart';
import 'package:spring_admin/screens/splash/splash_screen.dart';
import '../../screens/home/home.dart';
import '../../screens/quick_register.dart';
import '../../screens/settings.dart';
import '../../screens/help.dart';
import '../../screens/guest list/guest_list.dart';
import '../../screens/analytics.dart';
import '../../screens/new entry/success.dart';
import '../../screens/guest list/view_guest.dart';

class AppRoutes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case HomeScreen.routeName:
        return getPageTransition(HomeScreen(), settings);
      case QuickRegisterScreen.routeName:
        return getPageTransition(QuickRegisterScreen(), settings);
      case SettingsScreen.routeName:
          return getPageTransition(SettingsScreen(), settings);
      case HelpScreen.routeName:
        return getPageTransition(HelpScreen(), settings);
      case GuestListsScreen.routeName:
        return getPageTransition(GuestListsScreen(), settings);
      case AnalyticsScreen.routeName:
        return getPageTransition(AnalyticsScreen(), settings);
      case QrCodeVerifyScreen.routeName:
        final args = settings.arguments as Map<String, dynamic>;
        return getPageTransition(
          QrCodeVerifyScreen(
            eventId: args['eventId'] as int?,
          ), 
          settings
        );
      case SuccessScreen.routeName:
        return MaterialPageRoute(builder: (_) => const SuccessScreen());
      case ViewGuestScreen.routeName:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ViewGuestScreen(
            userId: args['userId'] as String,
          ),
        );
      case DepartureScreen.routeName :
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => DepartureScreen(
            eventId: args['eventId'] as int,
          ),
        );
      
      case SplashScreen.routeName:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case LoginScreen.routeName:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case RegisterScreen.routeName:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      default:
        return MaterialPageRoute(builder: (_) => Container());
    }
  }

  static getPageTransition(dynamic screenName, RouteSettings setting) {
    return PageTransition(
        child: screenName,
        type: PageTransitionType.theme,
        alignment: Alignment.center,
        settings: setting,
        duration: const Duration(milliseconds: 1000),
        maintainStateData: true,
        curve: Curves.easeInOut);
  }
}
