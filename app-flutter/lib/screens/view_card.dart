import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spring_admin/apis/server_api.dart';
import 'package:spring_admin/utils/constants/server_endpoints.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewCardScreen extends StatefulWidget {
  static const String routeName = '/view-card';
  
  final String shortCode;

  const ViewCardScreen({
    Key? key,
    required this.shortCode,
  }) : super(key: key);

  @override
  State<ViewCardScreen> createState() => _ViewCardScreenState();
}

class _ViewCardScreenState extends State<ViewCardScreen> {
  late Future<Map<String, dynamic>> _cardFuture;

  @override
  void initState() {
    super.initState();
    _cardFuture = ServerApi.resolveShortCode(shortCode: widget.shortCode);
  }

  /// Prepend base URL to relative paths from card_urls
  String _buildFullUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${ServerEndpoints.baseUrl}$path';
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: Platform.isAndroid
              ? LaunchMode.externalApplication
              : LaunchMode.platformDefault,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open URL')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Short code copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF00897B), Color(0xFF26A69A)],
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'View Card',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
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
      body: Container(
        color: const Color(0xFFF5F5F5),
        child: FutureBuilder<Map<String, dynamic>>(
            future: _cardFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFF00897B),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Loading your card...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error Loading Card',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                snapshot.error
                                    .toString()
                                    .replaceFirst('Exception: ', ''),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _cardFuture = ServerApi.resolveShortCode(
                                shortCode: widget.shortCode,
                              );
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00897B),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: Text('No data available'),
                );
              }

              final data = snapshot.data!;
              // Direct fields from updated API response
              final shortCode = (data['short_code'] ?? widget.shortCode).toString();
              final guestName = (data['user_name'] ?? 'Unknown').toString();
              final guestId = (data['user_id'] ?? 'N/A').toString();
              final validDate = (data['valid_date'] ?? 'N/A').toString();
              final eventName = (data['event_name'] ?? 'N/A').toString();
              final cardUrls = data['card_urls'] as Map<String, dynamic>?;

              // Build full URLs from relative paths
              final previewUrl = cardUrls?['preview'] != null
                  ? _buildFullUrl(cardUrls!['preview'] as String)
                  : null;
              final downloadUrl = cardUrls?['download'] != null
                  ? _buildFullUrl(cardUrls!['download'] as String)
                  : null;

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Guest info card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Teal header band
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.badge_outlined,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          guestName,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          shortCode.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withValues(alpha: 0.8),
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Info rows
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              child: Column(
                                children: [
                                  _buildInfoRow('Guest ID', guestId,
                                      icon: Icons.numbers_rounded,
                                      iconColor: Colors.blueGrey),
                                  _buildInfoRow('Event', eventName,
                                      icon: Icons.event_rounded,
                                      iconColor: Colors.indigo),
                                  _buildInfoRow('Valid Till', validDate,
                                      icon: Icons.calendar_today_rounded,
                                      iconColor: Colors.green,
                                      valueColor: Colors.green[700]),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),
                      const Text(
                        'Card Actions',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (previewUrl != null) ...[                        _buildActionButton(
                          icon: Icons.visibility_rounded,
                          title: 'View Card',
                          subtitle: 'Open visitor card in browser',
                          color: Colors.blue,
                          onTap: () => _launchUrl(previewUrl),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (downloadUrl != null) ...[                        _buildActionButton(
                          icon: Icons.download_rounded,
                          title: 'Download Card',
                          subtitle: 'Save visitor card',
                          color: Colors.green,
                          onTap: () => _launchUrl(downloadUrl),
                        ),
                        const SizedBox(height: 12),
                      ],

                      _buildActionButton(
                        icon: Icons.copy_rounded,
                        title: 'Copy Short Code',
                        subtitle: 'Copy "${shortCode.toUpperCase()}" to clipboard',
                        color: Colors.purple,
                        onTap: () => _copyToClipboard(shortCode),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    IconData? icon,
    Color? iconColor,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
if (icon != null) ...[
            Icon(icon, size: 18, color: iconColor ?? Colors.grey[400]),
            const SizedBox(width: 10),
          ],
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          ],),
                    const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? const Color(0xFF1A237E),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 23),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey[300]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
