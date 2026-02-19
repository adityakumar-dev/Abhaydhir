/**
 * Browser Fingerprinting Utility
 * Generates a unique browser fingerprint for spam prevention.
 * This is a lightweight, privacy-respectful fingerprint based on
 * publicly available browser characteristics.
 */

async function getCanvasFingerprint(): Promise<string> {
  try {
    const canvas = document.createElement("canvas");
    const ctx = canvas.getContext("2d");
    if (!ctx) return "no-canvas";

    canvas.width = 200;
    canvas.height = 50;

    ctx.textBaseline = "top";
    ctx.font = "14px Arial";
    ctx.fillStyle = "#f60";
    ctx.fillRect(125, 1, 62, 20);
    ctx.fillStyle = "#069";
    ctx.fillText("fingerprint", 2, 15);
    ctx.fillStyle = "rgba(102, 204, 0, 0.7)";
    ctx.fillText("fingerprint", 4, 17);

    return canvas.toDataURL().slice(-50);
  } catch {
    return "canvas-error";
  }
}

function getWebGLFingerprint(): string {
  try {
    const canvas = document.createElement("canvas");
    const gl =
      canvas.getContext("webgl") || canvas.getContext("experimental-webgl");
    if (!gl) return "no-webgl";

    const debugInfo = (gl as WebGLRenderingContext).getExtension(
      "WEBGL_debug_renderer_info"
    );
    if (!debugInfo) return "no-debug-info";

    const vendor = (gl as WebGLRenderingContext).getParameter(
      debugInfo.UNMASKED_VENDOR_WEBGL
    );
    const renderer = (gl as WebGLRenderingContext).getParameter(
      debugInfo.UNMASKED_RENDERER_WEBGL
    );

    return `${vendor}~${renderer}`;
  } catch {
    return "webgl-error";
  }
}

function getBrowserCharacteristics(): string {
  const characteristics = [
    navigator.userAgent,
    navigator.language,
    screen.colorDepth?.toString() || "",
    `${screen.width}x${screen.height}`,
    new Date().getTimezoneOffset().toString(),
    navigator.hardwareConcurrency?.toString() || "",
    navigator.maxTouchPoints?.toString() || "0",
    (navigator as Navigator & { deviceMemory?: number }).deviceMemory?.toString() || "",
    typeof (window as Window & { ontouchstart?: unknown }).ontouchstart !== "undefined" ? "touch" : "no-touch",
    window.devicePixelRatio?.toString() || "",
  ];

  return characteristics.join("|");
}

async function hashString(str: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(str);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * Generate a unique browser fingerprint.
 * Combines canvas, WebGL, and browser characteristics.
 */
export async function generateFingerprint(): Promise<string> {
  const [canvasFp, webglFp, browserFp] = await Promise.all([
    getCanvasFingerprint(),
    Promise.resolve(getWebGLFingerprint()),
    Promise.resolve(getBrowserCharacteristics()),
  ]);

  const combined = `${canvasFp}|${webglFp}|${browserFp}`;
  return hashString(combined);
}

/**
 * Session ID management for feedback
 */
const SESSION_KEY = "feedback_session_id";
const SUBMITTED_KEY = "feedback_submitted_events";

export function getStoredSessionId(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(SESSION_KEY);
}

export function storeSessionId(sessionId: string): void {
  if (typeof window === "undefined") return;
  localStorage.setItem(SESSION_KEY, sessionId);
}

export function hasSubmittedFeedback(eventId: number): boolean {
  if (typeof window === "undefined") return false;
  try {
    const submitted = JSON.parse(
      localStorage.getItem(SUBMITTED_KEY) || "{}"
    );
    const entry = submitted[eventId];
    if (!entry) return false;

    // Check if submission was within 24 hours
    const submittedAt = new Date(entry).getTime();
    const now = Date.now();
    return now - submittedAt < 24 * 60 * 60 * 1000;
  } catch {
    return false;
  }
}

export function markFeedbackSubmitted(eventId: number): void {
  if (typeof window === "undefined") return;
  try {
    const submitted = JSON.parse(
      localStorage.getItem(SUBMITTED_KEY) || "{}"
    );
    submitted[eventId] = new Date().toISOString();
    localStorage.setItem(SUBMITTED_KEY, JSON.stringify(submitted));
  } catch {
    // Ignore storage errors
  }
}
