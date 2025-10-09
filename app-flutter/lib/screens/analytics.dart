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
      
      if (data != null && data['success'] == true) {
        setState(() {
          analyticsData = data['analytics'];
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFFCCCB),
                Color(0xFFFFCCCB).withOpacity(0.6),
                Color(0xFFF5F5F5).withOpacity(0.1)
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Analytics',
              style: TextStyle(
                color: Color(0xFF1A237E),
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1A237E)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                width: double.infinity,
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFCCCB),
                      Color(0xFFFFCCCB).withOpacity(0.6),
                      Color(0xFFF5F5F5).withOpacity(0.1)
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),
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
                    Text(
                      errorMessage!,
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: loadAnalytics,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                      ),
                      child: const Text('Retry', style: TextStyle(color: Colors.white)),
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
                            _buildStatRow('Event', analyticsData!['event']['name']),
                            _buildStatRow('Location', analyticsData!['event']['location']),
                            _buildStatRow('Date', _formatDate(analyticsData!['event']['date'])),
                            _buildStatRow('Max Capacity', analyticsData!['event']['max_capacity']?.toString() ?? 'N/A'),
                          ],
                        ),
                        Icons.event,
                      ),
                      const SizedBox(height: 16),

                      // Crowd Status Cards
                      Text(
                        'Current Crowd Status',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Currently Inside',
                              analyticsData!['crowd_status']['currently_inside'].toString(),
                              Icons.people,
                              _getCapacityColor(analyticsData!['crowd_status']['capacity_status']),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Total People',
                              analyticsData!['crowd_status']['total_people_inside'].toString(),
                              Icons.groups,
                              _getCapacityColor(analyticsData!['crowd_status']['capacity_status']),
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
                              analyticsData!['crowd_status']['groups_inside'].toString(),
                              Icons.group,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Individuals',
                              analyticsData!['crowd_status']['individuals_inside'].toString(),
                              Icons.person,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Capacity Status Banner
                      _buildCapacityBanner(),
                      const SizedBox(height: 16),

                      // Last Hour Statistics
                      Text(
                        'Last Hour Statistics',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildAnalyticsCard(
                        'Entry Activity',
                        Column(
                          children: [
                            _buildStatRow(
                              'Total Entries',
                              analyticsData!['last_hour']['entries'].toString(),
                            ),
                            _buildStatRow(
                              'Unique Visitors',
                              analyticsData!['last_hour']['unique_visitors'].toString(),
                            ),
                            _buildStatRow(
                              'Entry Rate',
                              '${analyticsData!['last_hour']['entry_rate_per_minute'].toStringAsFixed(1)}/min',
                            ),
                            _buildStatRow(
                              'Avg Processing Time',
                              '${analyticsData!['last_hour']['avg_processing_time_seconds'].toStringAsFixed(1)}s',
                            ),
                          ],
                        ),
                        Icons.access_time,
                      ),
                      const SizedBox(height: 12),
                      _buildEntryTypeBreakdown(),
                      const SizedBox(height: 16),

                      // Today's Summary
                      Text(
                        'Today\'s Summary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Unique Visitors',
                              analyticsData!['today_summary']['total_unique_visitors'].toString(),
                              Icons.person_outline,
                              Color(0xFF1A237E),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Total Entries',
                              analyticsData!['today_summary']['total_entries'].toString(),
                              Icons.login,
                              Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Exited',
                              analyticsData!['today_summary']['exited_visitors'].toString(),
                              Icons.logout,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Avg Duration',
                              '${analyticsData!['today_summary']['avg_visit_duration_minutes'].toStringAsFixed(0)}m',
                              Icons.timer,
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Hourly Distribution
                      _buildAnalyticsCard(
                        'Hourly Distribution',
                        _buildHourlyChart(),
                        Icons.timeline,
                      ),
                      const SizedBox(height: 16),

                      // Peak Hour Info
                      if (analyticsData!['peak_hour'] != null) ...[
                        _buildAnalyticsCard(
                          'Peak Hour',
                          Column(
                            children: [
                              Text(
                                '${analyticsData!['peak_hour']['hour']}:00',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A237E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildStatRow(
                                'Entries',
                                analyticsData!['peak_hour']['entries'].toString(),
                              ),
                              _buildStatRow(
                                'Unique Visitors',
                                analyticsData!['peak_hour']['unique_visitors'].toString(),
                              ),
                            ],
                          ),
                          Icons.trending_up,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Scanning Performance
                      // _buildAnalyticsCard(
                      //   'Scanning Performance',
                      //   Column(
                      //     children: [
                      //       _buildStatRow(
                      //         'Average Scan Time',
                      //         '${analyticsData!['scanning_performance']['avg_scan_time_seconds'].toStringAsFixed(2)}s',
                      //       ),
                      //       _buildStatRow(
                      //         'Min Scan Time',
                      //         '${analyticsData!['scanning_performance']['min_scan_time_seconds'].toStringAsFixed(2)}s',
                      //       ),
                      //       _buildStatRow(
                      //         'Max Scan Time',
                      //         '${analyticsData!['scanning_performance']['max_scan_time_seconds'].toStringAsFixed(2)}s',
                      //       ),
                      //       _buildStatRow(
                      //         'Median Scan Time',
                      //         '${analyticsData!['scanning_performance']['median_scan_time_seconds'].toStringAsFixed(2)}s',
                      //       ),
                      //     ],
                      //   ),
                      //   Icons.qr_code_scanner,
                      // ),
                      // const SizedBox(height: 16),

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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, Widget content, IconData icon) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Color(0xFF1A237E)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
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

  Widget _buildCapacityBanner() {
    final capacityPercentage = analyticsData!['crowd_status']['capacity_percentage'];
    final capacityStatus = analyticsData!['crowd_status']['capacity_status'];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getCapacityColor(capacityStatus).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getCapacityColor(capacityStatus),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            capacityStatus == 'critical' 
                ? Icons.warning_amber_rounded 
                : Icons.info_outline,
            color: _getCapacityColor(capacityStatus),
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Capacity: ${capacityPercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getCapacityColor(capacityStatus),
                  ),
                ),
                Text(
                  'Status: ${capacityStatus.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 14,
                    color: _getCapacityColor(capacityStatus),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryTypeBreakdown() {
    final entryTypes = analyticsData!['entry_types'] as List;
    
    if (entryTypes.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return _buildAnalyticsCard(
      'Entry Type Breakdown',
      Column(
        children: entryTypes.map((type) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type['entry_type'].toString().toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: type['percentage'] / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getEntryTypeColor(type['entry_type']),
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
                      type['count'].toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    Text(
                      '${type['percentage'].toStringAsFixed(1)}%',
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
      case 'normal':
        return Colors.green;
      case 'bypass':
        return Colors.orange;
      case 'manual':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildHourlyChart() {
    final hourlyData = analyticsData!['hourly_distribution'] as List;
    
    if (hourlyData.isEmpty) {
      return const Text('No hourly data available');
    }
    
    final maxEntries = hourlyData.fold<num>(
      0,
      (max, item) => item['entries'] > max ? item['entries'] : max,
    );
    
    return Column(
      children: hourlyData.map<Widget>((hourData) {
        final hour = hourData['hour'].toString().padLeft(2, '0');
        final entries = hourData['entries'] as num;
        final percentage = maxEntries > 0 ? entries / maxEntries : 0;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  '$hour:00',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A237E),
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage.toDouble(),
                      child: Container(
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 10, 128, 120),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          entries.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
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
                    '${entry['unique_id_type'].toString().toUpperCase()} • ${entry['entry_type'].toString().toUpperCase()}',
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
