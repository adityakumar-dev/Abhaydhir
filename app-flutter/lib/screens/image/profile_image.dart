import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';

class ProfileImageScreen extends StatefulWidget {
  const ProfileImageScreen({super.key, required this.base64Image, required this.name});
  final String base64Image;
  final String name;
  @override
  State<ProfileImageScreen> createState() => _ProfileImageScreenState();
}

class _ProfileImageScreenState extends State<ProfileImageScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        leading: IconButton(onPressed: (){
          Navigator.pop(context);
        }, icon: Icon(Icons.arrow_back)),
        actions: [
          IconButton(onPressed: ()async{
            final isGranted = await checkAndRequestPermissions(skipIfExists: false);
            if (isGranted) {
              Uint8List bytes = base64Decode(widget.base64Image.split(',')[1]);
             final result = await SaverGallery.saveImage(bytes, fileName: '${DateTime.now().millisecondsSinceEpoch}.jpg', skipIfExists: false);
             if(result.isSuccess){
              Fluttertoast.showToast(msg: 'Image saved to gallery');
             }else{
              Fluttertoast.showToast(msg: 'Failed to save image to gallery');
             }
            }
          }, icon: Icon(Icons.download)),
        ],
      ),
      body: Column(
        children: [
        
          Image.memory(  base64Decode(widget.base64Image.split(',')[1]),),
          
        ],
      ),
    );
  }
}


Future<bool> checkAndRequestPermissions({required bool skipIfExists}) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return false; // Only Android and iOS platforms are supported
  }

  if (Platform.isAndroid) {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = deviceInfo.version.sdkInt;

    if (skipIfExists) {
      // Read permission is required to check if the file already exists
      return sdkInt >= 33
          ? await Permission.photos.request().isGranted
          : await Permission.storage.request().isGranted;
    } else {
      // No read permission required for Android SDK 29 and above
      return sdkInt >= 29 ? true : await Permission.storage.request().isGranted;
    }
  } else if (Platform.isIOS) {
    // iOS permission for saving images to the gallery
    return skipIfExists
        ? await Permission.photos.request().isGranted
        : await Permission.photosAddOnly.request().isGranted;
  }

  return false; // Unsupported platforms
}