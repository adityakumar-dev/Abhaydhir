"use client"

import { useState, useEffect, useCallback, useRef, type ReactNode } from "react"
import { useRouter } from "next/navigation"
import { supabase } from "@/services/adminAuth"
import { API_BASE_URL } from "@/services/api"

const EVENT_ID = 1

// ── Types ─────────────────────────────────────────────────────────────────────

interface DailySummary {
  Camera: {
    "exit-cam": { Sad: number; Count: number; Happy: number; undetected: number }
    "entry-cam": { unique_count: number; duplicacy_count: number }
  }
  registration: {
    total_groups: number
    total_members: number
    total_individual: number
    total_registration: number
  }
}

interface OnboardingData {
  [date: string]: DailySummary
}

interface TouristStatistics {
  total_tourist_registrations: number
  total_individual_registrations: number
  total_group_registrations: number
  total_members: number
  with_entry_today_registrations: number
  with_entry_today_members: number
  currently_inside_registrations: number
  currently_inside_members: number
}

interface TouristPagination {
  limit: number
  offset: number
  count: number
  total: number
  date: string
  search: string | null
}

interface TodayEntry {
  has_entry_today: boolean
  is_currently_inside: boolean
  total_entries_today: number
  open_entries: number
  last_entry?: { arrival_time: string; departure_time?: string }
}

interface Tourist {
  user_id: number
  name: string
  phone?: string
  is_group: boolean
  group_name?: string
  group_count?: number
  valid_date: string
  today_entry: TodayEntry
}

interface EntryItem {
  item_id: number; arrival_time: string; departure_time?: string
  duration?: string; entry_type?: string; entry_number?: number
}

interface HistoryRecord { entry_date: string; record_id: number; entry_count: number; items?: EntryItem[] }

interface TouristProfile {
  tourist: {
    user_id: number; name: string; phone?: number
    unique_id_type?: string; unique_id?: string
    is_student?: boolean; is_group?: boolean; group_count?: number
    valid_date: string; registered_event_id?: number
    created_at?: string; qr_code?: string
    image_path?: string; unique_id_path?: string
    group_name?: string
  }
  today: {
    has_entry: boolean; entry_record_id?: number
    entry_count: number; open_entries: number
    last_entry_time?: string; entries: EntryItem[]
  }
  history: { last_10_days: HistoryRecord[]; total_records: number }
  message?: string
}

// ── Auth helper ───────────────────────────────────────────────────────────────

async function getAuthHeaders(): Promise<HeadersInit> {
  const { data: { session } } = await supabase.auth.getSession()
  if (!session?.access_token) throw new Error("Not authenticated — please log in again.")
  return {
    Authorization: `Bearer ${session.access_token}`,
    "Content-Type": "application/json",
  }
}

// ── SVG Decorations ───────────────────────────────────────────────────────────

function Rangoli({ size = 200, opacity = 0.08, color1 = "#d97706", color2 = "#16a34a" }: {
  size?: number; opacity?: number; color1?: string; color2?: string
}) {
  return (
    <svg width={size} height={size} viewBox="0 0 200 200" style={{ opacity }}>
      {[0, 45, 90, 135].map(angle => (
        <g key={angle} transform={`rotate(${angle} 100 100)`}>
          <ellipse cx="100" cy="55" rx="8" ry="40" fill={color1} />
          <ellipse cx="100" cy="145" rx="8" ry="40" fill={color2} />
        </g>
      ))}
      {[22.5, 67.5, 112.5, 157.5].map(angle => (
        <g key={angle} transform={`rotate(${angle} 100 100)`}>
          <ellipse cx="100" cy="62" rx="5" ry="32" fill={color2} opacity="0.7" />
        </g>
      ))}
      <circle cx="100" cy="100" r="22" fill={color1} opacity="0.6" />
      <circle cx="100" cy="100" r="12" fill={color2} opacity="0.8" />
      <circle cx="100" cy="100" r="5" fill="#fff" opacity="0.9" />
    </svg>
  )
}

// ── Skeleton loader ───────────────────────────────────────────────────────────

function Skeleton({ h = 80, w = "100%" }: { h?: number; w?: string }) {
  return <div className="skel" style={{ height: h, width: w, borderRadius: 12 }} />
}

// ── Aggregate stat card ───────────────────────────────────────────────────────

function AggCard({ icon, label, value, color = "#d97706", delay = 0 }: {
  icon: ReactNode; label: string; value: number | string; color?: string; delay?: number
}) {
  return (
    <div style={{
      background: "#fff",
      borderRadius: 18,
      padding: "1.25rem 1.4rem",
      boxShadow: "0 4px 28px rgba(180,80,0,0.09)",
      border: `1.5px solid ${color}20`,
      display: "flex",
      alignItems: "center",
      gap: "1rem",
      animation: `fadeUp 0.6s ease both ${delay}ms`,
    }}>
      <div style={{
        width: 50, height: 50, borderRadius: "50%",
        background: `${color}18`,
        display: "flex", alignItems: "center", justifyContent: "center",
        color: color, flexShrink: 0,
      }}>{icon}</div>
      <div>
        <div style={{ fontSize: "1.7rem", fontWeight: 800, color, lineHeight: 1.05 }}>
          {typeof value === "number" ? value.toLocaleString("en-IN") : value}
        </div>
        <div style={{ fontSize: "0.76rem", color: "#6b7280", fontWeight: 500, marginTop: 2 }}>{label}</div>
      </div>
    </div>
  )
}

// ── Section divider with title ────────────────────────────────────────────────

function SectionTitle({ title, icon }: { title: string; icon?: ReactNode }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: "1rem", marginBottom: "1.5rem" }}>
      <div style={{ height: 1, flex: 1, background: "linear-gradient(90deg, #d97706, transparent)" }} />
      <span style={{
        fontFamily: "'Playfair Display', Georgia, serif",
        fontSize: "1.35rem", fontWeight: 800, color: "#78350f",
        display: "flex", alignItems: "center", gap: "0.6rem",
      }}>
        {icon && <span style={{ color: "#d97706", display: "flex", alignItems: "center" }}>{icon}</span>}
        {title}
      </span>
      <div style={{ height: 1, flex: 1, background: "linear-gradient(90deg, transparent, #d97706)" }} />
    </div>
  )
}

// ── SVG Icon helpers ─────────────────────────────────────────────────────────

function IconUsers() {
  return (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
      <circle cx="9" cy="7" r="4"/>
      <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
      <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
    </svg>
  )
}

function IconUser() {
  return (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
      <circle cx="12" cy="7" r="4"/>
    </svg>
  )
}

function IconEye() {
  return (
    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
      <circle cx="12" cy="12" r="3"/>
    </svg>
  )
}

function IconX() {
  return (
    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
      <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
    </svg>
  )
}

function IconClock() {
  return (
    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
    </svg>
  )
}

function IconCalendar() {
  return (
    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
      <line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/>
      <line x1="3" y1="10" x2="21" y2="10"/>
    </svg>
  )
}

function IconId() {
  return (
    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="2" y="7" width="20" height="14" rx="2" ry="2"/>
      <path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/>
    </svg>
  )
}

function IconPhone() {
  return (
    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07A19.5 19.5 0 0 1 4.69 12 19.79 19.79 0 0 1 1.59 3.47 2 2 0 0 1 3.56 1.27h3a2 2 0 0 1 2 1.72c.127.96.361 1.903.7 2.81a2 2 0 0 1-.45 2.11L7.91 8.81a16 16 0 0 0 6.29 6.29l.91-.91a2 2 0 0 1 2.11-.45c.907.339 1.85.573 2.81.7a2 2 0 0 1 1.72 2.02z"/>
    </svg>
  )
}

function IconDownload() {
  return (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
      <polyline points="7 10 12 15 17 10"/>
      <line x1="12" y1="15" x2="12" y2="3"/>
    </svg>
  )
}

