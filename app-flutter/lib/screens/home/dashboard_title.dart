import 'dart:ui';
import 'package:flutter/material.dart';

Widget buildDashboardTile(
  BuildContext context,
  String title,
  String subtitle,
  IconData icon,
  Color color,
  VoidCallback onPressed,
) {
  final size = MediaQuery.of(context).size;
  final isTablet = size.width > 600;

  return InkWell(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(20),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          decoration: BoxDecoration(
            // color: Color(0xFFFFDCD1),
            // color: Colors.red,
            color: Color.fromARGB(255, 10, 128, 120).withOpacity(0.2),
            // color: color.withOpacity(0.4), // Semi-transparent color overlay
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                offset: Offset(0, 5),
                color: Colors.black.withOpacity(0.1),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(size.width * 0.03),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: isTablet ? 48 : 40,
                  color: Colors.white,
                ),
                SizedBox(height: size.height * 0.01),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isTablet ? 20 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: size.height * 0.005),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: Color.fromARGB(255, 10, 128, 120),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
