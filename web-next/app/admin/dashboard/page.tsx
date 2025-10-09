"use client";
import { useState, useEffect } from "react";
import { createEvent, getAllEvents, updateEventStatus } from "@/services/eventApi";
import { getAllTourists } from "@/services/touristApi";
import { getAllUsers, deleteUser } from "@/services/usersApi";
import { useRouter } from "next/navigation";
import { useUser } from "@/context/admin_context";
import { supabase } from "@/services/adminAuth";

export default function AdminDashboard() {
  const router = useRouter();
  const { user } = useUser();
  const [activeView, setActiveView] = useState<'home' | 'events' | 'tourists' | 'users'>('home');
  const [showEventForm, setShowEventForm] = useState(false);
  const [events, setEvents] = useState<any[]>([]);
  const [tourists, setTourists] = useState<any[]>([]);
  const [users, setUsers] = useState<any[]>([]);
  const [stats, setStats] = useState({ events: 0, tourists: 0, activeEvents: 0, users: 0 });
  const [eventForm, setEventForm] = useState({
    name: "",
    description: "",
    start_date: "",
    end_date: "",
    location: "",
    max_capacity: "",
    is_active: true,
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    if (user) {
      loadStats();
    }
  }, [user]);

  const loadStats = async () => {
    try {
      const eventsData = await getAllEvents();
      const touristsData = await getAllTourists();
      const usersData = await getAllUsers();
      setStats({
        events: eventsData.events.length,
        tourists: touristsData.pagination?.total || touristsData.tourists.length,
        activeEvents: eventsData.events.filter((e: any) => e.is_active).length,
        users: usersData.users?.length || 0,
      });
    } catch (err) {
      console.error("Failed to load stats", err);
    }
  };

  const loadEvents = async () => {
    try {
      setLoading(true);
      const data = await getAllEvents();
      setEvents(data.events);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const loadTourists = async () => {
    try {
      setLoading(true);
      const data = await getAllTourists(50, 0);
      setTourists(data.tourists);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const loadUsers = async () => {
    try {
      setLoading(true);
      const data = await getAllUsers();
      setUsers(data.users);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteUser = async (userId: string) => {
    if (!confirm("Are you sure you want to delete this user?")) return;
    try {
      await deleteUser(userId);
      setSuccess("User deleted successfully");
      loadUsers();
      loadStats();
    } catch (err: any) {
      setError(err.message);
    }
  };

  const toggleEventStatus = async (event_id: number, currentStatus: boolean) => {
    try {
      await updateEventStatus(event_id, !currentStatus);
      setSuccess("Event status updated");
      loadEvents();
      loadStats();
    } catch (err: any) {
      setError(err.message);
    }
  };

  const handleEventFormChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    setEventForm({ ...eventForm, [e.target.name]: e.target.value });
  };

  const handleEventFormSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSuccess(null);
    try {
      const result = await createEvent(eventForm);
      setSuccess(result.message || "Event created successfully");
      setShowEventForm(false);
      setEventForm({
        name: "",
        description: "",
        start_date: "",
        end_date: "",
        location: "",
        max_capacity: "",
        is_active: true,
      });
      loadStats();
      if (activeView === 'events') loadEvents();
    } catch (err: any) {
      setError(err.message || "Failed to create event");
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
    router.replace("/admin/auth");
  };

  const renderHome = () => (
    <div className="space-y-6">
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-white rounded-xl shadow-md p-6">
          <h3 className="text-sm font-medium text-gray-500 mb-2">Total Events</h3>
          <p className="text-3xl font-bold text-yellow-600">{stats.events}</p>
        </div>
        <div className="bg-white rounded-xl shadow-md p-6">
          <h3 className="text-sm font-medium text-gray-500 mb-2">Active Events</h3>
          <p className="text-3xl font-bold text-green-600">{stats.activeEvents}</p>
        </div>
        <div className="bg-white rounded-xl shadow-md p-6">
          <h3 className="text-sm font-medium text-gray-500 mb-2">Total Tourists</h3>
          <p className="text-3xl font-bold text-blue-600">{stats.tourists}</p>
        </div>
        <div className="bg-white rounded-xl shadow-md p-6">
          <h3 className="text-sm font-medium text-gray-500 mb-2">Total Users</h3>
          <p className="text-3xl font-bold text-purple-600">{stats.users}</p>
        </div>
      </div>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <button
          className="bg-yellow-600 text-white p-6 rounded-xl shadow-md hover:bg-yellow-700 transition-colors"
          onClick={() => setShowEventForm(true)}
        >
          <div className="text-lg font-semibold mb-2">Create New Event</div>
          <div className="text-sm opacity-90">Add a new event to the system</div>
        </button>
        <button
          className="bg-blue-600 text-white p-6 rounded-xl shadow-md hover:bg-blue-700 transition-colors"
          onClick={() => { setActiveView('events'); loadEvents(); }}
        >
          <div className="text-lg font-semibold mb-2">Manage Events</div>
          <div className="text-sm opacity-90">View and manage all events</div>
        </button>
        <button
          className="bg-green-600 text-white p-6 rounded-xl shadow-md hover:bg-green-700 transition-colors"
          onClick={() => { setActiveView('tourists'); loadTourists(); }}
        >
          <div className="text-lg font-semibold mb-2">View Tourists</div>
          <div className="text-sm opacity-90">See all registered tourists</div>
        </button>
        <button
          className="bg-purple-600 text-white p-6 rounded-xl shadow-md hover:bg-purple-700 transition-colors"
          onClick={() => { setActiveView('users'); loadUsers(); }}
        >
          <div className="text-lg font-semibold mb-2">Manage Users</div>
          <div className="text-sm opacity-90">View and manage all users</div>
        </button>
      </div>
    </div>
  );

  const renderEvents = () => (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold text-gray-800">All Events</h2>
        <button
          className="bg-yellow-600 text-white px-4 py-2 rounded-lg hover:bg-yellow-700"
          onClick={() => setShowEventForm(true)}
        >
          + Create Event
        </button>
      </div>
      {loading ? (
        <div className="text-center py-12">Loading...</div>
      ) : (
        <div className="grid grid-cols-1 gap-4">
          {events.map((event) => (
            <div key={event.event_id} className="bg-white rounded-xl shadow-md p-6">
              <div className="flex justify-between items-start">
                <div className="flex-1">
                  <h3 className="text-xl font-bold text-gray-800">{event.name}</h3>
                  <p className="text-sm text-gray-600 mt-1">{event.description}</p>
                  <div className="mt-3 space-y-1 text-sm text-gray-700">
                    <div className="flex items-center gap-2">
                      <span>📌 <span className="font-mono text-base">{event.event_id}</span></span>
                      <button
                        className="ml-2 px-2 py-1 bg-gray-100 rounded text-xs text-gray-700 hover:bg-gray-200"
                        title="Copy Event ID"
                        onClick={() => navigator.clipboard.writeText(event.event_id.toString())}
                      >
                        Copy
                      </button>
                    </div>
                    <div className="text-xs text-blue-600 mt-1">This Event ID will be used for Tourist Registration.</div>
                    <div>📍 {event.location}</div>
                    <div>📅 {new Date(event.start_date).toLocaleDateString()} - {new Date(event.end_date).toLocaleDateString()}</div>
                    {event.max_capacity && <div>👥 Max: {event.max_capacity}</div>}
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <span className={`px-3 py-1 rounded-full text-xs font-semibold ${event.is_active ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                    {event.is_active ? 'Active' : 'Inactive'}
                  </span>
                  <button
                    className="px-3 py-1 bg-blue-600 text-white text-xs rounded hover:bg-blue-700"
                    onClick={() => toggleEventStatus(event.event_id, event.is_active)}
                  >
                    Toggle
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );

  const renderTourists = () => (
    <div className="space-y-4">
      <h2 className="text-2xl font-bold text-gray-800">All Tourists</h2>
      {loading ? (
        <div className="text-center py-12">Loading...</div>
      ) : (
        <div className="bg-white rounded-xl shadow-md overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">ID</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Email</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">ID Type</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Group</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {tourists.map((tourist) => (
                <tr key={tourist.user_id} className="hover:bg-gray-50">
                  <td className="px-6 py-4 text-sm text-gray-900">{tourist.user_id}</td>
                  <td className="px-6 py-4 text-sm text-gray-900">{tourist.name}</td>
                  <td className="px-6 py-4 text-sm text-gray-600">{tourist.email || 'N/A'}</td>
                  <td className="px-6 py-4 text-sm text-gray-600">{tourist.unique_id_type}</td>
                  <td className="px-6 py-4 text-sm text-gray-600">
                    {tourist.is_group ? `Yes (${tourist.group_count})` : 'No'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );

  const renderUsers = () => (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h2 className="text-xl font-bold text-purple-700">User Management</h2>
        <button
          onClick={loadUsers}
          className="bg-purple-600 text-white px-4 py-2 rounded-lg hover:bg-purple-700 transition-colors"
        >
          Refresh
        </button>
      </div>
      {loading ? (
        <div className="bg-white rounded-xl shadow-md p-12 text-center">
          <div className="text-gray-600">Loading users...</div>
        </div>
      ) : users.length === 0 ? (
        <div className="bg-white rounded-xl shadow-md p-12 text-center">
          <div className="text-gray-600">No users found</div>
        </div>
      ) : (
        <div className="bg-white rounded-xl shadow-md overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-purple-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-purple-700 uppercase tracking-wider">
                  ID
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-purple-700 uppercase tracking-wider">
                  Email
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-purple-700 uppercase tracking-wider">
                  Role
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-purple-700 uppercase tracking-wider">
                  Created At
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-purple-700 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {users.map((user) => (
                <tr key={user.id} className="hover:bg-purple-50">
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    {user.id}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-600">
                    {user.email}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-600">
                    <span className="bg-purple-100 text-purple-800 px-2 py-1 rounded-full text-xs font-medium">
                      {user.role || 'admin'}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-600">
                    {new Date(user.created_at).toLocaleDateString()}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm">
                    <button
                      onClick={() => handleDeleteUser(user.id)}
                      className="text-red-600 hover:text-red-800 font-medium"
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );

  return (
    <div className="min-h-screen bg-gradient-to-br from-yellow-50 to-white">
      {/* Header */}
      <div className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex justify-between items-center">
            <div className="flex items-center gap-4">
              <h1 className="text-2xl font-bold text-yellow-700">Admin Dashboard</h1>
              {activeView !== 'home' && (
                <button
                  className="text-sm text-gray-600 hover:text-gray-800"
                  onClick={() => setActiveView('home')}
                >
                  ← Back to Home
                </button>
              )}
            </div>
            <div className="flex items-center gap-3">
              <span className="text-sm text-gray-700 hidden sm:block">{user?.email}</span>
              <button
                className="bg-red-500 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:bg-red-600 transition-colors"
                onClick={handleLogout}
              >
                Logout
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {success && (
          <div className="bg-green-50 border border-green-200 text-green-700 px-4 py-3 rounded-lg mb-4">
            {success}
          </div>
        )}
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mb-4">
            {error}
          </div>
        )}

        {activeView === 'home' && renderHome()}
        {activeView === 'events' && renderEvents()}
        {activeView === 'tourists' && renderTourists()}
        {activeView === 'users' && renderUsers()}
      </div>

      {/* Event Form Modal */}
      {showEventForm && (
        <div className="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl shadow-lg p-8 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-2xl font-bold text-yellow-700">Create New Event</h2>
              <button
                className="text-gray-500 hover:text-gray-700 text-2xl"
                onClick={() => setShowEventForm(false)}
              >
                ×
              </button>
            </div>
            <form className="space-y-4" onSubmit={handleEventFormSubmit}>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Event Name *</label>
                <input
                  type="text"
                  name="name"
                  value={eventForm.name}
                  onChange={handleEventFormChange}
                  className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-yellow-200 focus:border-yellow-400"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
                <textarea
                  name="description"
                  value={eventForm.description}
                  onChange={handleEventFormChange}
                  className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-yellow-200 focus:border-yellow-400"
                  rows={3}
                />
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Start Date *</label>
                  <input
                    type="datetime-local"
                    name="start_date"
                    value={eventForm.start_date}
                    onChange={handleEventFormChange}
                    className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-yellow-200 focus:border-yellow-400"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">End Date *</label>
                  <input
                    type="datetime-local"
                    name="end_date"
                    value={eventForm.end_date}
                    onChange={handleEventFormChange}
                    className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-yellow-200 focus:border-yellow-400"
                    required
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Location *</label>
                <input
                  type="text"
                  name="location"
                  value={eventForm.location}
                  onChange={handleEventFormChange}
                  className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-yellow-200 focus:border-yellow-400"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Max Capacity</label>
                <input
                  type="number"
                  name="max_capacity"
                  value={eventForm.max_capacity}
                  onChange={handleEventFormChange}
                  className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-yellow-200 focus:border-yellow-400"
                  placeholder="Leave empty for unlimited"
                />
              </div>
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  name="is_active"
                  checked={eventForm.is_active}
                  onChange={e => setEventForm({ ...eventForm, is_active: e.target.checked })}
                  className="rounded"
                />
                <label className="text-sm font-medium text-gray-700">Active Event</label>
              </div>
              <button
                type="submit"
                className="w-full bg-yellow-600 text-white py-3 rounded-lg font-semibold hover:bg-yellow-700 transition-colors disabled:bg-yellow-400"
                disabled={loading}
              >
                {loading ? "Creating..." : "Create Event"}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
