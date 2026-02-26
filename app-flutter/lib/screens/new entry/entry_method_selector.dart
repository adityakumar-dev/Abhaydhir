import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spring_admin/providers/event_provider.dart';
import 'package:spring_admin/screens/new entry/qr_code_verify.dart';
import 'package:spring_admin/screens/new entry/manual_code_entry.dart';
import 'package:spring_admin/utils/event_required_mixin.dart';

class EntryMethodSelector extends StatefulWidget {
  static const String routeName = '/entryMethodSelector';

  const EntryMethodSelector({super.key});

  @override
  State<EntryMethodSelector> createState() => _EntryMethodSelectorState();
}

class _EntryMethodSelectorState extends State<EntryMethodSelector>
    with EventRequiredMixin {
  String? _currentEventName;
  bool _isLoadingEvent = true;

  @override
  void initState() {
    super.initState();
    _loadEventInfo();
  }

  Future<void> _loadEventInfo() async {
    if (!mounted) return;
    final eventProvider = Provider.of<EventProvider>(context, listen: false);

    if (eventProvider.hasSelectedEvent) {
      setState(() {
        _currentEventName = eventProvider.selectedEventName;
        _isLoadingEvent = false;
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
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'New Entry',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            centerTitle: true,
          ),
        ),
      ),
      body: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Event Selection Banner
                          if (!_isLoadingEvent && _currentEventName != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color.fromARGB(255, 10, 128, 120),
                                    const Color.fromARGB(255, 10, 128, 120)
                                        .withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Processing entry for:',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          _currentEventName!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Title
                          const Text(
                            'Select Entry Method',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A237E),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose how to register the tourist entry',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 28),
                          // QR Code Option
                          _buildMethodCard(
                            icon: Icons.qr_code_2,
                            title: 'Scan QR Code',
                            description: 'Scan the visitor\'s QR code using camera',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const QrCodeVerifyScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          // Manual Code Entry Option
                          _buildMethodCard(
                            icon: Icons.keyboard_outlined,
                            title: 'Enter Short Code',
                            description: 'Manually enter the visitor\'s short code',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ManualCodeEntry(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildMethodCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF00897B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 28,
                color: const Color(0xFF00897B),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
