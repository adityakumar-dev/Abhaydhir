import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:spring_admin/apis/server_api.dart';

class RegisterScreen extends StatefulWidget {
  static const String routeName = '/register';
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 10, 128, 120),
                Color.fromARGB(255, 5, 100, 100),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: AppBar(
            leading: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            ),
            backgroundColor: Colors.transparent,
            title: Text(
              "Register Your Account",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            actions: [
              IconButton(
                icon: _isLoading 
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(Icons.check, color: Colors.white),
                onPressed: _isLoading ? null : () async {
                  if (_nameController.text.isEmpty ||
                      _emailController.text.isEmpty ||
                      _passwordController.text.isEmpty ||
                      _apiKeyController.text.isEmpty) {
                    Fluttertoast.showToast(
                      msg: "Please fill all the fields",
                      backgroundColor: Colors.red,
                      textColor: Colors.white,
                    );
                  } else {
                    await _handleRegister();
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                "Create Admin/Security Account",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Fill in the details below to register. You need an API key to register as admin or security personnel.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 30),
              
              inputTextfield(
                "Full Name",
                Icons.person_outline_rounded,
                _nameController,
                isFocused: true,
                readOnly: false,
              ),
              const SizedBox(height: 15),
              
              inputTextfield(
                "Email",
                Icons.email_outlined,
                _emailController,
                readOnly: false,
              ),
              const SizedBox(height: 15),
              
              inputTextfield(
                "Password",
                Icons.lock_outline_rounded,
                _passwordController,
                isPassword: true,
                readOnly: false,
              ),
              const SizedBox(height: 15),
              
              inputTextfield(
                "API Key (admin/security)",
                Icons.vpn_key_outlined,
                _apiKeyController,
                readOnly: false,
              ),
              const SizedBox(height: 10),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(
                  "* Enter 'admin' or 'security' as API key",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              Container(
                width: double.infinity,
                height: 55,
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
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 10, 128, 120),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    setState(() => _isLoading = true);

    try {
      // Validate API key
      final apiKey = _apiKeyController.text.trim().toLowerCase();
      if (apiKey != 'admin' && apiKey != 'security') {
        Fluttertoast.showToast(
          msg: "Invalid API key. Use 'admin' or 'security'",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // Register user using backend API
      final result = await ServerApi.registerUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        apiKey: apiKey,
      );

      if (!mounted) return;

      if (result != null) {
        Fluttertoast.showToast(
          msg: "Registration successful! You can now login.",
          backgroundColor: Colors.green,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
        
        // Navigate back to login
        Navigator.pop(context);
      } else {
        Fluttertoast.showToast(
          msg: "Registration failed. Please try again.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      debugPrint("Registration error: $e");
      if (mounted) {
        Fluttertoast.showToast(
          msg: "An error occurred: ${e.toString()}",
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

  // Input text field widget
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
}