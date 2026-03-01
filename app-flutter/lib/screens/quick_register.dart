import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:spring_admin/providers/camera_settings_provider.dart';
import 'package:spring_admin/providers/event_provider.dart';
import 'package:spring_admin/screens/camer_capture_screen.dart';
import 'package:spring_admin/apis/server_api.dart';
import 'package:spring_admin/utils/constants/server_endpoints.dart';
import 'package:spring_admin/utils/event_required_mixin.dart';
import 'package:image_picker/image_picker.dart';
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
  final _phoneController = TextEditingController();
  final _countController = TextEditingController(text: '1');
  String _selectedValidDate = '2026-03-01';
  File? _uniqueIdPhotoFile;

  static const List<Map<String, String>> _validDates = [
    // {'label': 'Feb 28', 'value': '2026-02-28'},
    {'label': 'Mar 1',  'value': '2026-03-01'},
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

  Widget _buildPeopleCountSelector() {
    final count = int.tryParse(_countController.text) ?? 1;
    final isGroup = count > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isGroup ? Icons.groups_rounded : Icons.person_rounded,
              size: 16,
              color: const Color(0xFF1A237E),
            ),
            const SizedBox(width: 6),
            Text(
              isGroup ? 'Group Registration' : 'Individual Registration',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isGroup
                    ? const Color(0xFF00897B).withOpacity(0.12)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isGroup ? 'Group' : 'Individual',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isGroup ? const Color(0xFF00897B) : Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Set to 1 for individual, or more for group',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Decrement button
            _buildCounterButton(
              icon: Icons.remove_rounded,
              onTap: count > 1
                  ? () => setState(() {
                        _countController.text = (count - 1).toString();
                      })
                  : null,
            ),
            // Count display / text field
            Expanded(
              child: TextFormField(
                controller: _countController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isGroup ? const Color(0xFF00897B) : const Color(0xFF1A237E),
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isGroup
                          ? const Color(0xFF00897B).withOpacity(0.4)
                          : Colors.grey.shade200,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF00897B), width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Colors.redAccent, width: 2),
                  ),
                  // suffixText: 'people',
                  suffixStyle:
                      TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final n = int.tryParse(value ?? '');
                  if (n == null || n < 1) return 'Minimum 1 person';
                  return null;
                },
              ),
            ),
            // Increment button
            _buildCounterButton(
              icon: Icons.add_rounded,
              onTap: () => setState(() {
                _countController.text = (count + 1).toString();
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCounterButton({required IconData icon, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFF00897B)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: const Color(0xFF00897B).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : Colors.grey.shade400,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildValidDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Valid Date',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select the date this registration is valid for',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 12),
        Row(
          children: _validDates.map((d) {
            final isSelected = _selectedValidDate == d['value'];
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => setState(() => _selectedValidDate = d['value']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color.fromARGB(255, 10, 128, 120)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color.fromARGB(255, 10, 128, 120)
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color.fromARGB(255, 10, 128, 120).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    d['label']!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _pickIdPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (pickedFile != null && mounted) {
      setState(() => _uniqueIdPhotoFile = File(pickedFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraProvider = Provider.of<CameraSettingsProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00897B), Color(0xFF26A69A)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Quick Register',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            centerTitle: true,
          ),
        ),
      ),
      body: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Event Selection Banner
                                // if (registeredEventName != null)
                                //   Container(
                                //     margin: const EdgeInsets.only(bottom: 16),
                                //     padding: const EdgeInsets.all(12),
                                //     decoration: BoxDecoration(
                                //       gradient: LinearGradient(
                                //         colors: [
                                //           const Color.fromARGB(255, 10, 128, 120),
                                //           const Color.fromARGB(255, 10, 128, 120).withOpacity(0.8),
                                //         ],
                                //       ),
                                //       borderRadius: BorderRadius.circular(8),
                                //     ),
                                //     child: Row(
                                //       children: [
                                //         const Icon(Icons.event, color: Colors.white, size: 20),
                                //         const SizedBox(width: 8),
                                //         Expanded(
                                //           child: Column(
                                //             crossAxisAlignment: CrossAxisAlignment.start,
                                //             children: [
                                //               const Text(
                                //                 'Registering for:',
                                //                 style: TextStyle(
                                //                   color: Colors.white70,
                                //                   fontSize: 11,
                                //                 ),
                                //               ),
                                //               Text(
                                //                 registeredEventName!,
                                //                 style: const TextStyle(
                                //                   color: Colors.white,
                                //                   fontSize: 15,
                                //                   fontWeight: FontWeight.bold,
                                //                 ),
                                //               ),
                                //             ],
                                //           ),
                                //         ),
                                //         // IconButton(
                                //         //   icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                                //         //   onPressed: _showEventSelector,
                                //         //   tooltip: 'Change Event',
                                //         // ),
                                //       ],
                                //     ),
                                //   ),
                                _buildPhotoRow(cameraProvider),
                                const SizedBox(height: 16),
                                _buildInputField(
                                  controller: _nameController,
                                  label: 'Full Name',
                                  helperText: 'e.g. Rahul Sharma',
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
                                  controller: _phoneController,
                                  label: 'Phone Number',
                                  helperText: 'e.g. 9876543210',
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter phone number';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildValidDateSelector(),
                                const SizedBox(height: 16),
                                _buildPeopleCountSelector(),
                                if (error != null) _buildErrorMessage(),
                                const SizedBox(height: 16),
                                _buildSubmitButton(cameraProvider),
                              ],
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildPhotoRow(CameraSettingsProvider cameraProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_camera_outlined, size: 15, color: Color(0xFF1A237E)),
            const SizedBox(width: 5),
            const Text(
              'Photos',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A237E),
              ),
            ),
            
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildPhotoTile(
                label: 'Face Photo',
                icon: Icons.face_outlined,
                accentColor: const Color(0xFF00897B),
                imageFile: cameraProvider.capturedImage != null
                    ? File(cameraProvider.capturedImage!.path)
                    : null,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
                  );
                  setState(() {});
                },
                onClear: () {
                  cameraProvider.resetOverlay();
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPhotoTile(
                label: 'ID Document',
                icon: Icons.badge_outlined,
                accentColor: const Color(0xFF00897B),
                imageFile: _uniqueIdPhotoFile,
                onTap: _pickIdPhoto,
                onClear: () => setState(() => _uniqueIdPhotoFile = null),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoTile({
    required String label,
    required IconData icon,
    required Color accentColor,
    required File? imageFile,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final hasImage = imageFile != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
            if (hasImage) ...[
              const Spacer(),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: hasImage ? null : accentColor.withOpacity(0.04),
              border: Border.all(
                color: hasImage ? accentColor : accentColor.withOpacity(0.25),
                width: hasImage ? 2 : 1.5,
              ),
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      imageFile,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 28, color: accentColor.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tap to add',
                        style: TextStyle(
                          fontSize: 12,
                          color: accentColor.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF1A237E),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF00897B),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        hintText: helperText,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF00897B), size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
          borderSide: const BorderSide(color: Color(0xFF00897B), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
      validator: validator,
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
      height: 52,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : () => _handleSubmit(cameraProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00897B),
          disabledBackgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
          shadowColor: const Color(0xFF00897B).withOpacity(0.4),
        ),
        icon: isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.how_to_reg_rounded, size: 20),
        label: Text(
          isLoading ? 'Registering...' : 'Register Guest',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3),
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
      showLoadingDialog(context, "Registering Tourist...");

      // Derive registration type from people count
      final int peopleCount = int.tryParse(_countController.text.trim()) ?? 1;
      final bool isGroupReg = peopleCount > 1;

      // Use ServerApi to register tourist
      final result = await ServerApi.registerTourist(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        isGroup: isGroupReg,
        groupCount: peopleCount,
        registeredEventId: registeredEventId!,
        validDate: _selectedValidDate,
        imageFile: cameraProvider.capturedImage != null
            ? File(cameraProvider.capturedImage!.path)
            : null,
        uniqueIdPhotoFile: _uniqueIdPhotoFile,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result != null) {
        visitorCardUrl = result['visitor_card_url'];
        cameraProvider.resetOverlay();
        _showVisitorCardDownloadDialog();
      } else {
        throw Exception('Registration failed. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      // Close loading dialog if still showing
      if (Navigator.canPop(context)) Navigator.pop(context);

      // Extract clean message — strip "Exception: " prefix
      String raw = e.toString();
      if (raw.startsWith('Exception: ')) raw = raw.substring(11);

      setState(() => error = raw);
      _showErrorDialog(raw);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Red header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              decoration: const BoxDecoration(
                color: Color(0xFFD32F2F),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.error_outline, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Registration Failed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Message body
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, color: Color(0xFF333333), height: 1.5),
              ),
            ),
            // Action
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('OK, Fix & Retry', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                                Icons.sms_outlined,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Visitor card will be sent via SMS to the tourist.',
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
    _phoneController.dispose();
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