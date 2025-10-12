import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:spring_admin/providers/event_provider.dart';
import 'package:spring_admin/apis/server_api.dart';
import 'package:spring_admin/screens/event_selector_dialog.dart';
import 'package:spring_admin/utils/event_required_mixin.dart';
import 'dart:convert';

class QrCodeVerifyScreen extends StatefulWidget {
  static const String routeName = '/qrCodeVerify';

  final int? eventId; // Make optional, will load from storage

  const QrCodeVerifyScreen({
    super.key,

    this.eventId,
  });

  @override
  State<QrCodeVerifyScreen> createState() => _QrCodeVerifyScreenState();
}

class _QrCodeVerifyScreenState extends State<QrCodeVerifyScreen> with EventRequiredMixin {
  final MobileScannerController controller = MobileScannerController();
  bool isProcessing = false;
  String? error;
  bool is_detected = false;
  
  // Event info
  int? _currentEventId;
  String? _currentEventName;
  bool _isLoadingEvent = true;

  @override
  void initState() {
    super.initState();
    _loadEventInfo();
  }

  Future<void> _loadEventInfo() async {
    // Priority: widget parameter > EventProvider
    if (widget.eventId != null) {
      setState(() {
        _currentEventId = widget.eventId;
        // _currentEntryPoint = widget.entryPoint ?? " "main_gate"";
        _isLoadingEvent = false;
      });
      return;
    }

    // Load from EventProvider
    try {
      if (!mounted) return;
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      
      if (eventProvider.hasSelectedEvent) {
        setState(() {
          _currentEventId = eventProvider.selectedEventId;
          _currentEventName = eventProvider.selectedEventName;
          _isLoadingEvent = false;
        });
      } else {
        // No event selected, show error
        setState(() {
          error = 'No event selected. Please select an event first.';
          _isLoadingEvent = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load event info: ${e.toString()}';
        _isLoadingEvent = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
             if (is_detected) return;
              setState(() {
                is_detected = true;
              });
              _onDetect(capture);
            },
          ),
          _buildOverlay(),
          if (error != null) _buildErrorOverlay(),
          if (isProcessing) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (isProcessing || error != null) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    setState(() {
      isProcessing = true;
    });

    try {
      // Parse QR code - expecting format: TOURIST-{user_id}-{unique_id}
      final qrCodeValue = barcodes[0].rawValue?.toString() ?? '';
      debugPrint("Scanned QR code: $qrCodeValue");

      // Extract user ID from QR code
      int userId;
      if (qrCodeValue.startsWith('TOURIST-')) {
        final parts = qrCodeValue.split('-');
        if (parts.length >= 2) {
          userId = int.parse(parts[1]);
        } else {
          throw Exception('Invalid QR code format');
        }
      } else {
        // Fallback: try to parse as JSON
        try {
          final qrData = json.decode(qrCodeValue);
          userId = int.parse(qrData['user_id'].toString());
        } catch (e) {
          throw Exception('Invalid QR code format. Expected TOURIST-{id}-{unique_id}');
        }
      }


      // Check if event is loaded
      if (_currentEventId == null) {
        throw Exception('No event selected');
      }

      // Show loading
      if (!context.mounted) return;
      _showLoadingDialog(context, 'Registering entry...');

      // Create entry using ServerApi with loaded event info
      final result = await ServerApi.createEntry(
        userId: userId,
        eventId: _currentEventId!,
        entryType: 'normal',
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result != null && result['message'] != null) {
        Fluttertoast.showToast(
          msg: result['message'],
          backgroundColor: Colors.green,
        );

        // Exit QR screen
        Navigator.of(context).pop();
      } else {
        throw Exception('Failed to create entry');
      }
    } catch (e) {
      // Hide loading dialog if showing
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      Fluttertoast.showToast(
        msg: 'Error: ${e.toString()}',
        backgroundColor: Colors.red,
      );

      // Reset processing state
      setState(() {
        isProcessing = false;
        is_detected = false;
      });
    }
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: 180,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 10,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  color: Color.fromARGB(255, 10, 128, 120),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Row(
                  children: [
                  
                    IconButton(
                      icon: const Icon(Icons.flash_on, color: Colors.white),
                      onPressed: () => controller.toggleTorch(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios,
                          color: Colors.white),
                      onPressed: () => controller.switchCamera(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Event info banner
          if (_currentEventName != null && !_isLoadingEvent)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 10, 128, 120),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _currentEventName!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Align QR code within the frame to scan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 60,
              ),
              const SizedBox(height: 16),
              Text(
                error!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    error = null;
                    controller.start();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Try Again'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Go Back',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Verifying QR Code...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
