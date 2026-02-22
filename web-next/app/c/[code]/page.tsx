"use client";

import { useState, useEffect, useMemo } from "react";
import Link from "next/link";
import { Download, ArrowLeft, Loader2, AlertTriangle } from "lucide-react";
import { resolveShortCode, getVisitorCard } from "@/services/touristApi";

/**
 * Module-level caches — survive React Strict Mode unmount→remount cycles.
 * useEffect runs multiple times in dev, but the cache prevents duplicate API calls.
 */
const _resolveCache = new Map<string, Promise<any>>();
const _cardBlobCache = new Map<string, Blob>();

export default function VisitorCardPage({ params }: { params: { code: string } }) {
  const shortCode = useMemo(() => String(params.code), [params.code]);

  const [resolveStatus, setResolveStatus] = useState<"loading" | "success" | "error">("loading");
  const [cardImageUrl, setCardImageUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [downloading, setDownloading] = useState(false);

  /* ── 1. Resolve short code + fetch image (module-level cache prevents duplicates) ── */
  useEffect(() => {
    if (!shortCode) return;
    let cancelled = false;

    // Use cached promise if available (survives Strict Mode remounts)
    const promise =
      _resolveCache.get(shortCode) ??
      resolveShortCode(shortCode).then(async (data) => {
        // Cache the blob too
        if (!_cardBlobCache.has(data.token)) {
          const blob = await getVisitorCard(data.token);
          _cardBlobCache.set(data.token, blob);
        }
        return data;
      });

    _resolveCache.set(shortCode, promise);

    promise
      .then((data) => {
        if (cancelled) return;
        // Use cached blob
        const blob = _cardBlobCache.get(data.token);
        if (blob) {
          const url = URL.createObjectURL(blob);
          setCardImageUrl(url);
        }
        setResolveStatus("success");
      })
      .catch((err) => {
        if (cancelled) return;
        setError((err as Error).message);
        setResolveStatus("error");
      });

    return () => { cancelled = true; };
  }, [shortCode]);

  /* ── Download handler ── */
  const handleDownload = async () => {
    setDownloading(true);
    try {
      const data = await resolveShortCode(shortCode);
      const blob = await getVisitorCard(data.token, true);
      const filename = `visitor_card_${Date.now()}.png`;
      const url = URL.createObjectURL(blob);
      const a = Object.assign(document.createElement("a"), {
        href: url,
        download: filename,
      });
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch (err) {
      alert("Download failed: " + (err as Error).message);
    } finally {
      setDownloading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 via-purple-50/30 to-blue-50/40 flex flex-col">
      {/* Header */}
      <div className="bg-white/80 backdrop-blur-sm border-b border-slate-200/50 px-4 py-3">
        <div className="max-w-2xl mx-auto flex items-center justify-between">
          <Link
            href="/"
            className="flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900 transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
            Back to Home
          </Link>
          <h1 className="text-lg font-bold text-gray-900">Visitor Card</h1>
          <div className="w-16" /> {/* Spacer */}
        </div>
      </div>

      {/* Main content */}
      <main className="flex-1 flex items-center justify-center px-4 py-8">
        {/* Loading */}
        {resolveStatus === "loading" && (
          <div className="text-center">
            <Loader2 className="w-10 h-10 text-violet-500 animate-spin mx-auto mb-3" />
            <p className="text-gray-600 font-medium">Loading your card...</p>
          </div>
        )}

        {/* Error */}
        {resolveStatus === "error" && (
          <div className="text-center max-w-md">
            <div className="bg-red-100 rounded-full w-16 h-16 flex items-center justify-center mx-auto mb-4">
              <AlertTriangle className="w-8 h-8 text-red-600" />
            </div>
            <h2 className="text-lg font-bold text-gray-900 mb-2">Unable to Load Card</h2>
            <p className="text-gray-600 text-sm leading-relaxed mb-4">
              {error ?? "Something went wrong. Please check the link and try again."}
            </p>
            <Link
              href="/"
              className="inline-block bg-violet-600 text-white px-6 py-2 rounded-lg text-sm font-semibold hover:bg-violet-700 transition-colors"
            >
              Return to Home
            </Link>
          </div>
        )}

        {/* Success - Card display */}
        {resolveStatus === "success" && cardImageUrl && (
          <div className="w-full max-w-2xl">
            <div className="bg-white rounded-2xl shadow-lg overflow-hidden">
              {/* Card image */}
              <div className="bg-gray-100 flex items-center justify-center min-h-96">
                <img
                  src={cardImageUrl}
                  alt="Visitor Card"
                  className="w-full h-auto object-contain"
                />
              </div>

              {/* Action buttons */}
              <div className="p-6 border-t border-gray-200 flex gap-3">
                <button
                  className="flex-1 flex items-center justify-center gap-2 bg-gradient-to-r from-violet-600 to-purple-600 text-white py-3 rounded-lg font-semibold hover:from-violet-700 hover:to-purple-700 transition-all"
                  onClick={handleDownload}
                  disabled={downloading}
                >
                  {downloading ? (
                    <>
                      <Loader2 className="w-5 h-5 animate-spin" />
                      Downloading...
                    </>
                  ) : (
                    <>
                      <Download className="w-5 h-5" />
                      Download Card
                    </>
                  )}
                </button>
              </div>
            </div>

            {/* Info footer */}
            <div className="mt-6 text-center text-xs text-gray-500">
              <p>This visitor card is valid for a limited time.</p>
              <p className="mt-1">Short code: <span className="font-mono text-gray-700">{shortCode}</span></p>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}