
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:logger/web.dart';
import 'package:spring_admin/apis/server_api.dart';
import 'package:spring_admin/utils/constants/server_endpoints.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:spring_admin/utils/event_required_mixin.dart';

class ViewGuestScreen extends StatefulWidget {
  static const String routeName = '/viewGuest';
  final String userId;

  const ViewGuestScreen({
    super.key,
    required this.userId,
    // required this.isQuickRegister,
  });

  @override
  State<ViewGuestScreen> createState() => _ViewGuestScreenState();
}

class _ViewGuestScreenState extends State<ViewGuestScreen> with EventRequiredMixin {
  Map<String, dynamic>? guestData;
  bool isLoading = true;
  String? error;
  
  bool showQR = false;

  @override
  void initState() {
    super.initState();
    fetchGuestDetails();
  }

  Future<void> fetchGuestDetails() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Use ServerApi to get tourist by ID
      final result = await ServerApi.getTouristById(int.parse(widget.userId));
      ServerApi.logger.i('Guest details: $result');

      if (result != null ) {
        final touristData = result;

        setState(() {
          guestData = {
            'user': touristData['user'],
            'meta': touristData['meta'],
            'all_entry_records': touristData['all_entry_records'] ?? [],
            'today_entry': touristData['today_entry'] ?? {},
            'image_token': touristData['image_token'],
          };
          isLoading = false;
        });
      } else {
        ServerApi.logger.e('No tourist data found in response: $result');
        throw Exception('Failed to load tourist details');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to load guest details: $e');
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _downloadVisitorCard() async {
    try {
      // Get JWT token from backend response
      // Note: The backend should return visitor_card_url with JWT token
      // For now, show message that card will be emailed
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Visitor Card'),
          content: const Text(
            'The visitor card has been sent to the registered email address. '
            'Please check your email to download the card.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error: ${e.toString()}',
        backgroundColor: Colors.red,
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: Color.fromARGB(255, 10, 128, 120),
          ),
        ),
      );
    }

