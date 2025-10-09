import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spring_admin/providers/event_provider.dart';

/// Mixin to ensure event is selected before screen loads
/// Add this to any StatefulWidget's State that requires event ID
/// 
/// Usage:
/// class _MyScreenState extends State<MyScreen> with EventRequiredMixin {
///   @override
///   Widget build(BuildContext context) {
///     // Event ID is guaranteed to be available here
///     final eventId = getEventId(context);
///     ...
///   }
/// }
mixin EventRequiredMixin<T extends StatefulWidget> on State<T> {
  bool _eventChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkEventSelection();
    });
  }

  /// Check if event is selected, show dialog if not
  void _checkEventSelection() {
    if (_eventChecked) return;
    
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    
    if (!eventProvider.hasSelectedEvent) {
      _eventChecked = true;
      _showEventRequiredDialog(eventProvider);
    } else {
      _eventChecked = true;
    }
  }

  /// Show dialog when event is required but not selected
  void _showEventRequiredDialog(EventProvider eventProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Expanded(child: Text('Event Required')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This screen requires an active event to function properly.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              if (eventProvider.events.isNotEmpty) ...[
                Text(
                  'Available Events:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 8),
                ...eventProvider.events.map((event) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.event, color: Color(0xFF0A8078), size: 20),
                    title: Text(
                      event['name'] ?? 'Unknown Event',
                      style: TextStyle(fontSize: 13),
                    ),
                    onTap: () async {
                      await eventProvider.selectEvent(
                        event['event_id'] as int,
                        event['name'] as String,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        setState(() {});
                      }
                    },
                  );
                }).toList(),
              ] else
                Text(
                  'No events available. Please contact the administrator.',
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to previous screen
              },
              child: Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  /// Get the current event ID (guaranteed to be non-null after check)
  int? getEventId(BuildContext context) {
    return Provider.of<EventProvider>(context, listen: false).selectedEventId;
  }

  /// Get the current event name
  String? getEventName(BuildContext context) {
    return Provider.of<EventProvider>(context, listen: false).selectedEventName;
  }

  /// Get the full event provider
  EventProvider getEventProvider(BuildContext context, {bool listen = false}) {
    return Provider.of<EventProvider>(context, listen: listen);
  }
}