function IconTicket() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M2 9a3 3 0 0 1 0 6v2a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-2a3 3 0 0 1 0-6V7a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2Z"/>
      <path d="M13 5v2"/><path d="M13 17v2"/><path d="M13 11v2"/>
    </svg>
  )
}
function IconBarChart2() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/>
      <line x1="6" y1="20" x2="6" y2="14"/><line x1="2" y1="20" x2="22" y2="20"/>
    </svg>
  )
}
function IconCalendarDays() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
      <line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/>
      <line x1="3" y1="10" x2="21" y2="10"/>
      <path d="M8 14h.01"/><path d="M12 14h.01"/><path d="M16 14h.01"/>
      <path d="M8 18h.01"/><path d="M12 18h.01"/>
    </svg>
  )
}
function IconClipboardList() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="8" y="2" width="8" height="4" rx="1" ry="1"/>
      <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/>
      <line x1="9" y1="12" x2="15" y2="12"/><line x1="9" y1="16" x2="15" y2="16"/>
      <path d="M9 8h1"/>
    </svg>
  )
}
function IconTrendingUp() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="22 7 13.5 15.5 8.5 10.5 2 17"/>
      <polyline points="16 7 22 7 22 13"/>
    </svg>
  )
}
function IconLogIn() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/>
      <polyline points="10 17 15 12 10 7"/>
      <line x1="15" y1="12" x2="3" y2="12"/>
    </svg>
  )
}
function IconRepeatArrows() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/>
      <polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/>
    </svg>
  )
}
function IconSmile() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="10"/>
      <path d="M8 13s1.5 2 4 2 4-2 4-2"/>
      <line x1="9" y1="9" x2="9.01" y2="9"/><line x1="15" y1="9" x2="15.01" y2="9"/>
    </svg>
  )
}
function IconFrown() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="10"/>
      <path d="M16 16s-1.5-2-4-2-4 2-4 2"/>
      <line x1="9" y1="9" x2="9.01" y2="9"/><line x1="15" y1="9" x2="15.01" y2="9"/>
    </svg>
  )
}
function IconHelpCircle() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="10"/>
      <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/>
      <line x1="12" y1="17" x2="12.01" y2="17"/>
    </svg>
  )
}
function IconAlertTriangle() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
      <line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>
    </svg>
  )
}
function IconCameraLens() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/>
      <circle cx="12" cy="13" r="4"/>
    </svg>
  )
}
function IconSentiment() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
      <line x1="9" y1="10" x2="9.01" y2="10"/><line x1="15" y1="10" x2="15.01" y2="10"/>
      <path d="M9.5 14.5s1 1.5 2.5 1.5 2.5-1.5 2.5-1.5"/>
    </svg>
  )
}

// ── Profile Dialog ────────────────────────────────────────────────────────────

function ProfileDialog({ userId, onClose }: { userId: number; onClose: () => void }) {
  const [profile, setProfile] = useState<TouristProfile | null>(null)
  const [loading, setLoading]   = useState(true)
  const [error, setError]       = useState<string | null>(null)
  const [imgError, setImgError] = useState(false)
  const [photoOpen, setPhotoOpen] = useState(false)
  const overlayRef = useRef<HTMLDivElement>(null)

  const fetchProfile = useCallback(async () => {
    setLoading(true); setError(null)
    try {
      const headers = await getAuthHeaders()
      const res = await fetch(`${API_BASE_URL}/profile/${userId}?event_id=${EVENT_ID}`, { headers })
      if (!res.ok) {
        const err = await res.json().catch(() => null)
        throw new Error(err?.detail ?? `Request failed (${res.status})`)
      }
      setProfile(await res.json())
    } catch (e: any) { setError(e.message) }
    finally { setLoading(false) }
  }, [userId])

  useEffect(() => {
    fetchProfile()
    document.body.style.overflow = "hidden"
    return () => { document.body.style.overflow = "" }
  }, [fetchProfile])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") onClose() }
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  }, [onClose])

  const fmtDate = (d?: string) =>
    d ? new Date(d + "T00:00:00").toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short", year: "numeric" }) : "—"

  return (
    <>
      {/* Photo lightbox */}
      {photoOpen && !imgError && profile?.tourist?.image_path && (
        <div
          onClick={() => setPhotoOpen(false)}
          style={{
            position: "fixed", inset: 0, zIndex: 1100,
            background: "rgba(0,0,0,0.93)", backdropFilter: "blur(10px)",
            display: "flex", alignItems: "center", justifyContent: "center",
            cursor: "zoom-out", animation: "fadeIn 0.15s ease",
          }}
        >
          <img
            src={profile.tourist.image_path}
            alt={profile.tourist.name}
            style={{ maxWidth: "88vw", maxHeight: "88vh", borderRadius: 20, objectFit: "contain", boxShadow: "0 32px 100px rgba(0,0,0,0.7)" }}
          />
          <button
            onClick={e => { e.stopPropagation(); setPhotoOpen(false) }}
            style={{
              position: "absolute", top: 22, right: 22,
              background: "rgba(255,255,255,0.13)", border: "1px solid rgba(255,255,255,0.22)",
              borderRadius: "50%", width: 44, height: 44, cursor: "pointer", color: "#fff",
              display: "flex", alignItems: "center", justifyContent: "center",
            }}
          ><IconX /></button>
        </div>
      )}
      <div
        ref={overlayRef}
        onClick={e => { if (e.target === overlayRef.current) onClose() }}
        style={{
          position: "fixed", inset: 0, zIndex: 1000,
          background: "rgba(0,0,0,0.55)", backdropFilter: "blur(6px)",
          display: "flex", alignItems: "center", justifyContent: "center",
          padding: "1rem", animation: "fadeIn 0.2s ease",
        }}
      >
      <div style={{
        background: "#fff", borderRadius: 24, width: "100%", maxWidth: 660,
        maxHeight: "90vh", overflowY: "auto",
        boxShadow: "0 30px 90px rgba(0,0,0,0.35)",
        animation: "slideUp 0.28s ease",
      }}>
        {/* Dialog header */}
        <div style={{
          background: "linear-gradient(100deg, #92400e 0%, #b45309 60%, #d97706 100%)",
          borderRadius: "24px 24px 0 0", padding: "1.2rem 1.5rem",
          display: "flex", alignItems: "center", justifyContent: "space-between",
          position: "sticky", top: 0, zIndex: 10,
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: "0.75rem" }}>
            <div style={{ width: 34, height: 34, borderRadius: 10, background: "rgba(255,255,255,0.18)", display: "flex", alignItems: "center", justifyContent: "center", color: "#fff", flexShrink: 0 }}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
            </div>
            <div>
              <div style={{ fontFamily: "'Playfair Display', Georgia, serif", fontWeight: 800, color: "#fff", fontSize: "1rem" }}>Visitor Profile</div>
              <div style={{ fontSize: "0.71rem", color: "rgba(255,255,255,0.6)", letterSpacing: "0.07em" }}>ID #{userId} · Spring Festival 2026</div>
            </div>
          </div>
          <button onClick={onClose} style={{
            background: "rgba(255,255,255,0.18)", border: "none", borderRadius: "50%",
            width: 36, height: 36, cursor: "pointer", color: "#fff",
            display: "flex", alignItems: "center", justifyContent: "center",
          }}><IconX /></button>
        </div>

        <div style={{ padding: "1.75rem" }}>
          {/* Loading */}
          {loading && (
            <div style={{ display: "flex", flexDirection: "column", gap: "0.9rem" }}>
              <div style={{ display: "flex", gap: "1rem", alignItems: "center" }}>
                <Skeleton h={80} w="80px" />
                <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: "0.5rem" }}>
                  <Skeleton h={22} /><Skeleton h={16} /><Skeleton h={16} />
                </div>
              </div>
            </div>
          )}

          {/* Error */}
          {!loading && error && (
            <div style={{ textAlign: "center", padding: "2rem" }}>
              <div style={{ marginBottom: "0.75rem", color: "#dc2626", display: "flex", justifyContent: "center" }}><IconAlertTriangle /></div>
              <div style={{ fontWeight: 700, color: "#dc2626", marginBottom: "0.5rem" }}>{error}</div>
              <button onClick={fetchProfile} style={{
                marginTop: "0.75rem", padding: "0.5rem 1.4rem", borderRadius: 50,
                background: "#dc2626", color: "#fff", border: "none", cursor: "pointer",
                fontWeight: 700, fontSize: "0.87rem",
              }}>↺ Retry</button>
            </div>
          )}

          {/* Profile content */}
          {!loading && !error && profile && (() => {
            const t = profile.tourist
            return (
              <>
                {/* Identity */}
                <div style={{
                  display: "flex", gap: "1.25rem", alignItems: "flex-start",
                  background: "linear-gradient(135deg, #fffbeb, #fef3c7)",
                  borderRadius: 18, padding: "1.25rem",
                  border: "1.5px solid rgba(251,191,36,0.28)", marginBottom: "1.25rem",
                }}>
                  {/* Photo */}
                  <div style={{ flexShrink: 0 }}>
                    {t.image_path && !imgError ? (
                      <img src={t.image_path} alt={t.name} onError={() => setImgError(true)}
                        onClick={() => setPhotoOpen(true)}
                        style={{ width: 88, height: 88, borderRadius: 16, objectFit: "cover", border: "3px solid rgba(217,119,6,0.3)", cursor: "zoom-in" }} />
                    ) : (
                      <div style={{
                        width: 88, height: 88, borderRadius: 16,
                        background: "linear-gradient(135deg, #d97706, #b45309)",
                        display: "flex", alignItems: "center", justifyContent: "center",
                        color: "#fff", fontWeight: 800, fontSize: "2rem",
                        fontFamily: "'Playfair Display', Georgia, serif",
                      }}>{t.name?.charAt(0)?.toUpperCase() ?? "?"}</div>
                    )}
                  </div>
                  {/* Info */}
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontFamily: "'Playfair Display', Georgia, serif", fontSize: "1.2rem", fontWeight: 800, color: "#78350f", marginBottom: "0.4rem" }}>{t.name}</div>
                    <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap", marginBottom: "0.75rem" }}>
                      <span style={{
                        display: "inline-flex", alignItems: "center", gap: 5,
                        fontSize: "0.72rem", fontWeight: 700, padding: "0.22rem 0.75rem", borderRadius: 50,
                        background: t.is_group ? "#fef3c7" : "#ecfdf5",
                        color: t.is_group ? "#92400e" : "#15803d",
                        border: `1px solid ${t.is_group ? "#fde68a" : "#bbf7d0"}`,
                      }}>
                        {t.is_group ? <IconUsers /> : <IconUser />}
                        {t.is_group ? `Group · ${t.group_count ?? 1} members` : "Individual"}
                      </span>
                      {t.is_student && (
                        <span style={{ fontSize: "0.72rem", fontWeight: 700, padding: "0.22rem 0.75rem", borderRadius: 50, background: "#eff6ff", color: "#1d4ed8", border: "1px solid #bfdbfe" }}>Student</span>
                      )}
                    </div>
                    <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "0.35rem" }}>
                      {[
                        { icon: <IconPhone />, val: t.phone ? String(t.phone) : "—" },
                        { icon: <IconCalendar />, val: fmtDate(t.valid_date) },
                        t.unique_id_type ? { icon: <IconId />, val: `${t.unique_id_type}: ${t.unique_id ?? "—"}` } : null,
                        t.group_name    ? { icon: null, val: `Group: ${t.group_name}` } : null,
                      ].filter(Boolean).map((item, i) => (
                        <div key={i} style={{ display: "flex", alignItems: "center", gap: 6, fontSize: "0.79rem", color: "#6b7280" }}>
                          <span style={{ color: "#d97706", flexShrink: 0 }}>{item!.icon}</span>
                          <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{item!.val}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>

                {/* ID document inline */}
                {t.unique_id_path && (
                  <div style={{ marginTop: "1.25rem" }}>
                    <div style={{ fontSize: "0.7rem", fontWeight: 700, letterSpacing: "0.1em", textTransform: "uppercase", color: "#92400e", marginBottom: "0.6rem", display: "flex", alignItems: "center", gap: 5 }}>
                      <IconId /> ID Document
                    </div>
                    <div style={{ borderRadius: 16, overflow: "hidden", border: "1.5px solid #fde68a", background: "#fffbeb" }}>
                      <img
                        src={t.unique_id_path}
                        alt="ID Document"
                        style={{ width: "100%", display: "block", maxHeight: 280, objectFit: "contain" }}
                      />
                    </div>
                  </div>
                )}
              </>
            )
          })()}
        </div>
      </div>
    </div>
    </>
  )
}

