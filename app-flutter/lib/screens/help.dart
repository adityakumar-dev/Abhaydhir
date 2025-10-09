import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HelpScreen extends StatefulWidget {
  static const String routeName = '/help';
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final List<Map<String, String>> faqList = [
    {
      'question': 'How do I verify a visitor?',
      'answer': 'Use the "New Entry" feature to scan the visitor\'s QR code or enter their registration ID. The AI system will automatically verify their identity against their pre-registered information.'
    },
    {
      'question': 'What should I do if face verification fails?',
      'answer': 'If face verification fails, you can: 1) Try scanning again in better lighting, 2) Use the manual verification option to check their government ID, 3) Contact a supervisor for assistance.'
    },
    {
      'question': 'How to handle group registrations?',
      'answer': 'For groups from institutions or organizations, use the "Quick Register" feature. Select "Group Entry" option and scan the group leader\'s authorization code first, then proceed with individual verifications.'
    },
    {
      'question': 'Where can I find visitor statistics?',
      'answer': 'Access the "Analytics" section from the dashboard to view real-time statistics including total visitors, verification success rates, and peak entry times.'
    },
    {
      'question': 'How to handle emergency situations?',
      'answer': 'In case of emergencies: 1) Use the quick action button in the top right corner, 2) Contact security command center, 3) Follow the standard operating procedures available in the Settings > Emergency Protocols section.'
    },
    {
      'question': 'What are the different verification methods available?',
      'answer': 'The system supports: 1) QR code scanning, 2) Face verification, 3) Manual ID verification, 4) Registration ID lookup. Choose the most appropriate method based on the situation.'
    },
    {
      'question': 'How to update visitor status?',
      'answer': 'Access the "Guest List" section, search for the visitor, and use the status toggle to mark their entry/exit. All updates are automatically synchronized with the central database.'
    },
    {
      'question': 'What to do if the system is offline?',
      'answer': 'The app has an offline mode that stores data locally. Continue processing visitors, and the data will automatically sync when connection is restored. For extended outages, switch to the manual verification protocol.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 255, 165, 164),
                Color.fromARGB(255, 255, 200, 200),
                Color.fromARGB(255, 255, 200, 200).withOpacity(0.1),
                
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(CupertinoIcons.arrow_left, color: Color(0xFF1a237e),),
        ),
        title: Text(
          'Help & Support',
          style: TextStyle(
            color: Color(0xFF1a237e),
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
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
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: faqList.length,
            itemBuilder: (context, index) {
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: ExpansionTile(
                  title: Text(
                    faqList[index]['question']!,
                    style: const TextStyle(
                      color: Color.fromARGB(255, 10, 128, 120),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        faqList[index]['answer']!,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}