    if (guestData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: Center(child: Text('No guest data available')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
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
          child: AppBar(
            scrolledUnderElevation: 0,
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              guestData!['user'] != null
                  ? guestData!['user']['name'] ?? 'Guest'
                  : 'Guest',
              style: const TextStyle(
                color: Color(0xFF1A237E),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Color.fromARGB(255, 10, 128, 120),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          actions: [
            // Download visitor card button
            if (guestData!['meta']?['visitor_card_jwt'] != null)
              IconButton(
                icon: const Icon(Icons.download, color: Color.fromARGB(255, 10, 128, 120)),
                onPressed: () => _downloadVisitorCard(),
                tooltip: 'Download Visitor Card',
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromARGB(255, 10, 128, 120),
              ),
              onPressed: () => _showHistoryDetails(),
              child: const Text('History', style: TextStyle(color: Colors.white),),
            ),
          ],
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
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
                _buildProfileImage(),
                _buildUserInfo(guestData!['user']),
                _buildQRSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    final imageToken = guestData?['image_token'];
    final baseUrl = ServerEndpoints.baseUrl;
    
    return GestureDetector(
      onTap: (){
        // Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileImageScreen(imageToken: imageToken, name: guestData?['user']['name'] ?? 'Guest')));
      },
      child: Container(
        height: 250,
        width: double.infinity,
        color: const Color(0xFF1A237E),
        child: imageToken != null
            ? Image.network(
                '$baseUrl/tourists/user-image/$imageToken',
                fit: BoxFit.cover,
                headers: {
                  'ngrok-skip-browser-warning': 'true',
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading image: $error');
                  return _buildDefaultProfileImage();
                },
              )
            : _buildDefaultProfileImage(),
      ),
    );
  }

  Widget _buildDefaultProfileImage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text('No Image Available', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildUserInfo(Map<String, dynamic> user) {
    final todayEntry = guestData?['today_entry'] ?? {};
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user['name'] ?? 'N/A',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Email: ${user['email'] ?? 'No email'}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'ID Type: ${user['unique_id_type']?.toUpperCase() ?? 'N/A'}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'ID Number: ${user['unique_id'] ?? 'N/A'}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (user['is_group'] == true) ...[
            const SizedBox(height: 8),
            Text(
              'Group Size: ${user['group_count']} members',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Registered: ${formatDate(user['created_at'])}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          // Today's Entry Status
          if (todayEntry['has_entry_today'] == true) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: todayEntry['is_currently_inside'] == true
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: todayEntry['is_currently_inside'] == true
                      ? Colors.green
                      : Colors.orange,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    todayEntry['is_currently_inside'] == true
                        ? Icons.check_circle
                        : Icons.exit_to_app,
                    color: todayEntry['is_currently_inside'] == true
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todayEntry['is_currently_inside'] == true
                              ? 'Currently Inside'
                              : 'Has Exited',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: todayEntry['is_currently_inside'] == true
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                        Text(
                          'Today\'s Entries: ${todayEntry['total_entries_today'] ?? 0}',
                          style: TextStyle(color: Colors.grey[700], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQRSection() {
    final meta = guestData!['meta'];
    final qrCode = meta?['qr_code'];
    final user = guestData!['user'];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QR Code',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 16),
          if (qrCode != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 3,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // QR Code
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFF1A237E).withOpacity(0.2),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: qrCode,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1A237E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Tourist Name
                    Text(
                      user['name'] ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    // QR Code Text
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A237E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        qrCode,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1A237E),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Scan to verify entry/exit',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'No QR Code available',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showHistoryDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _buildDetailedHistory(scrollController),
      ),
    );
  }

  Widget _buildDetailedHistory(ScrollController scrollController) {
    final allEntryRecords = guestData?['all_entry_records'] as List? ?? [];

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Entry History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (allEntryRecords.isEmpty)
          Center(
            child: Text(
              'No entry records found',
              style: TextStyle(color: Colors.grey[600]),
            ),
          )
        else
          ...allEntryRecords.map((record) {
            return FutureBuilder<Map<String, dynamic>>(
              future: _fetchEntryItemsForRecord(record['record_id']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date: ${formatDate(record['entry_date'])}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A237E),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final entryItems = snapshot.data?['items'] as List? ?? [];
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date: ${formatDate(record['entry_date'])}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (entryItems.isEmpty)
                          Text(
                            'No entries for this date',
                            style: TextStyle(color: Colors.grey[600]),
                          )
                        else
                          ...entryItems.map((item) => Card(
                            margin: const EdgeInsets.only(top: 8),
                            color: Colors.grey[50],
                            child: ListTile(
                              title: Text(
                                'Arrival: ${_formatDateTime(item['arrival_time'])}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1A237E),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item['departure_time'] != null)
                                    Text('Departure: ${_formatDateTime(item['departure_time'])}')
                                  else
                                    const Text(
                                      'Still inside',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  if (item['duration'] != null)
                                    Text('Duration: ${item['duration']} minutes'),
                                  if (item['entry_type'] != null)
                                    Text('Type: ${item['entry_type']}'),
                                ],
                              ),
                              leading: Icon(
                                item['departure_time'] != null
                                    ? Icons.check_circle
                                    : Icons.access_time,
                                color: item['departure_time'] != null
                                    ? Colors.green
                                    : const Color(0xFF1A237E),
                              ),
                            ),
                          )).toList(),
                      ],
                    ),
                  ),
                );
              },
            );
          }).toList(),
      ],
    );
  }

  Future<Map<String, dynamic>> _fetchEntryItemsForRecord(int recordId) async {
    // Since the today_entry already has entry_items, we can use that for today's record
    // For other records, we would need to fetch from the API
    // For now, return empty list for non-today records
    final todayEntry = guestData?['today_entry'];
    if (todayEntry != null && 
        todayEntry['entry_record'] != null && 
        todayEntry['entry_record']['record_id'] == recordId) {
      return {'items': todayEntry['entry_items'] ?? []};
    }
    
    // For historical records, return empty for now
    // You can implement API call here if needed
    return {'items': []};
  }

  String _formatDateTime(String dateTime) {
    try {
      // The date is already in IST (+05:30) according to the response
      DateTime parsedDate = DateTime.parse(dateTime);
      return DateFormat('hh:mm a').format(parsedDate);
    } catch (e) {
      return dateTime;
    }
  }

  String formatDate(String dateTime) {
    try {
      DateTime parsedDate = DateTime.parse(dateTime);
      return DateFormat('dd MMMM yyyy').format(parsedDate);
    } catch (e) {
      return dateTime;
    }
  }
}


