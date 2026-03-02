import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:spring_admin/apis/server_api.dart';
import 'package:spring_admin/utils/event_required_mixin.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../guest_profile/guest_profile_detail.dart';

// Define a Guest model for better type safety and performance
class Guest {
  final int userId;
  final String uniqueId;
  final String name;
  final String phone;
  final String validDate;
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
    required this.phone,
    required this.validDate,
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
        name: json['name']?.toString() ?? 'Unknown',
        phone: json['phone']?.toString() ?? 'N/A',
        validDate: json['valid_date']?.toString() ?? 'N/A',
        uniqueIdType: json['unique_id_type']?.toString() ?? 'ID',
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
  bool _isSearching = false;

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
  int _currentOffset = 0;
  static const int _pageSize = 20;

  // Fixed event dates
  static const List<Map<String, String>> _availableDates = [
    {'label': 'Feb 27', 'value': '2026-02-27'},
    {'label': 'Feb 28', 'value': '2026-02-28'},
    {'label': 'Mar 1',  'value': '2026-03-01'},
  ];
  String _selectedDate = '2026-03-01';

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
    if (_isLoadingMore || !_hasMoreData || isLoading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreGuests();
    }
  }

  Future<void> _loadMoreGuests() async {
    if (_isLoadingMore || !_hasMoreData || isLoading) return;

    final eventId = getEventId(context);
    if (eventId == null) return;

    // Set synchronously BEFORE any await to prevent race with _onScroll
    _isLoadingMore = true;
    setState(() {});

    try {
      final searchQuery = _searchController.text.trim();
      final result = await ServerApi.getTouristsByEvent(
        eventId,
        date: _selectedDate,
        limit: _pageSize,
        offset: _currentOffset,
        search: searchQuery.isEmpty ? null : searchQuery,
        onlyActive: _showActiveOnly,
      );

      if (!mounted) return;

      if (result != null && result['tourists'] != null) {
        final touristsData = result['tourists'] as List;
        final newGuests = touristsData
            .map((t) => Guest.fromJson(t))
            .toList();

        setState(() {
          guests.addAll(newGuests);
          _currentOffset += touristsData.length; // record-based: 0 → 20 → 40 → 60
          _hasMoreData = touristsData.length >= _pageSize;
          _isLoadingMore = false;
        });
        _filterGuests();
      } else {
        setState(() {
          _hasMoreData = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading more guests: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // Filtering is now server-side; this just syncs the display list.
  void _filterGuests() {
    setState(() => filteredGuests = guests);
  }

  /// Debounced entry point when the user types in the search field.
  void _triggerSearch(String value) {
    _debounceTimer?.cancel();
    if (!_isSearching) setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 500), fetchGuests);
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
        _currentOffset = 0;
        _hasMoreData = true;
      });

      // Use ServerApi to get tourists by event
      final searchQuery = _searchController.text.trim();
      final result = await ServerApi.getTouristsByEvent(
        eventId,
        date: _selectedDate,
        limit: _pageSize,
        offset: 0,
        search: searchQuery.isEmpty ? null : searchQuery,
        onlyActive: _showActiveOnly,
      );

      if (!mounted) return;

      if (result != null && result['tourists'] != null) {
        final touristsData = result['tourists'] as List;
        
        final newGuests = touristsData.map((tourist) {
          return Guest.fromJson(tourist);
        }).toList();
        
        // Add all guest IDs to the set
        _loadedGuestIds.addAll(newGuests.map((guest) => guest.userId.toString()));

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
          _currentOffset = newGuests.length;
          _hasMoreData = newGuests.length >= _pageSize;
          isLoading = false;
          _isSearching = false;
        });
        _filterGuests();
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
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            scrolledUnderElevation: 0,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Guest List',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.download, color: Colors.white),
                tooltip: 'Download Entry Data',
                onPressed: _showDownloadDialog,
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            RefreshIndicator(
              onRefresh: fetchGuests,
              child: Column(
                children: [
                   Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // _buildHeaderCard(),
                          _buildStatistics(),
                          _buildDateSelector(),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _triggerSearch,
                              decoration: InputDecoration(
                                hintText: 'Search by name or phone…',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _isSearching
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      )
                                    : _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              _searchController.clear();
                                              fetchGuests();
                                            },
                                          )
                                        : null,
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
                                    setState(() => _showActiveOnly = selected);
                                    fetchGuests();
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
                        childCount: filteredGuests.length + (_isLoadingMore || (!_hasMoreData && filteredGuests.isNotEmpty) ? 1 : 0),
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

  Widget _buildDateSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: _availableDates.map((d) {
          final isSelected = _selectedDate == d['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(d['label']!),
              selected: isSelected,
              onSelected: (_) {
                if (_selectedDate != d['value']!) {
                  setState(() => _selectedDate = d['value']!);
                  fetchGuests();
                }
              },
              selectedColor: const Color(0xFF1A237E),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF1A237E),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              side: BorderSide(
                color: const Color(0xFF1A237E).withOpacity(0.4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
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
    final statusColor = guest.isCurrentlyInside ? Colors.green : Colors.grey[400];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: guest.isCurrentlyInside 
              ? Colors.green.withOpacity(0.5)
              : Colors.grey.withOpacity(0.2),
          width: guest.isCurrentlyInside ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GuestProfileDetail(
                userId: guest.userId,
                guestName: guest.name,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name and Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guest.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // const SizedBox(height: 4),
                        // Row(
                        //   children: [
                        //     Icon(
                        //       Icons.phone,
                        //       size: 14,
                        //       color: Colors.grey[600],
                        //     ),
                        //     const SizedBox(width: 4),
                        //     Text(
                        //       guest.phone,
                        //       style: TextStyle(
                        //         fontSize: 13,
                        //         color: Colors.grey[600],
                        //         fontWeight: FontWeight.w500,
                        //       ),
                        //     ),
                        //   ],
                        // ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor?.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: statusColor?.withOpacity(0.3) ?? Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          guest.isCurrentlyInside ? 'Inside' : 'Outside',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Phone and Valid Till Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phone',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 14,
                              color: Colors.teal[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              guest.phone,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00897B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Valid Till',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        guest.validDate,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Entry Stats and Group Info
              Row(
                children: [
                  if (guest.isGroup)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.groups,
                              size: 14,
                              color: Colors.purple,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${guest.groupCount} members',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.orange,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Individual',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (guest.totalEntriesToday > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${guest.totalEntriesToday} ${guest.totalEntriesToday == 1 ? 'entry' : 'entries'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00897B),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _showDownloadDialog() async {
    final eventId = getEventId(context);
    if (eventId == null) {
      Fluttertoast.showToast(
        msg: "No event selected",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    // Show loading dialog while fetching date range
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Fetch available date range from backend
      final dateRangeData = await ServerApi.getEventEntryDateRange(eventId);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (dateRangeData == null) {
        Fluttertoast.showToast(
          msg: "Failed to fetch date range",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      final entryDateRange = dateRangeData['entry_date_range'] as Map<String, dynamic>?;
      final hasEntries = entryDateRange?['has_entries'] ?? false;
      
      if (!hasEntries) {
        Fluttertoast.showToast(
          msg: "No entry records found for this event",
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      final firstEntryDate = entryDateRange?['first_entry_date'] as String?;
      final lastEntryDate = entryDateRange?['last_entry_date'] as String?;

      if (firstEntryDate == null || lastEntryDate == null) {
        Fluttertoast.showToast(
          msg: "Invalid date range",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // Parse dates
      final firstDate = DateTime.parse(firstEntryDate);
      final lastDate = DateTime.parse(lastEntryDate);

      // Show download dialog with date range options
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => _DownloadDialog(
          eventId: eventId,
          firstEntryDate: firstDate,
          lastEntryDate: lastDate,
          eventName: dateRangeData['event']?['name'] ?? 'Event',
        ),
      );

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog if still open
      
      debugPrint('Error fetching date range: $e');
      Fluttertoast.showToast(
        msg: "Error: ${e.toString()}",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }
}

/// Download Dialog Widget
class _DownloadDialog extends StatefulWidget {
  final int eventId;
  final DateTime firstEntryDate;
  final DateTime lastEntryDate;
  final String eventName;

  const _DownloadDialog({
    required this.eventId,
    required this.firstEntryDate,
    required this.lastEntryDate,
    required this.eventName,
  });

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  DateTime? selectedFromDate;
  DateTime? selectedToDate;
  bool isDownloading = false;

  @override
  void initState() {
    super.initState();
    // Default to full range
    selectedFromDate = widget.firstEntryDate;
    selectedToDate = widget.lastEntryDate;
  }

  Future<void> _selectFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedFromDate ?? widget.firstEntryDate,
      firstDate: widget.firstEntryDate,
      lastDate: widget.lastEntryDate,
      helpText: 'Select Start Date',
    );

    if (picked != null) {
      setState(() {
        selectedFromDate = picked;
        // Ensure toDate is not before fromDate
        if (selectedToDate != null && selectedToDate!.isBefore(picked)) {
          selectedToDate = picked;
        }
      });
    }
  }

  Future<void> _selectToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedToDate ?? widget.lastEntryDate,
      firstDate: selectedFromDate ?? widget.firstEntryDate,
      lastDate: widget.lastEntryDate,
      helpText: 'Select End Date',
    );

    if (picked != null) {
      setState(() {
        selectedToDate = picked;
      });
    }
  }

  String _formatDateDisplay(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateApi(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _downloadCsv() async {
    if (selectedFromDate == null || selectedToDate == null) {
      Fluttertoast.showToast(
        msg: "Please select both dates",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      isDownloading = true;
    });

    try {
      final fromDateStr = _formatDateApi(selectedFromDate!);
      final toDateStr = _formatDateApi(selectedToDate!);
      
      final downloadUrl = ServerApi.getDownloadEventEntriesUrl(
        widget.eventId,
        fromDateStr,
        toDateStr,
      );

      // Get JWT token from Supabase session
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;
      
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      // Make HTTP request with JWT headers
      final response = await http.get(
        Uri.parse(downloadUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        // Get downloads directory
        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          directory = await getApplicationDocumentsDirectory();
        } else {
          directory = await getDownloadsDirectory();
        }

        if (directory == null) {
          throw Exception('Could not access downloads directory');
        }

        // Generate filename with current date: guest_list_2025-10-12.csv
        final now = DateTime.now();
        final dateStr = DateFormat('yyyy-MM-dd').format(now);
        final filename = 'guest_list_$dateStr.csv';
        final filePath = '${directory.path}/$filename';

        // Write file
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        if (!mounted) return;
        Navigator.pop(context);
        
        // Show share dialog
        _showShareDialog(filePath, filename);
      } else {
        throw Exception('Download failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error downloading CSV: $e');
      if (!mounted) return;
      
      Fluttertoast.showToast(
        msg: "Download failed: ${e.toString()}",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          isDownloading = false;
        });
      }
    }
  }

  void _showShareDialog(String filePath, String filename) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text(
              'Download Complete',
              style: TextStyle(
                color: Colors.green,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File saved as:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              filename,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Share the file via WhatsApp, Email, etc.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                final xFile = XFile(filePath);
                await Share.shareXFiles(
                  [xFile],
                  text: 'Guest List CSV Export - ${filename}',
                  subject: 'Guest List Data',
                );
              } catch (e) {
                debugPrint('Error sharing file: $e');
                Fluttertoast.showToast(
                  msg: "Failed to share: ${e.toString()}",
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                );
              }
            },
            icon: Icon(Icons.share, size: 18),
            label: Text('Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1A237E),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.download, color: Color(0xFF1A237E)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Download Entry Data',
              style: TextStyle(
                color: Color(0xFF1A237E),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event: ${widget.eventName}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Available range: ${_formatDateDisplay(widget.firstEntryDate)} - ${_formatDateDisplay(widget.lastEntryDate)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Select Date Range:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            // From Date
            InkWell(
              onTap: isDownloading ? null : _selectFromDate,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'From: ${selectedFromDate != null ? _formatDateDisplay(selectedFromDate!) : 'Select'}',
                      style: TextStyle(fontSize: 14),
                    ),
                    Icon(Icons.calendar_today, size: 18, color: Color(0xFF1A237E)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            // To Date
            InkWell(
              onTap: isDownloading ? null : _selectToDate,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'To: ${selectedToDate != null ? _formatDateDisplay(selectedToDate!) : 'Select'}',
                      style: TextStyle(fontSize: 14),
                    ),
                    Icon(Icons.calendar_today, size: 18, color: Color(0xFF1A237E)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'CSV will include all entry records within selected dates',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isDownloading ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton.icon(
          onPressed: isDownloading ? null : _downloadCsv,
          icon: isDownloading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(Icons.download, size: 18),
          label: Text(isDownloading ? 'Downloading...' : 'Download CSV'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF1A237E),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}