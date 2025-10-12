import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_settings_provider.dart';

class CameraCaptureScreen extends StatefulWidget {
  static const String routeName = '/cameraCapture';

  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> with WidgetsBindingObserver {
  CameraSettingsProvider? cameraProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    cameraProvider = Provider.of<CameraSettingsProvider>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await cameraProvider?.initCamera();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraSettingsProvider>(
      builder: (context, provider, child) {
        if (provider.isInitializing) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        final cameraController = provider.controller;
        if (cameraController == null || !cameraController.value.isInitialized) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: ElevatedButton(
                onPressed: () => provider.initCamera(),
                child: const Text('Retry'),
              ),
            ),
          );
        }
      final size = MediaQuery.of(context).size;
      final deviceRatio = size.width / size.height;
        // Modify the scale calculation to better fit the screen
        final scale = 1.5 / (deviceRatio * cameraController.value.aspectRatio);


        // Calculate total rotation
        final baseRotation = provider.getRotationAngle();
        final cameraRotation = provider.isFrontCamera ? 
            -90 * (3.1415927 / 180) : 
            90 * (3.1415927 / 180);
        final totalRotation = baseRotation + cameraRotation;
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
                Transform.scale(
                  scale: scale,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: cameraController.value.aspectRatio,
                      child: Transform.rotate(
                        angle: totalRotation,
                        child: CameraPreview(cameraController),
                      ),
                    ),
                  ),
                ),
              _buildControls(provider),
              if (provider.isProcessing) 
                const Center(child: CircularProgressIndicator(color: Colors.white)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls(CameraSettingsProvider provider) {
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
                IconButton(
                  icon: Icon(
                    provider.isFrontCamera ? Icons.camera_front : Icons.camera_rear,
                    color: Colors.white,
                  ),
                  onPressed: () => provider.changeCamera(),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: FloatingActionButton.large(
              onPressed: () async {
                await provider.captureImage();
                if (provider.capturedImage != null && mounted) {
                  Navigator.pop(context);
                }
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.camera_alt, size: 32, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}