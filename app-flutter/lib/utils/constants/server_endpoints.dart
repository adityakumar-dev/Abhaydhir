class ServerEndpoints {
  // Base URL - for testing
  // static String baseUrl = 'https://enabled-flowing-bedbug.ngrok-free.app';
  // Base URL - for production 
  static String baseUrl = 'api.vmsbutu.it.com';
  

  // ============================================================
  // EVENT ENDPOINTS
  // ============================================================
  
  // Create new event (Admin only)
  static String createEvent() => '$baseUrl/event/register';
  
  // Get all events (Admin only)
  static String getAllEvents() => '$baseUrl/event/';
  
  // Get active events (Public)
  static String getActiveEvents() => '$baseUrl/event/public/active';
  
  // Get single event by ID (Admin/Security)
  static String getEventById(int eventId) => '$baseUrl/event/$eventId';
  
  // Get active event by ID (Public)
  static String getActiveEventById(int eventId) => '$baseUrl/event/active/$eventId';
  
  // Update event status (Admin only)
  static String updateEventStatus(int eventId, bool isActive) => 
      '$baseUrl/event/status?event_id=$eventId&is_active=$isActive';
  
  // Update event guards (Admin only)
  static String updateEventGuards(int eventId) => '$baseUrl/event/$eventId/guards';

  // ============================================================
  // TOURIST ENDPOINTS
  // ============================================================
  
  // Register tourist (Public)
  static String registerTourist() => '$baseUrl/tourists/register';
  
  // Get all tourists (Admin only)
  static String getAllTourists({int limit = 20, int offset = 0}) => 
      '$baseUrl/tourists/?limit=$limit&offset=$offset';
  
  // Get tourists by event (Admin/Security)
  static String getTouristsByEvent(int eventId, {int limit = 20, int offset = 0}) => 
      '$baseUrl/tourists/event/$eventId?limit=$limit&offset=$offset';
  
  // Get single tourist by ID (Admin/Security)
  static String getTouristById(int userId) => '$baseUrl/tourists/$userId';
  
  // Get visitor card with JWT token (Public)
  static String getVisitorCard(String jwtToken) => '$baseUrl/tourists/visitor-card/$jwtToken';
  
  // Download visitor card with JWT token (Public)
  static String downloadVisitorCard(String jwtToken) => '$baseUrl/tourists/download-visitor-card/$jwtToken';
  
  // Get entry date range for event (Admin/Security)
  static String getEventEntryDateRange(int eventId) => '$baseUrl/tourists/event/$eventId/entry-date-range';
  
  // Download entry data CSV (Admin/Security)
  static String downloadEventEntries(int eventId, String fromDate, String toDate) => 
      '$baseUrl/tourists/event/$eventId/download-entries?from_date=$fromDate&to_date=$toDate';

  // ============================================================
  // USER MANAGEMENT ENDPOINTS
  // ============================================================
  
  // Register user with admin/security key (Protected)
  static String registerUser() => '$baseUrl/users/register';
  
  // List all users (Admin only)
  static String listUsers() => '$baseUrl/users/list';
  
  // Delete user (Admin only)
  static String deleteUser(String userId) => '$baseUrl/users/delete/$userId';

  // ============================================================
  // ENTRY MANAGEMENT ENDPOINTS
  // ============================================================
  
  // Create entry (Admin/Security)
  static String createEntry() => '$baseUrl/entry/';
  
  // Register departure (Admin/Security)
  static String registerDeparture() => '$baseUrl/entry/departure';
  
  // Get today's entries (Admin/Security)
  static String getTodayEntries(int userId, int eventId) => 
      '$baseUrl/entry/today/$userId/$eventId';
  
  // Get entry history (Admin/Security)
  static String getEntryHistory(int userId, int eventId, int limit) => 
      '$baseUrl/entry/history/$userId/$eventId?limit=$limit';

  // ============================================================
  // HELPER METHODS
  // ============================================================
  
  // Helper method to build query parameters
  static String addQueryParams(String url, Map<String, dynamic> params) {
    if (params.isEmpty) return url;
    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
    return '$url?$queryString';
  }
}