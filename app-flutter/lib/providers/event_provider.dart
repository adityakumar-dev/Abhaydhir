import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spring_admin/apis/server_api.dart';

/// Centralized event management provider
/// Fetches events once at startup and caches them
class EventProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _events = [];
  int? _selectedEventId;
  String? _selectedEventName;
  bool _isLoading = false;
  String? _error;
  bool _initialized = false;

  // Getters
  List<Map<String, dynamic>> get events => _events;
  int? get selectedEventId => _selectedEventId;
  String? get selectedEventName => _selectedEventName;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasSelectedEvent => _selectedEventId != null;
  bool get initialized => _initialized;

  // Constants for SharedPreferences
  static const String _eventIdKey = 'selected_event_id';
  static const String _eventNameKey = 'selected_event_name';

  /// Initialize provider - fetch events and load saved selection
  /// Call this once at app startup
  Future<void> initialize() async {
    if (_initialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Load saved event from storage
      await _loadSavedEvent();

      // Fetch active events from backend
      await fetchActiveEvents();

      _initialized = true;
    } catch (e) {
      _error = 'Failed to initialize: ${e.toString()}';
      debugPrint('EventProvider initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch active events from backend
  Future<void> fetchActiveEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await ServerApi.getActiveEvents();

      if (result != null && result.isNotEmpty) {
        _events = List<Map<String, dynamic>>.from(result);
        _error = null;

        final prefs = await SharedPreferences.getInstance();
        _selectedEventId = prefs.getInt(_eventIdKey);
        _selectedEventName = prefs.getString(_eventNameKey);
        notifyListeners();
        if (_selectedEventId != null) {

          final stillExists = _events.any(
            (e){
                ServerApi.logger.i('Checking event: ${e['event_id']} against selected: $_selectedEventId'); 
              return e['event_id'] == _selectedEventId;
          });
          if (!stillExists) {
            // Selected event no longer active
            _error = 'Previously selected event is no longer active. Please choose another event.';
            await clearSelection();
            notifyListeners();
            return; // Don't auto-select, let user choose
          }
        }
      } else {
        _events = [];
        _error = 'No active events found. Please contact the organizer.';
      }
    } catch (e) {
      _error = 'Failed to fetch events: ${e.toString()}';
      debugPrint('EventProvider fetch error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load saved event from SharedPreferences
  Future<void> _loadSavedEvent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedEventId = prefs.getInt(_eventIdKey);
      _selectedEventName = prefs.getString(_eventNameKey);
    } catch (e) {
      debugPrint('Error loading saved event: $e');
    }
  }

  /// Select an event and save to storage
  Future<void> selectEvent(int eventId, String eventName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_eventIdKey, eventId);
      await prefs.setString(_eventNameKey, eventName);

      _selectedEventId = eventId;
      _selectedEventName = eventName;
      notifyListeners();

      debugPrint('Event selected: $eventName (ID: $eventId)');
    } catch (e) {
      debugPrint('Error saving event: $e');
      throw Exception('Failed to save event selection');
    }
  }

  /// Clear event selection
  Future<void> clearSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_eventIdKey);
      await prefs.remove(_eventNameKey);

      _selectedEventId = null;
      _selectedEventName = null;
      _initialized = false;
      _error = null;
      _isLoading = false;
      _events = [];
      notifyListeners();

      debugPrint('Event selection cleared');
    } catch (e) {
      debugPrint('Error clearing event: $e');
    }
  }

  /// Get event details by ID from cached events
  Map<String, dynamic>? getEventById(int eventId) {
    try {
      return _events.firstWhere((e) => e['event_id'] == eventId);
    } catch (e) {
      return null;
    }
  }

  /// Check if event is selected
  bool isEventSelected(int eventId) {
    return _selectedEventId == eventId;
  }

  /// Resync events (refresh from backend)
  Future<void> resync() async {
    await fetchActiveEvents();
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
