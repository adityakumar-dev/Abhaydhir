"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useUser } from "@/context/admin_context";
import { supabase } from "@/services/adminAuth";
import { getAdminOnboardingStats, OnboardingStats } from "@/services/adminApi";

// ── Dummy camera summary data ─────────────────────────────────────────────────
const DUMMY_CAM_SUMMARY = {
  entry: {
    active_now: 14,
    today_entries: 52,
    unique_total: 137,
  },
  exit: {
    near_exit: 9,
    exited_today: 48,
    avg_dwell: "7m 23s",
    emotions: { very_happy: 22, happy: 61, sad: 17 },
  },
};

// ── Emotion bar (self-contained, no extra deps) ───────────────────────────────
function EmotionBar({ label, emoji, pct, color }: { label: string; emoji: string; pct: number; color: string }) {
  return (
    <div className="flex flex-col gap-1">
      <div className="flex justify-between items-center text-xs text-gray-500">
        <span>{emoji} {label}</span>
        <span className="font-semibold" style={{ color }}>{pct}%</span>
      </div>
      <div className="h-1.5 rounded-full bg-gray-100 overflow-hidden">
        <div className="h-full rounded-full transition-all duration-700" style={{ width: `${pct}%`, background: color }} />
      </div>
    </div>
  );
}

export default function EventOneDashboard() {
  const router = useRouter();
  const { user } = useUser();
  const [stats, setStats] = useState<OnboardingStats | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (user) fetchStats();
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

  const cam = DUMMY_CAM_SUMMARY;
  const emotionTotal = Object.values(cam.exit.emotions).reduce((a, b) => a + b, 0);

  return (
    <div className="min-h-screen bg-gradient-to-br from-yellow-50 to-white">

      {/* ── Header ──────────────────────────────────────────────────────────── */}
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

        {/* ── Error ───────────────────────────────────────────────────────── */}
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

        {/* ── Existing onboarding stats ────────────────────────────────────── */}
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

            <div className="space-y-8 mb-10">
              <div>
                <h2 className="text-xl font-semibold text-gray-800 mb-3">Registrations by Date</h2>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  {Object.entries(stats.date_wise.registrations).map(([date, cnt]) => (
                    <div key={date} className="bg-white rounded-xl shadow-md p-5 text-center">
                      <div className="text-lg font-bold text-gray-800">
                        {new Date(date).toLocaleDateString(undefined, { month: "short", day: "numeric" })}
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
                        {new Date(date).toLocaleDateString(undefined, { month: "short", day: "numeric" })}
                      </div>
                      <div className="text-2xl font-bold text-blue-600">{cnt}</div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </>
        )}

        {loading && !stats && <div className="text-center py-20 text-gray-400">Loading…</div>}
        {!loading && !stats && !error && <div className="text-center py-20 text-gray-400">No data available.</div>}

        {/* ── Camera Summary ───────────────────────────────────────────────── */}
        <div className="mb-2">
          <h2 className="text-xl font-semibold text-gray-800 mb-1">Camera Overview</h2>
          <p className="text-sm text-gray-400 mb-4">Live summary from entry &amp; exit cams</p>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">

            {/* Entry Cam */}
            <div className="bg-white rounded-xl shadow-md p-6 border border-gray-100">
              <div className="flex items-center gap-2 mb-5">
                <span className="w-2 h-2 rounded-full bg-cyan-400 animate-pulse" />
                <h3 className="text-sm font-semibold text-gray-700 uppercase tracking-widest">Entry Cam</h3>
                <span className="ml-auto text-xs text-gray-400 bg-gray-100 px-2 py-0.5 rounded-full">cam1</span>
              </div>

              <div className="grid grid-cols-3 gap-4 mb-1">
                <div className="text-center">
                  <p className="text-2xl font-bold text-cyan-600">{cam.entry.active_now}</p>
                  <p className="text-xs text-gray-400 mt-0.5">Active Now</p>
                </div>
                <div className="text-center border-x border-gray-100">
                  <p className="text-2xl font-bold text-blue-600">{cam.entry.today_entries}</p>
                  <p className="text-xs text-gray-400 mt-0.5">Today</p>
                </div>
                <div className="text-center">
                  <p className="text-2xl font-bold text-gray-700">{cam.entry.unique_total}</p>
                  <p className="text-xs text-gray-400 mt-0.5">Unique Total</p>
                </div>
              </div>
            </div>

            {/* Exit Cam */}
            <div className="bg-white rounded-xl shadow-md p-6 border border-gray-100">
              <div className="flex items-center gap-2 mb-5">
                <span className="w-2 h-2 rounded-full bg-violet-400 animate-pulse" />
                <h3 className="text-sm font-semibold text-gray-700 uppercase tracking-widest">Exit Cam</h3>
                <span className="ml-auto text-xs text-gray-400 bg-gray-100 px-2 py-0.5 rounded-full">cam2</span>
              </div>

              {/* top numbers */}
              <div className="grid grid-cols-3 gap-4 mb-5">
                <div className="text-center">
                  <p className="text-2xl font-bold text-violet-600">{cam.exit.near_exit}</p>
                  <p className="text-xs text-gray-400 mt-0.5">Near Exit</p>
                </div>
                <div className="text-center border-x border-gray-100">
                  <p className="text-2xl font-bold text-indigo-600">{cam.exit.exited_today}</p>
                  <p className="text-xs text-gray-400 mt-0.5">Exited Today</p>
                </div>
                <div className="text-center">
                  <p className="text-2xl font-bold text-gray-700">{cam.exit.avg_dwell}</p>
                  <p className="text-xs text-gray-400 mt-0.5">Avg Dwell</p>
                </div>
              </div>

              {/* emotion bars */}
              <div className="border-t border-gray-100 pt-4 flex flex-col gap-2.5">
                <EmotionBar label="Very Happy" emoji="😄" pct={Math.round(cam.exit.emotions.very_happy / emotionTotal * 100)} color="#22c55e" />
                <EmotionBar label="Happy"      emoji="🙂" pct={Math.round(cam.exit.emotions.happy      / emotionTotal * 100)} color="#f59e0b" />
                <EmotionBar label="Sad"        emoji="😞" pct={Math.round(cam.exit.emotions.sad        / emotionTotal * 100)} color="#f87171" />
              </div>
            </div>

          </div>
        </div>

      </div>
    </div>
  );
}