// ── Main Dashboard Page ───────────────────────────────────────────────────────

export default function SpringFestival2026Page() {
  const router = useRouter()

  // ── Onboarding state ───────────────────────────────────────────────────────
  const [onboarding, setOnboarding] = useState<OnboardingData | null>(null)
  const [onboardingLoading, setOnboardingLoading] = useState(true)
  const [onboardingError, setOnboardingError] = useState<string | null>(null)
  const [activeDay, setActiveDay] = useState("2026-02-27")

  // ── Tourists state ─────────────────────────────────────────────────────────
  const [tourists, setTourists] = useState<Tourist[]>([])
  const [statistics, setStatistics] = useState<TouristStatistics | null>(null)
  const [pagination, setPagination] = useState<TouristPagination | null>(null)
  const [touristsLoading, setTouristsLoading] = useState(true)
  const [touristsError, setTouristsError] = useState<string | null>(null)

  // ── Filter state ───────────────────────────────────────────────────────────
  const [limit, setLimit] = useState(20)
  const [dateFilter, setDateFilter] = useState("2026-02-27")
  const [search, setSearch] = useState("")
  const [searchInput, setSearchInput] = useState("")
  const [onlyActive, setOnlyActive] = useState(false)
  const [page, setPage] = useState(0)

  // ── Profile dialog state ───────────────────────────────────────────────────
  const [profileUserId, setProfileUserId] = useState<number | null>(null)

  // ── Fetch onboarding ───────────────────────────────────────────────────────

  const fetchOnboarding = useCallback(async () => {
    setOnboardingLoading(true)
    setOnboardingError(null)
    try {
      const headers = await getAuthHeaders()
      const res = await fetch(`${API_BASE_URL}/admin/onboarding`, {
        method: "POST",
        headers,
        body: JSON.stringify({ event_id: String(EVENT_ID) }),   // backend expects str
      })
      if (!res.ok) {
        const err = await res.json().catch(() => null)
        throw new Error(err?.detail ?? `Request failed (${res.status})`)
      }
      const data = await res.json()
      // API returns [{ get_event_full_summary: { "2026-02-27": { ... }, ... } }]
      const raw: OnboardingData =
        Array.isArray(data)
          ? data[0]?.get_event_full_summary ?? data[0]
          : data?.get_event_full_summary ?? data
      setOnboarding(raw)
      const firstDay = Object.keys(raw).sort()[0]
      if (firstDay) setActiveDay(firstDay)
    } catch (e: any) {
      setOnboardingError(e.message)
    } finally {
      setOnboardingLoading(false)
    }
  }, [])

  useEffect(() => { fetchOnboarding() }, [fetchOnboarding])

  // ── Fetch tourists ─────────────────────────────────────────────────────────

  const fetchTourists = useCallback(async (
    date: string, searchVal: string, active: boolean, offset: number, lim: number,
  ) => {
    setTouristsLoading(true)
    setTouristsError(null)
    try {
      const headers = await getAuthHeaders()
      const params = new URLSearchParams({
        limit: String(lim),
        offset: String(offset),
        date,
        only_active: String(active),
      })
      if (searchVal.trim()) params.set("search", searchVal.trim())
      const res = await fetch(`${API_BASE_URL}/tourists/event/${EVENT_ID}?${params}`, { headers })
      if (!res.ok) {
        const err = await res.json().catch(() => null)
        throw new Error(err?.detail ?? `Request failed (${res.status})`)
      }
      const data = await res.json()
      setTourists(data.tourists ?? [])
      setStatistics(data.statistics ?? null)
      setPagination(data.pagination ?? null)
    } catch (e: any) {
      setTouristsError(e.message)
    } finally {
      setTouristsLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchTourists(dateFilter, search, onlyActive, page * limit, limit)
  }, [dateFilter, search, onlyActive, page, limit, fetchTourists])

  const applySearch = () => {
    setSearch(searchInput)
    setPage(0)
  }

  const resetFilters = () => {
    setSearchInput("")
    setSearch("")
    setOnlyActive(false)
    setPage(0)
  }

  // ── Aggregated totals ──────────────────────────────────────────────────────

  const totals = onboarding
    ? Object.values(onboarding).reduce(
        (acc, d) => ({
          registrations: acc.registrations + d.registration.total_registration,
          members: acc.members + d.registration.total_members,
          groups: acc.groups + d.registration.total_groups,
          individuals: acc.individuals + d.registration.total_individual,
          footfall: acc.footfall + d.Camera["exit-cam"].Count,
          unique: acc.unique + d.Camera["entry-cam"].unique_count,
          reEntry: acc.reEntry + d.Camera["entry-cam"].duplicacy_count,
          happy: acc.happy + d.Camera["exit-cam"].Happy,
          sad: acc.sad + d.Camera["exit-cam"].Sad,
          undetected: acc.undetected + d.Camera["exit-cam"].undetected,
        }),
        { registrations: 0, members: 0, groups: 0, individuals: 0, footfall: 0, unique: 0, reEntry: 0, happy: 0, sad: 0, undetected: 0 }
      )
    : null

  const days = onboarding ? Object.keys(onboarding).sort() : []
  const dayData = onboarding?.[activeDay] ?? null

  const fmtDate = (d: string) =>
    new Date(d + "T00:00:00").toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short" })

  const totalPages = pagination ? Math.ceil(pagination.total / limit) : 0

  const exportCSV = () => {
    if (!onboarding || !totals) return
    const fmtFull = (d: string) =>
      new Date(d + "T00:00:00").toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" })
    const sortedDays = Object.keys(onboarding).sort()
    const lines: string[] = []
    lines.push("Spring Festival 2026 — Event Report")
    lines.push(`Generated: ${new Date().toLocaleDateString("en-IN", { day: "numeric", month: "long", year: "numeric" })}`)
    lines.push("")
    // ── 3-day combined totals ──
    lines.push("=== 3-DAY COMBINED TOTALS ===")
    lines.push("Metric,Value")
    lines.push(`Total Registrations,${totals.registrations}`)
    lines.push(`Total Members,${totals.members}`)
    lines.push(`Group Registrations,${totals.groups}`)
    lines.push(`Individual Registrations,${totals.individuals}`)
    lines.push(`Total Footfall (Exit Cam),${totals.footfall}`)
    lines.push(`Unique Entries (Entry Cam),${totals.unique}`)
    lines.push(`Re-entries (Entry Cam),${totals.reEntry}`)
    lines.push(`Happy Exits,${totals.happy}`)
    lines.push(`Sad Exits,${totals.sad}`)
    lines.push(`Undetected Exits,${totals.undetected}`)
    lines.push("")
    // ── day-wise breakdown ──
    lines.push("=== DAY-WISE BREAKDOWN ===")
    lines.push("Date,Registrations,Members,Groups,Individuals,Unique Entries,Re-entries,Exit Footfall,Happy,Sad,Undetected")
    sortedDays.forEach((d, i) => {
      const day = onboarding[d]
      lines.push([
        `${fmtFull(d)} (Day ${i + 1})`,
        day.registration.total_registration,
        day.registration.total_members,
        day.registration.total_groups,
        day.registration.total_individual,
        day.Camera["entry-cam"].unique_count,
        day.Camera["entry-cam"].duplicacy_count,
        day.Camera["exit-cam"].Count,
        day.Camera["exit-cam"].Happy,
        day.Camera["exit-cam"].Sad,
        day.Camera["exit-cam"].undetected,
      ].join(","))
    })
    lines.push([
      "TOTAL (3-Day)",
      totals.registrations, totals.members, totals.groups, totals.individuals,
      totals.unique, totals.reEntry, totals.footfall,
      totals.happy, totals.sad, totals.undetected,
    ].join(","))
    const blob = new Blob([lines.join("\n")], { type: "text/csv;charset=utf-8;" })
    const url = URL.createObjectURL(blob)
    const a = document.createElement("a")
    a.href = url
    a.download = "spring-festival-2026-report.csv"
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400;0,700;0,800;1,400&family=Lato:wght@300;400;500;700&display=swap');
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Lato', sans-serif; }

        @keyframes fadeUp {
          from { opacity: 0; transform: translateY(22px); }
          to   { opacity: 1; transform: translateY(0); }
        }
        @keyframes spin-slow    { to { transform: rotate(360deg); } }
        @keyframes spin-reverse { to { transform: rotate(-360deg); } }
        @keyframes fadeIn   { from { opacity: 0; } to { opacity: 1; } }
        @keyframes slideUp  { from { opacity: 0; transform: translateY(40px); } to { opacity: 1; transform: translateY(0); } }
        @keyframes shimmer {
          0%   { background-position: -200% 0; }
          100% { background-position:  200% 0; }
        }
        @keyframes pulse-badge {
          0%, 100% { box-shadow: 0 0 0 0 rgba(22,163,74,0.4); }
          50%       { box-shadow: 0 0 0 6px rgba(22,163,74,0); }
        }

        .skel {
          background: linear-gradient(90deg, #f3e8d0 25%, #fde68a 50%, #f3e8d0 75%);
          background-size: 200% 100%;
          animation: shimmer 1.6s infinite;
        }

        .day-tab {
          cursor: pointer;
          padding: 0.6rem 1.5rem;
          border-radius: 50px;
          font-weight: 600;
          font-size: 0.87rem;
          border: 1.5px solid transparent;
          transition: all 0.22s;
          white-space: nowrap;
          letter-spacing: 0.02em;
        }
        .day-tab:hover { border-color: #d97706; color: #d97706 !important; }

        .sf-btn {
          padding: 0.5rem 1.15rem;
          border-radius: 50px;
          font-weight: 600;
          font-size: 0.87rem;
          cursor: pointer;
          border: 1.5px solid transparent;
          transition: all 0.2s;
          display: inline-flex; align-items: center; gap: 0.35rem;
        }
        .sf-btn:hover  { filter: brightness(1.08); transform: translateY(-1px); }
        .sf-btn:active { transform: translateY(0); }
        .sf-btn:disabled { opacity: 0.45; cursor: default; transform: none; }

        .t-row { transition: background 0.15s; }
        .t-row:hover { background: #fffbeb !important; }

        .stat-chip {
          border-radius: 12px;
          padding: 0.85rem 1rem;
          text-align: center;
          transition: transform 0.2s, box-shadow 0.2s;
        }
        .stat-chip:hover { transform: translateY(-3px); box-shadow: 0 10px 30px rgba(0,0,0,0.1); }

        .view-btn {
          padding: 0.28rem 0.65rem; border-radius: 8px; font-size: 0.73rem;
          font-weight: 700; cursor: pointer; border: 1.5px solid #e5e7eb;
          background: #fff; color: #6b7280; display: inline-flex; align-items: center; gap: 4px;
          transition: all 0.18s; white-space: nowrap;
        }
        .view-btn:hover {
          background: linear-gradient(135deg, #d97706, #b45309);
          color: #fff; border-color: transparent;
          box-shadow: 0 4px 14px rgba(217,119,6,0.35); transform: translateY(-1px);
        }
        input:focus { outline: none; border-color: #d97706 !important; box-shadow: 0 0 0 3px rgba(217,119,6,0.12); }
        select:focus { outline: none; border-color: #d97706 !important; }

        @media (max-width: 640px) {
          .overview-grid { grid-template-columns: repeat(2, 1fr) !important; }
          .day-grid { grid-template-columns: 1fr !important; }
          .table-header, .t-row { grid-template-columns: 40px 1fr 90px 60px !important; }
          .col-phone { display: none !important; }
          .filter-bar { flex-direction: column !important; }
        }
      `}</style>

      {profileUserId !== null && (
        <ProfileDialog userId={profileUserId} onClose={() => setProfileUserId(null)} />
      )}

      <div style={{ minHeight: "100vh", background: "linear-gradient(160deg, #fffbeb 0%, #fef9f0 45%, #f0fdf4 100%)" }}>

        {/* ══════════════════════════════════════════
            HEADER
        ══════════════════════════════════════════ */}
        <header style={{
          background: "linear-gradient(100deg, #92400e 0%, #b45309 55%, #d97706 100%)",
          position: "relative",
          overflow: "hidden",
        }}>
          {/* Rainbow top stripe */}
          <div style={{ height: 3, background: "linear-gradient(90deg, #fbbf24, #16a34a, #fbbf24, #dc2626, #fbbf24)" }} />

          {/* Rangoli accents */}
          <div style={{ position: "absolute", right: -50, top: "50%", transform: "translateY(-50%)", animation: "spin-slow 60s linear infinite", pointerEvents: "none" }}>
            <Rangoli size={210} opacity={0.11} color1="#fbbf24" color2="#fff" />
          </div>
          <div style={{ position: "absolute", left: -40, top: "50%", transform: "translateY(-50%)", animation: "spin-reverse 80s linear infinite", pointerEvents: "none" }}>
            <Rangoli size={160} opacity={0.07} color1="#fff" color2="#fbbf24" />
          </div>

          <div style={{
            maxWidth: 1340, margin: "0 auto", padding: "1.1rem 1.5rem",
            display: "flex", alignItems: "center", justifyContent: "space-between",
            position: "relative", zIndex: 2, flexWrap: "wrap", gap: "0.75rem",
          }}>
            {/* Title block */}
            <div>
              <div style={{ display: "flex", alignItems: "center", gap: "0.65rem", flexWrap: "wrap" }}>
                <span style={{
                  fontFamily: "'Playfair Display', Georgia, serif",
                  fontSize: "clamp(1.1rem, 3vw, 1.5rem)", fontWeight: 800, color: "#fff",
                }}>Spring Festival 2026</span>
                <span style={{
                  fontSize: "0.72rem", fontWeight: 700, letterSpacing: "0.1em", textTransform: "uppercase",
                  background: "rgba(255,255,255,0.18)", border: "1px solid rgba(255,255,255,0.35)",
                  color: "rgba(255,255,255,0.9)", padding: "0.2rem 0.75rem", borderRadius: 50,
                  display: "inline-flex", alignItems: "center", gap: "0.35rem",
                }}>
                  <svg width="8" height="8" viewBox="0 0 8 8"><circle cx="4" cy="4" r="4" fill="#4ade80"/></svg>
                  COMPLETED
                </span>
              </div>
              <div style={{ fontSize: "0.78rem", color: "rgba(255,255,255,0.6)", letterSpacing: "0.08em", textTransform: "uppercase", marginTop: "0.2rem" }}>
                Event Dashboard · Feb 27 – Mar 1, 2026 · Lok Bhavan Dehradun
              </div>
            </div>

            {/* Back button */}
            <button
              onClick={() => router.back()}
              className="sf-btn"
              style={{ background: "rgba(255,255,255,0.15)", borderColor: "rgba(255,255,255,0.4)", color: "#fff" }}
            >
              ← Back
            </button>
          </div>
        </header>

        <div style={{ maxWidth: 1340, margin: "0 auto", padding: "2.5rem 1.5rem 5rem" }}>

          {/* ══════════════════════════════════════════
              SECTION 1 — 3-DAY OVERVIEW SUMMARY
          ══════════════════════════════════════════ */}
          <div style={{ marginBottom: "3rem" }}>
            <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: "1rem", marginBottom: "1.5rem" }}>
              <div style={{ flex: 1 }}><SectionTitle title="3-Day Event Overview" icon={<IconBarChart2 />} /></div>
              {totals && (
                <button
                  onClick={exportCSV}
                  className="sf-btn"
                  style={{ background: "linear-gradient(135deg, #d97706, #b45309)", color: "#fff", borderColor: "transparent", boxShadow: "0 4px 18px rgba(217,119,6,0.3)", flexShrink: 0, marginTop: 2 }}
                >
                  <IconDownload /> Export CSV
                </button>
              )}
            </div>

            {onboardingLoading ? (
              <div className="overview-grid" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(190px, 1fr))", gap: "1rem", marginTop: "-0.75rem" }}>
                {[...Array(10)].map((_, i) => <Skeleton key={i} h={90} />)}
              </div>
            ) : onboardingError ? (
              <div style={{
                background: "#fef2f2", border: "1.5px solid #fca5a5",
                borderRadius: 14, padding: "1.2rem 1.5rem",
                color: "#dc2626", display: "flex", alignItems: "center", gap: "1rem", flexWrap: "wrap",
              }}>
                <span style={{ display: "inline-flex", alignItems: "center", gap: "0.5rem" }}><IconAlertTriangle /> {onboardingError}</span>
                <button onClick={fetchOnboarding} className="sf-btn"
                  style={{ background: "#dc2626", color: "#fff", borderColor: "transparent" }}>
                  ↺ Retry
                </button>
              </div>
            ) : totals ? (
              <>
                {/* Registration aggregate */}
                <div style={{ marginBottom: "0.75rem" }}>
                  <p style={{ fontSize: "0.72rem", fontWeight: 700, letterSpacing: "0.12em", textTransform: "uppercase", color: "#d97706", marginBottom: "0.75rem", display: "flex", alignItems: "center", gap: "0.4rem" }}>
                    <IconClipboardList /> Registration Totals
                  </p>
                  <div className="overview-grid" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(190px, 1fr))", gap: "1rem" }}>
                    <AggCard icon={<IconTicket />} label="Total Registrations" value={totals.registrations} color="#d97706" delay={0} />
                    <AggCard icon={<IconUsers />} label="Total Members" value={totals.members} color="#b45309" delay={60} />
                    <AggCard icon={<IconClipboardList />} label="Group Registrations" value={totals.groups} color="#92400e" delay={120} />
                    <AggCard icon={<IconUser />} label="Individual Registrations" value={totals.individuals} color="#78350f" delay={180} />
                  </div>
                </div>

                {/* Camera aggregate */}
                <div>
                  <p style={{ fontSize: "0.72rem", fontWeight: 700, letterSpacing: "0.12em", textTransform: "uppercase", color: "#16a34a", marginBottom: "0.75rem", marginTop: "1.25rem", display: "flex", alignItems: "center", gap: "0.4rem" }}>
                    <IconCameraLens /> Camera & Footfall Totals
                  </p>
                  <div className="overview-grid" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(190px, 1fr))", gap: "1rem" }}>
                    <AggCard icon={<IconTrendingUp />} label="Total Footfall (Exit Cam)" value={totals.footfall} color="#16a34a" delay={0} />
                    <AggCard icon={<IconLogIn />} label="Unique Entries" value={totals.unique} color="#15803d" delay={60} />
                    <AggCard icon={<IconRepeatArrows />} label="Re-entries" value={totals.reEntry} color="#0ea5e9" delay={120} />
                    <AggCard icon={<IconSmile />} label="Happy Exits" value={totals.happy} color="#22c55e" delay={180} />
                    <AggCard icon={<IconFrown />} label="Sad Exits" value={totals.sad} color="#ef4444" delay={240} />
                    <AggCard icon={<IconHelpCircle />} label="Undetected" value={totals.undetected} color="#f59e0b" delay={300} />
                  </div>
                </div>
              </>
            ) : null}
          </div>

          {/* ══════════════════════════════════════════
              SECTION 2 — DAY-WISE BREAKDOWN
          ══════════════════════════════════════════ */}
          {!onboardingLoading && !onboardingError && onboarding && (
            <div style={{ marginBottom: "3rem", animation: "fadeUp 0.65s ease both 0.25s" }}>
              <SectionTitle title="Day-wise Breakdown" icon={<IconCalendarDays />} />

              {/* Day tabs */}
              <div style={{ display: "flex", gap: "0.75rem", marginBottom: "1.5rem", overflowX: "auto", paddingBottom: 4, flexWrap: "wrap" }}>
                {days.map(d => (
                  <button
                    key={d}
                    className="day-tab"
                    onClick={() => setActiveDay(d)}
                    style={{
                      background: activeDay === d ? "linear-gradient(135deg, #d97706, #b45309)" : "#fff",
                      color: activeDay === d ? "#fff" : "#6b7280",
                      borderColor: activeDay === d ? "transparent" : "#e5e7eb",
                      boxShadow: activeDay === d ? "0 4px 18px rgba(217,119,6,0.35)" : "0 2px 8px rgba(0,0,0,0.05)",
                    }}
                  >
                    {fmtDate(d)}
                  </button>
                ))}
              </div>

              {/* Day detail cards */}
              {dayData && (
                <div className="day-grid" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(340px, 1fr))", gap: "1.25rem" }}>

                  {/* ── Registration card ── */}
                  <div style={{
                    background: "#fff", borderRadius: 22, padding: "1.75rem",
                    boxShadow: "0 8px 36px rgba(180,80,0,0.10)",
                    border: "1.5px solid rgba(251,191,36,0.22)",
                    animation: "fadeUp 0.5s ease both",
                  }}>
                    <div style={{ display: "flex", alignItems: "center", gap: "0.85rem", marginBottom: "1.4rem" }}>
                      <div style={{
                        width: 44, height: 44, borderRadius: "50%",
                        background: "linear-gradient(135deg, #fbbf24, #d97706)",
                        display: "flex", alignItems: "center", justifyContent: "center", color: "#fff", flexShrink: 0,
                      }}><IconClipboardList /></div>
                      <div>
                        <div style={{ fontFamily: "'Playfair Display', Georgia, serif", fontWeight: 700, fontSize: "1.05rem", color: "#78350f" }}>Registrations</div>
                        <div style={{ fontSize: "0.73rem", color: "#9ca3af" }}>{fmtDate(activeDay)}</div>
                      </div>
                    </div>

                    <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "0.75rem" }}>
                      {[
                        { label: "Total Registrations", val: dayData.registration.total_registration, color: "#d97706" },
                        { label: "Total Members",       val: dayData.registration.total_members,      color: "#b45309" },
                        { label: "Group Bookings",      val: dayData.registration.total_groups,       color: "#92400e" },
                        { label: "Individual",          val: dayData.registration.total_individual,   color: "#16a34a" },
                      ].map(({ label, val, color }) => (
                        <div key={label} className="stat-chip"
                          style={{ background: `${color}0c`, border: `1px solid ${color}22` }}>
                          <div style={{ fontSize: "1.6rem", fontWeight: 800, color }}>{val.toLocaleString("en-IN")}</div>
                          <div style={{ fontSize: "0.71rem", color: "#6b7280", marginTop: 3 }}>{label}</div>
                        </div>
                      ))}
                    </div>

                    {/* Members per registration bar */}
                    {dayData.registration.total_registration > 0 && (
                      <div style={{ marginTop: "1.25rem", paddingTop: "1rem", borderTop: "1px solid #f3f4f6" }}>
                        <div style={{ display: "flex", justifyContent: "space-between", fontSize: "0.76rem", color: "#6b7280", marginBottom: 6 }}>
                          <span>Avg. members per registration</span>
                          <span style={{ fontWeight: 700, color: "#d97706" }}>
                            {(dayData.registration.total_members / dayData.registration.total_registration).toFixed(1)}x
                          </span>
                        </div>
                        <div style={{ height: 7, borderRadius: 99, background: "#f3e8d0", overflow: "hidden" }}>
                          <div style={{
                            width: `${Math.min(100, (dayData.registration.total_members / dayData.registration.total_registration / 10) * 100)}%`,
                            height: "100%",
                            background: "linear-gradient(90deg, #fbbf24, #d97706)",
                            borderRadius: 99,
                          }} />
                        </div>
                      </div>
                    )}
                  </div>

                  {/* ── Entry Camera card ── */}
                  <div style={{
                    background: "#fff", borderRadius: 22, padding: "1.75rem",
                    boxShadow: "0 8px 36px rgba(21,128,61,0.08)",
                    border: "1.5px solid rgba(22,163,74,0.2)",
                    animation: "fadeUp 0.5s ease both 0.08s",
                  }}>
                    <div style={{ display: "flex", alignItems: "center", gap: "0.85rem", marginBottom: "1.4rem" }}>
                      <div style={{
                        width: 44, height: 44, borderRadius: "50%",
                        background: "linear-gradient(135deg, #16a34a, #15803d)",
                        display: "flex", alignItems: "center", justifyContent: "center", color: "#fff", flexShrink: 0,
                      }}><IconCameraLens /></div>
                      <div>
                        <div style={{ fontFamily: "'Playfair Display', Georgia, serif", fontWeight: 700, fontSize: "1.05rem", color: "#14532d" }}>Entry Camera</div>
                        <div style={{ fontSize: "0.73rem", color: "#9ca3af" }}>Face recognition · {fmtDate(activeDay)}</div>
                      </div>
                    </div>

                    <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "0.75rem", marginBottom: "1.25rem" }}>
                      {[
                        { label: "Unique Entries", val: dayData.Camera["entry-cam"].unique_count, color: "#16a34a" },
                        { label: "Re-entries (Dup.)", val: dayData.Camera["entry-cam"].duplicacy_count, color: "#0ea5e9" },
                      ].map(({ label, val, color }) => (
                        <div key={label} className="stat-chip"
                          style={{ background: `${color}0c`, border: `1px solid ${color}22` }}>
                          <div style={{ fontSize: "1.8rem", fontWeight: 800, color }}>{val.toLocaleString("en-IN")}</div>
                          <div style={{ fontSize: "0.71rem", color: "#6b7280", marginTop: 3 }}>{label}</div>
                        </div>
                      ))}
                    </div>

                    {/* Unique ratio bar */}
                    {(() => {
                      const total = dayData.Camera["entry-cam"].unique_count + dayData.Camera["entry-cam"].duplicacy_count
                      const pct = total > 0 ? Math.round((dayData.Camera["entry-cam"].unique_count / total) * 100) : 0
                      return (
                        <>
                          <div style={{ display: "flex", justifyContent: "space-between", fontSize: "0.76rem", color: "#6b7280", marginBottom: 6 }}>
                            <span>Unique visitor ratio</span>
                            <span style={{ fontWeight: 700, color: "#16a34a" }}>{pct}%</span>
                          </div>
                          <div style={{ height: 8, borderRadius: 99, background: "#e5e7eb", overflow: "hidden" }}>
                            <div style={{
                              width: `${pct}%`, height: "100%",
                              background: "linear-gradient(90deg, #16a34a, #4ade80)",
                              borderRadius: 99, transition: "width 1s ease",
                            }} />
                          </div>
                          <div style={{ display: "flex", justifyContent: "space-between", marginTop: 6, fontSize: "0.71rem", color: "#9ca3af" }}>
                            <span>Total scans: {total.toLocaleString("en-IN")}</span>
                            <span style={{ color: "#0ea5e9" }}>Re-entries: {(100 - pct)}%</span>
                          </div>
                        </>
                      )
                    })()}
                  </div>

                  {/* ── Exit Camera / Sentiment card ── */}
                  <div style={{
                    background: "#fff", borderRadius: 22, padding: "1.75rem",
                    boxShadow: "0 8px 36px rgba(99,102,241,0.08)",
                    border: "1.5px solid rgba(99,102,241,0.18)",
                    animation: "fadeUp 0.5s ease both 0.16s",
                  }}>
                    <div style={{ display: "flex", alignItems: "center", gap: "0.85rem", marginBottom: "1.4rem" }}>
                      <div style={{
                        width: 44, height: 44, borderRadius: "50%",
                        background: "linear-gradient(135deg, #6366f1, #4338ca)",
                        display: "flex", alignItems: "center", justifyContent: "center", color: "#fff", flexShrink: 0,
                      }}><IconSentiment /></div>
                      <div>
                        <div style={{ fontFamily: "'Playfair Display', Georgia, serif", fontWeight: 700, fontSize: "1.05rem", color: "#312e81" }}>Exit Camera · Sentiment</div>
                        <div style={{ fontSize: "0.73rem", color: "#9ca3af" }}>AI mood detection · {fmtDate(activeDay)}</div>
                      </div>
                    </div>

                    <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: "0.6rem", marginBottom: "1.25rem" }}>
                      {[
                        { label: "Total",       val: dayData.Camera["exit-cam"].Count,       color: "#6366f1", icon: <IconBarChart2 /> },
                        { label: "Happy",       val: dayData.Camera["exit-cam"].Happy,       color: "#16a34a", icon: <IconSmile /> },
                        { label: "Sad",         val: dayData.Camera["exit-cam"].Sad,         color: "#ef4444", icon: <IconFrown /> },
                        { label: "Undetected",  val: dayData.Camera["exit-cam"].undetected,  color: "#f59e0b", icon: <IconHelpCircle /> },
                      ].map(({ label, val, color, icon }) => (
                        <div key={label} className="stat-chip"
                          style={{ background: `${color}0c`, border: `1px solid ${color}22` }}>
                          <div style={{ marginBottom: 4, color: color, display: "flex", justifyContent: "center" }}>{icon}</div>
                          <div style={{ fontSize: "1.15rem", fontWeight: 800, color }}>{val.toLocaleString("en-IN")}</div>
                          <div style={{ fontSize: "0.65rem", color: "#6b7280", marginTop: 2 }}>{label}</div>
                        </div>
                      ))}
                    </div>

                    {/* Sentiment stacked bar */}
                    {(() => {
                      const total = dayData.Camera["exit-cam"].Count || 1
                      const hPct = Math.round((dayData.Camera["exit-cam"].Happy      / total) * 100)
                      const sPct = Math.round((dayData.Camera["exit-cam"].Sad        / total) * 100)
                      const uPct = Math.round((dayData.Camera["exit-cam"].undetected / total) * 100)
                      return (
                        <>
                          <div style={{ height: 10, borderRadius: 99, background: "#e5e7eb", overflow: "hidden", display: "flex" }}>
                            <div style={{ width: `${hPct}%`, background: "#16a34a", transition: "width 1s ease" }} />
                            <div style={{ width: `${sPct}%`, background: "#ef4444", transition: "width 1s ease" }} />
                            <div style={{ width: `${uPct}%`, background: "#f59e0b", transition: "width 1s ease" }} />
                          </div>
                          <div style={{ display: "flex", gap: "1.1rem", marginTop: 8, fontSize: "0.72rem", color: "#6b7280", flexWrap: "wrap" }}>
                            {[
                              { dot: "#16a34a", label: `Happy ${hPct}%` },
                              { dot: "#ef4444", label: `Sad ${sPct}%` },
                              { dot: "#f59e0b", label: `Undetected ${uPct}%` },
                            ].map(({ dot, label }) => (
                              <span key={label} style={{ display: "flex", alignItems: "center", gap: 5 }}>
                                <span style={{ width: 9, height: 9, borderRadius: "50%", background: dot, display: "inline-block", flexShrink: 0 }} />
                                {label}
                              </span>
                            ))}
                          </div>
                          {/* Satisfaction score */}
                          <div style={{
                            marginTop: "1.25rem", paddingTop: "1rem", borderTop: "1px solid #f3f4f6",
                            display: "flex", justifyContent: "space-between", alignItems: "center",
                          }}>
                            <span style={{ fontSize: "0.76rem", color: "#6b7280" }}>Satisfaction score</span>
                            <span style={{
                              fontSize: "1.1rem", fontWeight: 800,
                              color: hPct >= 70 ? "#16a34a" : hPct >= 50 ? "#f59e0b" : "#ef4444",
                            }}>{hPct}%</span>
                          </div>
                        </>
                      )
                    })()}
                  </div>

                </div>
              )}
            </div>
          )}

          {/* ══════════════════════════════════════════
              SECTION 3 — ALL REGISTRATIONS TABLE
          ══════════════════════════════════════════ */}
          <div style={{ animation: "fadeUp 0.65s ease both 0.35s" }}>
            <SectionTitle title="All Registrations" icon={<IconClipboardList />} />

            {/* Live statistics bar */}
            {statistics && (
              <div style={{
                display: "grid",
                gridTemplateColumns: "repeat(auto-fit, minmax(140px, 1fr))",
                gap: "0.75rem",
                marginBottom: "1.5rem",
              }}>
                {[
                  { icon: <IconTicket />,        label: "Total Registrations", val: statistics.total_tourist_registrations,    color: "#d97706" },
                  { icon: <IconUsers />,          label: "Total Members",        val: statistics.total_members,                  color: "#b45309" },
                  { icon: <IconClipboardList />,  label: "Groups",              val: statistics.total_group_registrations,      color: "#92400e" },
                  { icon: <IconUser />,           label: "Individuals",          val: statistics.total_individual_registrations, color: "#78350f" },
                ].map(({ icon, label, val, color }) => (
                  <div key={label} className="stat-chip"
                    style={{ background: "#fff", border: `1.5px solid ${color}18`, boxShadow: "0 2px 12px rgba(180,80,0,0.07)" }}>
                    <div style={{ marginBottom: 3, color: color, display: "flex", justifyContent: "center" }}>{icon}</div>
                    <div style={{ fontSize: "1.35rem", fontWeight: 800, color }}>{val.toLocaleString("en-IN")}</div>
                    <div style={{ fontSize: "0.68rem", color: "#9ca3af", lineHeight: 1.4 }}>{label}</div>
                  </div>
                ))}
              </div>
            )}

            {/* ── Filter bar ── */}
            <div className="filter-bar" style={{
              background: "#fff",
              borderRadius: 16, padding: "1.15rem 1.4rem",
              boxShadow: "0 4px 22px rgba(180,80,0,0.08)",
              border: "1.5px solid rgba(251,191,36,0.2)",
              display: "flex", flexWrap: "wrap", gap: "0.75rem", alignItems: "flex-end",
              marginBottom: "1.2rem",
            }}>
              {/* Date */}
              <div style={{ display: "flex", flexDirection: "column", gap: 5 }}>
                <label style={{ fontSize: "0.68rem", color: "#6b7280", fontWeight: 700, letterSpacing: "0.09em", textTransform: "uppercase" }}>Date</label>
                <select
                  value={dateFilter}
                  onChange={e => { setDateFilter(e.target.value); setPage(0) }}
                  style={{
                    padding: "0.48rem 0.9rem", borderRadius: 10,
                    border: "1.5px solid #e5e7eb", fontSize: "0.87rem",
                    color: "#374151", background: "#fff", cursor: "pointer",
                  }}
                >
                  <option value="2026-02-27">Feb 27, 2026</option>
                  <option value="2026-02-28">Feb 28, 2026</option>
                  <option value="2026-03-01">Mar 1, 2026</option>
                </select>
              </div>

              {/* Per page */}
              <div style={{ display: "flex", flexDirection: "column", gap: 5 }}>
                <label style={{ fontSize: "0.68rem", color: "#6b7280", fontWeight: 700, letterSpacing: "0.09em", textTransform: "uppercase" }}>Per page</label>
                <select
                  value={limit}
                  onChange={e => { setLimit(Number(e.target.value)); setPage(0) }}
                  style={{
                    padding: "0.48rem 0.9rem", borderRadius: 10,
                    border: "1.5px solid #e5e7eb", fontSize: "0.87rem",
                    color: "#374151", background: "#fff", cursor: "pointer",
                  }}
                >
                  {[10, 20, 50, 100, 250, 500].map(n => (
                    <option key={n} value={n}>{n} rows</option>
                  ))}
                </select>
              </div>

              {/* Search */}
              <div style={{ display: "flex", flexDirection: "column", gap: 5, flex: 1, minWidth: 200 }}>
                <label style={{ fontSize: "0.68rem", color: "#6b7280", fontWeight: 700, letterSpacing: "0.09em", textTransform: "uppercase" }}>Search by name</label>
                <div style={{ display: "flex", gap: "0.5rem" }}>
                  <input
                    type="text"
                    placeholder="e.g. Ravi Kumar…"
                    value={searchInput}
                    onChange={e => setSearchInput(e.target.value)}
                    onKeyDown={e => e.key === "Enter" && applySearch()}
                    style={{
                      flex: 1, padding: "0.48rem 0.9rem",
                      borderRadius: 10, border: "1.5px solid #e5e7eb",
                      fontSize: "0.87rem", color: "#374151", transition: "border 0.2s",
                    }}
                  />
                  <button className="sf-btn" onClick={applySearch}
                    style={{ background: "linear-gradient(135deg, #d97706, #b45309)", color: "#fff", borderColor: "transparent" }}>
                    🔍 Search
                  </button>
                </div>
              </div>

              {/* Only active toggle */}
              <div style={{ display: "flex", flexDirection: "column", gap: 5 }}>
                <label style={{ fontSize: "0.68rem", color: "#6b7280", fontWeight: 700, letterSpacing: "0.09em", textTransform: "uppercase" }}>Mode</label>
                <button
                  className="sf-btn"
                  onClick={() => { setOnlyActive(v => !v); setPage(0) }}
                  style={{
                    background: onlyActive ? "linear-gradient(135deg, #16a34a, #15803d)" : "#fff",
                    color: onlyActive ? "#fff" : "#6b7280",
                    borderColor: onlyActive ? "transparent" : "#e5e7eb",
                    boxShadow: onlyActive ? "0 4px 14px rgba(21,128,61,0.3)" : "none",
                    animation: onlyActive ? "pulse-badge 2s infinite" : "none",
                  }}
                >
                  {onlyActive ? "📍 Inside Only" : "👥 Show All"}
                </button>
              </div>

              {/* Reset */}
              <div style={{ display: "flex", flexDirection: "column", gap: 5 }}>
                <label style={{ fontSize: "0.68rem", color: "transparent" }}>·</label>
                <button className="sf-btn" onClick={resetFilters}
                  style={{ background: "#f3f4f6", color: "#6b7280", borderColor: "#e5e7eb" }}>
                  ↺ Reset
                </button>
              </div>
            </div>

            {/* ── Table ── */}
            <div style={{
              background: "#fff", borderRadius: 18, overflow: "hidden",
              boxShadow: "0 4px 28px rgba(180,80,0,0.09)",
              border: "1.5px solid rgba(251,191,36,0.15)",
            }}>
              {/* Table header */}
              <div className="table-header" style={{
                display: "grid",
                gridTemplateColumns: "48px 1fr 150px 108px 64px 96px",
                padding: "0.9rem 1.3rem",
                background: "linear-gradient(90deg, #fffbeb, #fef3c7 60%, #fffbeb)",
                borderBottom: "1.5px solid rgba(251,191,36,0.28)",
                fontSize: "0.68rem", fontWeight: 700,
                color: "#92400e", letterSpacing: "0.09em", textTransform: "uppercase",
              }}>
                <span>#</span>
                <span>Name</span>
                <span style={{ display: "flex", alignItems: "center", gap: 5 }}><IconPhone /> Phone</span>
                <span>Type</span>
                <span style={{ textAlign: "right" }}>Members</span>
                <span style={{ textAlign: "center" }}>Actions</span>
              </div>

              {/* Loading skeleton */}
              {touristsLoading ? (
                <div style={{ padding: "1.5rem" }}>
                  {[...Array(8)].map((_, i) => (
                    <div key={i} style={{ display: "grid", gridTemplateColumns: "48px 1fr 150px 108px 64px 96px", gap: "0.5rem", marginBottom: "0.65rem" }}>
                      {[...Array(6)].map((_, j) => <Skeleton key={j} h={34} />)}
                    </div>
                  ))}
                </div>

              ) : touristsError ? (
                <div style={{ padding: "2.5rem", textAlign: "center", color: "#dc2626" }}>
                  <div style={{ fontSize: "2rem", marginBottom: "0.5rem" }}>⚠️</div>
                  <div style={{ fontWeight: 600, marginBottom: "0.75rem" }}>{touristsError}</div>
                  <button className="sf-btn" onClick={() => fetchTourists(dateFilter, search, onlyActive, page * limit, limit)}
                    style={{ background: "#dc2626", color: "#fff", borderColor: "transparent" }}>
                    ↺ Retry
                  </button>
                </div>

              ) : tourists.length === 0 ? (
                <div style={{ padding: "3.5rem", textAlign: "center" }}>
                  <div style={{ fontSize: "3rem", marginBottom: "0.75rem" }}>🌿</div>
                  <div style={{ fontWeight: 700, fontSize: "1rem", color: "#374151", marginBottom: 4 }}>No registrations found</div>
                  <div style={{ fontSize: "0.85rem", color: "#9ca3af" }}>Try a different date or clear the search filter</div>
                </div>

              ) : tourists.map((t, idx) => (
                <div
                  key={t.user_id}
                  className="t-row"
                  style={{
                    display: "grid",
                    gridTemplateColumns: "48px 1fr 150px 108px 64px 96px",
                    padding: "0.75rem 1.3rem",
                    borderBottom: idx < tourists.length - 1 ? "1px solid #f3f4f6" : "none",
                    alignItems: "center",
                    background: idx % 2 === 0 ? "#fff" : "#fafafa",
                  }}
                >
                  {/* # */}
                  <span style={{ fontSize: "0.78rem", color: "#d1d5db", fontWeight: 600 }}>
                    {page * limit + idx + 1}
                  </span>

                  {/* Name */}
                  <div style={{ minWidth: 0 }}>
                    <div style={{ fontWeight: 700, fontSize: "0.91rem", color: "#1f2937", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{t.name}</div>
                    {t.group_name && (
                      <div style={{ fontSize: "0.73rem", color: "#d97706", marginTop: 2, display: "flex", alignItems: "center", gap: 4, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                        <IconUsers />{t.group_name}
                      </div>
                    )}
                  </div>

                  {/* Phone */}
                  <div className="col-phone" style={{ display: "flex", alignItems: "center", gap: 6 }}>
                    <span style={{ color: t.phone ? "#d97706" : "#e5e7eb", flexShrink: 0 }}><IconPhone /></span>
                    <span style={{ fontSize: "0.85rem", fontWeight: t.phone ? 600 : 400, color: t.phone ? "#374151" : "#d1d5db", fontVariantNumeric: "tabular-nums" }}>
                      {t.phone ?? "—"}
                    </span>
                  </div>

                  {/* Type badge — SVG icons, no emoji */}
                  <div>
                    <span style={{
                      display: "inline-flex", alignItems: "center", gap: 5,
                      fontSize: "0.71rem", fontWeight: 700, padding: "0.22rem 0.65rem",
                      borderRadius: 50,
                      background: t.is_group ? "#fef3c7" : "#ecfdf5",
                      color:      t.is_group ? "#92400e" : "#15803d",
                      border: `1px solid ${t.is_group ? "#fde68a" : "#bbf7d0"}`,
                    }}>
                      {t.is_group ? <IconUsers /> : <IconUser />}
                      {t.is_group ? "Group" : "Solo"}
                    </span>
                  </div>

                  {/* Members */}
                  <div style={{ textAlign: "right", fontWeight: 800, fontSize: "1rem", color: "#374151" }}>
                    {t.is_group ? (t.group_count ?? 1) : 1}
                  </div>

                  {/* Actions */}
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "center" }}>
                    <button
                      className="view-btn"
                      onClick={() => setProfileUserId(t.user_id)}
                      title={`View profile for ${t.name}`}
                    >
                      <IconEye /> Profile
                    </button>
                  </div>
                </div>
              ))}
            </div>

            {/* ── Pagination ── */}
            {pagination && pagination.total > 0 && (
              <div style={{
                display: "flex", alignItems: "center", justifyContent: "space-between",
                marginTop: "1.25rem", flexWrap: "wrap", gap: "0.75rem",
              }}>
                <div style={{ fontSize: "0.84rem", color: "#6b7280" }}>
                  Showing{" "}
                  <strong style={{ color: "#374151" }}>{(page * limit + 1).toLocaleString("en-IN")}</strong>–
                  <strong style={{ color: "#374151" }}>{Math.min((page + 1) * limit, pagination.total).toLocaleString("en-IN")}</strong>
                  {" "}of{" "}
                  <strong style={{ color: "#d97706" }}>{pagination.total.toLocaleString("en-IN")}</strong> registrations
                  {search && <span style={{ color: "#9ca3af" }}> · "{search}"</span>}
                </div>
                <div style={{ display: "flex", gap: "0.5rem", alignItems: "center" }}>
                  <button className="sf-btn" disabled={page === 0} onClick={() => setPage(0)}
                    style={{ background: page === 0 ? "#f3f4f6" : "#fff", color: page === 0 ? "#d1d5db" : "#374151", borderColor: "#e5e7eb" }}>
                    «
                  </button>
                  <button className="sf-btn" disabled={page === 0} onClick={() => setPage(p => p - 1)}
                    style={{ background: page === 0 ? "#f3f4f6" : "#fff", color: page === 0 ? "#d1d5db" : "#374151", borderColor: "#e5e7eb" }}>
                    ← Prev
                  </button>
                  <span style={{
                    padding: "0.5rem 1.1rem",
                    background: "linear-gradient(135deg, #d97706, #b45309)",
                    color: "#fff", borderRadius: 50, fontSize: "0.87rem", fontWeight: 700,
                    boxShadow: "0 4px 14px rgba(217,119,6,0.3)",
                  }}>
                    {page + 1} / {totalPages}
                  </span>
                  <button className="sf-btn" disabled={(page + 1) >= totalPages} onClick={() => setPage(p => p + 1)}
                    style={{ background: (page + 1) >= totalPages ? "#f3f4f6" : "#fff", color: (page + 1) >= totalPages ? "#d1d5db" : "#374151", borderColor: "#e5e7eb" }}>
                    Next →
                  </button>
                  <button className="sf-btn" disabled={(page + 1) >= totalPages} onClick={() => setPage(totalPages - 1)}
                    style={{ background: (page + 1) >= totalPages ? "#f3f4f6" : "#fff", color: (page + 1) >= totalPages ? "#d1d5db" : "#374151", borderColor: "#e5e7eb" }}>
                    »
                  </button>
                </div>
              </div>
            )}
          </div>

          {/* ── Decorative footer ── */}
          <div style={{ textAlign: "center", marginTop: "4rem", paddingTop: "2rem", borderTop: "1px solid rgba(251,191,36,0.2)" }}>
            <div style={{ display: "flex", justifyContent: "center", marginBottom: "0.75rem" }}>
              <div style={{ animation: "spin-slow 40s linear infinite" }}>
                <Rangoli size={55} opacity={0.28} />
              </div>
            </div>
            <p style={{ fontFamily: "'Playfair Display', Georgia, serif", color: "#92400e", fontSize: "0.88rem", opacity: 0.65 }}>
              Spring Festival 2026 · Veer Madho Singh Bhandari Uttarakhand Technical University
            </p>
            <p style={{ fontSize: "0.75rem", color: "#9ca3af", marginTop: 4 }}>
              Feb 27 – Mar 1, 2026 · Dehradun, Uttarakhand
            </p>
          </div>

        </div>
      </div>
    </>
  )
}
