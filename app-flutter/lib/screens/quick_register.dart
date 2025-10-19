import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:spring_admin/providers/camera_settings_provider.dart';
import 'package:spring_admin/providers/event_provider.dart';
import 'package:spring_admin/screens/camer_capture_screen.dart';
import 'package:spring_admin/screens/event_selector_dialog.dart';
import 'package:spring_admin/apis/server_api.dart';
import 'package:spring_admin/utils/constants/server_endpoints.dart';
import 'package:spring_admin/utils/event_required_mixin.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;

class QuickRegisterScreen extends StatefulWidget {
  static const String routeName = '/quickRegister';
  const QuickRegisterScreen({super.key});

  @override
  State<QuickRegisterScreen> createState() => _QuickRegisterScreenState();
}

class _QuickRegisterScreenState extends State<QuickRegisterScreen> with EventRequiredMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _idController = TextEditingController();
  final _groupNameController = TextEditingController();
  final _countController = TextEditingController();
  String _selectedIdType = 'aadhar';
  String _registrationType = 'individual';
  final List<String> _idTypes = [
    'aadhar',
    'passport',
    'college_id',
    'other',
  ];
  bool isLoading = false;
  String? error;
  String? visitorCardUrl;
  int? registeredEventId;
  String? registeredEventName;

  @override
  void initState() {
    super.initState();
    _loadEventInfo();
  }

  Future<void> _loadEventInfo() async {
    if (!mounted) return;
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    
    if (eventProvider.hasSelectedEvent) {
      setState(() {
        registeredEventId = eventProvider.selectedEventId;
        registeredEventName = eventProvider.selectedEventName;
      });
    }
  }

  // Future<void> _showEventSelector() async {
  //   final result = await showEventSelectorDialog(context);
    
  //   if (result != null && mounted) {
  //     setState(() {
  //       registeredEventId = result['event_id'];
  //       registeredEventName = result['event_name'];
  //     });
  //   }
  // }

  Widget _buildRegistrationTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Registration Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _registrationType = 'individual';
                    _groupNameController.clear();
                    _countController.clear();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _registrationType == 'individual'
                        ? const Color.fromARGB(255, 10, 128, 120)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _registrationType == 'individual'
                          ? const Color.fromARGB(255, 10, 128, 120)
                          : Colors.grey.shade200,
                    ),
                    boxShadow: _registrationType == 'individual'
                        ? [
                            BoxShadow(
                              color: const Color.fromARGB(255, 10, 128, 120).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.person,
                        size: 24,
                        color: _registrationType == 'individual'
                            ? Colors.white
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Individual',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _registrationType == 'individual'
                              ? Colors.white
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _registrationType = 'group';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _registrationType == 'group'
                        ? const Color.fromARGB(255, 10, 128, 120)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _registrationType == 'group'
                          ? const Color.fromARGB(255, 10, 128, 120)
                          : Colors.grey.shade200,
                    ),
                    boxShadow: _registrationType == 'group'
                        ? [
                            BoxShadow(
                              color: const Color.fromARGB(255, 10, 128, 120).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.group,
                        size: 24,
                        color: _registrationType == 'group'
                            ? Colors.white
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Group',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _registrationType == 'group'
                              ? Colors.white
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIdTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ID Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedIdType,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.badge_outlined,
                color: Color.fromARGB(255, 10, 128, 120),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            alignment: AlignmentDirectional.center,
            items: _idTypes.map((String type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(
                  type.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(color: Colors.grey.shade800),
                  textAlign: TextAlign.center,
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedIdType = newValue!;
              });
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cameraProvider = Provider.of<CameraSettingsProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        flexibleSpace: Container(
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
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1A237E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Quick Register',
          style: TextStyle(
            color: Color(0xFF1A237E),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.event, color: Color(0xFF1A237E)),
          //   onPressed: _showEventSelector,
          //   tooltip: 'Select Event',
          // ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            bottom: -190,
            left: 150,
            right: -150,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.4,
              child: Image.asset(
                'assets/images/aipen.png',
                height: MediaQuery.of(context).size.height * 0.4,
                color: Color.fromARGB(255, 255, 165, 164),
              ),
            ),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Event Selection Banner
                                if (registeredEventName != null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color.fromARGB(255, 10, 128, 120),
                                          const Color.fromARGB(255, 10, 128, 120).withOpacity(0.8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.event, color: Colors.white, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Registering for:',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              Text(
                                                registeredEventName!,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // IconButton(
                                        //   icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                                        //   onPressed: _showEventSelector,
                                        //   tooltip: 'Change Event',
                                        // ),
                                      ],
                                    ),
                                  ),
                                Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 8,
                                    ),
                                    child: _buildPhotoSection(cameraProvider),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildRegistrationTypeSelector(),
                                const SizedBox(height: 16),
                                _buildInputField(
                                  controller: _nameController,
                                  label: 'Full Name',
                                  helperText: "Guest Name",
                                  icon: Icons.person_outline,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter full name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildInputField(
                                  controller: _emailController,
                                  label: 'Email Address',
                                  helperText: "Guest Email Address",
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter email address';
                                    }
                                    if (!RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                    ).hasMatch(value)) {
                                      return 'Please enter a valid email address';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildIdTypeDropdown(),
                                const SizedBox(height: 16),
                                _buildInputField(
                                  controller: _idController,
                                  label: 'ID Number',
                                  helperText: "Enter ID Number",
                                  icon: Icons.credit_card,
                                  keyboardType: TextInputType.text,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter ID Number';
                                    }
                                    return null;
                                  },
                                ),
                                if (_registrationType == 'group') ...[
                                  const SizedBox(height: 16),
                                  _buildInputField(
                                    controller: _groupNameController,
                                    label: 'Group Name',
                                    helperText: "Enter Group Name",
                                    icon: Icons.group,
                                    validator: (value) {
                                      if (_registrationType == 'group' && 
                                          (value == null || value.trim().isEmpty)) {
                                        return 'Please enter Group Name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _buildInputField(
                                    controller: _countController,
                                    label: 'Count',
                                    helperText: "Enter Count",
                                    icon: Icons.numbers,
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (_registrationType == 'group' && 
                                          (value == null || value.trim().isEmpty)) {
                                        return 'Please enter Count';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                                if (error != null) _buildErrorMessage(),
                                const SizedBox(height: 16),
                                _buildSubmitButton(cameraProvider),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(CameraSettingsProvider cameraProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1a237e),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CameraCaptureScreen(),
                ),
              );
              setState(() {});
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child:
                  cameraProvider.capturedImage != null
                      ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(cameraProvider.capturedImage!.path),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(
                                Icons.refresh,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                cameraProvider.resetOverlay();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            const CameraCaptureScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      )
                      : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to capture photo',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: const Color.fromARGB(255, 10, 128, 120),
            ),
            filled: true,
            labelText: helperText,
            labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color.fromARGB(255, 10, 128, 120),
              ),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        error!,
        style: const TextStyle(color: Colors.red, fontSize: 14),
      ),
    );
  }

  Widget _buildSubmitButton(CameraSettingsProvider cameraProvider) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : () => _handleSubmit(cameraProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 10, 128, 120),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child:
            isLoading
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : const Text(
                  'Register Guest',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
      ),
    );
  }

  Future<void> _handleSubmit(CameraSettingsProvider cameraProvider) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if event is selected
    if (registeredEventId == null) {
      Fluttertoast.showToast(
        msg: 'Please select an event first',
        backgroundColor: Colors.orange,
      );
      return;
    }

    setState(() {
      error = null;
      isLoading = true;
    });

    try {
      if (cameraProvider.capturedImage == null) {
        throw Exception('Please capture a photo');
      }

      showLoadingDialog(context, "Registering Tourist...");

      // Use ServerApi to register tourist
      final result = await ServerApi.registerTourist(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        uniqueIdType: _selectedIdType,
        uniqueId: _idController.text.trim(),
        isGroup: _registrationType == 'group',
        groupCount: _registrationType == 'group' 
            ? int.tryParse(_countController.text) ?? 1 
            : 1,
        registeredEventId: registeredEventId!,
        imageFile: File(cameraProvider.capturedImage!.path),
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result != null && result['message'] != null) {
        visitorCardUrl = result['visitor_card_url'];
        
        Fluttertoast.showToast(
          msg: result['message'] ?? 'Tourist registered successfully!',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        // Show download dialog if visitor card is available
        if (visitorCardUrl != null) {
          _showVisitorCardDownloadDialog();
        } else {
          Navigator.pop(context);
        }
        
        cameraProvider.resetOverlay();
      } else {
        throw Exception('Failed to register tourist');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      Fluttertoast.showToast(
        msg: 'Error: ${e.toString()}',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      
      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showVisitorCardDownloadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient background
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade400,
                        Colors.green.shade600,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Registration Successful',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tourist has been registered successfully!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade50,
                              Colors.blue.shade100.withOpacity(0.3),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.email_outlined,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Visitor card will be emailed to the tourist.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (visitorCardUrl != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'You can also download the visitor card now:',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Actions
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (visitorCardUrl != null) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _downloadVisitorCard(),
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('Download'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color.fromARGB(255, 10, 128, 120),
                              side: const BorderSide(
                                color: Color.fromARGB(255, 10, 128, 120),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Close dialog
                            Navigator.pop(context); // Go back to previous screen
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 10, 128, 120),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(fontWeight: FontWeight.w600),
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
    );
  }

  Future<void> _downloadVisitorCard() async {
    if (visitorCardUrl == null) {
      Fluttertoast.showToast(
        msg: 'Visitor card URL not available',
        backgroundColor: Colors.red,
      );
      return;
    }

    try {
      showLoadingDialog(context, 'Downloading visitor card...');

      // Construct full URL from the visitor_card_url (which is /tourists/visitor-card/{jwt_token})
      final downloadUrl = '${ServerEndpoints.baseUrl}${visitorCardUrl}';
      
      final response = await http.get(Uri.parse(downloadUrl));

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200) {
        // Save the file to downloads directory
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${directory.path}/visitor_card_$timestamp.png';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Open the file
        await OpenFile.open(filePath);

        Fluttertoast.showToast(
          msg: 'Visitor card downloaded successfully!',
          backgroundColor: Colors.green,
        );
      } else {
        throw Exception('Failed to download: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog if still open
      
      debugPrint('Error downloading visitor card: $e');
      Fluttertoast.showToast(
        msg: 'Error downloading visitor card: ${e.toString()}',
        backgroundColor: Colors.red,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _idController.dispose();
    _groupNameController.dispose();
    _countController.dispose();
    super.dispose();
  }
}

void showLoadingDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (context) => Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 140,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 10,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
  );
}