"use client"

import { useState, useEffect, useRef } from "react"

// ── Inline SVG icons to avoid any dependency on lucide-react ──────────────────

function IconMenu() {
  return (
    <svg width="24" height="24" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
      <line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="18" x2="21" y2="18"/>
    </svg>
  )
}
function IconX() {
  return (
    <svg width="24" height="24" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
      <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
    </svg>
  )
}

// ── Decorative Rangoli SVG ────────────────────────────────────────────────────

function Rangoli({ size = 200, opacity = 0.08, color1 = "#d97706", color2 = "#16a34a" }) {
  return (
    <svg width={size} height={size} viewBox="0 0 200 200" style={{ opacity }}>
      {[0,45,90,135].map(angle => (
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

// ── Floating Petal Particle ───────────────────────────────────────────────────

function FloatingPetal({ style }) {
  return (
    <div style={{
      position: "absolute",
      width: 10,
      height: 16,
      borderRadius: "50% 50% 50% 0",
      background: "linear-gradient(135deg, #f59e0b, #ef4444)",
      opacity: 0.25,
      animation: "floatPetal 8s ease-in-out infinite",
      ...style,
    }} />
  )
}

// ── Feature Card ─────────────────────────────────────────────────────────────

function FeatureCard({ icon, title, desc, delay = 0 }) {
  return (
    <div style={{
      background: "rgba(255,255,255,0.85)",
      backdropFilter: "blur(12px)",
      borderRadius: 20,
      padding: "2rem 1.75rem",
      boxShadow: "0 8px 40px rgba(180,80,0,0.10), 0 2px 8px rgba(0,0,0,0.04)",
      border: "1.5px solid rgba(251,191,36,0.25)",
      animation: `fadeUp 0.7s ease both`,
      animationDelay: `${delay}ms`,
      transition: "transform 0.25s, box-shadow 0.25s",
      cursor: "default",
    }}
    onMouseEnter={e => {
      e.currentTarget.style.transform = "translateY(-6px)"
      e.currentTarget.style.boxShadow = "0 20px 60px rgba(180,80,0,0.18), 0 4px 12px rgba(0,0,0,0.06)"
    }}
    onMouseLeave={e => {
      e.currentTarget.style.transform = "translateY(0)"
      e.currentTarget.style.boxShadow = "0 8px 40px rgba(180,80,0,0.10), 0 2px 8px rgba(0,0,0,0.04)"
    }}
    >
      <div style={{
        width: 52, height: 52,
        borderRadius: "50%",
        background: "linear-gradient(135deg, #f59e0b, #d97706)",
        display: "flex", alignItems: "center", justifyContent: "center",
        fontSize: 24, marginBottom: "1rem",
        boxShadow: "0 4px 16px rgba(217,119,6,0.35)"
      }}>{icon}</div>
      <h3 style={{ fontFamily: "'Playfair Display', Georgia, serif", fontSize: "1.2rem", fontWeight: 700, color: "#78350f", marginBottom: "0.5rem" }}>{title}</h3>
      <p style={{ color: "#6b7280", lineHeight: 1.7, fontSize: "0.95rem" }}>{desc}</p>
    </div>
  )
}

// ── Stat Card ────────────────────────────────────────────────────────────────

function StatCard({ number, label }) {
  return (
    <div style={{ textAlign: "center" }}>
      <div style={{
        fontFamily: "'Playfair Display', Georgia, serif",
        fontSize: "clamp(2rem, 5vw, 3.5rem)",
        fontWeight: 800,
        background: "linear-gradient(135deg, #f59e0b, #16a34a)",
        WebkitBackgroundClip: "text",
        WebkitTextFillColor: "transparent",
        lineHeight: 1.1,
      }}>{number}</div>
      <div style={{ color: "#92400e", fontSize: "0.9rem", fontWeight: 500, marginTop: "0.25rem", letterSpacing: "0.05em" }}>{label}</div>
    </div>
  )
}

// ── Main Component ────────────────────────────────────────────────────────────

export default function LandingPage() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [scrolled, setScrolled] = useState(false)
  const [heroVisible, setHeroVisible] = useState(false)

  useEffect(() => {
    setHeroVisible(true)
    const onScroll = () => setScrolled(window.scrollY > 20)
    window.addEventListener("scroll", onScroll)
    return () => window.removeEventListener("scroll", onScroll)
  }, [])

  const petals = Array.from({ length: 12 }, (_, i) => ({
    left: `${(i * 8.3) % 100}%`,
    top: `${(i * 13.7) % 100}%`,
    animationDelay: `${i * 0.7}s`,
    animationDuration: `${7 + (i % 4)}s`,
    transform: `rotate(${i * 30}deg)`,
  }))

  return (
    <>
      {/* ── Global Styles ── */}
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400;0,600;0,700;0,800;1,400&family=Lato:wght@300;400;700&display=swap');
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        html { scroll-behavior: smooth; }
        body { font-family: 'Lato', sans-serif; }

        @keyframes floatPetal {
          0%   { transform: translateY(0) rotate(0deg) scale(1); opacity: 0.2; }
          50%  { transform: translateY(-30px) rotate(180deg) scale(1.1); opacity: 0.35; }
          100% { transform: translateY(0) rotate(360deg) scale(1); opacity: 0.2; }
        }
        @keyframes fadeUp {
          from { opacity: 0; transform: translateY(30px); }
          to   { opacity: 1; transform: translateY(0); }
        }
        @keyframes fadeIn {
          from { opacity: 0; }
          to   { opacity: 1; }
        }
        @keyframes slideDown {
          from { opacity: 0; transform: translateY(-16px); }
          to   { opacity: 1; transform: translateY(0); }
        }
        @keyframes spin-slow {
          to { transform: rotate(360deg); }
        }
        @keyframes spin-reverse {
          to { transform: rotate(-360deg); }
        }
        @keyframes pulse-soft {
          0%, 100% { opacity: 0.12; }
          50% { opacity: 0.22; }
        }
        .nav-link {
          color: rgba(255,255,255,0.88);
          text-decoration: none;
          font-weight: 500;
          font-size: 0.95rem;
          letter-spacing: 0.03em;
          position: relative;
          padding-bottom: 2px;
          transition: color 0.2s;
        }
        .nav-link::after {
          content: '';
          position: absolute;
          left: 0; bottom: -2px;
          width: 0; height: 1.5px;
          background: #fbbf24;
          transition: width 0.3s ease;
        }
        .nav-link:hover { color: #fbbf24; }
        .nav-link:hover::after { width: 100%; }
        .cta-btn {
          display: inline-block;
          text-decoration: none;
          background: linear-gradient(135deg, #d97706, #b45309);
          color: #fff;
          padding: 1rem 2.5rem;
          border-radius: 50px;
          font-weight: 700;
          font-size: 1.05rem;
          letter-spacing: 0.04em;
          box-shadow: 0 8px 30px rgba(180,83,9,0.45);
          transition: transform 0.25s, box-shadow 0.25s, background 0.25s;
        }
        .cta-btn:hover {
          transform: translateY(-3px) scale(1.03);
          box-shadow: 0 16px 40px rgba(180,83,9,0.55);
          background: linear-gradient(135deg, #f59e0b, #d97706);
        }
        .register-btn {
          text-decoration: none;
          background: rgba(255,255,255,0.15);
          color: #fff;
          border: 1.5px solid rgba(255,255,255,0.5);
          padding: 0.45rem 1.4rem;
          border-radius: 50px;
          font-weight: 600;
          font-size: 0.9rem;
          letter-spacing: 0.04em;
          transition: background 0.2s, border-color 0.2s;
        }
        .register-btn:hover {
          background: rgba(255,255,255,0.28);
          border-color: #fbbf24;
        }
        .section-label {
          display: inline-block;
          font-size: 0.8rem;
          font-weight: 700;
          letter-spacing: 0.18em;
          text-transform: uppercase;
          color: #d97706;
          border: 1px solid #fde68a;
          background: #fffbeb;
          padding: 0.3rem 1rem;
          border-radius: 50px;
          margin-bottom: 1rem;
        }
      `}</style>

      <div style={{ minHeight: "100vh", background: "#fffbf2", overflowX: "hidden" }}>

        {/* ── NAV ── */}
        <nav style={{
          position: "sticky", top: 0, zIndex: 100,
          background: scrolled
            ? "rgba(120,53,15,0.97)"
            : "linear-gradient(90deg, #92400e 0%, #b45309 50%, #d97706 100%)",
          backdropFilter: scrolled ? "blur(16px)" : "none",
          boxShadow: scrolled ? "0 4px 32px rgba(0,0,0,0.18)" : "none",
          transition: "background 0.4s, box-shadow 0.4s",
        }}>
          {/* Decorative top border */}
          <div style={{ height: 3, background: "linear-gradient(90deg, #fbbf24, #16a34a, #fbbf24, #dc2626, #fbbf24)" }} />

          <div style={{ maxWidth: 1200, margin: "0 auto", padding: "0.9rem 1.5rem", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            {/* Logo */}
            <div>
              <div style={{ fontSize: "0.7rem", color: "rgba(255,255,255,0.7)", letterSpacing: "0.12em", textTransform: "uppercase" }}>Visitor & Entry</div>
              <div style={{ fontFamily: "'Playfair Display', Georgia, serif", fontSize: "1.15rem", fontWeight: 700, color: "#fff", letterSpacing: "0.01em", lineHeight: 1.2 }}>Management System</div>
            </div>

            {/* Desktop links */}
            <div style={{ display: "flex", alignItems: "center", gap: "2.5rem" }} className="desktop-nav">
              <a href="/vasontutsav2025" className="nav-link">Past Events</a>
              <a href="/register/1" className="register-btn">Register Now →</a>
            </div>

            {/* Mobile toggle */}
            <button
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              style={{ background: "none", border: "none", color: "#fff", cursor: "pointer", display: "flex" }}
              className="mobile-toggle"
            >
              {mobileMenuOpen ? <IconX /> : <IconMenu />}
            </button>
          </div>

          {/* Mobile Menu */}
          {mobileMenuOpen && (
            <div style={{
              background: "rgba(120,53,15,0.98)",
              padding: "1rem 1.5rem 1.5rem",
              borderTop: "1px solid rgba(255,255,255,0.1)",
              animation: "slideDown 0.25s ease",
              display: "flex", flexDirection: "column", gap: "0.75rem"
            }}>
              <a href="/vasontutsav2025" className="nav-link" style={{ padding: "0.5rem 0" }} onClick={() => setMobileMenuOpen(false)}>Past Events</a>
              <a href="/register/1" className="nav-link" style={{ padding: "0.5rem 0" }} onClick={() => setMobileMenuOpen(false)}>Register</a>
            </div>
          )}

          <style>{`
            @media (min-width: 768px) { .mobile-toggle { display: none !important; } }
            @media (max-width: 767px) { .desktop-nav { display: none !important; } }
          `}</style>
        </nav>

        {/* ── HERO ── */}
        <header style={{
          position: "relative",
          minHeight: "100vh",
          display: "flex", alignItems: "center", justifyContent: "center",
          overflow: "hidden",
          background: "linear-gradient(160deg, #fffbeb 0%, #fef3c7 30%, #ecfdf5 70%, #f0fdf4 100%)",
        }}>
          {/* Animated Rangoli backgrounds */}
          <div style={{ position: "absolute", top: -60, left: -60, animation: "spin-slow 60s linear infinite" }}>
            <Rangoli size={320} opacity={0.09} />
          </div>
          <div style={{ position: "absolute", bottom: -80, right: -80, animation: "spin-reverse 80s linear infinite" }}>
            <Rangoli size={400} opacity={0.07} color1="#16a34a" color2="#d97706" />
          </div>
          <div style={{ position: "absolute", top: "30%", right: "5%", animation: "spin-slow 45s linear infinite" }}>
            <Rangoli size={160} opacity={0.06} />
          </div>
          <div style={{ position: "absolute", top: "10%", left: "60%", animation: "spin-reverse 55s linear infinite" }}>
            <Rangoli size={120} opacity={0.05} color1="#dc2626" color2="#16a34a" />
          </div>

          {/* Floating petals */}
          {petals.map((p, i) => <FloatingPetal key={i} style={p} />)}

          {/* Horizontal divider lines */}
          <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: "100%", pointerEvents: "none" }}>
            <div style={{ position: "absolute", top: "20%", left: 0, right: 0, height: 1, background: "linear-gradient(90deg, transparent, rgba(251,191,36,0.15), transparent)" }} />
            <div style={{ position: "absolute", top: "80%", left: 0, right: 0, height: 1, background: "linear-gradient(90deg, transparent, rgba(22,163,74,0.15), transparent)" }} />
          </div>

          {/* Hero Content */}
          <div style={{
            position: "relative", zIndex: 10,
            maxWidth: 880, margin: "0 auto",
            padding: "4rem 1.5rem",
            textAlign: "center",
            opacity: heroVisible ? 1 : 0,
            transform: heroVisible ? "translateY(0)" : "translateY(40px)",
            transition: "opacity 0.9s ease, transform 0.9s ease",
          }}>
            {/* Pill badge */}
            <div style={{
              display: "inline-flex", alignItems: "center", gap: "0.5rem",
              background: "rgba(251,191,36,0.15)",
              border: "1px solid rgba(251,191,36,0.4)",
              padding: "0.4rem 1.2rem",
              borderRadius: 50,
              marginBottom: "2rem",
              animation: "fadeUp 0.6s ease both 0.2s",
            }}>
              <span style={{ fontSize: "1rem" }}>🌸</span>
              <span style={{ fontSize: "0.8rem", fontWeight: 700, letterSpacing: "0.12em", textTransform: "uppercase", color: "#92400e" }}>Spring Festival 2026</span>
              <span style={{ fontSize: "1rem" }}>🌸</span>
            </div>

            {/* Main headline */}
            <h1 style={{
              fontFamily: "'Playfair Display', Georgia, serif",
              fontSize: "clamp(2.4rem, 6vw, 5rem)",
              fontWeight: 800,
              lineHeight: 1.1,
              color: "#451a03",
              marginBottom: "1.5rem",
              animation: "fadeUp 0.7s ease both 0.35s",
            }}>
              Visitor &amp; Entry<br />
              <span style={{
                background: "linear-gradient(135deg, #d97706, #b45309)",
                WebkitBackgroundClip: "text",
                WebkitTextFillColor: "transparent",
              }}>Management System</span>
            </h1>

            {/* Sub-headline */}
            <p style={{
              fontSize: "clamp(1rem, 2.5vw, 1.2rem)",
              color: "#6b7280",
              lineHeight: 1.8,
              maxWidth: 660,
              margin: "0 auto 2.5rem",
              animation: "fadeUp 0.7s ease both 0.5s",
            }}>
              Inspired by the Hon'ble <strong style={{ color: "#d97706" }}>Governor Sir</strong> and developed under the vision of the Hon'ble Vice-Chancellor of{" "}
              <strong style={{ color: "#15803d" }}>Veer Madho Singh Bhandari Uttarakhand Technical University</strong>
            </p>

            {/* Decorative divider */}
            <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: "1rem", marginBottom: "2.5rem", animation: "fadeUp 0.7s ease both 0.6s" }}>
              <div style={{ height: 1, width: 60, background: "linear-gradient(90deg, transparent, #d97706)" }} />
              <span style={{ fontSize: "1.4rem" }}>✦</span>
              <div style={{ height: 1, width: 60, background: "linear-gradient(90deg, #d97706, transparent)" }} />
            </div>

            {/* CTA */}
            <div style={{ animation: "fadeUp 0.7s ease both 0.7s" }}>
              <a href="/register/1" className="cta-btn">
                Register for Spring Festival 2026 &nbsp;→
              </a>
            </div>

   
          </div>

          {/* Bottom wave */}
          <div style={{ position: "absolute", bottom: 0, left: 0, right: 0 }}>
            <svg viewBox="0 0 1440 80" style={{ display: "block", width: "100%" }} preserveAspectRatio="none">
              <path d="M0,40 C360,80 1080,0 1440,40 L1440,80 L0,80 Z" fill="#ffffff" />
            </svg>
          </div>
        </header>

        {/* ── VISION SECTION ── */}
        <section style={{ background: "#fff", padding: "6rem 1.5rem" }}>
          <div style={{ maxWidth: 1100, margin: "0 auto" }}>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))", gap: "4rem", alignItems: "center" }}>

              {/* Text */}
              <div>
                <span className="section-label">Our Vision</span>
                <h2 style={{
                  fontFamily: "'Playfair Display', Georgia, serif",
                  fontSize: "clamp(2rem, 4vw, 3rem)",
                  fontWeight: 800,
                  color: "#451a03",
                  lineHeight: 1.2,
                  marginBottom: "1.5rem",
                }}>
                  Tradition meets<br />
                  <span style={{ color: "#16a34a", fontStyle: "italic" }}>Innovation</span>
                </h2>
                <p style={{ color: "#4b5563", lineHeight: 1.85, fontSize: "1.05rem", marginBottom: "1.25rem" }}>
                  Inspired by the Governor's commitment to modernizing government operations, we have built a seamless visitor and entry management system that honours the spirit of tradition while embracing the efficiency of technology.
                </p>
                <p style={{ color: "#4b5563", lineHeight: 1.85, fontSize: "1.05rem", marginBottom: "2rem" }}>
                  Under the visionary leadership of the Hon'ble Vice-Chancellor of Veer Madho Singh Bhandari Uttarakhand Technical University, this platform redefines secure and transparent administrative management.
                </p>

                <div style={{ display: "flex", alignItems: "center", gap: "1rem" }}>
                  <div style={{ width: 4, height: 60, borderRadius: 99, background: "linear-gradient(180deg, #d97706, #16a34a)" }} />
                  <p style={{ color: "#9ca3af", fontStyle: "italic", fontSize: "0.95rem" }}>
                    "Building excellence in service delivery,<br />one visitor at a time."
                  </p>
                </div>
              </div>

              {/* Visual panel */}
              <div style={{ position: "relative" }}>
                <div style={{
                  borderRadius: 24,
                  overflow: "hidden",
                  background: "linear-gradient(135deg, #fffbeb, #ecfdf5)",
                  border: "2px solid rgba(251,191,36,0.3)",
                  padding: "2.5rem",
                  boxShadow: "0 20px 60px rgba(180,80,0,0.12)",
                  position: "relative",
                }}>
                  {/* Rangoli inside card */}
                  <div style={{ display: "flex", justifyContent: "center", marginBottom: "1.5rem" }}>
                    <div style={{ animation: "spin-slow 30s linear infinite" }}>
                      <Rangoli size={140} opacity={0.45} />
                    </div>
                  </div>

                  <div style={{ textAlign: "center" }}>
                    <p style={{ fontFamily: "'Playfair Display', Georgia, serif", fontSize: "1.1rem", color: "#92400e", fontWeight: 600, marginBottom: "0.5rem" }}>
                      वीर माधो सिंह भण्डारी
                    </p>
                    <p style={{ color: "#6b7280", fontSize: "0.9rem" }}>Uttarakhand Technical University</p>
                    <div style={{ margin: "1rem 0", height: 1, background: "linear-gradient(90deg, transparent, #d97706, transparent)" }} />
                    <p style={{ fontSize: "0.85rem", color: "#9ca3af" }}>Dehradun, Uttarakhand</p>
                  </div>
                </div>

                {/* Floating accent */}
                <div style={{
                  position: "absolute", bottom: -20, right: -20,
                  width: 80, height: 80,
                  background: "linear-gradient(135deg, #fbbf24, #d97706)",
                  borderRadius: "50%",
                  display: "flex", alignItems: "center", justifyContent: "center",
                  fontSize: "2rem",
                  boxShadow: "0 8px 24px rgba(217,119,6,0.4)",
                }}>🏛️</div>
              </div>
            </div>
          </div>
        </section>



        {/* ── BANNER CTA ── */}
        <section style={{
          background: "linear-gradient(135deg, #92400e 0%, #b45309 50%, #15803d 100%)",
          padding: "5rem 1.5rem",
          position: "relative",
          overflow: "hidden",
        }}>
          {/* Background rangoli */}
          <div style={{ position: "absolute", right: -80, top: "50%", transform: "translateY(-50%)", animation: "spin-slow 50s linear infinite", opacity: 0.12 }}>
            <Rangoli size={360} opacity={1} color1="#fbbf24" color2="#fff" />
          </div>
          <div style={{ position: "absolute", left: -60, top: "50%", transform: "translateY(-50%)", animation: "spin-reverse 70s linear infinite", opacity: 0.08 }}>
            <Rangoli size={280} opacity={1} color1="#fff" color2="#fbbf24" />
          </div>

          <div style={{ maxWidth: 700, margin: "0 auto", textAlign: "center", position: "relative", zIndex: 2 }}>
            <div style={{ fontSize: "2.5rem", marginBottom: "1rem" }}>🌺</div>
            <h2 style={{
              fontFamily: "'Playfair Display', Georgia, serif",
              fontSize: "clamp(1.8rem, 4vw, 3rem)",
              fontWeight: 800,
              color: "#fff",
              marginBottom: "1rem",
              lineHeight: 1.2,
            }}>Ready for Spring Festival 2026?</h2>
            <p style={{ color: "rgba(255,255,255,0.8)", fontSize: "1.1rem", lineHeight: 1.7, marginBottom: "2.5rem" }}>
              Secure your spot at one of Uttarakhand's most vibrant university celebrations. Register today before seats fill up.
            </p>
            <a href="/register/1" style={{
              display: "inline-block",
              textDecoration: "none",
              background: "#fff",
              color: "#92400e",
              padding: "1rem 2.8rem",
              borderRadius: 50,
              fontWeight: 800,
              fontSize: "1.05rem",
              letterSpacing: "0.04em",
              boxShadow: "0 8px 32px rgba(0,0,0,0.2)",
              transition: "transform 0.2s, box-shadow 0.2s",
            }}
            onMouseEnter={e => { e.currentTarget.style.transform = "scale(1.05)"; e.currentTarget.style.boxShadow = "0 16px 48px rgba(0,0,0,0.3)"; }}
            onMouseLeave={e => { e.currentTarget.style.transform = "scale(1)"; e.currentTarget.style.boxShadow = "0 8px 32px rgba(0,0,0,0.2)"; }}
            >
              Register Now &nbsp;→
            </a>
          </div>
        </section>

        {/* ── FOOTER ── */}
        <footer style={{
          background: "#1c0a00",
          color: "#fff",
          padding: "3rem 1.5rem 1.5rem",
        }}>
          {/* Top accent */}
          <div style={{ height: 3, background: "linear-gradient(90deg, #fbbf24, #16a34a, #fbbf24, #dc2626, #fbbf24)", marginBottom: "3rem", borderRadius: 99 }} />

          <div style={{ maxWidth: 1100, margin: "0 auto" }}>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))", gap: "2rem", marginBottom: "2.5rem" }}>

              <div>
                <div style={{ fontFamily: "'Playfair Display', Georgia, serif", fontSize: "1.3rem", fontWeight: 700, marginBottom: "0.75rem", color: "#fbbf24" }}>VEMS</div>
                <p style={{ color: "rgba(255,255,255,0.55)", fontSize: "0.9rem", lineHeight: 1.7 }}>
                  Visitor &amp; Entry Management System — redefining administrative excellence for public events.
                </p>
              </div>

              <div>
                <div style={{ fontWeight: 700, fontSize: "0.8rem", letterSpacing: "0.1em", textTransform: "uppercase", color: "#fbbf24", marginBottom: "0.75rem" }}>Institution</div>
                <p style={{ color: "rgba(255,255,255,0.55)", fontSize: "0.9rem", lineHeight: 1.8 }}>
                  Veer Madho Singh Bhandari<br />
                  Uttarakhand Technical University<br />
                  Dehradun, Uttarakhand
                </p>
              </div>

              <div>
                <div style={{ fontWeight: 700, fontSize: "0.8rem", letterSpacing: "0.1em", textTransform: "uppercase", color: "#fbbf24", marginBottom: "0.75rem" }}>Quick Links</div>
                <div style={{ display: "flex", flexDirection: "column", gap: "0.4rem" }}>
                  {[["Past Events", "/vasontutsav2025"], ["Register", "/register/1"]].map(([label, href]) => (
                    <a key={href} href={href} style={{ color: "rgba(255,255,255,0.55)", fontSize: "0.9rem", textDecoration: "none", transition: "color 0.2s" }}
                      onMouseEnter={e => e.currentTarget.style.color = "#fbbf24"}
                      onMouseLeave={e => e.currentTarget.style.color = "rgba(255,255,255,0.55)"}
                    >{label}</a>
                  ))}
                </div>
              </div>
            </div>

            <div style={{ borderTop: "1px solid rgba(255,255,255,0.08)", paddingTop: "1.5rem", display: "flex", flexWrap: "wrap", justifyContent: "space-between", alignItems: "center", gap: "1rem" }}>
              <p style={{ color: "rgba(255,255,255,0.35)", fontSize: "0.82rem" }}>© 2026 VEMS · All rights reserved</p>
              <a href="https://github.com/adityakumar-dev" style={{ color: "rgba(255,255,255,0.35)", fontSize: "0.82rem", textDecoration: "none", transition: "color 0.2s" }}
                onMouseEnter={e => e.currentTarget.style.color = "#fbbf24"}
                onMouseLeave={e => e.currentTarget.style.color = "rgba(255,255,255,0.35)"}
              >
                Crafted by adityakumar-dev ↗
              </a>
            </div>
          </div>
        </footer>

      </div>
    </>
  )
}