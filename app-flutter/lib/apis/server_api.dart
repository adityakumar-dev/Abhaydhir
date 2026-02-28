import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger/web.dart';
import 'package:spring_admin/utils/constants/server_endpoints.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServerApi {
  static Logger logger = Logger(
    printer: PrettyPrinter(methodCount: 0),
  );

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Get JWT token from Supabase session
  static Future<String?> _getAuthToken() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      return session?.accessToken;
    } catch (e) {
      debugPrint('Error getting auth token: $e');
      return null;
    }
  }

  /// Build headers with authentication
  static Future<Map<String, String>> _buildHeaders({
    bool requiresAuth = true,
    String? apiKey,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true'
    };

    if (requiresAuth) {
      final token = await _getAuthToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final client = Supabase.instance.client;
    logger.i('Supabase client initialized: ${client.auth.currentUser != null}');
    logger.i('Current user: ${client.auth.currentUser?.email}');
    logger.i('Current session valid: ${client.auth.currentSession != null}');

    if (apiKey != null) {
      headers['x-api-key'] = 'Bearer $apiKey';
    }
    logger.i('Headers: $headers');

    return headers;
  }

  /// Handle API errors
  static void _handleError(String operation, dynamic error) {
    debugPrint('Error in $operation: $error');
  }

  // ============================================================
  // EVENT APIS
  // ============================================================

  /// Get all active events (Public - no auth required)
  static Future<List<dynamic>?> getActiveEvents() async {
    try {

      final headers = await _buildHeaders(requiresAuth: true);
      logger.i('Headers in getActiveEvents: $headers');
      final response = await http.get(
        Uri.parse(ServerEndpoints.getActiveEvents()),
        headers: headers,
      );


      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['events'] as List<dynamic>;
      } else {
        logger.e("Response Header was : ${response.headers}");
        logger.e("request header was : $headers");
        logger.e('Error response in getActiveEvents: ${response.body}');
        _handleError('getActiveEvents', response.body);
        return null;
      }
    } catch (e) {
      _handleError('getActiveEvents', e);
      return null;
    }
  }

  /// Get active event by ID (Public - no auth required)
  static Future<Map<String, dynamic>?> getActiveEventById(int eventId) async {
    try {
      final response = await http.get(
        Uri.parse(ServerEndpoints.getActiveEventById(eventId)),
        headers: await _buildHeaders(requiresAuth: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['event'] as Map<String, dynamic>;
      } else {
        _handleError('getActiveEventById', response.body);
        return null;
      }
    } catch (e) {
      _handleError('getActiveEventById', e);
      return null;
    }
  }

  /// Get all events (Admin only)
  static Future<List<dynamic>?> getAllEvents() async {
    try {
      final response = await http.get(
        Uri.parse(ServerEndpoints.getAllEvents()),
        headers: await _buildHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['events'] as List<dynamic>;
      } else {
        _handleError('getAllEvents', response.body);
        return null;
      }
    } catch (e) {
      _handleError('getAllEvents', e);
      return null;
    }
  }

  /// Create new event (Admin only)
  static Future<Map<String, dynamic>?> createEvent({
    required String name,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    List<String>? eventEntries,
    Map<String, dynamic>? entryRules,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final body = {
        'name': name,
        'description': description,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'event_entries': eventEntries ?? ['main_gate'],
        'entry_rules': entryRules ?? {},
        'metadata': metadata ?? {},
        'is_active': true,
      };

      final response = await http.post(
        Uri.parse(ServerEndpoints.createEvent()),
        headers: await _buildHeaders(),
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        _handleError('createEvent', response.body);
        return null;
      }
    } catch (e) {
      _handleError('createEvent', e);
      return null;
    }
  }

  /// Update event status (Admin only)
  static Future<bool> updateEventStatus(int eventId, bool isActive) async {
    try {
      final response = await http.put(
        Uri.parse(ServerEndpoints.updateEventStatus(eventId, isActive)),
        headers: await _buildHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      _handleError('updateEventStatus', e);
      return false;
    }
  }

  // ============================================================
  // TOURIST APIS
  // ============================================================

  /// Register tourist (Public - no auth required)
  static Future<Map<String, dynamic>?> registerTourist({
    required String name,
    required String phone,
    required bool isGroup,
    required int groupCount,
    required int registeredEventId,
    required String validDate,
    File? imageFile,
    File? uniqueIdPhotoFile,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ServerEndpoints.registerTourist()),
      );

      // Add form fields
      request.fields['name'] = name;
      request.fields['phone'] = phone;
      request.fields['is_group'] = isGroup.toString();
      request.fields['group_count'] = groupCount.toString();
      request.fields['registered_event_id'] = registeredEventId.toString();
      request.fields['valid_date'] = validDate;

      // Add face image (optional)
      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );
      }

      // Add unique ID photo (optional)
      if (uniqueIdPhotoFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('unique_id_photo', uniqueIdPhotoFile.path),
        );
      }

      // Send request (no auth required for tourist registration)
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        // Parse the backend error detail and throw so caller can display it
        String errorMsg = 'Registration failed';
        try {
          final body = json.decode(response.body);
          if (body is Map) {
            errorMsg = body['detail']?.toString() ??
                body['message']?.toString() ??
                errorMsg;
          }
        } catch (_) {}
        _handleError('registerTourist', response.body);
        throw Exception(errorMsg);
      }
    } catch (e) {
      _handleError('registerTourist', e);
      rethrow;
    }
  }

  /// Get all tourists (Admin only)
  static Future<Map<String, dynamic>?> getAllTourists({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(ServerEndpoints.getAllTourists(limit: limit, offset: offset)),
        headers: await _buildHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        _handleError('getAllTourists', response.body);
        return null;
      }
    } catch (e) {
      _handleError('getAllTourists', e);
      return null;
    }
  }

  /// Get tourists by event (Admin/Security)
  static Future<Map<String, dynamic>?> getTouristsByEvent(
    int eventId, {
    String? date,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(ServerEndpoints.getTouristsByEvent(
          eventId,
          date: date,
          limit: limit,
          offset: offset,
        )),
        headers: await _buildHeaders(),
      );

  logger.i('Response status: ${response.statusCode}');
  logger.i('Response body: ${jsonDecode(response.body)}');
  // logger.i("Response ")

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        _handleError('getTouristsByEvent', response.body);
        return null;
      }
    } catch (e) {
      _handleError('getTouristsByEvent', e);
      return null;
    }
  }

  /// Get tourist by ID (Admin/Security)
  static Future<Map<String, dynamic>?> getTouristById(int userId) async {
    try {
      final response = await http.get(
        Uri.parse(ServerEndpoints.getTouristById(userId)),
        headers: await _buildHeaders(),
      );

  logger.i('Response status: ${response.statusCode}');
  logger.i('Response body: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        logger.i("${data['tourist']}"); // Log the tourist data
        return data['tourist'] as Map<String, dynamic>;
      } else {
        _handleError('getTouristById', response.body);
        return null;
      }
    } catch (e) {
      _handleError('getTouristById', e);
      return null;
    }
  }

  /// Get visitor card URL from JWT token
  static String getVisitorCardUrl(String jwtToken) {
    return ServerEndpoints.getVisitorCard(jwtToken);
  }

  /// Get visitor card download URL from JWT token
  static String getVisitorCardDownloadUrl(String jwtToken) {
    return ServerEndpoints.downloadVisitorCard(jwtToken);
  }

  /// Get entry date range for an event (Admin/Security)
  static Future<Map<String, dynamic>?> getEventEntryDateRange(int eventId) async {
    try {
      final headers = await _buildHeaders();
      final response = await http.get(
        Uri.parse(ServerEndpoints.getEventEntryDateRange(eventId)),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        _handleError('getEventEntryDateRange', response.body);
        return null;
      }
    } catch (e) {
      _handleError('getEventEntryDateRange', e);
      return null;
    }
  }

  /// Get URL for downloading event entries CSV
  static String getDownloadEventEntriesUrl(int eventId, String fromDate, String toDate) {
    return ServerEndpoints.downloadEventEntries(eventId, fromDate, toDate);
  }

  // ============================================================
  // USER MANAGEMENT APIS
  // ============================================================

  /// Register user with admin/security key (Protected)
  static Future<Map<String, dynamic>?> registerUser({
    required String email,
    required String password,
    required String name,
    required String apiKey, // 'admin' or 'security'
  }) async {
    try {
      final body = {
        'email': email,
        'password': password,
        'name': name,
      };

      final response = await http.post(
        Uri.parse(ServerEndpoints.registerUser()),
        headers: await _buildHeaders(requiresAuth: false, apiKey: apiKey),
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        _handleError('registerUser', response.body);
        return null;
      }
    } catch (e) {
      _handleError('registerUser', e);
      return null;
    }
  }

  /// List all users (Admin only)
  static Future<List<dynamic>?> listUsers() async {
    try {
      final response = await http.get(
        Uri.parse(ServerEndpoints.listUsers()),
        headers: await _buildHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['users'] as List<dynamic>;
      } else {
        _handleError('listUsers', response.body);
        return null;
      }
    } catch (e) {
      _handleError('listUsers', e);
      return null;
    }
  }

  /// Delete user (Admin only)
  static Future<bool> deleteUser(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse(ServerEndpoints.deleteUser(userId)),
        headers: await _buildHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      _handleError('deleteUser', e);
      return false;
    }
  }

  // ============================================================
  // ENTRY MANAGEMENT APIS
  // ============================================================

  /// Create entry (Admin/Security)
  static Future<Map<String, dynamic>?> createEntry({
    required int userId,
    required int eventId,
    String entryType = 'normal',
    String? bypassReason,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final body = {
        'user_id': userId,
        'event_id': eventId,
        'entry_type': entryType,
        if (bypassReason != null) 'bypass_reason': bypassReason,
        if (metadata != null) 'metadata': metadata,
      };

      final response = await http.post(
        Uri.parse(ServerEndpoints.createEntry()),
        headers: await _buildHeaders(),
        body: json.encode(body),
      );


      if (response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        String errorMsg = 'Entry failed';
        try {
          final body = json.decode(response.body);
          if (body is Map) {
            errorMsg = body['detail']?.toString() ??
                body['message']?.toString() ??
                errorMsg;
          }
        } catch (_) {}
        _handleError('createEntry', response.body);
        throw Exception(errorMsg);
      }
    } catch (e) {
      _handleError('createEntry', e);
      rethrow;
    }
  }

  /// Create entry using short code (QR Code text value)
  static Future<Map<String, dynamic>?> createEntryWithCode({
    required String shortCode,
    required int eventId,
  }) async {
    try {
      final body = {
        'short_code': shortCode,
        'event_id': eventId,
      };

      final response = await http.post(
        Uri.parse(ServerEndpoints.createEntry()),
        headers: await _buildHeaders(),
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        String errorMsg = 'Entry failed';
        try {
          final body = json.decode(response.body);
          if (body is Map) {
            errorMsg = body['detail']?.toString() ?? body['message']?.toString() ?? errorMsg;
          }
        } catch (_) {}
        _handleError('createEntryWithCode', response.body);
        throw Exception(errorMsg);
      }
    } catch (e) {
      _handleError('createEntryWithCode', e);
      rethrow;
    }
  }

  /// Register departure (Admin/Security)
  static Future<Map<String, dynamic>?> registerDeparture({
    required int userId,
    required int eventId,
    String? entryPoint,
  }) async {
    try {
      final body = {
        'user_id': userId,
        'event_id': eventId,
        if (entryPoint != null) 'entry_point': entryPoint,
      };

      final response = await http.post(
        Uri.parse(ServerEndpoints.registerDeparture()),
        headers: await _buildHeaders(),
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        _handleError('registerDeparture', response.body);
        return null;
      }
    } catch (e) {
      _handleError('registerDeparture', e);
      return null;
    }
  }

  /// Get entry status (Admin/Security)
  // static Future<Map<String, dynamic>?> getEntryStatus(
  //   int userId,
  //   int eventId,
  // ) async {
  //   try {
  //     final response = await http.get(
  //       Uri.parse(ServerEndpoints.getEntryStatus(userId, eventId)),
  //       headers: await _buildHeaders(),
  //     );

  //     if (response.statusCode == 200) {
  //       return json.decode(response.body) as Map<String, dynamic>;
  //     } else {
  //       _handleError('getEntryStatus', response.body);
  //       return null;
  //     }
  //   } catch (e) {
  //     _handleError('getEntryStatus', e);
  //     return null;
  //   }
  // }

  /// Get entry history (Admin/Security)
  static Future<Map<String, dynamic>?> getEntryHistory(
    int userId, {
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(ServerEndpoints.getEntryHistory(
          userId,
           limit,
           offset,
        )),
        headers: await _buildHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        _handleError('getEntryHistory', response.body);
        return null;
      }
    } catch (e) {
      _handleError('getEntryHistory', e);
      return null;
    }
  }

  // ============================================================
  // AUTHENTICATION HELPERS
  // ============================================================

  /// Get current user from Supabase
  static User? getCurrentUser() {
    return Supabase.instance.client.auth.currentUser;
  }

  /// Get current session from Supabase
  static Session? getCurrentSession() {
    return Supabase.instance.client.auth.currentSession;
  }

  // ============================================================
  // ANALYTICS API
  // ============================================================
  // COMPREHENSIVE ANALYTICS
  // ============================================================

  /// Get comprehensive event analytics in a single RPC call
  /// Returns: event_info, crowd_status, today_summary, last_hour, entry_type_breakdown,
  /// hourly_distribution, recent_entries, alerts, registrations_summary
  static Future<Map<String, dynamic>?> getEventAnalytics(int eventId, {String? queryDate}) async {
    try {
      debugPrint('━━━ Fetching comprehensive analytics for event: $eventId ━━━');
      
      final headers = await _buildHeaders(requiresAuth: true);
      
      // Build URL with optional query date
      String url = '${ServerEndpoints.baseUrl}/analytics/event/$eventId';
      if (queryDate != null && queryDate.isNotEmpty) {
        url += '?query_date=$queryDate';
      }
      
      final response = await http.get(Uri.parse(url), headers: headers);
      
      debugPrint('Analytics request status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        debugPrint('✅ Analytics data received successfully');
        debugPrint('📊 Event Info: ${data['event_info']}');
        debugPrint('👥 Crowd Status: ${data['crowd_status']}');
        debugPrint('📈 Today Summary: ${data['today_summary']}');
        debugPrint('⏰ Last Hour: ${data['last_hour']}');
        debugPrint('📋 Entry Type Breakdown: ${data['entry_type_breakdown']}');
        debugPrint('📊 Hourly Distribution: ${data['hourly_distribution']}');
        debugPrint('👤 Recent Entries: ${data['recent_entries']}');
        debugPrint('⚠️ Alerts: ${data['alerts']}');
        debugPrint('📊 Registrations Summary: ${data['registrations_summary']}');
        
        return data;
      } else {
        debugPrint('❌ Failed to fetch analytics: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      logger.e('Error fetching analytics: $e');
      debugPrint('❌ Analytics error: $e');
      _handleError('getEventAnalytics', e);
      return null;
    }
  }

  /// Get live entry feed for security monitoring
  static Future<Map<String, dynamic>?> getLiveEntryFeed(
    int eventId, {
    int limit = 20,
  }) async {
    try {
      debugPrint('Fetching live feed for event: $eventId');
      
      final headers = await _buildHeaders(requiresAuth: true);
      final url = Uri.parse(
        '${ServerEndpoints.baseUrl}/analytics/event/$eventId/live-feed?limit=$limit'
      );
      
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Live feed data received successfully');
        return data;
      } else {
        debugPrint('Failed to fetch live feed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _handleError('getLiveEntryFeed', e);
      return null;
    }
  }

  /// Get security alerts for event
  static Future<Map<String, dynamic>?> getSecurityAlerts(int eventId) async {
    try {
      debugPrint('Fetching security alerts for event: $eventId');
      
      final headers = await _buildHeaders(requiresAuth: true);
      final url = Uri.parse(
        '${ServerEndpoints.baseUrl}/analytics/event/$eventId/security-alerts'
      );
      
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Security alerts received successfully');
        return data;
      } else {
        debugPrint('Failed to fetch security alerts: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _handleError('getSecurityAlerts', e);
      return null;
    }
  }

  /// Check if user is logged in and session is valid
  static bool isLoggedIn() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return false;
    
    // Check if session is expired
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return false;
    
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now < expiresAt;
  }

  /// Logout from Supabase
  static Future<void> logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      _handleError('logout', e);
    }
  }

  // ============================================================
  // RENEW CARD ENDPOINTS
  // ============================================================

  /// Renew card using short code
  static Future<Map<String, dynamic>> renewCard({
    required String shortCode,
    required String validDate,
  }) async {
    try {
      final url = Uri.parse('${ServerEndpoints.baseUrl}/quick/renew');
      final headers = await _buildHeaders(requiresAuth: false);
      // Remove JSON content-type header for form data encoding
      headers.remove('Content-Type');

      final formData = {
        'short_code': shortCode,
        'valid_date': validDate,
      };

      logger.i('Renewing card with short code: $shortCode, date: $validDate');

      final response = await http
          .post(url, headers: headers, body: formData)
          .timeout(const Duration(seconds: 10));

      logger.i('Renew card response status: ${response.statusCode}');
      logger.i('Renew card response: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result;
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage =
            errorBody['detail'] ?? errorBody['message'] ?? 'Failed to renew card';
        throw Exception(errorMessage);
      }
    } catch (e) {
      logger.e('Error renewing card: $e');
      _handleError('renewCard', e);
      rethrow;
    }
  }

  /// Renew card using phone number
  static Future<Map<String, dynamic>> renewCardByPhone({
    required String phone,
    required int eventId,
    required String validDate,
  }) async {
    try {
      final url = Uri.parse('${ServerEndpoints.baseUrl}/quick/renew-by-phone');
      final headers = await _buildHeaders(requiresAuth: false);
      // Remove JSON content-type header for form data encoding
      headers.remove('Content-Type');

      final formData = {
        'phone': phone,
        'registered_event_id': eventId.toString(),
        'valid_date': validDate,
      };

      logger.i('Renewing card by phone: $phone, date: $validDate');

      final response = await http
          .post(url, headers: headers, body: formData)
          .timeout(const Duration(seconds: 10));

      logger.i('Renew by phone response status: ${response.statusCode}');
      logger.i('Renew by phone response: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result;
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage =
            errorBody['detail'] ?? errorBody['message'] ?? 'Failed to renew card';
        throw Exception(errorMessage);
      }
    } catch (e) {
      logger.e('Error renewing card by phone: $e');
      _handleError('renewCardByPhone', e);
      rethrow;
    }
  }

  // ============================================================
  // TOURIST PROFILE ENDPOINTS
  // ============================================================

  /// Get complete tourist profile with today's entries and history
  static Future<Map<String, dynamic>> getTouristProfile({
    required int userId,
    int eventId = 1,
  }) async {
    try {
      final url = Uri.parse('${ServerEndpoints.baseUrl}/profile/$userId')
          .replace(queryParameters: {'event_id': eventId.toString()});
      final headers = await _buildHeaders();

      logger.i('Fetching tourist profile for user_id: $userId, event_id: $eventId');

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      logger.i('Tourist profile response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        logger.i('Tourist profile data received successfully ${result['tourist']['unique_id_path']}');
        return result;
      } else if (response.statusCode == 404) {
        throw Exception('Tourist not found');
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage =
            errorBody['detail'] ?? errorBody['message'] ?? 'Failed to fetch profile';
        throw Exception(errorMessage);
      }
    } catch (e) {
      logger.e('Error fetching tourist profile: $e');
      _handleError('getTouristProfile', e);
      rethrow;
    }
  }

  /// Get complete tourist profile by phone number
  static Future<Map<String, dynamic>> getTouristProfileByPhone({
    required String phone,
    int eventId = 1,
  }) async {
    try {
      final url = Uri.parse('${ServerEndpoints.baseUrl}/profile/phone/$phone')
          .replace(queryParameters: {'event_id': eventId.toString()});
      final headers = await _buildHeaders();

      logger.i('Fetching tourist profile by phone: $phone, event_id: $eventId');

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      logger.i('Tourist profile by phone response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result;
      } else if (response.statusCode == 404) {
        throw Exception('Tourist not found with this phone number');
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage =
            errorBody['detail'] ?? errorBody['message'] ?? 'Failed to fetch profile';
        throw Exception(errorMessage);
      }
    } catch (e) {
      logger.e('Error fetching tourist profile by phone: $e');
      _handleError('getTouristProfileByPhone', e);
      rethrow;
    }
  }

  /// Get complete tourist profile with related users (same phone number)
  static Future<Map<String, dynamic>> getTouristWithRelated({
    required int userId,
    int eventId = 1,
  }) async {
    try {
      final url = Uri.parse('${ServerEndpoints.baseUrl}/complete/$userId')
          .replace(queryParameters: {'event_id': eventId.toString()});
      final headers = await _buildHeaders();

      logger.i('Fetching complete profile with related users for user_id: $userId, event_id: $eventId');

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      logger.i('Complete profile response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result;
      } else if (response.statusCode == 404) {
        throw Exception('Tourist not found');
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage =
            errorBody['detail'] ?? errorBody['message'] ?? 'Failed to fetch profile';
        throw Exception(errorMessage);
      }
    } catch (e) {
      logger.e('Error fetching complete tourist profile: $e');
      _handleError('getTouristWithRelated', e);
      rethrow;
    }
  }

  // ============================================================
  // SHORT CODE CARD ENDPOINTS
  // ============================================================

  /// Resolve short code to get visitor card URLs and token
  static Future<Map<String, dynamic>> resolveShortCode({
    required String shortCode,
  }) async {
    try {
      final url = Uri.parse('${ServerEndpoints.baseUrl}/tourists/short/$shortCode');
      final headers = await _buildHeaders(requiresAuth: false);

      logger.i('Resolving short code: $shortCode');

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      logger.i('Resolve short code response status: ${response.statusCode}');
      logger.i('Resolve short code response: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result;
      } else if (response.statusCode == 404) {
        throw Exception('Short code not found');
      } else if (response.statusCode == 410) {
        throw Exception('Short link has expired');
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage =
            errorBody['detail'] ?? errorBody['message'] ?? 'Failed to resolve short code';
        throw Exception(errorMessage);
      }
    } catch (e) {
      logger.e('Error resolving short code: $e');
      _handleError('resolveShortCode', e);
      rethrow;
    }
  }
}
