import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:spring_admin/utils/constants/server_endpoints.dart';

class CustomScanner extends StatefulWidget {
  final String operationType;
  
  const CustomScanner({
    super.key, 
    required this.operationType,
  }) : assert(
    operationType == 'entry' || operationType == 'exit',
    'operationType must be either "entry" or "exit"'
  );

  @override
  State<CustomScanner> createState() => _CustomScannerState();
}

class _CustomScannerState extends State<CustomScanner> {
  late final MobileScannerController controller;
  bool isProcessing = false;
  bool hasScanned = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> handleQRScan(String code) async {
    if (hasScanned) return;
    hasScanned = true;
    
    setState(() {
      isProcessing = true;  // Set loading state
    });
    
    try {
      if (code.isEmpty) {
        throw Exception('Invalid QR code');
      }

      // Parse QR data
      final qrData = json.decode(code);
      debugPrint("QR Data: $qrData");
      
      if (qrData['user_id'] == null) {
        throw Exception('Invalid QR code format: missing user_id');
      }

      if (widget.operationType == 'entry') {
        // For entry, just return the user_id to previous screen
        if (!mounted) return;
        Fluttertoast.showToast(
          msg: 'QR code scanned successfully',
          backgroundColor: Colors.green,
        );
        Navigator.of(context).pop(qrData['user_id'].toString());
        return;
      }

      // For exit operation - this is deprecated, use DepartureScreen instead
      throw Exception('Please use the dedicated Departure screen for exit operations');
    } catch (e) {
      debugPrint("Error in handleQRScan: $e");
      if (!mounted) return;
      
      Fluttertoast.showToast(
        msg: e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );

      // Reset scan state
      hasScanned = false;
    } finally {
      // Always cleanup
      if (mounted) {
        setState(() {
          isProcessing = false;  // Reset loading state
        });
      }
      controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) async {
              final code = capture.barcodes.first.rawValue;
              if (code != null) {
                await handleQRScan(code);
              }
            },
          ),
          _buildOverlay(),
          if (isProcessing)  // Show loading overlay when processing
            Container(
              color: Colors.black54,
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.operationType == 'entry' 
                        ? 'Processing entry...' 
                        : 'Processing exit...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
}