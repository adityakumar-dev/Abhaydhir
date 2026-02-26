import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spring_admin/apis/server_api.dart';
import 'package:spring_admin/providers/event_provider.dart';
import 'package:spring_admin/utils/event_required_mixin.dart';

class AnalyticsScreen extends StatefulWidget {
  static const String routeName = '/analytics';
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with EventRequiredMixin {
  Map<String, dynamic>? analyticsData;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    if (!mounted) return;
    
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    final eventId = eventProvider.selectedEventId;
    
    if (eventId == null) {
      setState(() {
        errorMessage = 'No event selected';
        isLoading = false;
      });
      return;
    }
    
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      final data = await ServerApi.getEventAnalytics(eventId);
      
      if (!mounted) return;
      
      if (data != null) {
        setState(() {
          analyticsData = data;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load analytics data';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Event Analytics',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF1A237E),
                ),
              )
            else if (errorMessage != null)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: loadAnalytics,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (analyticsData == null)
              const Center(
                child: Text('No analytics data available'),
              )
            else
              RefreshIndicator(
                onRefresh: loadAnalytics,
                color: const Color(0xFF1A237E),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event Info Card
                      _buildAnalyticsCard(
                        'Event Information',
                        Column(
                          children: [
                            _buildStatRow('Event', analyticsData!['event_info']['name']),
                            _buildStatRow('Location', analyticsData!['event_info']['location']),
                            _buildStatRow('Start Date', _formatDate(analyticsData!['event_info']['start_date'])),
                            _buildStatRow('End Date', _formatDate(analyticsData!['event_info']['end_date'])),
                            if (analyticsData!['event_info']['max_capacity'] != null)
                              _buildStatRow('Max Capacity', analyticsData!['event_info']['max_capacity'].toString()),
                          ],
                        ),
                        Icons.event,
                      ),
                      const SizedBox(height: 20),

                      // Crowd Status Section Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A237E),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Current Crowd Status',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A237E),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Currently Inside',
                              (analyticsData!['crowd_status']['currently_inside'] ?? 0).toString(),
                              Icons.people,
                              _getCapacityColor(analyticsData!['crowd_status']['capacity_status'] ?? 'unknown'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Total People',
                              (analyticsData!['crowd_status']['total_people_inside'] ?? 0).toString(),
                              Icons.groups,
                              _getCapacityColor(analyticsData!['crowd_status']['capacity_status'] ?? 'unknown'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Groups',
                              (analyticsData!['crowd_status']['groups_inside'] ?? 0).toString(),
                              Icons.group,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Individuals',
                              (analyticsData!['crowd_status']['individuals_inside'] ?? 0).toString(),
                              Icons.person,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Last Hour Statistics
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A237E),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Last Hour Statistics',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A237E),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildAnalyticsCard(
                        'Entry Activity',
                        Column(
                          children: [
                            _buildStatRow(
                              'Total Entries',
                              (analyticsData!['last_hour']['entries'] ?? 0).toString(),
                            ),
                            _buildStatRow(
                              'Unique Visitors',
                              (analyticsData!['last_hour']['unique_visitors'] ?? 0).toString(),
                            ),
                            _buildStatRow(
                              'Entry Rate',
                              '${((analyticsData!['last_hour']['entry_rate_per_min'] ?? 0.0) as num).toStringAsFixed(1)}/min',
                            ),
                            _buildStatRow(
                              'Bypass Entries',
                              (analyticsData!['last_hour']['bypass_entries'] ?? 0).toString(),
                            ),
                          ],
                        ),
                        Icons.access_time,
                      ),
                      const SizedBox(height: 12),
                      _buildEntryTypeBreakdown(),
                      const SizedBox(height: 20),

                      // Today's Summary
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A237E),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Today\'s Summary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A237E),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Unique Visitors',
                              (analyticsData!['today_summary']['total_unique_visitors'] ?? 0).toString(),
                              Icons.person_outline,
                              Color(0xFF1A237E),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Total Entries',
                              (analyticsData!['today_summary']['total_entries'] ?? 0).toString(),
                              Icons.login,
                              Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Registrations Summary
                      _buildRegistrationsSummary(),
                      const SizedBox(height: 20),

                      // Recent Entries
                      _buildRecentEntriesSection(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, Widget content, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Color(0xFF1A237E).withOpacity(0.03),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(0xFF1A237E).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Color(0xFF1A237E), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              content,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color.fromARGB(255, 10, 128, 120),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCapacityColor(String status) {
    switch (status) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'moderate':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Widget _buildCapacityBanner() {
  //   final capacityPercentage = ((analyticsData!['crowd_status']['capacity_percentage'] ?? 0.0) as num);
  //   final capacityStatus = analyticsData!['crowd_status']['capacity_status'] ?? 'unknown';
    
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: _getCapacityColor(capacityStatus).withOpacity(0.1),
  //       borderRadius: BorderRadius.circular(12),
  //       border: Border.all(
  //         color: _getCapacityColor(capacityStatus),
  //         width: 2,
  //       ),
  //     ),
  //     child: Row(
  //       children: [
  //         Icon(
  //           capacityStatus == 'critical' 
  //               ? Icons.warning_amber_rounded 
  //               : Icons.info_outline,
  //           color: _getCapacityColor(capacityStatus),
  //           size: 32,
  //         ),
  //         const SizedBox(width: 16),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 'Capacity: ${capacityPercentage.toStringAsFixed(1)}%',
  //                 style: TextStyle(
  //                   fontSize: 18,
  //                   fontWeight: FontWeight.bold,
  //                   color: _getCapacityColor(capacityStatus),
  //                 ),
  //               ),
  //               Text(
  //                 'Status: ${capacityStatus.toUpperCase()}',
  //                 style: TextStyle(
  //                   fontSize: 14,
  //                   color: _getCapacityColor(capacityStatus),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildEntryTypeBreakdown() {
    final entryTypes = analyticsData!['entry_type_breakdown'] as List;
    
    if (entryTypes.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return _buildAnalyticsCard(
      'Entry Type Breakdown',
      Column(
        children: entryTypes.map((type) {
          final percentage = ((type['percentage'] ?? 0) as num) / 100.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (type['entry_type'] ?? '').toString().replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getEntryTypeColor(type['entry_type'] ?? ''),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      (type['count'] ?? 0).toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    Text(
                      '${((type['percentage'] ?? 0) as num).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
      Icons.category,
    );
  }

  Color _getEntryTypeColor(String type) {
    switch (type) {
      case 'qr_code_scan':
        return Colors.green;
      case 'bypass':
        return Colors.orange;
      case 'manual':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(timestamp);
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildRegistrationsSummary() {
    final regSummary = analyticsData!['registrations_summary'];
    final attendanceRate = regSummary['attendance_rate_pct'] ?? 0.0;
    
    return _buildAnalyticsCard(
      'Registrations Summary',
      Column(
        children: [
          _buildStatRow(
            'Total Registered',
            (regSummary['total_registered'] ?? 0).toString(),
          ),
          _buildStatRow(
            'Registered Members',
            (regSummary['total_registered_members'] ?? 0).toString(),
          ),
          _buildStatRow(
            'Individuals',
            (regSummary['total_reg_individuals'] ?? 0).toString(),
          ),
          _buildStatRow(
            'Groups',
            (regSummary['total_reg_groups'] ?? 0).toString(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Attendance Rate',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A237E),
                  ),
                ),
                Text(
                  '${attendanceRate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      Icons.people_outline,
    );
  }

  Widget _buildRecentEntriesSection() {
    final recentEntries = analyticsData!['recent_entries'] as List;
    
    if (recentEntries.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Entries',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 12),
        ...recentEntries.map((entry) {
          final isInside = entry['departure_time'] == null;
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isInside 
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                child: Icon(
                  entry['is_group'] ? Icons.groups : Icons.person,
                  color: isInside ? Colors.green : Colors.grey,
                ),
              ),
              title: Text(
                entry['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A237E),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry['entry_type'].toString().replaceAll('_', ' ').toUpperCase()}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (entry['is_group'])
                    Text(
                      '${entry['group_count']} members',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isInside 
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isInside ? 'Inside' : 'Exited',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isInside ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(entry['arrival_time']),
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}
