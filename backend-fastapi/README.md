# Abhaydhir Backend API Documentation

Complete API documentation for the Abhaydhir FastAPI backend system.

---

## Table of Contents

1. [Event Routes](#event-routes)
2. [Tourist Routes](#tourist-routes)
3. [User Routes](#user-routes)
4. [Entry Routes](#entry-routes)
5. [Feedback Routes](#feedback-routes)
6. [SMS Routes](#sms-routes)
7. [Analytics Routes](#analytics-routes)

---

## Event Routes

**Base URL:** `/event`

### Create Event (Admin Only)
- **Endpoint:** `POST /event/register`
- **Authentication:** Required (JWT - Admin only)
- **Description:** Register a new event
- **Request Body:**
  ```json
  {
    "event_name": "string",
    "event_date": "date",
    "location": "string",
    "is_active": boolean
  }
  ```
- **Response:** `201 Created` - Event created successfully

### Get All Events (Admin Only)
- **Endpoint:** `GET /event/`
- **Authentication:** Required (JWT - Admin only)
- **Description:** Retrieve all events
- **Response:** `200 OK` - List of all events

### Get Active Events (Admin & Security)
- **Endpoint:** `GET /event/public/active`
- **Authentication:** Required (JWT - Admin/Security)
- **Description:** Get all active events for public registration
- **Response:** `200 OK` - List of active events

### Get Single Event (Admin & Security)
- **Endpoint:** `GET /event/{event_id}`
- **Authentication:** Required (JWT - Admin/Security)
- **Description:** Retrieve a specific event by ID
- **Response:** `200 OK` - Event details

### Update Event Guards (Admin Only)
- **Endpoint:** `PUT /event/{event_id}/guards`
- **Authentication:** Required (JWT - Admin only)
- **Description:** Update allowed security guards for an event
- **Response:** `200 OK` - Guards updated

### Update Event Status (Admin Only)
- **Endpoint:** `PUT /event/status`
- **Authentication:** Required (JWT - Admin only)
- **Description:** Update event active/inactive status
- **Response:** `200 OK` - Status updated

### Check Event Status (Public Access) ⭐
- **Endpoint:** `GET /event/check/{event_id}`
- **Authentication:** Not required
- **Description:** Anyone can check if an event exists and is active
- **Response:** `200 OK`
  ```json
  {
    "event": {
      "event_id": 1,
      "event_name": "string",
      "is_active": true,
      ...
    }
  }
  ```

---

## Tourist Routes

**Base URL:** `/tourists`

### Register Tourist
- **Endpoint:** `POST /tourists/register`
- **Authentication:** Not required
- **Description:** Register a new tourist
- **Request Body:**
  ```json
  {
    "name": "string",
    "email": "string",
    "phone": "string",
    "group_count": integer
  }
  ```
- **Response:** `201 Created` - Tourist registered

### Get All Tourists (Admin & Security)
- **Endpoint:** `GET /tourists/`
- **Authentication:** Required (JWT)
- **Description:** Retrieve all tourists
- **Response:** `200 OK` - List of tourists

### Get Tourists by Event
- **Endpoint:** `GET /tourists/event/{event_id}`
- **Authentication:** Required (JWT)
- **Description:** Get all tourists registered for an event
- **Response:** `200 OK` - List of tourists

### Get Single Tourist
- **Endpoint:** `GET /tourists/{user_id}`
- **Authentication:** Not required
- **Description:** Retrieve tourist details by ID
- **Response:** `200 OK` - Tourist details

### Get Tourist Profile Image (Public Access)
- **Endpoint:** `GET /tourists/user-image/{token}`
- **Authentication:** Not required
- **Description:** Download tourist profile image with signed URL
- **Response:** `200 OK` - Image file

### Get Image Token
- **Endpoint:** `GET /tourists/{user_id}/image-token`
- **Authentication:** Not required
- **Description:** Generate signed URL token for tourist image
- **Response:** `200 OK`
  ```json
  {
    "image_url": "string",
    "token": "string"
  }
  ```

### Get Visitor Card (Public Access)
- **Endpoint:** `GET /tourists/visitor-card/{token}`
- **Authentication:** Not required
- **Description:** Display visitor card for an event with HTML template
- **Response:** `200 OK` - HTML visitor card page

### Download Visitor Card (Public Access)
- **Endpoint:** `GET /tourists/download-visitor-card/{token}`
- **Authentication:** Not required
- **Description:** Download visitor card as image
- **Response:** `200 OK` - PNG/Image file

### Get Event Entry Date Range
- **Endpoint:** `GET /tourists/event/{event_id}/entry-date-range`
- **Authentication:** Not required
- **Description:** Get date range when entries were made for an event
- **Response:** `200 OK`
  ```json
  {
    "event_id": 1,
    "first_entry": "date",
    "last_entry": "date"
  }
  ```

### Download Event Entries (Bulk Export)
- **Endpoint:** `GET /tourists/event/{event_id}/download-entries`
- **Authentication:** Not required
- **Description:** Download all entries for an event as CSV/JSON
- **Response:** `200 OK` - File download

---

## User Routes

**Base URL:** `/users`

### Register User (Admin Only)
- **Endpoint:** `POST /users/register`
- **Authentication:** Required (JWT - Admin only)
- **Description:** Create a new user (admin, security, tourist)
- **Request Body:**
  ```json
  {
    "email": "string",
    "password": "string",
    "name": "string"
  }
  ```
- **Response:** `201 Created` - User registered

### List All Users (Admin Only)
- **Endpoint:** `GET /users/list`
- **Authentication:** Required (JWT - Admin only)
- **Description:** Retrieve all users with their roles
- **Response:** `200 OK` - List of users

### Delete User (Admin Only)
- **Endpoint:** `DELETE /users/delete/{user_id}`
- **Authentication:** Required (JWT - Admin only)
- **Description:** Delete a user
- **Response:** `200 OK` - User deleted

---

## Entry Routes

**Base URL:** `/entry`

### Create Entry/Arrival (Admin & Security)
- **Endpoint:** `POST /entry/`
- **Authentication:** Required (JWT - Admin/Security)
- **Description:** Register tourist arrival at event
- **Request Body:**
  ```json
  {
    "user_id": integer,
    "event_id": integer,
    "entry_type": "normal | bypass | manual",
    "bypass_reason": "string (optional)",
    "metadata": "object (optional)"
  }
  ```
- **Response:** `201 Created` - Entry created

### Create Departure
- **Endpoint:** `POST /entry/departure`
- **Authentication:** Required (JWT - Admin/Security)
- **Description:** Register tourist departure from event
- **Request Body:**
  ```json
  {
    "user_id": integer,
    "event_id": integer
  }
  ```
- **Response:** `200 OK` - Departure recorded

### Get Today's Entries
- **Endpoint:** `GET /entry/today/{user_id}/{event_id}`
- **Authentication:** Not required
- **Description:** Get entry/departure times for today
- **Response:** `200 OK` - Today's entry data

### Get Entry History
- **Endpoint:** `GET /entry/history/{user_id}/{event_id}`
- **Authentication:** Not required
- **Description:** Get complete entry/departure history
- **Response:** `200 OK` - Entry history

---

## Feedback Routes

**Base URL:** `/feedback`

### Create Session
- **Endpoint:** `POST /feedback/session`
- **Authentication:** Not required
- **Description:** Generate anonymous session ID for feedback
- **Response:** `200 OK`
  ```json
  {
    "session_id": "uuid-string",
    "message": "Session created successfully"
  }
  ```

### Submit Anonymous Feedback ⭐
- **Endpoint:** `POST /feedback/anonymous/submit`
- **Authentication:** Not required
- **Description:** Submit anonymous feedback for an event
- **Spam Prevention:**
  - Max 3 submissions per hour per IP
  - Browser fingerprint tracking required
  - 24-hour cooldown per device per event
  - 5-minute multi-submission detection
- **Request Body:**
  ```json
  {
    "event_id": integer,
    "rating": 1-5,
    "comment": "string (optional, max 1000 chars)",
    "fingerprint": "string (required)",
    "metadata": "object (optional)",
    "session_id": "uuid (optional)"
  }
  ```
- **Response:** `201 Created`
  ```json
  {
    "success": true,
    "message": "Thank you! Your feedback has been submitted successfully",
    "feedback_id": integer,
    "session_id": "uuid"
  }
  ```
- **Error Responses:**
  - `400 Bad Request` - Missing fingerprint
  - `404 Not Found` - Event doesn't exist
  - `409 Conflict` - Duplicate submission or rate limit exceeded
  - `429 Too Many Requests` - Too many submissions

### Get Event Feedback Statistics
- **Endpoint:** `GET /feedback/event/{event_id}/stats`
- **Authentication:** Not required
- **Description:** Get anonymous feedback statistics for an event
- **Response:** `200 OK`
  ```json
  {
    "event_id": 1,
    "total_feedback": integer,
    "average_rating": float,
    "rating_distribution": {
      "1": integer,
      "2": integer,
      "3": integer,
      "4": integer,
      "5": integer
    }
  }
  ```

---

## SMS Routes

**Base URL:** `/sms`

### View Visitor Card (HTML Template)
- **Endpoint:** `GET /sms/view-card`
- **Authentication:** Not required
- **Parameters:**
  - `token`: Public access token
  - `visitor_id`: Visitor identifier
- **Description:** Display visitor card in browser
- **Response:** `200 OK` - HTML page

### Download Visitor Card
- **Endpoint:** `GET /sms/download-card`
- **Authentication:** Not required
- **Parameters:**
  - `token`: Public access token
- **Description:** Download visitor card image
- **Response:** `200 OK` - Image file

### Send Greeting SMS
- **Endpoint:** `POST /sms/send-greeting`
- **Authentication:** Not required
- **Description:** Send SMS greeting to visitor
- **Request Body:**
  ```json
  {
    "phone": "string",
    "message": "string",
    "visitor_id": integer
  }
  ```
- **Response:** `200 OK` - SMS sent

---

## Analytics Routes

**Base URL:** `/analytics`

### Get Event Security Analytics
- **Endpoint:** `GET /analytics/event/{event_id}/security-analytics`
- **Authentication:** Required (JWT)
- **Description:** Get detailed security and attendance analytics
- **Response:** `200 OK` - Analytics data
  - Total entries/exits
  - Peak traffic times
  - Security alerts
  - Breach attempts

### Get Live Feed
- **Endpoint:** `GET /analytics/event/{event_id}/live-feed`
- **Authentication:** Required (JWT)
- **Description:** Get real-time entry/exit feed
- **Response:** `200 OK` - Live event data

### Get Security Alerts
- **Endpoint:** `GET /analytics/event/{event_id}/security-alerts`
- **Authentication:** Required (JWT)
- **Description:** Get security alerts and anomalies
- **Response:** `200 OK` - Alerts list

---

## Authentication

### JWT Token
- **Header:** `Authorization: Bearer {token}`
- **Issuer:** Supabase Auth
- **User Claims:**
  - `sub`: User ID
  - `email`: User email
  - `role`: User role (admin, security, tourist)

### Roles

1. **Admin** - Full system access
2. **Security** - Event management & entry control
3. **Tourist** - Limited to own data

---

## Error Responses

### Standard Error Format
```json
{
  "detail": "Error message"
}
```

### Status Codes
- `200 OK` - Successful request
- `201 Created` - Resource created
- `400 Bad Request` - Invalid input
- `403 Forbidden` - Access denied
- `404 Not Found` - Resource not found
- `409 Conflict` - Duplicate/conflict
- `429 Too Many Requests` - Rate limit exceeded
- `500 Internal Server Error` - Server error

---

## Environment Variables

```env
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
LEGACY_JWT_SECRET=your_jwt_secret
```

---

## Notes

- All timestamps are in UTC/ISO format
- Pagination not yet implemented
- Rate limiting uses in-memory store (upgrade to Redis for production)
- Public endpoints don't require authentication
- Feedback collection is completely anonymous with spam protection

---

**Last Updated:** February 18, 2026
