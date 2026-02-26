"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { useRouter } from "next/navigation";
import { useUser } from "@/context/admin_context";
import { supabase } from "@/services/adminAuth";
import { getAdminOnboardingStats, OnboardingStats } from "@/services/adminApi";

// ── Camera backend base URL ───────────────────────────────────────────────────
const CAM_BASE = process.env.NEXT_PUBLIC_CAM_URL ?? "";
const CAM_WS   = CAM_BASE.replace(/^https/, "wss").replace(/^http/, "ws") + "/ws";

// ── Types ─────────────────────────────────────────────────────────────────────
interface CamState {
  cam: "entry-cam" | "exit-cam";
  online: boolean;
  unique_count: number;
  active_count: number;
  last_seen: number;
  last_event: string;
  ws_connected: boolean;
}

interface HourlyRow  { cam: string; date: string; hour: number; count: number; }
interface EmotionRow { emotion: string; count: number; }
interface ReturnsData {
  total_unique: number;
  return_visitors: number;
  return_rate: number;
}
interface CaptureItem {
  cam: string;
  track_id: number;
  image_b64: string;
  emotion: string | null;
  emotion_score: number | null;
  received_at: string;
}
interface LiveEvent {
  id: string;
  cam: string;
  event: string;
  ts: number;
  detail: string;
}

// ── Auth / fetch helpers ──────────────────────────────────────────────────────
async function authHeaders(): Promise<Record<string, string>> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session?.access_token) throw new Error("Not authenticated");
  return { Authorization: `Bearer ${session.access_token}` };
}

async function camFetch<T>(path: string, opts?: RequestInit): Promise<T> {
  const hdrs = await authHeaders();
  const res  = await fetch(`${CAM_BASE}${path}`, {
    ...opts,
    headers: { ...hdrs, ...(opts?.headers as object | undefined) },
  });
  if (!res.ok) {
    const err = await res.json().catch(() => null);
    throw new Error(err?.detail ?? `${path} failed (${res.status})`);
  }
  return res.json();
}

function eventDetail(d: Record<string, any>): string {
  switch (d.event) {
    case "heartbeat": return `Active: ${d.active_count} | Unique: ${d.unique_count}`;
    case "enter":     return `Track #${d.track_id} entered (conf ${(d.conf as number)?.toFixed(2)})`;
    case "exit":      return `Track #${d.track_id} exited (dwell ${d.dwell}s)`;
    case "new_entry": return `New unique visitor #${d.unique_count}`;
    case "captured":  return `Captured track #${d.track_id}`;
    case "reentry":   return `Re-entry: CID ${d.cid}, visit #${d.visit_count}`;
    case "archived":  return `Archived #${d.track_id} — ${d.emotion} (${(d.emotion_score as number)?.toFixed(2)})`;
    default:          return String(d.event);
  }
}

// ── Emotion display maps ──────────────────────────────────────────────────────
const EMOTION_COLOR: Record<string, string> = {
  VeryHappy: "#22c55e",
  Happy:     "#f59e0b",
  Neutral:   "#6b7280",
  Sad:       "#f87171",
  Angry:     "#ef4444",
};
const EMOTION_EMOJI: Record<string, string> = {
  VeryHappy: "😄",
  Happy:     "🙂",
  Neutral:   "😐",
  Sad:       "😞",
  Angry:     "😠",
};

// ── Sub-components ────────────────────────────────────────────────────────────
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

function HourlyChart({ data, cam }: { data: HourlyRow[]; cam: string }) {
  const rows = data.filter((r) => r.cam === cam);
  const max  = Math.max(...rows.map((r) => r.count), 1);
  return (
    <div className="flex items-end gap-px h-20 w-full">
      {Array.from({ length: 24 }, (_, h) => {
        const row = rows.find((r) => r.hour === h);
        const pct = ((row?.count ?? 0) / max) * 100;
        return (
          <div key={h} className="flex-1 flex flex-col items-center relative group">
            <div
              className="w-full rounded-t bg-blue-400 transition-all duration-300"
              style={{ height: `${pct}%`, minHeight: pct > 0 ? 2 : 0 }}
            />
            <span className="absolute -top-6 left-1/2 -translate-x-1/2 text-xs bg-gray-800 text-white px-1 rounded opacity-0 group-hover:opacity-100 whitespace-nowrap z-10 pointer-events-none">
              {h}:00 — {row?.count ?? 0}
            </span>
          </div>
        );
      })}
    </div>
  );
}

