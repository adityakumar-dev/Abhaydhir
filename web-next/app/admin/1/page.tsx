"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useUser } from "@/context/admin_context";
import { supabase } from "@/services/adminAuth";
import { getAdminOnboardingStats, OnboardingStats } from "@/services/adminApi";

export default function EventOneDashboard() {
  const router = useRouter();
  const { user } = useUser();
  const [stats, setStats] = useState<OnboardingStats | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (user) {
      fetchStats();
    }
  }, [user?.id]);

  const fetchStats = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getAdminOnboardingStats();
      setStats(data);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
    router.replace("/admin/auth");
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-yellow-50 to-white">
      {/* header */}
      <div className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <h1 className="text-2xl font-bold text-yellow-700">Event‑1 Dashboard</h1>
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

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mb-4">
            {error}
          </div>
        )}
        <div className="flex justify-end mb-4">
          <button
            onClick={fetchStats}
            className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
            disabled={loading}
          >
            {loading ? "Refreshing…" : "Refresh"}
          </button>
        </div>

        {stats && (
          <>
            <div className="grid grid-cols-1 sm:grid-cols-3 lg:grid-cols-4 gap-6 mb-8">
              <div className="bg-white rounded-xl shadow-md p-6">
                <h3 className="text-sm font-medium text-gray-500 mb-2">Total Registered</h3>
                <p className="text-3xl font-bold text-yellow-600">{stats.total_registered}</p>
              </div>
              <div className="bg-white rounded-xl shadow-md p-6">
                <h3 className="text-sm font-medium text-gray-500 mb-2">Currently Inside</h3>
                <p className="text-3xl font-bold text-green-600">{stats.currently_inside}</p>
              </div>
              <div className="bg-white rounded-xl shadow-md p-6">
                <h3 className="text-sm font-medium text-gray-500 mb-2">Feedback Submissions</h3>
                <p className="text-3xl font-bold text-indigo-600">{stats.feedback_submissions}</p>
              </div>
            </div>

            <div className="space-y-8">
              <div>
                <h2 className="text-xl font-semibold text-gray-800 mb-3">Registrations by Date</h2>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  {Object.entries(stats.date_wise.registrations).map(([date, cnt]) => (
                    <div key={date} className="bg-white rounded-xl shadow-md p-5 text-center">
                      <div className="text-lg font-bold text-gray-800">
                        {new Date(date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}
                      </div>
                      <div className="text-2xl font-bold text-blue-600">{cnt}</div>
                    </div>
                  ))}
                </div>
              </div>
              <div>
                <h2 className="text-xl font-semibold text-gray-800 mb-3">Entries by Date</h2>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  {Object.entries(stats.date_wise.entries).map(([date, cnt]) => (
                    <div key={date} className="bg-white rounded-xl shadow-md p-5 text-center">
                      <div className="text-lg font-bold text-gray-800">
                        {new Date(date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}
                      </div>
                      <div className="text-2xl font-bold text-blue-600">{cnt}</div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </>
        )}

        {loading && !stats && (
          <div className="text-center py-20 text-gray-400">Loading…</div>
        )}

        {!loading && !stats && !error && (
          <div className="text-center py-20 text-gray-400">No data available.</div>
        )}
      </div>
    </div>
  );
}
