import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:spring_admin/apis/server_api.dart';
import 'package:spring_admin/utils/event_required_mixin.dart';

import 'view_guest.dart';

// Define a Guest model for better type safety and performance
class Guest {
  final int userId;
  final String uniqueId;
  final String name;
  final String email;
  final String uniqueIdType;
  final bool isGroup;
  final int groupCount;
  final String createdAt;
  final bool hasEntryToday;
  final bool isCurrentlyInside;
  final int totalEntriesToday;
  final int openEntries;
  final String? latestEntry;

  Guest({
    required this.userId,
    required this.uniqueId,
    required this.name,
    required this.email,
    required this.uniqueIdType,
    required this.isGroup,
    required this.groupCount,
    required this.createdAt,
    required this.hasEntryToday,
    required this.isCurrentlyInside,
    required this.totalEntriesToday,
    required this.openEntries,
    this.latestEntry,
  });

  factory Guest.fromJson(Map<String, dynamic> json) {
    try {
      final todayEntry = json['today_entry'] as Map<String, dynamic>? ?? {};
      final lastEntry = todayEntry['last_entry'] as Map<String, dynamic>?;
      
      return Guest(
        userId: json['user_id'] as int,
        uniqueId: json['unique_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        uniqueIdType: json['unique_id_type']?.toString() ?? '',
        isGroup: json['is_group'] ?? false,
        groupCount: json['group_count'] ?? 1,
        createdAt: json['created_at']?.toString() ?? '',
        hasEntryToday: todayEntry['has_entry_today'] ?? false,
        isCurrentlyInside: todayEntry['is_currently_inside'] ?? false,
        totalEntriesToday: todayEntry['total_entries_today'] ?? 0,
        openEntries: todayEntry['open_entries'] ?? 0,
        latestEntry: lastEntry?['arrival_time']?.toString(),
      );
    } catch (e, stackTrace) {
      debugPrint('Error creating Guest from JSON: $e');
      debugPrint('JSON data: ${json.toString()}');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}

Future<Map<String, dynamic>> parseJsonData(String body) async {
  try {
    debugPrint('Response body: $body');
    final parsedData = json.decode(body);
    
    if (parsedData['status'] != 'success') {
      throw Exception('API returned error status: ${parsedData['message']}');
    }

    final data = parsedData['data'];
    if (data == null) {
      throw Exception('Data field is null in response');
    }

    final allUsers = (data['all_users'] as List?)?.map((user) {
      debugPrint('Processing user: ${json.encode(user)}');
      return Guest.fromJson(user);
    }).toList() ?? [];

    final statistics = data['statistics'] as Map<String, dynamic>? ?? {};
    final todayStatistics = data['today_statistics'] as Map<String, dynamic>? ?? {};

    return {
      'statistics': statistics,
      'today_statistics': todayStatistics,
      'all_users': allUsers,
    };
  } catch (e, stackTrace) {
    debugPrint('Error parsing JSON: $e');
    debugPrint('Stack trace: $stackTrace');
    return {'error': 'Failed to parse JSON: $e'};
  }
}

class GuestListsScreen extends StatefulWidget {
  static const String routeName = '/guestList';
  const GuestListsScreen({super.key});

  @override
  State<GuestListsScreen> createState() => _GuestListsScreenState();
}

class _GuestListsScreenState extends State<GuestListsScreen> with EventRequiredMixin {
  final Set<String> _loadedGuestIds = {};
  List<Guest> guests = [];
  List<Guest> filteredGuests = [];
  bool isLoading = true;
  String? error;
  String selectedFilter = 'all';
  bool _showActiveOnly = false;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  // Statistics variables
  Map<String, dynamic> statistics = {};
  
  // Separate counts for registrations vs members
  int totalRegistrations = 0;
  int totalIndividualRegistrations = 0;
  int totalGroupRegistrations = 0;
  int totalMembers = 0;
  int currentlyInsideRegistrations = 0;
  int currentlyInsideMembers = 0;
  int withEntryTodayRegistrations = 0;
  int withEntryTodayMembers = 0;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    fetchGuests();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreGuests();
    }
  }

  Future<void> _loadMoreGuests() async {
    // Pagination disabled for now - using single event fetch
    return;
  }

  void _filterGuests() {
    setState(() {
      List<Guest> filtered = guests;
      
      // Apply active filter
      if (_showActiveOnly) {
        filtered = filtered.where((guest) => guest.isCurrentlyInside).toList();
      }
      
      // Apply search filter
      final searchQuery = _searchController.text;
      if (searchQuery.isEmpty) {
        filteredGuests = filtered;
      } else {
        filteredGuests = filtered.where((guest) {
          return guest.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
              guest.email.toLowerCase().contains(searchQuery.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> fetchGuests() async {
    if (!mounted) return;
    
    // Get event ID from EventProvider
    final eventId = getEventId(context);
    if (eventId == null) {
      setState(() {
        isLoading = false;
        error = 'No event selected';
      });
      return;
    }
    
    try {
      setState(() {
        isLoading = true;
        error = null;
        _loadedGuestIds.clear();
        _hasMoreData = false; // Disable pagination for now
      });

      // Use ServerApi to get tourists by event
      final result = await ServerApi.getTouristsByEvent(eventId);

      if (!mounted) return;

      if (result != null && result['tourists'] != null) {
        final touristsData = result['tourists'] as List;
        
        final newGuests = touristsData.map((tourist) {
          return Guest.fromJson(tourist);
        }).toList();
        
        // Add all guest IDs to the set
        _loadedGuestIds.addAll(newGuests.map((guest) => guest.uniqueId));

        // Get statistics from backend response - NEW STRUCTURE
        final stats = result['statistics'] as Map<String, dynamic>? ?? {};
        
        setState(() {
          // Store all statistics
          statistics = stats;
          
          // Extract individual values for easier access
          totalRegistrations = stats['total_tourist_registrations'] ?? 0;
          totalIndividualRegistrations = stats['total_individual_registrations'] ?? 0;
          totalGroupRegistrations = stats['total_group_registrations'] ?? 0;
          totalMembers = stats['total_members'] ?? 0;
          currentlyInsideRegistrations = stats['currently_inside_registrations'] ?? 0;
          currentlyInsideMembers = stats['currently_inside_members'] ?? 0;
          withEntryTodayRegistrations = stats['with_entry_today_registrations'] ?? 0;
          withEntryTodayMembers = stats['with_entry_today_members'] ?? 0;
          
          guests = newGuests;
          filteredGuests = newGuests;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch tourists');
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error in fetchGuests: $e');
      Fluttertoast.showToast(
        msg: "Error: ${e.toString()}",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      setState(() {
        error = 'Failed to load guests. Please try again.';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Color(0xFFF5F5F5).withOpacity(0.1)
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: AppBar(
            scrolledUnderElevation: 0,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, 
                color: Color(0xFF1A237E)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Guest List',
              style: TextStyle(
                color: Color(0xFF1A237E),
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
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
            RefreshIndicator(
              onRefresh: fetchGuests,
              child: Column(
                children: [
                   Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // _buildHeaderCard(),
                          _buildStatistics(),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) => _filterGuests(),
                              decoration: InputDecoration(
                                hintText: 'Search by name or email',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                FilterChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _showActiveOnly ? Icons.check_circle : Icons.circle_outlined,
                                        size: 16,
                                        color: _showActiveOnly ? Colors.white : Colors.green,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(_showActiveOnly ? 'Active Only' : 'Show All'),
                                    ],
                                  ),
                                  selected: _showActiveOnly,
                                  onSelected: (selected) {
                                    setState(() {
                                      _showActiveOnly = selected;
                                      _filterGuests();
                                    });
                                  },
                                  selectedColor: Colors.green,
                                  labelStyle: TextStyle(
                                    color: _showActiveOnly ? Colors.white : Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  side: BorderSide(
                                    color: Colors.green.withOpacity(0.5),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${filteredGuests.length} guest${filteredGuests.length != 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              _showActiveOnly ? 'Currently Inside' : 'All Guests',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A237E),
                              ),
                            ),
                          ),
                        ],
                      ),
                 
                  Expanded(
                    
                    child: CustomScrollView(
                                    controller: _scrollController,
                                    slivers: [
                    SliverToBoxAdapter(
                     ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= filteredGuests.length) {
                            if (_isLoadingMore) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            if (!_hasMoreData) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('No more guests to load'),
                                ),
                              );
                            }
                            return null;
                          }
                    
                          final guest = filteredGuests[index];
                          return _buildGuestCard(guest);
                        },
                        childCount: filteredGuests.length + (_isLoadingMore || !_hasMoreData ? 1 : 0),
                      ),
                    ),
                                    ],
                                  ),
                  ),
            
                ],
              )),
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Members',
              totalMembers.toString(),
              Icons.people_outline,
              Colors.blue,
              subtitle: '$totalRegistrations registrations',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Inside',
              currentlyInsideMembers.toString(),
              Icons.location_on_outlined,
              Colors.green,
              subtitle: '$currentlyInsideRegistrations entries',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Today',
              withEntryTodayMembers.toString(),
              Icons.check_circle_outline,
              Colors.orange,
              subtitle: '$withEntryTodayRegistrations entries',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Groups',
              totalGroupRegistrations.toString(),
              Icons.groups_outlined,
              Colors.purple,
              subtitle: '$totalIndividualRegistrations indiv.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title, 
    String value, 
    IconData icon, 
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 8,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuestCard(Guest guest) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: guest.isCurrentlyInside 
              ? Colors.green.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
          width: guest.isCurrentlyInside ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1A237E).withOpacity(0.1),
          child: const Icon(
            Icons.person_outline,
            color: Color(0xFF1A237E),
          ),
        ),
        title: Text(
          guest.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              guest.email,
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (guest.isGroup) Text(
              'Group: ${guest.groupCount} members',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    guest.uniqueIdType.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Created: ${_formatDate(guest.createdAt)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (guest.isCurrentlyInside)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: Colors.green,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Currently Inside',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (guest.hasEntryToday && !guest.isCurrentlyInside)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.exit_to_app,
                          size: 12,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Has Exited',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (guest.totalEntriesToday > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${guest.totalEntriesToday} ${guest.totalEntriesToday == 1 ? 'entry' : 'entries'} today',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.pushNamed(
            context,
            ViewGuestScreen.routeName,
            arguments: {
              'userId': guest.userId.toString(),
            },
          );
        },
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}