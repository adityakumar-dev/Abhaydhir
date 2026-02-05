import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spring_admin/screens/analytics.dart';
import 'package:spring_admin/screens/home/dashboard_title.dart';
import 'package:spring_admin/screens/help.dart';
import 'package:spring_admin/screens/guest%20list/guest_list.dart';
import 'package:spring_admin/screens/login/login.dart';
import 'package:spring_admin/screens/new%20entry/qr_code_verify.dart';
import 'package:spring_admin/screens/new%20entry/departure_screen.dart';
import 'package:spring_admin/screens/quick_register.dart';
import 'package:spring_admin/providers/event_provider.dart';
import 'package:spring_admin/utils/ui/ui_helper.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _dialogShown = false;
  bool _isLoadingDialogShown = false;
  late final StreamSubscription<AuthState> _authStateSubscription;
  final _supabase = Supabase.instance.client;
  
  @override
  void initState() {
    super.initState();
    // Reset dialog flags when screen is initialized
    _dialogShown = false;
    _isLoadingDialogShown = false;
    
    // Listen to auth state changes - if user logs out or session expires, go to login
    _authStateSubscription = _supabase.auth.onAuthStateChange.listen(
      (data) {
        final session = data.session;
        
        // If session becomes null (logout or expiration), navigate to login
        if (session == null && mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            LoginScreen.routeName,
            (route) => false,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final eventProvider = Provider.of<EventProvider>(context);

    // Handle event provider states
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Handle loading state
      if (eventProvider.isLoading) {
        if (!_isLoadingDialogShown) {
          _isLoadingDialogShown = true;
          UiHelper.showLoadingDialog(context, 'Fetching events...');
        }
      } else {
        // Dismiss loading dialog if it was shown
        if (_isLoadingDialogShown) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          _isLoadingDialogShown = false;
        }

        // Handle different states after loading is complete
        if (eventProvider.initialized && !_dialogShown) {
          if (eventProvider.events.isEmpty) {
            // No events available
            _dialogShown = true;
            UiHelper.showNoEventsDialog(
              context,
              onRetry: () async {
                setState(() {
                  _dialogShown = false;
                });
                await eventProvider.resync();
              },
            );
          } else if (!eventProvider.hasSelectedEvent) {
            // Events available but none selected
            _dialogShown = true;
            UiHelper.showEventChooserDialog(
              context,
              events: eventProvider.events,
              title: 'Select Event',
              message: 'Choose an event to start working',
              onEventSelected: (eventId, eventName) async {
                await eventProvider.selectEvent(eventId, eventName);
                setState(() {
                  _dialogShown = false;
                });
              },
            );
          } else if (eventProvider.error != null) {
            // Error occurred (e.g., selected event no longer active)
            _dialogShown = true;
            UiHelper.showEventChooserDialog(
              context,
              events: eventProvider.events,
              title: 'Event Selection Required',
              message: eventProvider.error!,
              onEventSelected: (eventId, eventName) async {
                await eventProvider.selectEvent(eventId, eventName);
                eventProvider.clearError();
                setState(() {
                  _dialogShown = false;
                });
              },
            );
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFFCCCB),
                Color(0xFFF5F5F5),
                Color(0xFFF5F5F5).withOpacity(0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: AppBar(
            scrolledUnderElevation: 0,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Container(),
            
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              
                const Column(
                  children: [
                    Text(
                      'SPRING FESTIVAL 2026',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: const Color(0xFF1A237E),
                      ),
                    ),
                    Text(
                      'Security Portal',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color.fromARGB(255, 10, 128, 120),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Color.fromARGB(255, 10, 128, 120),
                ),
                onPressed: () async {
                  showDialog(context: context, builder: (context) => AlertDialog(
                    title: Text("Logout"),
                    content: Text("Are you sure you want to logout?"),
                    actions: [
                      TextButton(onPressed: () async {
                         SupabaseClient client = Supabase.instance.client;
                          await client.auth.signOut();
                          SharedPreferences prefs = await SharedPreferences.getInstance();
                          await prefs.clear();
                          await Provider.of<EventProvider>(context, listen: false).clearSelection();
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          LoginScreen.routeName,
                          (route) => false,
                        );
                      }, child: Text("Logout")),
                      TextButton(onPressed: () {
                        Navigator.pop(context);
                      }, child: Text("Cancel")),
                    ],
                  ));
                },
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              bottom: -190,
              left: 150,
              right: -150,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.4,
                child: Image.asset(
                  'assets/images/aipen.png',
                  // width: ,
                  height: MediaQuery.of(context).size.height * 0.4,
                  color: Color.fromARGB(255, 255, 165, 164),
                ),
              ),
            ),
        
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(
                            0.5,
                          ), // Semi-transparent color overlay
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.white,
                                child: const Icon(
                                  Icons.security,
                                  color: Color.fromARGB(255, 10, 128, 120),
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome, Security',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color.fromARGB(
                                          255,
                                          10,
                                          128,
                                          120,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
               
                // Dashboard Grid
                Container(
                  alignment: Alignment.center,
                  child: GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    crossAxisCount: size.width > 600 ? 3 : 2,
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.05,
                    ),
                    crossAxisSpacing: size.width * 0.04,
                    mainAxisSpacing: size.height * 0.02,
                    childAspectRatio: size.width > 600 ? 1.3 : 1.1,
                    children: [
                      buildDashboardTile(
                        context,
                        'Guest List',
                        'View & manage guests',
                        Icons.people_alt_rounded,
                        const Color.fromARGB(255, 52, 55, 95),
                        () => Navigator.pushNamed(
                          context,
                          GuestListsScreen.routeName,
                        ),
                      ),
                      buildDashboardTile(
                        context,
                        'New Entry',
                        'Add new guest',
                        Icons.person_add_rounded,
                        const Color.fromARGB(255, 52, 55, 95),
                        () async {
                          await Navigator.pushNamed(
                            context,
                            QrCodeVerifyScreen.routeName,
                            arguments: {
                            'eventId' : eventProvider.selectedEventId,

                            }
                          );
                         

                      },
                      ),
                      buildDashboardTile(
                        context,
                        'Departure',
                        'Exit the Guest',
                        Icons.exit_to_app_rounded,
                        const Color.fromARGB(255, 52, 55, 95),
                        () async {
                          await Navigator.pushNamed(
                            context,
                            DepartureScreen.routeName,
                            arguments: {
                              'eventId': eventProvider.selectedEventId,
                            }
                          );
                        },
                      ),
                      buildDashboardTile(
                        context,
                        'Quick Register',
                        'On-spot registration',
                        Icons.flash_on_rounded,
                        const Color.fromARGB(255, 52, 55, 95),
                        () => Navigator.pushNamed(
                          context,
                          QuickRegisterScreen.routeName,
                        ),
                      ),
                      buildDashboardTile(
                        context,
                        'Analytics',
                        'View statistics',
                        Icons.analytics_rounded,
                        const Color.fromARGB(255, 52, 55, 95),
                        () => Navigator.pushNamed(
                          context,
                          AnalyticsScreen.routeName,
                        ),
                      ),
            buildDashboardTile(context, "Help", "Adhaydhir help center", Icons.help,                        const Color.fromARGB(255, 52, 55, 95) , () => Navigator.pushNamed(context, HelpScreen.routeName))
                   ,  
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric( horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Logo and University Name Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/utu-logo.png',
                              height: 50,
                              width: 50,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Powered by",style: TextStyle(fontSize: 12,fontWeight: FontWeight.w500),),
                                Text(
                                  "VEER MADHO SINGH BHANDARI",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF1A237E),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  "UTTARAKHAND TECHNICAL UNIVERSITY",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1A237E).withOpacity(0.8),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                    
                      // Divider
                      Divider(
                        color: Color(0xFFFFCCCB).withOpacity(0.5),
                        thickness: 1,
                      ),
                  
                      
                      // Contact info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "P.O. Suddhowala, Dehradun, Uttarakhand",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      // SizedBox(height: 10,),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    "Credits:",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  TextButton(
                    onPressed: () async {
                      final Uri url = Uri.parse("https://github.com/adityakumar-dev");
                      try {
                        if (!await launchUrl(
                          url,
                          mode: LaunchMode.inAppBrowserView,
                        )) {
                          if (context.mounted) {
                            Fluttertoast.showToast(
                              msg: "Could not launch $url",
                              backgroundColor: Colors.red,
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Fluttertoast.showToast(
                            msg: "Error launching URL: ${e.toString()}",
                            backgroundColor: Colors.red,
                          );
                        }
                      }
                    },
                    child: Row(
                      children: [
                        // Icon(Icons.github_rounded,size: 14,),
                        Image.asset("assets/images/github.png",height: 14,width: 14,),
                        SizedBox(width: 4,),
                        Text("adityakumar-dev",style: TextStyle(fontSize: 12,fontWeight: FontWeight.w500),),
                      ],
                    ),
                  )
                ],
              ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