export default function EventOneDashboard() {
  const router  = useRouter();
  const { user } = useUser();

  // ── Onboarding stats (existing) ─────────────────────────────────────────────
  const [stats,   setStats]   = useState<OnboardingStats | null>(null);
  const [loading, setLoading] = useState(false);
  const [error,   setError]   = useState<string | null>(null);

  // ── Camera / WS state ────────────────────────────────────────────────────────
  const [cameras,    setCameras]    = useState<CamState[]>([]);
  const [frames,     setFrames]     = useState<Record<string, string>>({});
  const [hourly,     setHourly]     = useState<HourlyRow[]>([]);
  const [emotions,   setEmotions]   = useState<EmotionRow[]>([]);
  const [returns,    setReturns]    = useState<ReturnsData | null>(null);
  const [captures,   setCaptures]   = useState<CaptureItem[]>([]);
  const [liveEvents, setLiveEvents] = useState<LiveEvent[]>([]);
  const [wsStatus,   setWsStatus]   = useState<"connecting" | "connected" | "disconnected">("connecting");
  const [camError,   setCamError]   = useState<string | null>(null);

  const wsRef = useRef<WebSocket | null>(null);

  // ── Fetch full dashboard snapshot (/admin/camera) ────────────────────────────
  const fetchSnapshot = useCallback(async () => {
    try {
      const data = await camFetch<{
        today: string;
        cameras: CamState[];
        hourly: HourlyRow[];
        emotions: EmotionRow[];
        returns: ReturnsData;
        recent_captures: CaptureItem[];
      }>("/admin/camera");
      setCameras(data.cameras);
      setHourly(data.hourly);
      setEmotions(data.emotions);
      setReturns(data.returns);
      setCaptures(data.recent_captures);
      setCamError(null);
    } catch (e: any) {
      setCamError(e.message);
    }
  }, []);

  // ── WebSocket ────────────────────────────────────────────────────────────────
  useEffect(() => {
    if (!user) return;

    fetchSnapshot();

    const ws = new WebSocket(CAM_WS);
    wsRef.current = ws;
    setWsStatus("connecting");

    ws.onopen  = () => setWsStatus("connected");
    ws.onclose = () => setWsStatus("disconnected");
    ws.onerror = () => setWsStatus("disconnected");

    ws.onmessage = (e) => {
      try {
        const msg = JSON.parse(e.data as string);

        switch (msg.type) {
          // ── Full state snapshot sent immediately on connect ──────────────
          case "init_status":
            setCameras(msg.cameras ?? []);
            break;

          // ── Camera online/offline change ─────────────────────────────────
          case "cam_status":
            setCameras((prev) =>
              prev.map((c) =>
                c.cam === msg.cam ? { ...c, online: Boolean(msg.online) } : c
              )
            );
            break;

          // ── Live JPEG frame (1 fps) ──────────────────────────────────────
          case "frame":
            setFrames((prev) => ({ ...prev, [msg.cam as string]: msg.image as string }));
            break;

          // ── Any camera event ─────────────────────────────────────────────
          case "event": {
            const d = msg.data as Record<string, any>;

            // Keep live counts in sync on heartbeat
            if (d.event === "heartbeat") {
              setCameras((prev) =>
                prev.map((c) =>
                  c.cam === msg.cam
                    ? { ...c, active_count: d.active_count as number, unique_count: d.unique_count as number, last_event: "heartbeat" }
                    : c
                )
              );
            }

            // Append to live event feed (cap at 50)
            setLiveEvents((prev) => [
              {
                id:     `${String(msg.cam)}-${String(d.ts)}-${Math.random()}`,
                cam:    String(msg.cam),
                event:  String(d.event),
                ts:     d.ts as number,
                detail: eventDetail(d),
              },
              ...prev,
            ].slice(0, 50));

            // Append captured / archived images
            if ((d.event === "captured" || d.event === "archived") && d.image) {
              setCaptures((prev) => [
                {
                  cam:           String(msg.cam),
                  track_id:      d.track_id as number,
                  image_b64:     d.image as string,
                  emotion:       (d.emotion as string | undefined) ?? null,
                  emotion_score: (d.emotion_score as number | undefined) ?? null,
                  received_at:   new Date((d.ts as number) * 1000).toISOString(),
                },
                ...prev,
              ].slice(0, 40));
            }
            break;
          }
        }
      } catch {
        /* ignore parse errors */
      }
    };

    return () => { ws.close(); };
  }, [user?.id, fetchSnapshot]);

  // ── Onboarding stats ─────────────────────────────────────────────────────────
  const fetchStats = async () => {
    setLoading(true);
    setError(null);
    try {
      setStats(await getAdminOnboardingStats());
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (user) fetchStats();
  }, [user?.id]);

  const handleLogout = async () => {
    wsRef.current?.close();
    await supabase.auth.signOut();
    router.replace("/admin/auth");
  };

  // ── Derived values ────────────────────────────────────────────────────────────
  const entryCam     = cameras.find((c) => c.cam === "entry-cam");
  const exitCam      = cameras.find((c) => c.cam === "exit-cam");
  const emotionTotal = emotions.reduce((s, e) => s + e.count, 0);

  const wsStyle = {
    connected:    { wrap: "bg-green-100 text-green-700",  dot: "bg-green-400 animate-pulse", label: "WS Live" },
    connecting:   { wrap: "bg-yellow-100 text-yellow-700", dot: "bg-yellow-400",              label: "WS Connecting…" },
    disconnected: { wrap: "bg-red-100 text-red-700",       dot: "bg-red-400",                 label: "WS Offline" },
  }[wsStatus];

  return (
    <div className="min-h-screen bg-gradient-to-br from-yellow-50 to-white">

      {/* ── Header ───────────────────────────────────────────────────────────── */}
      <div className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <div className="flex items-center gap-3">
            <h1 className="text-2xl font-bold text-yellow-700">Event‑1 Dashboard</h1>
            <span className={`flex items-center gap-1.5 text-xs font-medium px-2.5 py-1 rounded-full ${wsStyle.wrap}`}>
              <span className={`w-1.5 h-1.5 rounded-full ${wsStyle.dot}`} />
              {wsStyle.label}
            </span>
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

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">

        {/* ── Errors ───────────────────────────────────────────────────────── */}
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mb-4">{error}</div>
        )}
        {camError && (
          <div className="bg-orange-50 border border-orange-200 text-orange-700 px-4 py-3 rounded-lg mb-4">
            Camera API: {camError}
          </div>
        )}

        {/* ── Refresh row ──────────────────────────────────────────────────── */}
        <div className="flex gap-2 justify-end mb-6">
          <button
            onClick={fetchSnapshot}
            className="bg-cyan-600 text-white px-4 py-2 rounded-lg hover:bg-cyan-700 transition-colors text-sm"
          >
            Refresh Cams
          </button>
          <button
            onClick={fetchStats}
            disabled={loading}
            className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors text-sm disabled:opacity-50"
          >
            {loading ? "Refreshing…" : "Refresh Stats"}
          </button>
        </div>

        {/* ── Camera Overview ──────────────────────────────────────────────── */}
        <section className="mb-10">
          <h2 className="text-xl font-semibold text-gray-800 mb-1">Camera Overview</h2>
          <p className="text-sm text-gray-400 mb-4">Live data from entry &amp; exit cameras</p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">

            {/* Entry Cam */}
            <div className="bg-white rounded-xl shadow-md p-6 border border-gray-100">
              <div className="flex items-center gap-2 mb-4">
                <span className={`w-2 h-2 rounded-full ${entryCam?.online ? "bg-cyan-400 animate-pulse" : "bg-gray-300"}`} />
                <h3 className="text-sm font-semibold text-gray-700 uppercase tracking-widest">Entry Cam</h3>
                <span className={`ml-auto text-xs px-2 py-0.5 rounded-full ${entryCam?.online ? "bg-cyan-50 text-cyan-700" : "bg-gray-100 text-gray-400"}`}>
                  {cameras.length === 0 ? "—" : entryCam?.online ? "Online" : "Offline"}
                </span>
              </div>

              {/* Live frame */}
              <div className="relative mb-4 rounded-lg overflow-hidden bg-gray-100 aspect-video flex items-center justify-center">
                {frames["entry-cam"] ? (
                  <img
                    src={`data:image/jpeg;base64,${frames["entry-cam"]}`}
                    alt="Entry cam live"
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <span className="text-xs text-gray-400">No frame yet</span>
                )}
                <span className="absolute top-1.5 right-1.5 bg-black/50 text-white text-xs px-1.5 py-0.5 rounded">LIVE</span>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="text-center">
                  <p className="text-2xl font-bold text-cyan-600">{entryCam?.active_count ?? "—"}</p>
                  <p className="text-xs text-gray-400 mt-0.5">Active Now</p>
                </div>
                <div className="text-center border-l border-gray-100">
                  <p className="text-2xl font-bold text-gray-700">{entryCam?.unique_count ?? "—"}</p>
                  <p className="text-xs text-gray-400 mt-0.5">Unique Total</p>
                </div>
              </div>
              {entryCam?.last_event && (
                <p className="text-xs text-gray-400 mt-3 text-center">
                  Last: <span className="font-medium text-gray-600">{entryCam.last_event}</span>
                </p>
              )}
            </div>

            {/* Exit Cam */}
            <div className="bg-white rounded-xl shadow-md p-6 border border-gray-100">
              <div className="flex items-center gap-2 mb-4">
                <span className={`w-2 h-2 rounded-full ${exitCam?.online ? "bg-violet-400 animate-pulse" : "bg-gray-300"}`} />
                <h3 className="text-sm font-semibold text-gray-700 uppercase tracking-widest">Exit Cam</h3>
                <span className={`ml-auto text-xs px-2 py-0.5 rounded-full ${exitCam?.online ? "bg-violet-50 text-violet-700" : "bg-gray-100 text-gray-400"}`}>
                  {cameras.length === 0 ? "—" : exitCam?.online ? "Online" : "Offline"}
                </span>
              </div>

              {/* Live frame */}
              <div className="relative mb-4 rounded-lg overflow-hidden bg-gray-100 aspect-video flex items-center justify-center">
                {frames["exit-cam"] ? (
                  <img
                    src={`data:image/jpeg;base64,${frames["exit-cam"]}`}
                    alt="Exit cam live"
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <span className="text-xs text-gray-400">No frame yet</span>
                )}
                <span className="absolute top-1.5 right-1.5 bg-black/50 text-white text-xs px-1.5 py-0.5 rounded">LIVE</span>
              </div>

              <div className="grid grid-cols-2 gap-4 mb-4">
                <div className="text-center">
                  <p className="text-2xl font-bold text-violet-600">{exitCam?.active_count ?? "—"}</p>
                  <p className="text-xs text-gray-400 mt-0.5">Active Now</p>
                </div>
                <div className="text-center border-l border-gray-100">
                  <p className="text-2xl font-bold text-gray-700">{exitCam?.unique_count ?? "—"}</p>
                  <p className="text-xs text-gray-400 mt-0.5">Unique Total</p>
                </div>
              </div>

              {/* Emotion bars from real API data */}
              {emotions.length > 0 && (
                <div className="border-t border-gray-100 pt-4 flex flex-col gap-2.5">
                  {emotions.map((e) => (
                    <EmotionBar
                      key={e.emotion}
                      label={e.emotion}
                      emoji={EMOTION_EMOJI[e.emotion] ?? "🫥"}
                      pct={emotionTotal > 0 ? Math.round((e.count / emotionTotal) * 100) : 0}
                      color={EMOTION_COLOR[e.emotion] ?? "#6b7280"}
                    />
                  ))}
                </div>
              )}
            </div>

          </div>
        </section>

        {/* ── Return Visitors ──────────────────────────────────────────────── */}
        {returns && (
          <section className="mb-10">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">Return Visitors</h2>
            <div className="grid grid-cols-3 gap-4">
              <div className="bg-white rounded-xl shadow-md p-6 text-center">
                <p className="text-3xl font-bold text-gray-700">{returns.total_unique}</p>
                <p className="text-xs text-gray-400 mt-1">Total Unique</p>
              </div>
              <div className="bg-white rounded-xl shadow-md p-6 text-center">
                <p className="text-3xl font-bold text-indigo-600">{returns.return_visitors}</p>
                <p className="text-xs text-gray-400 mt-1">Return Visitors</p>
              </div>
              <div className="bg-white rounded-xl shadow-md p-6 text-center">
                <p className="text-3xl font-bold text-green-600">{returns.return_rate.toFixed(1)}%</p>
                <p className="text-xs text-gray-400 mt-1">Return Rate</p>
              </div>
            </div>
          </section>
        )}

        {/* ── Hourly Chart ─────────────────────────────────────────────────── */}
        {hourly.length > 0 && (
          <section className="mb-10">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">Hourly Unique Counts (Today)</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="bg-white rounded-xl shadow-md p-6">
                <h3 className="text-sm font-semibold text-gray-600 mb-3">Entry Cam</h3>
                <HourlyChart data={hourly} cam="entry-cam" />
                <div className="flex justify-between text-xs text-gray-400 mt-1">
                  <span>0:00</span><span>12:00</span><span>23:00</span>
                </div>
              </div>
              <div className="bg-white rounded-xl shadow-md p-6">
                <h3 className="text-sm font-semibold text-gray-600 mb-3">Exit Cam</h3>
                <HourlyChart data={hourly} cam="exit-cam" />
                <div className="flex justify-between text-xs text-gray-400 mt-1">
                  <span>0:00</span><span>12:00</span><span>23:00</span>
                </div>
              </div>
            </div>
          </section>
        )}

        {/* ── Live Event Feed ──────────────────────────────────────────────── */}
        <section className="mb-10">
          <h2 className="text-xl font-semibold text-gray-800 mb-4">Live Event Feed</h2>
          <div className="bg-white rounded-xl shadow-md p-4 max-h-72 overflow-y-auto">
            {liveEvents.length === 0 ? (
              <p className="text-center text-sm text-gray-400 py-8">Waiting for events…</p>
            ) : (
              <ul className="divide-y divide-gray-100">
                {liveEvents.map((ev) => (
                  <li key={ev.id} className="flex items-start gap-3 py-2">
                    <span className={`mt-1 w-2 h-2 rounded-full flex-shrink-0 ${ev.cam === "entry-cam" ? "bg-cyan-400" : "bg-violet-400"}`} />
                    <div className="min-w-0">
                      <p className="text-xs font-semibold text-gray-600">
                        {ev.cam} · <span className="font-normal text-gray-500">{ev.event}</span>
                      </p>
                      <p className="text-xs text-gray-500 truncate">{ev.detail}</p>
                    </div>
                    <span className="ml-auto text-xs text-gray-300 flex-shrink-0">
                      {new Date(ev.ts * 1000).toLocaleTimeString()}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </section>

        {/* ── Recent Captures ──────────────────────────────────────────────── */}
        {captures.length > 0 && (
          <section className="mb-10">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">Recent Captures</h2>
            <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-6 gap-3">
              {captures.slice(0, 12).map((cap, i) => (
                <div key={i} className="bg-white rounded-xl shadow-md overflow-hidden border border-gray-100">
                  <img
                    src={`data:image/jpeg;base64,${cap.image_b64}`}
                    alt={`Capture ${cap.track_id}`}
                    className="w-full aspect-square object-cover"
                  />
                  <div className="p-1.5">
                    <p className="text-xs font-semibold text-gray-700">#{cap.track_id}</p>
                    {cap.emotion && (
                      <p className="text-xs text-gray-500">{EMOTION_EMOJI[cap.emotion] ?? "🫥"} {cap.emotion}</p>
                    )}
                    <p className="text-xs text-gray-300">{cap.cam === "entry-cam" ? "Entry" : "Exit"}</p>
                  </div>
                </div>
              ))}
            </div>
          </section>
        )}

        {/* ── Registration Stats ───────────────────────────────────────────── */}
        <section className="mb-10">
          <h2 className="text-xl font-semibold text-gray-800 mb-4">Registration Stats</h2>

          {loading && !stats && <div className="text-center py-10 text-gray-400">Loading…</div>}
          {!loading && !stats && !error && <div className="text-center py-10 text-gray-400">No data available.</div>}

          {stats && (
            <>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-6 mb-6">
                <div className="bg-white rounded-xl shadow-md p-6 text-center">
                  <p className="text-3xl font-bold text-yellow-600">{stats.total_registered}</p>
                  <p className="text-xs text-gray-400 mt-1">Total Registered</p>
                </div>
                <div className="bg-white rounded-xl shadow-md p-6 text-center">
                  <p className="text-3xl font-bold text-green-600">{stats.currently_inside}</p>
                  <p className="text-xs text-gray-400 mt-1">Currently Inside</p>
                </div>
                <div className="bg-white rounded-xl shadow-md p-6 text-center">
                  <p className="text-3xl font-bold text-indigo-600">{stats.feedback_submissions}</p>
                  <p className="text-xs text-gray-400 mt-1">Feedback Submissions</p>
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="bg-white rounded-xl shadow-md p-6">
                  <h3 className="text-sm font-semibold text-gray-700 mb-3">Registrations by Date</h3>
                  <div className="space-y-2">
                    {Object.entries(stats.date_wise.registrations).map(([date, cnt]) => (
                      <div key={date} className="flex justify-between items-center text-sm">
                        <span className="text-gray-600">{new Date(date).toLocaleDateString(undefined, { month: "short", day: "numeric" })}</span>
                        <span className="font-bold text-blue-600">{cnt}</span>
                      </div>
                    ))}
                  </div>
                </div>
                <div className="bg-white rounded-xl shadow-md p-6">
                  <h3 className="text-sm font-semibold text-gray-700 mb-3">Entries by Date</h3>
                  <div className="space-y-2">
                    {Object.entries(stats.date_wise.entries).map(([date, cnt]) => (
                      <div key={date} className="flex justify-between items-center text-sm">
                        <span className="text-gray-600">{new Date(date).toLocaleDateString(undefined, { month: "short", day: "numeric" })}</span>
                        <span className="font-bold text-blue-600">{cnt}</span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </>
          )}
        </section>

      </div>
    </div>
  );
}