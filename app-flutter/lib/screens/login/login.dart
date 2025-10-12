import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:spring_admin/providers/event_provider.dart';
import 'package:spring_admin/screens/home/home.dart';
import 'package:spring_admin/screens/register/register_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    try {
      // Use Supabase directly - auth state listener will handle navigation
      await _supabase.auth.signInWithPassword(
        email: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      eventProvider.clearSelection();
      await eventProvider.initialize();
      Navigator.pushNamed(context, HomeScreen.routeName);

      // Show success message (navigation handled by auth state listener)
      await Fluttertoast.showToast(
        msg: "Login successful",
        backgroundColor: Colors.green,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_SHORT,
      );
      
      // Auth state listener in splash screen will handle navigation to home
      
    } on AuthException catch (error) {
      if (!mounted) return;
      
      debugPrint("Auth error: ${error.message}");
      Fluttertoast.showToast(
        msg: error.message,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } on TimeoutException catch (e) {
      debugPrint("Timeout error: $e");
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Connection timed out. Please try again.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } on SocketException catch (e) {
      debugPrint("Socket error: $e");
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Network connection error. Please check your internet connection.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      debugPrint("Login error: $e");
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Login failed. Please try again.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void showLoginBox(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        // bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            // height: MediaQuery.of(context).size.height * 0.4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    child: inputTextfield(
                      "Email",
                      Icons.email_outlined,
                      _usernameController,
                      readOnly: false,
                      isFocused: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    child: inputTextfield(
                      "Password",
                      isPassword: true,
                      Icons.lock_outline_rounded,
                      _passwordController,
                      readOnly: false,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleLogin();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 10, 128, 120),
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.white, Colors.pink.shade100.withOpacity(0.1).withOpacity(0.1), Colors.pink.shade100.withOpacity(0.1), Colors.pink.shade100
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight)
                ),
                padding: const EdgeInsets.all(8.0),
                child: Opacity(
                  opacity: 0.1,
                  child: Image.asset(
                    'assets/images/utu-logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // Main Content
            SingleChildScrollView(
              child: Container(
                height: MediaQuery.of(context).size.height,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 30),
                decoration: BoxDecoration(
                  // color: Colors.white,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    // Logo
                     Column(
                      children: [
                        Image.asset(
                          'assets/images/emblem.png',
                          height: 120,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'SPRING FESTIVAL 2025',
                          style: TextStyle(
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "राजभवन उत्तराखंड",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          "RAJ BHAWAN UTTARKHAND",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                    Text("Login with your credentials", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),),
                    const SizedBox(height: 10),
                    AppUserLogin(),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Not a member? ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),),
                        TextButton(onPressed: (){
                          Navigator.pushNamed(context, RegisterScreen.routeName);
                        }, child: Text("Register", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue),)),
                      ],
                    ),
                    const Spacer(flex: 2),
                    // Powered by text
                    Column(
                      children: [
                        Text(
                          'Powered by',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        Image.asset('assets/images/utu-logo.png', height: 80),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Column AppUserLogin() {
    return Column(
      children: [
        // Email field
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: inputTextfield(
            "Email",
            Icons.email_outlined,
            _usernameController,
            onTap: () {
              showLoginBox(context);
            },
          ),
        ),
        const SizedBox(height: 25),

        // Password field
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: inputTextfield(
            "Password",
            Icons.lock_outline_rounded,
            _passwordController,
            isPassword: true,
            onTap: () {
              showLoginBox(context);
            },
          ),
        ),
        const SizedBox(height: 35),

        // Login button
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Color.fromARGB(255, 10, 128, 120).withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color.fromARGB(255, 10, 128, 120),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      height: 25,
                      width: 25,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                    : const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

}

  TextField inputTextfield(
    String hintText,
    IconData prefixIcon,
    TextEditingController controller, {
    bool isFocused = false,
    bool isPassword = false,
    bool readOnly = true,
    VoidCallback? onTap,
  }) {
    return TextField(
      // focusNode: focusNode,
      autofocus: isFocused,
      onTap: onTap,
      readOnly: readOnly,
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
        prefixIcon: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(
            prefixIcon,
            color: Color.fromARGB(255, 10, 128, 120),
            size: 24,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: Color.fromARGB(255, 10, 128, 120),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 20,
        ),
      ),
    );
  }