// lib/cameraSocket.ts
// Typed WebSocket client for the camera backend.
// Usage:
//   const cam = new CameraSocket({ cams: ['entry-cam'] })
//   cam.onFrame      = (camId, blobUrl) => { imgEl.src = blobUrl }
//   cam.onEvent      = (camId, data)    => console.log(data)
//   cam.onInitStatus = (cameras)        => updateUI(cameras)
//   cam.connect()
//   // cleanup: cam.destroy()

export interface CamState {
  cam: "entry-cam" | "exit-cam";
  online: boolean;
  unique_count: number;
  active_count: number;
  last_seen: number;
  last_event: string;
  ws_connected: boolean;
}

export interface CamEventData {
  event:
    | "heartbeat"
    | "enter"
    | "exit"
    | "new_entry"
    | "captured"
    | "reentry"
    | "archived"
    | "stats"
    | "emotions";
  ts: number;
  active_count?: number;
  unique_count?: number;
  track_id?: number;
  conf?: number;
  zone?: string;
  dwell?: number;
  image?: string;
  cid?: number;
  visit_count?: number;
  emotion?: string;
  emotion_score?: number;
}

export interface CamStatsData {
  event: "stats";
  unique_total: number;
  today_count: number;
  active_now: number;
  hourly: { hour: number; count: number }[];
  ts: number;
}

export interface CamEmotionEntry {
  emotion: string;
  count: number;
  percentage: number;
}

export interface CamEmotionsData {
  event: "emotions";
  total_archived: number;
  emotions: CamEmotionEntry[];
  ts: number;
}

export interface CameraSocketOptions {
  /** cam IDs to subscribe to. Pass [] for ALL cameras. */
  cams?: string[];
  /** WebSocket URL — defaults to NEXT_PUBLIC_CAM_URL with /ws appended */
  url?: string;
  /** Reconnect delay in ms (default 3 000) */
  retryMs?: number;
}

const defaultUrl = (): string => {
  const base = process.env.NEXT_PUBLIC_CAM_URL ?? "";
  return base.replace(/^https/, "wss").replace(/^http/, "ws") + "/ws";
};

export class CameraSocket {
  cams: string[];
  url: string;
  retryMs: number;

  private _ws: WebSocket | null = null;
  private _dead = false;
  private _frameUrls: Record<string, string> = {};

  // ── Callbacks ───────────────────────────────────────────────────────────────
  onInitStatus: (cameras: CamState[]) => void = () => {};
  onFrame: (cam: string, blobUrl: string) => void = () => {};
  onEvent: (cam: string, data: CamEventData) => void = () => {};
  /** Fired every ~30 s (both cams) with updated counts + hourly breakdown */
  onStats: (cam: string, data: CamStatsData) => void = () => {};
  /** Fired every ~30 s and immediately after each archive (exit-cam) */
  onEmotions: (cam: string, data: CamEmotionsData) => void = () => {};
  onCamStatus: (cam: string, online: boolean) => void = () => {};
  onConnect: () => void = () => {};
  onDisconnect: () => void = () => {};

  constructor({ cams = [], url, retryMs = 3_000 }: CameraSocketOptions = {}) {
    this.cams    = cams;
    this.url     = url ?? defaultUrl();
    this.retryMs = retryMs;
  }

  connect(): void {
    if (this._ws) return;
    this._dead = false;
    this._open();
  }

  destroy(): void {
    this._dead = true;
    if (this._ws) {
      this._ws.onclose = null;
      this._ws.close();
      this._ws = null;
    }
    Object.values(this._frameUrls).forEach((u) => URL.revokeObjectURL(u));
    this._frameUrls = {};
  }

  /** Dynamically change which cameras send frames (no reconnect needed). */
  subscribe(cams: string[]): void {
    this.cams = cams;
    if (this._ws?.readyState === WebSocket.OPEN) {
      this._send({ type: "subscribe", cams });
    }
  }

  // ── Internal ─────────────────────────────────────────────────────────────────
  private _open(): void {
    const ws = new WebSocket(this.url);
    this._ws  = ws;

    ws.onopen = () => {
      // tell backend which cam streams to subscribe to ([] = all)
      this._send({ type: "subscribe", cams: this.cams });
      this.onConnect();
    };

    ws.onmessage = (e: MessageEvent<string>) => {
      let msg: Record<string, any>;
      try { msg = JSON.parse(e.data); } catch { return; }
      this._handle(msg);
    };

    ws.onerror = () => { /* onclose fires immediately after */ };

    ws.onclose = () => {
      this._ws = null;
      this.onDisconnect();
      if (!this._dead) {
        setTimeout(() => this._open(), this.retryMs);
      }
    };
  }

  private _send(obj: object): void {
    if (this._ws?.readyState === WebSocket.OPEN) {
      this._ws.send(JSON.stringify(obj));
    }
  }

  private _handle(msg: Record<string, any>): void {
    switch (msg.type as string) {

      case "init_status":
        this.onInitStatus((msg.cameras as CamState[]) ?? []);
        break;

      case "subscribed":
        // acknowledged by backend — no action needed
        break;

      case "frame": {
        const image = msg.image as string | undefined;
        if (!image) break;
        const blob = this._b64toBlob(image, "image/jpeg");
        const url  = URL.createObjectURL(blob);
        if (this._frameUrls[msg.cam as string]) {
          URL.revokeObjectURL(this._frameUrls[msg.cam as string]);
        }
        this._frameUrls[msg.cam as string] = url;
        this.onFrame(msg.cam as string, url);
        break;
      }

      case "event": {
        const data = (msg.data ?? {}) as CamEventData;
        const camId = msg.cam as string;
        // Route specialised events to dedicated callbacks first
        if (data.event === "stats") {
          this.onStats(camId, data as unknown as CamStatsData);
        } else if (data.event === "emotions") {
          this.onEmotions(camId, data as unknown as CamEmotionsData);
        }
        // Always also fire the generic handler so callers can log everything
        this.onEvent(camId, data);
        break;
      }

      case "cam_status":
        this.onCamStatus(msg.cam as string, Boolean(msg.online));
        break;

      default:
        break;
    }
  }

  private _b64toBlob(b64: string, mime: string): Blob {
    const bin = atob(b64);
    const buf = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
    return new Blob([buf], { type: mime });
  }
}
